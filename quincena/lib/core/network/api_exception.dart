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

  @override
  String toString() => 'ApiException($statusCode): $message';
}
