import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

export 'api_response.dart';

/// Cliente HTTP centralizado para consumir el API REST de Quincena.
///
/// Gestiona headers comunes, token JWT en Bearer y deserialización de errores.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _httpClient;
  String _baseUrl;
  String? _authToken;

  /// Callback invocado cuando el servidor devuelve un 401 (Sesión inválida o expirada)
  VoidCallback? onUnauthorized;

  static String get _defaultBaseUrl {
    final configured = AppConfig.configuredApiUrl;
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    // Por defecto en desarrollo:
    // - En dispositivo físico Android por USB (con "adb reverse tcp:3000 tcp:3000"): usa 127.0.0.1
    // - En emulador Android nativo (AVD): usa 10.0.2.2
    // - Si deseas conectar por Wi-Fi sin cable: usa tu IP local (http://192.168.10.116:3000/v1)
    if (!kIsWeb && Platform.isAndroid) {
      // 127.0.0.1 permite tráfico directo por cable USB mediante el túnel ADB
      return 'http://127.0.0.1:3000/v1';
    }
    return 'http://localhost:3000/v1';
  }

  String get baseUrl => _baseUrl;
  void setBaseUrl(String url) => _baseUrl = url;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Map<String, String> _buildHeaders([Map<String, String>? extraHeaders]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await _httpClient.get(
      uri,
      headers: _buildHeaders(headers),
    );
    return _handleResponse(response);
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await _httpClient.post(
      uri,
      headers: _buildHeaders(headers),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await _httpClient.patch(
      uri,
      headers: _buildHeaders(headers),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<dynamic> delete(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final response = await _httpClient.delete(
      uri,
      headers: _buildHeaders(headers),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// Sube un archivo con campos opcionales mediante petición HTTP multipart/form-data (POST).
  ///
  /// - [path]: Ruta del endpoint relativo (p. ej. `/receipt-scans/upload`).
  /// - [file]: Archivo [File] a transferir en la petición.
  /// - [fieldName]: Nombre del campo de archivo esperado por el backend (por defecto `'file'`).
  /// - [fields]: Pares clave-valor de campos de texto adicionales en el multipart.
  /// - [headers]: Encabezados HTTP complementarios (se preserva automáticamente el boundary multipart).
  /// - [fromJson]: Función transformadora opcional para deserializar el resultado tipado [T].
  ///
  /// Inyecta automáticamente el token JWT en el encabezado `Authorization: Bearer <token>` si está autenticado.
  /// Lanza [ApiException] en códigos HTTP fuera de 2xx o si el archivo no existe.
  Future<ApiResponse<T>> uploadMultipart<T>(
    String path, {
    required File file,
    String fieldName = 'file',
    Map<String, String>? fields,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    // 1. Inyectar cabecera de autenticación y aceptación
    if (_authToken != null && _authToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    request.headers['Accept'] = 'application/json';

    // 2. Inyectar headers personalizados omitiendo Content-Type para preservar el boundary generado
    if (headers != null) {
      headers.forEach((key, value) {
        if (key.trim().toLowerCase() != 'content-type') {
          request.headers[key] = value;
        }
      });
    }

    // 3. Inyectar campos de formulario adicionales
    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    // 4. Validar existencia del archivo
    if (!await file.exists()) {
      throw ApiException(
        statusCode: 400,
        message: 'El archivo para subida no existe en la ruta: ${file.path}',
      );
    }

    // 5. Adjuntar archivo multipart
    final multipartFile = await http.MultipartFile.fromPath(
      fieldName,
      file.path,
    );
    request.files.add(multipartFile);

    // 6. Transmitir y procesar respuesta
    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    return _handleMultipartResponse<T>(response, fromJson: fromJson);
  }

  ApiResponse<T> _handleMultipartResponse<T>(
    http.Response response, {
    T Function(dynamic json)? fromJson,
  }) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      String? message;
      if (body is Map<String, dynamic>) {
        final msg = body['message'];
        if (msg is List) {
          message = msg.join(', ');
        } else if (msg is String) {
          message = msg;
        }
      }

      final T data = fromJson != null
          ? fromJson(body)
          : (body is T ? body : body as T);

      return ApiResponse<T>(
        statusCode: response.statusCode,
        data: data,
        message: message,
        rawBody: body,
        headers: response.headers,
      );
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    String message = 'Ha ocurrido un error en la solicitud de subida.';
    String? error;

    if (body is Map<String, dynamic>) {
      final msg = body['message'];
      if (msg is List) {
        message = msg.join(', ');
      } else if (msg is String) {
        message = msg;
      }
      error = body['error'] as String?;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      error: error,
      details: body,
    );
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    String message = 'Ha ocurrido un error en la solicitud.';
    String? error;

    if (body is Map<String, dynamic>) {
      final msg = body['message'];
      if (msg is List) {
        message = msg.join(', ');
      } else if (msg is String) {
        message = msg;
      }
      error = body['error'] as String?;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      error: error,
      details: body,
    );
  }

  void dispose() {
    _httpClient.close();
  }
}
