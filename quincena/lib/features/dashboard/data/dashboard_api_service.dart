import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'models/dashboard_data.dart';

/// Servicio para consumir los datos de la pantalla Inicio / Dashboard (Quincena Activa).
class DashboardApiService {
  DashboardApiService(this._client);

  final ApiClient _client;

  /// Obtiene los datos consolidados del Dashboard.
  /// Intenta consumir el endpoint optimizado `GET /biweekly-cycles/dashboard`.
  /// Si no está disponible, realiza fallback a los endpoints individuales.
  Future<DashboardData> getDashboard() async {
    try {
      final response = await _client.get('/biweekly-cycles/dashboard');
      if (response is Map<String, dynamic>) {
        return DashboardData.fromJson(response);
      }
    } on ApiException catch (e) {
      // Si el endpoint consolidado aún no existe o el ciclo no existe (404), intentamos fallback
      if (e.statusCode == 404) {
        return _fetchFallbackDashboard();
      }
      rethrow;
    } catch (_) {
      return _fetchFallbackDashboard();
    }

    return _fetchFallbackDashboard();
  }

  /// Fallback: consulta `GET /biweekly-cycles/current` y `GET /budget-allocations?cycleId=...`
  Future<DashboardData> _fetchFallbackDashboard() async {
    try {
      final cycleJson = await _client.get('/biweekly-cycles/current');
      if (cycleJson is! Map<String, dynamic>) {
        return _buildEmptySuggestedDashboard();
      }

      final cycle = DashboardCycle.fromJson(cycleJson);

      // Obtener asignaciones de presupuesto del ciclo
      final allocationsJson = await _client.get(
        '/budget-allocations?cycleId=${cycle.id}',
      );

      if (allocationsJson is Map<String, dynamic>) {
        final summary = DashboardSummary.fromJson(
          allocationsJson['summary'] as Map<String, dynamic>? ?? {},
        );
        final list = allocationsJson['allocations'] as List<dynamic>? ?? [];
        final categories = list
            .map((item) => DashboardCategory.fromJson(item as Map<String, dynamic>))
            .toList();

        return DashboardData(
          hasActiveCycle: true,
          cycle: cycle,
          summary: summary,
          categories: categories,
        );
      }

      return DashboardData(
        hasActiveCycle: true,
        cycle: cycle,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // No hay ciclo activo en la BD
        return _buildEmptySuggestedDashboard();
      }
      rethrow;
    }
  }

  DashboardData _buildEmptySuggestedDashboard() {
    final now = DateTime.now();
    final isFirstHalf = now.day <= 15;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;

    return DashboardData(
      hasActiveCycle: false,
      suggestedPeriod: SuggestedPeriod(
        year: now.year,
        month: now.month,
        period: isFirstHalf ? 'first_half' : 'second_half',
        startDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-${isFirstHalf ? '01' : '16'}',
        endDate: '${now.year}-${now.month.toString().padLeft(2, '0')}-${isFirstHalf ? '15' : lastDay}',
      ),
    );
  }

  Future<void> initCurrentCycle({double? customIncome}) async {
    final body = <String, dynamic>{};
    if (customIncome != null) body['total_income'] = customIncome;
    try {
      await _client.post('/biweekly-cycles/init-current', body: body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Fallback a POST /biweekly-cycles tradicional
        final now = DateTime.now();
        final isFirstHalf = now.day <= 15;
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final startDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${isFirstHalf ? '01' : '16'}';
        final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${isFirstHalf ? '15' : lastDay}';

        await _client.post('/biweekly-cycles', body: {
          'year': now.year,
          'month': now.month,
          'period': isFirstHalf ? 'first_half' : 'second_half',
          'start_date': startDate,
          'end_date': endDate,
          'total_income': customIncome ?? 7000.0,
        });
      } else {
        rethrow;
      }
    }
  }
}
