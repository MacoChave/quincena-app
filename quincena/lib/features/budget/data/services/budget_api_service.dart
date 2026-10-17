import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/network/api_exception.dart';
import 'package:quincena/features/dashboard/data/models/dashboard_data.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import '../models/models.dart';

/// Resultado consolidado de asignaciones y resumen financiero
class AllocationsResult {
  const AllocationsResult({
    required this.allocations,
    required this.summary,
  });

  final List<BudgetAllocation> allocations;
  final AllocationsSummary summary;
}

/// Servicio HTTP para la gestión de Presupuestos Base Cero (RF-03) y Plantillas (RF-04)
class BudgetApiService {
  BudgetApiService(this._client);

  final ApiClient _client;

  /// Obtiene las asignaciones y resumen financiero para un ciclo quincenal
  Future<AllocationsResult> getCycleAllocations(String cycleId) async {
    final response = await _client.get('/budget-allocations?cycleId=$cycleId');
    if (response is Map<String, dynamic>) {
      final allocsList = (response['allocations'] as List<dynamic>?) ?? [];
      final summaryJson = response['summary'] as Map<String, dynamic>? ?? {};

      final allocations = allocsList
          .map((item) => BudgetAllocation.fromJson(item as Map<String, dynamic>))
          .toList();
      final summary = AllocationsSummary.fromJson(summaryJson);

      return AllocationsResult(allocations: allocations, summary: summary);
    }

    return const AllocationsResult(
      allocations: [],
      summary: AllocationsSummary(),
    );
  }

  /// Crea una nueva partida presupuestaria en el ciclo activo
  Future<BudgetAllocation> createAllocation({
    required String cycleId,
    required String categoryId,
    required double allocatedAmount,
    String? destinationAccountId,
  }) async {
    final body = <String, dynamic>{
      'cycle_id': cycleId,
      'category_id': categoryId,
      'allocated_amount': allocatedAmount,
    };
    if (destinationAccountId != null && destinationAccountId.isNotEmpty) {
      body['destination_account_id'] = destinationAccountId;
    }

    final response = await _client.post(
      '/budget-allocations',
      body: body,
    );

    return BudgetAllocation.fromJson(response as Map<String, dynamic>);
  }

  /// Actualiza monto o cuenta destino de una asignación existente
  Future<BudgetAllocation> updateAllocation(
    String id, {
    double? allocatedAmount,
    String? destinationAccountId,
    bool clearDestinationAccount = false,
  }) async {
    final body = <String, dynamic>{};
    if (allocatedAmount != null) {
      body['allocated_amount'] = allocatedAmount;
    }
    if (clearDestinationAccount) {
      body['destination_account_id'] = null;
    } else if (destinationAccountId != null) {
      body['destination_account_id'] = destinationAccountId;
    }

    final response = await _client.patch(
      '/budget-allocations/$id',
      body: body,
    );

    return BudgetAllocation.fromJson(response as Map<String, dynamic>);
  }

  /// Elimina una partida presupuestaria
  Future<void> deleteAllocation(String id) async {
    await _client.delete('/budget-allocations/$id');
  }

  /// Obtiene las plantillas maestras para el período (first_half / second_half)
  Future<List<BudgetTemplate>> getTemplates(QuincenaPeriod period) async {
    final response = await _client.get('/budget-templates?period=${period.value}');
    if (response is List) {
      return response
          .map((item) => BudgetTemplate.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Crea un renglón en la plantilla maestra
  Future<BudgetTemplate> createTemplate({
    required QuincenaPeriod period,
    required String categoryId,
    required double defaultAmount,
    String? destinationAccountId,
  }) async {
    final body = <String, dynamic>{
      'period': period.value,
      'category_id': categoryId,
      'default_amount': defaultAmount,
    };
    if (destinationAccountId != null && destinationAccountId.isNotEmpty) {
      body['destination_account_id'] = destinationAccountId;
    }

    final response = await _client.post(
      '/budget-templates',
      body: body,
    );

    return BudgetTemplate.fromJson(response as Map<String, dynamic>);
  }

  /// Actualiza un renglón de plantilla existente
  Future<BudgetTemplate> updateTemplate(
    String id, {
    double? defaultAmount,
    String? destinationAccountId,
    bool clearDestinationAccount = false,
  }) async {
    final body = <String, dynamic>{};
    if (defaultAmount != null) {
      body['default_amount'] = defaultAmount;
    }
    if (clearDestinationAccount) {
      body['destination_account_id'] = null;
    } else if (destinationAccountId != null) {
      body['destination_account_id'] = destinationAccountId;
    }

    final response = await _client.patch(
      '/budget-templates/$id',
      body: body,
    );

    return BudgetTemplate.fromJson(response as Map<String, dynamic>);
  }

  /// Elimina un renglón de plantilla
  Future<void> deleteTemplate(String id) async {
    await _client.delete('/budget-templates/$id');
  }

  /// Aplica la plantilla predefinida al ciclo activo (RF-04)
  Future<AllocationsResult> applyTemplate({
    required String cycleId,
    bool overwrite = false,
  }) async {
    final response = await _client.post(
      '/budget-templates/apply',
      body: {
        'cycle_id': cycleId,
        'overwrite': overwrite,
      },
    );

    if (response is Map<String, dynamic>) {
      final allocsList = (response['allocations'] as List<dynamic>?) ?? [];
      final summaryJson = response['summary'] as Map<String, dynamic>? ?? {};

      final allocations = allocsList
          .map((item) => BudgetAllocation.fromJson(item as Map<String, dynamic>))
          .toList();
      final summary = AllocationsSummary.fromJson(summaryJson);

      return AllocationsResult(allocations: allocations, summary: summary);
    }

    return getCycleAllocations(cycleId);
  }

  /// Guarda el estado de las partidas del ciclo actual como plantilla maestra (RF-04)
  Future<dynamic> saveCycleAsTemplate({
    required String cycleId,
  }) async {
    return await _client.post(
      '/budget-templates/save-from-cycle',
      body: {
        'cycle_id': cycleId,
      },
    );
  }

  /// Obtiene la lista de categorías activas
  Future<List<Category>> getCategories() async {
    final response = await _client.get('/categories');
    if (response is List) {
      return response
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Obtiene la lista de cuentas financieras
  Future<List<FinancialAccount>> getFinancialAccounts() async {
    final response = await _client.get('/financial-accounts');
    if (response is List) {
      return response
          .map((item) => FinancialAccount.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Obtiene el ciclo quincenal activo actual
  Future<DashboardCycle?> getCurrentCycle() async {
    try {
      final response = await _client.get('/biweekly-cycles/current');
      if (response is Map<String, dynamic>) {
        return DashboardCycle.fromJson(response);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    return null;
  }
}
