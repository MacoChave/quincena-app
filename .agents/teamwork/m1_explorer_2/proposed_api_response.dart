import 'dart:convert';
import 'package:http/http.dart' as http;

/// Representa una respuesta exitosa tipada de la API REST de Quincena.
///
/// Encapsula el código de estado HTTP, la carga útil deserializada [data],
/// el mensaje informativo opcional [message] y el cuerpo crudo decodificado [rawBody].
class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.message,
    this.rawBody,
    this.headers,
  });

  /// Código de estado HTTP retornado por el servidor (p. ej. 200, 201).
  final int statusCode;

  /// Carga útil procesada o transformada a través de un deserializador genérico [T].
  final T data;

  /// Mensaje descriptivo proporcionado por el backend en el payload JSON.
  final String? message;

  /// Contenido decodificado original (Map, List, o String) para acceso directo flexible.
  final dynamic rawBody;

  /// Encabezados de la respuesta HTTP recibida.
  final Map<String, String>? headers;

  /// Indica si la petición fue exitosa (códigos 2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Acceso indexado dinámico para facilitar consumo cuando [data] o [rawBody] es un mapa.
  ///
  /// Permite sintaxis como `response['scan']` o `response['message']` sin necesidad de casts manuales.
  dynamic operator [](String key) {
    if (data is Map<String, dynamic>) {
      return (data as Map<String, dynamic>)[key];
    }
    if (rawBody is Map<String, dynamic>) {
      return (rawBody as Map<String, dynamic>)[key];
    }
    return null;
  }

  /// Constructor factory para instanciar a partir de una [http.Response].
  factory ApiResponse.fromResponse(
    http.Response response, {
    T Function(dynamic json)? fromJson,
  }) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    String? message;
    if (decoded is Map<String, dynamic>) {
      final msg = decoded['message'];
      if (msg is List) {
        message = msg.join(', ');
      } else if (msg is String) {
        message = msg;
      }
    }

    final T data = fromJson != null
        ? fromJson(decoded)
        : (decoded is T ? decoded : decoded as T);

    return ApiResponse<T>(
      statusCode: response.statusCode,
      data: data,
      message: message,
      rawBody: decoded,
      headers: response.headers,
    );
  }

  @override
  String toString() =>
      'ApiResponse<$T>(statusCode: $statusCode, message: $message, data: $data)';
}
