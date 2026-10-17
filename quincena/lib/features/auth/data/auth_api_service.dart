import '../../../core/network/api_client.dart';
import 'models/auth_tokens.dart';
import 'models/auth_user.dart';

class LoginResult {
  const LoginResult({
    required this.tokens,
    required this.user,
  });

  final AuthTokens tokens;
  final AuthUser user;
}

/// Servicio encargado de interactuar con el módulo de Autenticación de Quincena API (RF-AUTH).
class AuthApiService {
  AuthApiService(this._client);

  final ApiClient _client;

  /// Inicia sesión con correo y contraseña (RF-AUTH-01, CA-A1.1 - CA-A1.4)
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      '/auth/login',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = response as Map<String, dynamic>;
    final tokens = AuthTokens.fromJson(data);
    
    // El backend puede enviar 'user' o los datos directamente
    final userData = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    final user = AuthUser.fromJson(userData);

    // Configurar token en el cliente para solicitudes posteriores
    _client.setAuthToken(tokens.accessToken);

    return LoginResult(tokens: tokens, user: user);
  }

  /// Registro de nuevo usuario (RF-AUTH-01, CA-A1.2)
  Future<void> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    await _client.post(
      '/auth/register',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (fullName != null && fullName.trim().isNotEmpty)
          'full_name': fullName.trim(),
      },
    );
  }

  /// Solicitar recuperación de contraseña (RF-AUTH-02, CA-A2.1, CA-A2.2)
  /// Siempre devuelve un mensaje genérico por seguridad y prevención de enumeración.
  Future<String> requestPasswordReset({required String email}) async {
    final response = await _client.post(
      '/auth/forgot-password',
      body: {
        'email': email.trim().toLowerCase(),
      },
    );

    if (response is Map<String, dynamic> && response['message'] != null) {
      return response['message'] as String;
    }

    return 'Si el correo coincide con una cuenta activa, te hemos enviado un enlace o código de restablecimiento.';
  }

  /// Actualizar contraseña (RF-AUTH-02, CA-A2.3)
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/update-password',
      body: {
        'password': newPassword,
      },
    );
  }

  /// Cierre de sesión seguro en el servidor e invalidación de token (RF-AUTH-03, CA-A3.1, CA-A3.2)
  Future<void> logout() async {
    try {
      await _client.post('/auth/logout');
    } finally {
      _client.setAuthToken(null);
    }
  }

  /// Dar de baja y eliminar la cuenta definitivamente (RF-AUTH-04, CA-A4.1 - CA-A4.4)
  Future<void> deleteAccount({
    required String currentPassword,
    required String confirmationKeyword,
  }) async {
    try {
      await _client.post(
        '/auth/delete-account',
        body: {
          'password': currentPassword,
          'confirmation': confirmationKeyword,
        },
      );
    } finally {
      _client.setAuthToken(null);
    }
  }
}
