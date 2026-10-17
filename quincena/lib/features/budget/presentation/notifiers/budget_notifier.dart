import 'package:flutter/foundation.dart' hide Category;
import '../../../dashboard/data/models/dashboard_data.dart';
import '../../../financial_accounts/models/financial_account.dart';
import '../../data/models/models.dart';
import '../../data/services/budget_api_service.dart';

/// Notificador de estado reactivo para la pantalla de Presupuestos (RF-03 & RF-04)
/// Garantiza recálculo instantáneo de Presupuesto Base Cero (<16ms, 60fps)
class BudgetNotifier extends ChangeNotifier {
  BudgetNotifier({required BudgetApiService apiService})
      : _apiService = apiService;

  final BudgetApiService _apiService;

  // Estado del Ciclo Activo y Asignaciones (RF-03)
  DashboardCycle? _activeCycle;
  List<BudgetAllocation> _allocations = [];
  AllocationsSummary _summary = const AllocationsSummary();

  // Categorías y Cuentas de catálogo
  List<Category> _categories = [];
  List<FinancialAccount> _accounts = [];

  // Plantillas Maestras (RF-04)
  List<BudgetTemplate> _templatesFirstHalf = [];
  List<BudgetTemplate> _templatesSecondHalf = [];
  QuincenaPeriod _selectedTemplatePeriod = QuincenaPeriod.firstHalf;

  // Control de carga y errores
  bool _isLoading = false;
  bool _isActionLoading = false;
  String? _errorMessage;

  // Getters públicos
  DashboardCycle? get activeCycle => _activeCycle;
  List<BudgetAllocation> get allocations => List.unmodifiable(_allocations);
  AllocationsSummary get summary => _summary;
  List<Category> get categories => List.unmodifiable(_categories);
  List<FinancialAccount> get accounts => List.unmodifiable(_accounts);
  List<BudgetTemplate> get templatesFirstHalf => List.unmodifiable(_templatesFirstHalf);
  List<BudgetTemplate> get templatesSecondHalf => List.unmodifiable(_templatesSecondHalf);
  QuincenaPeriod get selectedTemplatePeriod => _selectedTemplatePeriod;
  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;

  /// Plantillas correspondientes al período seleccionado en la pestaña de plantillas
  List<BudgetTemplate> get currentTemplates =>
      _selectedTemplatePeriod == QuincenaPeriod.firstHalf
          ? _templatesFirstHalf
          : _templatesSecondHalf;

  /// Resumen dinámico agrupado por cuenta financiera de fondeo (CA-03.3)
  List<FundingAccountSummary> get fundingSummaries =>
      FundingAccountSummary.groupFromAllocations(
        allocations: _allocations,
        knownAccounts: _accounts,
      );

  /// Carga inicial de datos consolidada
  Future<void> loadData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Obtener ciclo actual
      _activeCycle = await _apiService.getCurrentCycle();

      // 2. Obtener categorías y cuentas financieras
      final categoriesFuture = _apiService.getCategories();
      final accountsFuture = _apiService.getFinancialAccounts();
      final templatesFirstFuture = _apiService.getTemplates(QuincenaPeriod.firstHalf);
      final templatesSecondFuture = _apiService.getTemplates(QuincenaPeriod.secondHalf);

      final results = await Future.wait([
        categoriesFuture,
        accountsFuture,
        templatesFirstFuture,
        templatesSecondFuture,
      ]);

      _categories = results[0] as List<Category>;
      _accounts = results[1] as List<FinancialAccount>;
      _templatesFirstHalf = results[2] as List<BudgetTemplate>;
      _templatesSecondHalf = results[3] as List<BudgetTemplate>;

