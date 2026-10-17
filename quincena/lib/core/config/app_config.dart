/// Entornos de ejecución de la aplicación Quincena
enum AppEnvironment {
  dev,
  prod,
}

/// Configuración centralizada de entorno y variables de compilación.
///
/// Permite inyectar valores mediante `--dart-define` al compilar o debuggear:
/// - `--dart-define=ENVIRONMENT=dev` (por defecto)
/// - `--dart-define=ENVIRONMENT=prod`
/// - `--dart-define=API_BASE_URL=https://...` (opcional para sobreescribir)
abstract final class AppConfig {
  static const String _rawEnv = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'dev',
  );

  static const String _customApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Entorno activo inferido
  static AppEnvironment get environment {
    switch (_rawEnv.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.dev;
    }
  }

  static bool get isDev => environment == AppEnvironment.dev;
  static bool get isProd => environment == AppEnvironment.prod;

  /// Nombre legible del entorno actual
  static String get environmentName => isProd ? 'Producción' : 'Desarrollo';

  /// URL base por defecto del backend según el entorno
  static String? get configuredApiUrl {
    if (_customApiUrl.isNotEmpty) {
      return _customApiUrl;
    }
    if (isProd) {
      // URL de producción por defecto
      return 'https://api.quincena.app/v1';
    }
    // En dev retorna null para permitir la detección de localhost / 10.0.2.2 en ApiClient
    return null;
  }
}
