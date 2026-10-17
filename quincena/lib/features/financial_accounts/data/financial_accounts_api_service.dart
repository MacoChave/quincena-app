import '../../../core/network/api_client.dart';
import '../models/financial_account.dart';

/// Servicio de integración HTTP para la gestión de cuentas financieras (RF-01)
class FinancialAccountsApiService {
  FinancialAccountsApiService(this._apiClient);

  final ApiClient _apiClient;

  /// Obtiene el listado de cuentas financieras activas del usuario
  Future<List<FinancialAccount>> getAccounts() async {
    final response = await _apiClient.get('/financial-accounts');
    if (response is List) {
      return response
          .map((item) =>
              FinancialAccount.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Crea una nueva cuenta financiera
  Future<FinancialAccount> createAccount({
    required String name,
    required AccountType accountType,
    String currency = 'GTQ',
    String colorHex = '#79ADDC',
    String icon = 'account_balance',
    bool isDefault = false,
    double initialBalance = 0.0,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'account_type': accountType.value,
      'currency': currency.toUpperCase(),
      'color_hex': colorHex,
      'icon': icon,
      'is_default': isDefault,
      'initial_balance': initialBalance,
    };

    final response = await _apiClient.post(
      '/financial-accounts',
      body: payload,
    );

    return FinancialAccount.fromJson(response as Map<String, dynamic>);
  }

  /// Actualiza una cuenta financiera existente
  Future<FinancialAccount> updateAccount(
    String id, {
    String? name,
    AccountType? accountType,
    String? currency,
    String? colorHex,
    String? icon,
    bool? isDefault,
    bool? isArchived,
    double? initialBalance,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name.trim();
    if (accountType != null) payload['account_type'] = accountType.value;
    if (currency != null) payload['currency'] = currency.toUpperCase();
    if (colorHex != null) payload['color_hex'] = colorHex;
    if (icon != null) payload['icon'] = icon;
    if (isDefault != null) payload['is_default'] = isDefault;
    if (isArchived != null) payload['is_archived'] = isArchived;
    if (initialBalance != null) payload['initial_balance'] = initialBalance;

    final response = await _apiClient.patch(
      '/financial-accounts/$id',
      body: payload,
    );

    return FinancialAccount.fromJson(response as Map<String, dynamic>);
  }

  /// Archiva una cuenta financiera (Soft Delete - CA-01.3)
  Future<void> archiveAccount(String id) async {
    await _apiClient.delete('/financial-accounts/$id');
  }

  /// Establece una cuenta como predeterminada (CA-01.2)
  Future<FinancialAccount> setDefaultAccount(String id) async {
    return updateAccount(id, isDefault: true);
  }
}
