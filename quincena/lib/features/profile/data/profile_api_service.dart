import '../../../core/network/api_client.dart';
import 'models/user_profile.dart';

/// Servicio para interactuar con el módulo de perfiles de Quincena API.
class ProfileApiService {
  ProfileApiService(this._client);

  final ApiClient _client;

  /// Obtiene los datos del perfil del usuario autenticado
  Future<UserProfile> getMe({String? userEmail}) async {
    final response = await _client.get('/profiles/me');
    return UserProfile.fromJson(response as Map<String, dynamic>, userEmail: userEmail);
  }

  /// Actualiza los datos del perfil (nombre completo, moneda por defecto)
  Future<UserProfile> updateProfile({
    String? fullName,
    String? currency,
    double? defaultIncome,
    String? userEmail,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (currency != null) body['currency'] = currency;
    if (defaultIncome != null) body['default_income'] = defaultIncome;

    final response = await _client.patch('/profiles/me', body: body);
    return UserProfile.fromJson(response as Map<String, dynamic>, userEmail: userEmail);
  }
}
