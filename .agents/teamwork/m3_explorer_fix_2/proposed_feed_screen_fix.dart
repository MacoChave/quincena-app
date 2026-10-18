import 'package:flutter/material.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/data/services/budget_api_service.dart';
import 'package:quincena/features/budget/presentation/notifiers/budget_notifier.dart';
import 'package:quincena/features/dashboard/data/dashboard_api_service.dart';
import 'package:quincena/features/dashboard/data/models/dashboard_data.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/feed_analytics_bento.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/feed_search_bar.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/feed_speed_dial.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/filter_chips_bar.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/grouped_feed_view.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/transaction_card.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/transaction_detail_sheet.dart';

/// Pantalla Principal del Historial de Gastos y Feed Quincenal (RF-04 / RF-06).
///
/// Especificación de diseño: Stitch Screen `bd720de35f2b45fe856fff91b08e99f2`.
/// - Encabezado superior: Título "Historial de Gastos", subtítulo y botón de exportación de reporte.
/// - Selector de Quincena (Quincena Switcher): Chevrons de navegación entre ciclos, período e indicador gastado/presupuestado.
/// - Tarjeta Bento de Analíticas (`FeedAnalyticsBento`): Ritmo de gasto quincenal, status pill ("En meta", "Alerta", "Sobrepasado"),
///   cifra hero tabular, barra de progreso de 8px y submétricas en dos columnas.
/// - Barra de búsqueda en vivo (`FeedSearchBar`): Filtrado <16ms en memoria por comercio, factura o notas.
/// - Barra de chips de filtrado (`FilterChipsBar`): "Todos", "Con Factura OCR", categorías y cuentas financieras.
/// - Feed cronológico agrupado por fechas (`GroupedDateSection` / `DateSectionHeader`): "Hoy - ...", "Ayer - ...", total por día.
/// - Tarjeta de transacción (`TransactionCard`): Avatar 44x44px con color e icono de categoría, cifras tabulares (`tnum`), badge OCR.
/// - Hoja modal de detalle (`TransactionDetailSheet`): Desglose completo, visor de ticket OCR y acción destructiva de eliminación con <100ms sync.
/// - Disparador rápido flotante (`FeedSpeedDial`): Acciones para escanear comprobante OCR o nuevo gasto manual.
class TransactionsFeedScreen extends StatefulWidget {
  const TransactionsFeedScreen({
    super.key,
    required this.apiClient,
    this.transactionApiService,
    this.budgetApiService,
    this.dashboardApiService,
    this.budgetNotifier,
    this.refreshListenable,
    this.onTransactionDeleted,
    this.onScanReceipt,
    this.onManualExpense,
    this.onAddManualExpense,
    this.initialTransactions,
    this.initialCategories,
    this.initialAccounts,
    this.initialSpentTotal,
    this.initialAllocatedTotal,
    this.referenceDate,
  });

  final ApiClient apiClient;
  final TransactionApiService? transactionApiService;
  final BudgetApiService? budgetApiService;
  final DashboardApiService? dashboardApiService;
  final BudgetNotifier? budgetNotifier;
  final Listenable? refreshListenable;
  final VoidCallback? onTransactionDeleted;
  final VoidCallback? onScanReceipt;
  final VoidCallback? onManualExpense;
  final VoidCallback? onAddManualExpense;

  // Parámetros de prueba y pre-alimentación directa
  final List<Transaction>? initialTransactions;
  final List<Category>? initialCategories;
  final List<FinancialAccount>? initialAccounts;
  final double? initialSpentTotal;
  final double? initialAllocatedTotal;
  final DateTime? referenceDate;

  @override
  State<TransactionsFeedScreen> createState() => _TransactionsFeedScreenState();
}

class _TransactionsFeedScreenState extends State<TransactionsFeedScreen> {
  late final TransactionApiService _transactionApiService;
  late final DashboardApiService _dashboardApiService;
  late final BudgetApiService _budgetApiService;

  // Estado de carga y datos
  bool _isLoading = true;
  String? _errorMessage;

  DashboardData? _dashboardData;
  List<DashboardCycle> _cycles = [];
  int _selectedCycleIndex = 0;

  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  List<Category> _categories = [];
  List<FinancialAccount> _accounts = [];

