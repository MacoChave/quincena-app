import 'dart:io';

/// Excepción tipada para respuestas de error de la API REST de Quincena.
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.error,
  });

  final int statusCode;
  final String message;
  final String? error;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => statusCode >= 500;

  /// Retorna exclusivamente el mensaje legible para el usuario
  /// (sin prefijos técnicos como `ApiException(401): `)
  @override
  String toString() => message;

  /// Detalles completos para logs o depuración
  String get debugDetails => 'ApiException($statusCode): $message (error: $error)';

  /// Extrae un mensaje limpio y amigable para el usuario a partir de cualquier error o excepción
  static String extractMessage(dynamic error) {
    if (error == null) return 'Ha ocurrido un error inesperado.';

    if (error is ApiException) {
      return error.message;
    }

    if (error is SocketException) {
      return 'No se pudo conectar con el servidor. Verifica que el backend esté activo y tu conexión de red.';
    }

    if (error is HttpException) {
      return 'Error en la conexión con el servidor.';
    }

    if (error is FormatException) {
      return 'Respuesta inesperada del servidor.';
    }

    final raw = error.toString().trim();

    // Elimina prefijos comunes de excepciones:
    // "ApiException(401): ...", "ApiException: ...", "Exception: ..."
    final cleaned = raw.replaceFirst(
      RegExp(r'^(ApiException(\(\d+\))?:\s*|Exception:\s*)', caseSensitive: false),
      '',
    );

    return cleaned.isNotEmpty ? cleaned : 'Ha ocurrido un error inesperado.';
  }
}