      // 3. Si hay ciclo activo, cargar sus asignaciones
      if (_activeCycle != null) {
        final allocResult = await _apiService.getCycleAllocations(_activeCycle!.id);
        _allocations = allocResult.allocations;
        _summary = allocResult.summary;
      } else {
        _allocations = [];
        _summary = const AllocationsSummary();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recálculo dinámico en memoria de Presupuesto Base Cero
  /// Se ejecuta instantáneamente (< 16 ms) ante cualquier cambio en el formulario
  void recalculateZeroBase() {
    final totalIncome = _activeCycle?.totalIncome ?? _summary.totalIncome;
    final totalAllocated = _allocations.fold<double>(
      0.0,
      (sum, item) => sum + item.allocatedAmount,
    );
    final totalSpent = _allocations.fold<double>(
      0.0,
      (sum, item) => sum + item.spentAmount,
    );
    final unallocated = totalIncome - totalAllocated;
    final isBalanced = unallocated.abs() < 0.01;

    _summary = _summary.copyWith(
      totalIncome: totalIncome,
      totalAllocated: totalAllocated,
      unallocated: unallocated,
      totalSpent: totalSpent,
      totalAvailable: totalAllocated - totalSpent,
      isBalanced: isBalanced,
    );
    notifyListeners();
  }

  /// Cambia la pestaña de plantillas (1ra vs 2da Quincena)
  void switchTemplatePeriod(QuincenaPeriod period) {
    if (_selectedTemplatePeriod != period) {
      _selectedTemplatePeriod = period;
      notifyListeners();
    }
  }

  /// Refresca únicamente las asignaciones del ciclo
  Future<void> refreshAllocations() async {
    if (_activeCycle == null) return;
    try {
      final allocResult = await _apiService.getCycleAllocations(_activeCycle!.id);
      _allocations = allocResult.allocations;
      _summary = allocResult.summary;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Refresca las plantillas maestras
  Future<void> refreshTemplates() async {
    try {
      final first = await _apiService.getTemplates(QuincenaPeriod.firstHalf);
      final second = await _apiService.getTemplates(QuincenaPeriod.secondHalf);
      _templatesFirstHalf = first;
      _templatesSecondHalf = second;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Crear una asignación en el ciclo activo
  Future<void> createAllocation({
    required String categoryId,
    required double allocatedAmount,
    String? destinationAccountId,
  }) async {
    if (_activeCycle == null) throw Exception('No hay un ciclo activo');
    _isActionLoading = true;
    notifyListeners();

    try {
      await _apiService.createAllocation(
        cycleId: _activeCycle!.id,
        categoryId: categoryId,
        allocatedAmount: allocatedAmount,
        destinationAccountId: destinationAccountId,
      );
      await refreshAllocations();
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Actualizar asignación existente
  Future<void> updateAllocation(
    String id, {
    double? allocatedAmount,
    String? destinationAccountId,
    bool clearDestinationAccount = false,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      await _apiService.updateAllocation(
        id,
        allocatedAmount: allocatedAmount,
        destinationAccountId: destinationAccountId,
        clearDestinationAccount: clearDestinationAccount,
      );
      await refreshAllocations();
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar asignación
  Future<void> deleteAllocation(String id) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      await _apiService.deleteAllocation(id);
      await refreshAllocations();
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Aplicar plantilla maestra al ciclo activo (RF-04)
  Future<void> applyTemplate({bool overwrite = false}) async {
    if (_activeCycle == null) throw Exception('No hay un ciclo activo');
    _isActionLoading = true;
    notifyListeners();

    try {
      final result = await _apiService.applyTemplate(
        cycleId: _activeCycle!.id,
        overwrite: overwrite,
      );
      _allocations = result.allocations;
      _summary = result.summary;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Guardar asignaciones del ciclo actual como plantilla maestra (RF-04)
  Future<void> saveCycleAsTemplate() async {
    if (_activeCycle == null) throw Exception('No hay un ciclo activo');
    _isActionLoading = true;
    notifyListeners();

    try {
      await _apiService.saveCycleAsTemplate(cycleId: _activeCycle!.id);
      await refreshTemplates();
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Crear partida en plantilla maestra
  Future<void> createTemplateItem({
    required QuincenaPeriod period,
    required String categoryId,
    required double defaultAmount,
    String? destinationAccountId,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      await _apiService.createTemplate(
        period: period,
        categoryId: categoryId,
        defaultAmount: defaultAmount,
        destinationAccountId: destinationAccountId,
      );
      await refreshTemplates();
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Actualizar partida de plantilla maestra
  Future<void> updateTemplateItem(
    String id, {
    double? defaultAmount,
    String? destinationAccountId,
    bool clearDestinationAccount = false,
  }) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      await _apiService.updateTemplate(
        id,
        defaultAmount: defaultAmount,
        destinationAccountId: destinationAccountId,
        clearDestinationAccount: clearDestinationAccount,
      );
      await refreshTemplates();
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar partida de plantilla maestra
  Future<void> deleteTemplateItem(String id) async {
    _isActionLoading = true;
    notifyListeners();

    try {
      await _apiService.deleteTemplate(id);
      await refreshTemplates();
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }
}
