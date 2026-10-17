import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../profile/data/models/user_profile.dart';
import '../../profile/data/profile_api_service.dart';
import 'auth_api_service.dart';
import 'models/auth_user.dart';

/// Gestor de sesión global y estado reactivo de autenticación para Quincena.
///
/// Implementa principios de desacoplamiento y estado limpio:
/// Notifica a los listeners cuando el usuario inicia sesión, cierra sesión
/// o cuando el perfil se actualiza.
class AuthSessionManager extends ChangeNotifier {
  AuthSessionManager({
    required ApiClient apiClient,
    AuthApiService? authApiService,
    ProfileApiService? profileApiService,
  })  : _apiClient = apiClient,
        _authApiService = authApiService ?? AuthApiService(apiClient),
        _profileApiService = profileApiService ?? ProfileApiService(apiClient) {
    _apiClient.onUnauthorized = _handleUnauthorized;
  }

  final ApiClient _apiClient;
  final AuthApiService _authApiService;
  final ProfileApiService _profileApiService;

  AuthUser? _user;
  UserProfile? _profile;
  bool _isLoading = false;
  String? _lastErrorMessage;

  AuthUser? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get lastErrorMessage => _lastErrorMessage;
  ApiClient get apiClient => _apiClient;

  void _handleUnauthorized() {
    clearSession();
  }

  /// Limpia todos los tokens y estado de memoria al cerrar sesión o invalidarse
  void clearSession() {
    _user = null;
    _profile = null;
    _apiClient.setAuthToken(null);
    notifyListeners();
  }

  /// Inicia sesión consumiendo el API
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      final result = await _authApiService.login(email: email, password: password);
      _user = result.user;

      // Intentar cargar el perfil ampliado del usuario
      try {
        _profile = await _profileApiService.getMe(userEmail: _user?.email);
      } catch (_) {
        // Fallback básico con datos del usuario si el perfil aún se está sincronizando
        _profile = UserProfile(
          id: _user!.id,
          email: _user!.email,
          fullName: _user!.fullName,
          currency: _user!.defaultCurrency,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _lastErrorMessage = e.toString().replaceFirst('ApiException: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Registrar nuevo usuario
  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _isLoading = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      await _authApiService.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _lastErrorMessage = e.toString().replaceFirst('ApiException: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Solicitar recuperación de contraseña (RF-AUTH-02)
  Future<String> requestPasswordReset(String email) async {
    return _authApiService.requestPasswordReset(email: email);
  }

  /// Actualizar contraseña
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authApiService.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Cierra sesión en el servidor y purga estados locales (RF-AUTH-03)
  Future<void> logout() async {
    try {
      await _authApiService.logout();
    } finally {
      clearSession();
    }
  }

  /// Dar de baja y eliminar la cuenta definitivamente (RF-AUTH-04)
  Future<void> deleteAccount({
    required String currentPassword,
    required String confirmationKeyword,
  }) async {
    try {
      await _authApiService.deleteAccount(
        currentPassword: currentPassword,
        confirmationKeyword: confirmationKeyword,
      );
    } finally {
      clearSession();
    }
  }

  /// Actualiza los datos del perfil
  Future<void> updateProfile({String? fullName, String? currency}) async {
    if (_profile == null) return;
    final updated = await _profileApiService.updateProfile(
      fullName: fullName,
      currency: currency,
      userEmail: _user?.email,
    );
    _profile = updated;
    notifyListeners();
  }

  /// Refresca el perfil del usuario autenticado
  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    try {
      _profile = await _profileApiService.getMe(userEmail: _user?.email);
      notifyListeners();
    } catch (_) {}
  }
}
