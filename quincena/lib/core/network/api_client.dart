import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exception.dart';

/// Cliente HTTP centralizado para consumir el API REST de Quincena.
///
/// Gestiona headers comunes, token JWT en Bearer y deserialización de errores.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(),
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

    // Si corre en emulador Android nativo usa 10.0.2.2, de lo contrario localhost
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:3000/v1';
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
    final response = await _httpClient.get(uri, headers: _buildHeaders(headers));
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
    );
  }

  void dispose() {
    _httpClient.close();
  }
}