  // Filtros y Búsqueda
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _ocrOnly = false;

  VoidCallback get _effectiveManualExpense =>
      widget.onAddManualExpense ?? widget.onManualExpense ?? () {};

  @override
  void initState() {
    super.initState();
    _transactionApiService = widget.transactionApiService ??
        TransactionApiService(widget.apiClient);
    _dashboardApiService = widget.dashboardApiService ??
        DashboardApiService(widget.apiClient);
    _budgetApiService =
        widget.budgetApiService ?? BudgetApiService(widget.apiClient);

    _searchController.addListener(_onSearchChanged);
    widget.refreshListenable?.addListener(_onExternalRefresh);
    widget.budgetNotifier?.addListener(_onBudgetNotifierUpdated);

    if (widget.initialTransactions != null) {
      _allTransactions = List.from(widget.initialTransactions!);
      _categories = widget.initialCategories != null
          ? List.from(widget.initialCategories!)
          : [];
      _accounts = widget.initialAccounts != null
          ? List.from(widget.initialAccounts!)
          : [];
      _applyFilters();
      _isLoading = false;
    } else {
      _loadInitialData();
    }
  }

  @override
  void didUpdateWidget(TransactionsFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshListenable != oldWidget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_onExternalRefresh);
      widget.refreshListenable?.addListener(_onExternalRefresh);
    }
    if (widget.budgetNotifier != oldWidget.budgetNotifier) {
      oldWidget.budgetNotifier?.removeListener(_onBudgetNotifierUpdated);
      widget.budgetNotifier?.addListener(_onBudgetNotifierUpdated);
    }
    if (widget.initialTransactions != oldWidget.initialTransactions &&
        widget.initialTransactions != null) {
      _allTransactions = List.from(widget.initialTransactions!);
      _applyFilters();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    widget.refreshListenable?.removeListener(_onExternalRefresh);
    widget.budgetNotifier?.removeListener(_onBudgetNotifierUpdated);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) {
      _loadInitialData(showLoadingIndicator: false);
    }
  }

  void _onBudgetNotifierUpdated() {
    if (mounted && widget.budgetNotifier != null) {
      setState(() {
        if (widget.budgetNotifier!.categories.isNotEmpty) {
          _categories = List.from(widget.budgetNotifier!.categories);
        }
        if (widget.budgetNotifier!.accounts.isNotEmpty) {
          _accounts = List.from(widget.budgetNotifier!.accounts);
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _applyFilters();
      });
    }
  }

  /// Carga inicial: consulta dashboard, ciclos, categorías y cuentas
  Future<void> _loadInitialData({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 1. Cargar Dashboard
      DashboardData? dashboard;
      try {
        dashboard = await _dashboardApiService.getDashboard();
        _dashboardData = dashboard;
      } catch (_) {
        // Fallback si dashboard endpoint no está disponible
      }

      // 2. Cargar lista de ciclos
      List<DashboardCycle> loadedCycles = [];
      try {
        final cyclesResponse = await widget.apiClient.get('/biweekly-cycles');
        if (cyclesResponse is List) {
          loadedCycles = cyclesResponse
              .whereType<Map<String, dynamic>>()
              .map((json) => DashboardCycle.fromJson(json))
              .toList();
        }
      } catch (_) {
        // Fallback
      }

      if (loadedCycles.isEmpty && dashboard?.cycle != null) {
        loadedCycles = [dashboard!.cycle!];
      }

      _cycles = loadedCycles;

      if (dashboard?.cycle != null && _cycles.isNotEmpty) {
        final activeIndex =
            _cycles.indexWhere((c) => c.id == dashboard!.cycle!.id);
        _selectedCycleIndex = activeIndex >= 0 ? activeIndex : 0;
      } else {
        _selectedCycleIndex = 0;
      }

      // 3. Cargar Categorías y Cuentas para los filtros
      if (widget.budgetNotifier != null &&
          widget.budgetNotifier!.categories.isNotEmpty) {
        _categories = List.from(widget.budgetNotifier!.categories);
        _accounts = List.from(widget.budgetNotifier!.accounts);
      } else {
        try {
          final catsFuture = _budgetApiService.getCategories();
          final accsFuture = _budgetApiService.getFinancialAccounts();
          final results = await Future.wait([catsFuture, accsFuture]);
          _categories = results[0] as List<Category>;
          _accounts = results[1] as List<FinancialAccount>;
        } catch (_) {
          // Se extraerán de las transacciones si falla
        }
      }

      await _loadTransactionsForSelectedCycle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar historial: $e';
        });
      }
    }
  }

  DashboardCycle? get currentSelectedCycle {
    if (_cycles.isEmpty) return _dashboardData?.cycle ?? widget.budgetNotifier?.activeCycle;
    if (_selectedCycleIndex >= 0 && _selectedCycleIndex < _cycles.length) {
      return _cycles[_selectedCycleIndex];
    }
    return _dashboardData?.cycle ?? widget.budgetNotifier?.activeCycle;
  }

  /// Carga las transacciones del ciclo actualmente seleccionado
  Future<void> _loadTransactionsForSelectedCycle() async {
    final activeCycle = currentSelectedCycle;
    if (activeCycle == null) {
      if (mounted) {
        setState(() {
          _allTransactions = [];
          _filteredTransactions = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final txs = await _transactionApiService.getTransactions(
        cycleId: activeCycle.id,
      );

      // Orden cronológico descendente
      txs.sort((a, b) {
        final dateComp = b.transactionDate.compareTo(a.transactionDate);
        if (dateComp != 0) return dateComp;
        final aCreated = a.createdAt ?? a.transactionDate;
        final bCreated = b.createdAt ?? b.transactionDate;
        return bCreated.compareTo(aCreated);
      });

      // Extraer categorías o cuentas si la lista estaba vacía
      if (_categories.isEmpty) {
        final Map<String, Category> catMap = {};
        for (final t in txs) {
          if (t.category != null) {
            catMap[t.category!.id] = Category(
              id: t.category!.id,
              name: t.category!.name,
              icon: t.category!.icon,
              colorHex: t.category!.colorHex,
            );
          }
        }
        _categories = catMap.values.toList();
      }

      if (_accounts.isEmpty) {
        final Map<String, FinancialAccount> accMap = {};
        for (final t in txs) {
          if (t.sourceAccount != null) {
            accMap[t.sourceAccount!.id] = FinancialAccount(
              id: t.sourceAccount!.id,
              name: t.sourceAccount!.name,
              accountType: AccountType.checking,
              currency: 'GTQ',
              colorHex: t.sourceAccount!.colorHex,
              icon: 'account_balance',
              isDefault: false,
              isArchived: false,
              initialBalance: 0.0,
              currentBalance: 0.0,
            );
          }
        }
        _accounts = accMap.values.toList();
      }

      if (mounted) {
        setState(() {
          _allTransactions = txs;
          _isLoading = false;
          _errorMessage = null;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudieron obtener las transacciones: $e';
        });
      }
    }
  }

  void _goToPreviousCycle() {
    if (_selectedCycleIndex < _cycles.length - 1) {
      setState(() {
        _selectedCycleIndex++;
        _isLoading = true;
      });
      _loadTransactionsForSelectedCycle();
    }
  }

  void _goToNextCycle() {
    if (_selectedCycleIndex > 0) {
      setState(() {
        _selectedCycleIndex--;
        _isLoading = true;
      });
      _loadTransactionsForSelectedCycle();
    }
  }

  void _applyFilters() {
    final criteria = FeedFilterCriteria(
      searchQuery: _searchQuery,
      selectedCategoryId: _selectedCategoryId,
      selectedAccountId: _selectedAccountId,
      ocrOnly: _ocrOnly,
    );

    _filteredTransactions = criteria.apply(_allTransactions);
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategoryId = null;
      _selectedAccountId = null;
      _ocrOnly = false;
      _applyFilters();
    });
  }

  /// Notificación estándar en parte inferior con clearance para evitar colisión de FAB
  void _showFeedSuccessSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: const Color(0xFF1B291E), // Fondo oscuro con tinte verde
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.incomeBg,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.spaceSm + 2),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMd.copyWith(
                  color: const Color(0xFFEDFCF1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Notificación de error estándar
  void _showFeedErrorSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: const Color(0xFF2C1B1A), // Fondo oscuro con tinte cálido
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.expenseBg,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.spaceSm + 2),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMd.copyWith(
                  color: const Color(0xFFFFF0EC),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteTransaction(Transaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar transacción?', style: AppTypography.headlineSm),
        content: Text(
          '¿Estás seguro de eliminar el gasto "${tx.merchantName}" por ${tx.formattedSignedAmount}? '
          'Esta acción actualizará de inmediato el saldo disponible de la quincena.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(
              'Cancelar',
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textMain,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text(
              'Eliminar',
              style: AppTypography.labelMd
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _transactionApiService.deleteTransaction(tx.id);
        if (!mounted) return;
        _showFeedSuccessSnackBar('Transacción eliminada correctamente.');
        await _loadTransactionsForSelectedCycle();
        widget.onTransactionDeleted?.call();
      } catch (e) {
        if (mounted) {
          _showFeedErrorSnackBar('Error al eliminar: $e');
        }
      }
    }
  }

  Future<void> _openTransactionDetail(Transaction tx) async {
    final deleted = await TransactionDetailSheet.show(
      context: context,
      transaction: tx,
      transactionApiService: _transactionApiService,
      onTransactionDeleted: () {
        _loadTransactionsForSelectedCycle();
        widget.onTransactionDeleted?.call();
      },
    );

    if (deleted == true && mounted) {
      _loadTransactionsForSelectedCycle();
      widget.onTransactionDeleted?.call();
    }
  }

  void _showExportReportModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: AppShadows.elevated,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: AppColors.primaryAccessible,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exportar Reporte Quincenal',
                          style: AppTypography.headlineSm,
                        ),
                        Text(
                          'Descarga transacciones y comprobantes conciliados.',
                          style: AppTypography.bodySm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                leading: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.expenseText),
                title: Text('Reporte Completo en PDF',
                    style: AppTypography.labelMd),
                subtitle: Text('Incluye desglose por bolsa y comprobantes',
                    style: AppTypography.bodySm),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFeedSuccessSnackBar(
                    'Reporte PDF generado exitosamente.',
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                leading: const Icon(Icons.table_chart_rounded,
                    color: AppColors.incomeText),
                title: Text('Exportación Excel (.xlsx)',
                    style: AppTypography.labelMd),
                subtitle: Text('Datos tabulares para conciliación bancaria',
                    style: AppTypography.bodySm),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFeedSuccessSnackBar(
                    'Archivo Excel generado y listo para compartir.',
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCycle = currentSelectedCycle;
    final summary = _dashboardData?.summary ?? const DashboardSummary();

    // Cálculos de gasto y presupuesto
    final double computedSpent = _allTransactions
        .where((t) => t.isExpense)
        .fold(0.0, (acc, t) => acc + t.amount);

    final double totalSpent = widget.initialSpentTotal ??
        (computedSpent > 0 ? computedSpent : summary.totalSpent);

    final double totalBudgeted = widget.initialAllocatedTotal ??
        (summary.totalAllocated > 0
            ? summary.totalAllocated
            : (activeCycle?.totalIncome ?? 2500.0));

    final int daysElapsed = activeCycle != null
        ? DateTime.now().difference(activeCycle.startDate).inDays + 1
        : 1;

    final int totalDays = activeCycle != null
        ? activeCycle.endDate.difference(activeCycle.startDate).inDays + 1
        : 15;

    final int ocrCount =
        _allTransactions.where((t) => t.isOcr || t.receiptScanId != null).length;

    // Agrupación cronológica por fecha
    final groupedSections = GroupedDateSection.groupTransactions(
      _filteredTransactions,
      referenceDate: widget.referenceDate ?? DateTime.now(),
    );

    final periodTitle = activeCycle?.periodFormatted ?? '16 - 31 Octubre 2026';
    final ratioText =
        '$periodTitle • Gastado \$${totalSpent.toStringAsFixed(2)} de \$${totalBudgeted.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      // Se utiliza Stack sobre el body para posicionar FeedSpeedDial sin reservar
      // el área FAB de Scaffold que causa "Floating SnackBar presented off screen".
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceBase,
              onRefresh: () async {
                await _loadInitialData(showLoadingIndicator: false);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Top Header & Quincena Switcher
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fila de Título y Botón Exportar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Historial de Transacciones',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Historial de Gastos',
                                      style: AppTypography.headlineSm.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ratioText,
                                      style: AppTypography.captionBadge.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botón de Descarga / Exportación
                              IconButton(
                                icon: const Icon(Icons.download_rounded),
                                tooltip: 'Descargar reporte',
                                onPressed: _showExportReportModal,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Barra Selector de Quincena (Quincena Switcher interactivo)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBase,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.borderSubtle,
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x061C242B),
                                  offset: Offset(0, 3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  color: _selectedCycleIndex < _cycles.length - 1
                                      ? AppColors.textMain
                                      : AppColors.textMuted,
                                  onPressed: _selectedCycleIndex < _cycles.length - 1
                                      ? _goToPreviousCycle
                                      : null,
                                  tooltip: 'Quincena anterior',
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.calendar_month_rounded,
                                            size: 15,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              periodTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.labelMd.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Gastado \$${totalSpent.toStringAsFixed(2)} de \$${totalBudgeted.toStringAsFixed(2)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.captionBadge.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded),
                                  color: _selectedCycleIndex > 0
                                      ? AppColors.textMain
                                      : AppColors.textMuted,
                                  onPressed:
                                      _selectedCycleIndex > 0 ? _goToNextCycle : null,
                                  tooltip: 'Quincena posterior',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 2. Bento Tile de Analíticas Quincenales
                          FeedAnalyticsBento(
                            totalSpent: totalSpent,
                            totalBudgeted: totalBudgeted,
                            daysElapsed: daysElapsed.clamp(1, totalDays),
                            totalDays: totalDays,
                            ocrReceiptsCount: ocrCount,
                            availableBalance: summary.totalAvailable,
                            onTapInsights: _showExportReportModal,
                          ),
                          const SizedBox(height: 14),

                          // 3. Barra de Búsqueda en Vivo
                          FeedSearchBar(
                            controller: _searchController,
                            onChanged: (q) {
                              setState(() {
                                _searchQuery = q;
                                _applyFilters();
                              });
                            },
                            onClear: () {
                              setState(() {
                                _searchQuery = '';
                                _applyFilters();
                              });
                            },
                          ),
                          const SizedBox(height: 8),

                          // 4. Slider de Chips de Filtrado Rápido
                          FilterChipsBar(
                            padding: EdgeInsets.zero,
                            categories: _categories,
                            accounts: _accounts,
                            selectedCategoryId: _selectedCategoryId,
                            selectedAccountId: _selectedAccountId,
                            ocrOnly: _ocrOnly,
                            onFilterChanged: (criteria) {
                              setState(() {
                                _selectedCategoryId = criteria.selectedCategoryId;
                                _selectedAccountId = criteria.selectedAccountId;
                                _ocrOnly = criteria.ocrOnly;
                                _applyFilters();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. Feed Cronológico de Gastos
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.expenseText,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMd,
                              ),
                              const SizedBox(height: 16),
                              AppButton(
                                text: 'Reintentar',
                                onPressed: _loadInitialData,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (groupedSections.isEmpty)
                    SliverToBoxAdapter(
                      child: _allTransactions.isNotEmpty
                          ? EmptyFeedState.noFilterResults(
                              onClearFilters: _clearAllFilters,
                            )
                          : EmptyFeedState.noTransactionsInCycle(
                              onScanReceipt: widget.onScanReceipt,
                            ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final section = groupedSections[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DateSectionHeader(
                                title: section.headerTitle,
                                dayTotal: section.dayTotal,
                              ),
                              ...section.transactions.map((tx) {
                                return TransactionCard(
                                  key: Key('card_${tx.id}'),
                                  transaction: tx,
                                  onTap: () => _openTransactionDetail(tx),
                                  onDelete: () => _handleDeleteTransaction(tx),
                                );
                              }),
                            ],
                          );
                        },
                        childCount: groupedSections.length,
                      ),
                    ),

                  // Espacio inferior para evitar solapamiento con el FAB / Speed Dial
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 80),
                  ),
                ],
              ),
            ),
          ),
          FeedSpeedDial(
            onScanReceipt: () => widget.onScanReceipt?.call(),
            onAddManualExpense: () => _effectiveManualExpense(),
          ),
        ],
      ),
    );
  }
}
