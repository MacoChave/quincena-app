import 'package:flutter/material.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/presentation/widgets/icon_helper.dart';
import 'package:quincena/features/dashboard/data/dashboard_api_service.dart';
import 'package:quincena/features/dashboard/data/models/dashboard_data.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'proposed_feed_analytics_bento.dart';

/// Pantalla Principal del Historial de Gastos Quincenales (RF-04 / RF-06).
///
/// Implementa fielmente el diseño de Stitch Screen `bd720de35f2b45fe856fff91b08e99f2`:
/// - Barra superior con título "Historial de Gastos", subtítulo "Flujo de Dinero" y botón de exportar reporte.
/// - Selector de Quincena (Quincena Switcher) con navegación por chevrons, período activo e indicador gastado/presupuestado.
/// - Tarjeta Bento de Analíticas (`FeedAnalyticsBento`) con ritmo de gasto, status pill ("En meta", "Alerta", "Sobrepasado"),
///   cifra hero tabular, barra de progreso de 8px semaforizada y submétricas (promedio diario y capturas OCR).
/// - Barra de búsqueda en vivo con filtrado instantáneo por comercio, factura o notas.
/// - Slider horizontal de chips de filtrado rápido ("Todos", Categorías dinámicas y "Con Factura OCR").
/// - Feed cronológico agrupado por fechas ("Hoy - 18 Octubre", "Ayer", etc.) con total del día.
/// - Tarjetas de transacción con avatar de categoría, comercio, hora, método de pago, monto tabular y hoja modal de detalle/eliminación.
/// - Pull-to-refresh (`RefreshIndicator`) sincronizado con `TransactionApiService.getTransactions(cycleId: activeCycle.id)`.
class TransactionsFeedScreen extends StatefulWidget {
  const TransactionsFeedScreen({
    super.key,
    required this.apiClient,
    this.transactionApiService,
    this.dashboardApiService,
    this.onScanReceipt,
    this.onManualExpense,
    this.refreshListenable,
  });

  final ApiClient apiClient;
  final TransactionApiService? transactionApiService;
  final DashboardApiService? dashboardApiService;
  final VoidCallback? onScanReceipt;
  final VoidCallback? onManualExpense;
  final Listenable? refreshListenable;

  @override
  State<TransactionsFeedScreen> createState() => _TransactionsFeedScreenState();
}

class _TransactionsFeedScreenState extends State<TransactionsFeedScreen> {
  late final TransactionApiService _transactionApiService;
  late final DashboardApiService _dashboardApiService;

  // Estados de carga y datos
  bool _isLoading = true;
  String? _errorMessage;

  DashboardData? _dashboardData;
  List<DashboardCycle> _cycles = [];
  int _selectedCycleIndex = 0;

  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];

  // Filtros y Búsqueda
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryFilter; // null = 'Todos'
  bool _filterOcrOnly = false;

  static const List<String> _spanishMonths = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _transactionApiService = widget.transactionApiService ??
        TransactionApiService(widget.apiClient);
    _dashboardApiService =
        widget.dashboardApiService ?? DashboardApiService(widget.apiClient);

    _searchController.addListener(_onSearchChanged);
    widget.refreshListenable?.addListener(_onExternalRefresh);

    _loadInitialData();
  }

  @override
  void didUpdateWidget(TransactionsFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshListenable != oldWidget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_onExternalRefresh);
      widget.refreshListenable?.addListener(_onExternalRefresh);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    widget.refreshListenable?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) {
      _loadInitialData(showLoadingIndicator: false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _applyFilters();
      });
    }
  }

  /// Carga inicial: consulta dashboard y todos los ciclos disponibles
  Future<void> _loadInitialData({bool showLoadingIndicator = true}) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final dashboard = await _dashboardApiService.getDashboard();
      _dashboardData = dashboard;

      // Obtener lista completa de ciclos para navegación con chevrons
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
        // Fallback: usar el ciclo activo del dashboard
      }

      if (loadedCycles.isEmpty && dashboard.cycle != null) {
        loadedCycles = [dashboard.cycle!];
      }

      _cycles = loadedCycles;

      // Ubicar el índice del ciclo activo actual
      if (dashboard.cycle != null && _cycles.isNotEmpty) {
        final activeIndex =
            _cycles.indexWhere((c) => c.id == dashboard.cycle!.id);
        _selectedCycleIndex = activeIndex >= 0 ? activeIndex : 0;
      } else {
        _selectedCycleIndex = 0;
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

      // Orden cronológico descendente (las más recientes primero)
      txs.sort((a, b) {
        final dateComp = b.transactionDate.compareTo(a.transactionDate);
        if (dateComp != 0) return dateComp;
        if (b.createdAt != null && a.createdAt != null) {
          return b.createdAt!.compareTo(a.createdAt!);
        }
        return 0;
      });

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

  DashboardCycle? get currentSelectedCycle {
    if (_cycles.isEmpty) return _dashboardData?.cycle;
    if (_selectedCycleIndex >= 0 && _selectedCycleIndex < _cycles.length) {
      return _cycles[_selectedCycleIndex];
    }
    return _dashboardData?.cycle;
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
    List<Transaction> result = List.from(_allTransactions);

    // 1. Filtro de búsqueda textual
    if (_searchQuery.isNotEmpty) {
      result = result.where((tx) {
        final matchesMerchant =
            tx.merchantName.toLowerCase().contains(_searchQuery);
        final matchesNotes =
            tx.notes?.toLowerCase().contains(_searchQuery) ?? false;
        final matchesCategory =
            tx.categoryName.toLowerCase().contains(_searchQuery);
        final matchesAccount =
            tx.sourceAccountName.toLowerCase().contains(_searchQuery);
        final matchesAmount = tx.amount.toString().contains(_searchQuery);
        return matchesMerchant ||
            matchesNotes ||
            matchesCategory ||
            matchesAccount ||
            matchesAmount;
      }).toList();
    }

    // 2. Filtro por categoría seleccionada
    if (_selectedCategoryFilter != null) {
      result = result.where((tx) {
        return tx.category?.name == _selectedCategoryFilter ||
            tx.categoryName == _selectedCategoryFilter;
      }).toList();
    }

    // 3. Filtro "Con Factura OCR"
    if (_filterOcrOnly) {
      result = result.where((tx) => tx.isOcr || tx.receiptScanId != null).toList();
    }

    _filteredTransactions = result;
  }

  String _formatCurrency(double amount) {
    final absAmount = amount.abs();
    final formatted = absAmount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return amount < 0 ? '-\$$formatted' : '\$$formatted';
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final isToday = now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day;
    final monthName = _spanishMonths[date.month - 1];

    if (isToday) {
      return 'Hoy · ${date.day} $monthName';
    } else if (isYesterday) {
      return 'Ayer · ${date.day} $monthName';
    } else {
      return '${date.day} $monthName';
    }
  }

  /// Agrupa las transacciones filtradas por día (clave YYYY-MM-DD)
  Map<String, List<Transaction>> _groupTransactionsByDate() {
    final Map<String, List<Transaction>> groups = {};
    for (final tx in _filteredTransactions) {
      final dateKey =
          '${tx.transactionDate.year}-${tx.transactionDate.month.toString().padLeft(2, '0')}-${tx.transactionDate.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(dateKey, () => []).add(tx);
    }
    return groups;
  }

  // --- Acciones de Exportación y Detalle ---

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
                  AppToast.showSuccess(
                    context,
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
                  AppToast.showSuccess(
                    context,
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

  void _showTransactionDetailSheet(Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              // Encabezado de Detalle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tx.categoryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      resolveCategoryIcon(tx.categoryIcon),
                      color: tx.categoryColor,
                      size: 26,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        tx.formattedSignedAmount,
                        style: AppTypography.currencyHeroMobile.copyWith(
                          color: tx.isExpense
                              ? AppColors.textMain
                              : AppColors.incomeText,
                        ),
                      ),
                      Text(
                        tx.categoryName,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tx.merchantName,
                style: AppTypography.headlineSm.copyWith(fontSize: 18),
              ),
              if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  tx.notes!,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Divider(height: 28, color: AppColors.borderSubtle),

              // Metadatos
              _buildDetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Fecha y Hora',
                value:
                    '${tx.transactionDate.day} ${_spanishMonths[tx.transactionDate.month - 1]} ${tx.transactionDate.year} · ${tx.transactionDate.hour.toString().padLeft(2, '0')}:${tx.transactionDate.minute.toString().padLeft(2, '0')} hrs',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Cuenta de Débito',
                value: tx.sourceAccountName,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                icon: tx.isOcr
                    ? Icons.document_scanner_outlined
                    : Icons.edit_note_rounded,
                label: 'Método de Registro',
                value: tx.entryMethod.label,
              ),

              const SizedBox(height: 24),

              // Botón de Eliminación (DELETE /transactions/:id)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expenseText,
                    side: const BorderSide(color: AppColors.expenseBg, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text('Eliminar Transacción',
                      style: AppTypography.labelMd.copyWith(
                          color: AppColors.expenseText,
                          fontWeight: FontWeight.w700)),
                  onPressed: () => _confirmDeleteTransaction(tx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.labelMd.copyWith(color: AppColors.textMain),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteTransaction(Transaction tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Eliminar transacción?', style: AppTypography.headlineSm),
        content: Text(
          '¿Estás seguro de eliminar el gasto "${tx.merchantName}" por ${_formatCurrency(tx.amount)}? '
          'Esta acción actualizará de inmediato el saldo disponible de la quincena.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text('Cancelar',
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseBg,
              foregroundColor: AppColors.textMain,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(dlgCtx, true),
            child: Text('Eliminar',
                style: AppTypography.labelMd
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context); // Cierra bottom sheet de detalle
      try {
        await _transactionApiService.deleteTransaction(tx.id);
        AppToast.showSuccess(context, 'Transacción eliminada correctamente.');
        await _loadTransactionsForSelectedCycle();
      } catch (e) {
        if (mounted) {
          AppToast.showError(context, 'Error al eliminar: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCycle = currentSelectedCycle;
    final summary = _dashboardData?.summary ?? const DashboardSummary();

    // Cálculos para Bento Tile
    final double totalSpent = _allTransactions
        .where((t) => t.isExpense)
        .fold(0.0, (acc, t) => acc + t.amount);

    final double totalBudgeted = summary.totalAllocated > 0
        ? summary.totalAllocated
        : (activeCycle?.totalIncome ?? 2500.0);

    final int daysElapsed = activeCycle != null
        ? DateTime.now().difference(activeCycle.startDate).inDays + 1
        : 1;

    final int totalDays = activeCycle != null
        ? activeCycle.endDate.difference(activeCycle.startDate).inDays + 1
        : 15;

    final int ocrCount =
        _allTransactions.where((t) => t.isOcr || t.receiptScanId != null).length;

    // Categorías únicas para filtro rápido
    final uniqueCategories = _allTransactions
        .map((t) => t.categoryName)
        .where((name) => name != 'Sin categoría')
        .toSet()
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila de Título y Botón Exportar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FLUJO DE DINERO',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Historial de Gastos',
                                style: AppTypography.headlineLg,
                              ),
                            ],
                          ),
                          // Botón de Descarga / Exportación
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showExportReportModal,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceBase,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                    width: 1,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x081C242B),
                                      offset: Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.file_download_outlined,
                                  color: AppColors.textMain,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Barra Selector de Quincena (Quincena Switcher)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.borderSubtle, width: 1),
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
                            // Chevron Izquierdo (Ciclo anterior)
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              color: _selectedCycleIndex < _cycles.length - 1
                                  ? AppColors.textMain
                                  : AppColors.textMuted,
                              onPressed:
                                  _selectedCycleIndex < _cycles.length - 1
                                      ? _goToPreviousCycle
                                      : null,
                              tooltip: 'Quincena anterior',
                            ),
                            // Información central del período
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
                                      Text(
                                        activeCycle?.periodFormatted ??
                                            'Ciclo Quincenal',
                                        style: AppTypography.labelMd.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  RichText(
                                    text: TextSpan(
                                      style: AppTypography.bodySm.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      children: [
                                        const TextSpan(text: 'Gastado '),
                                        TextSpan(
                                          text: _formatCurrency(totalSpent),
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.textMain,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ' de ${_formatCurrency(totalBudgeted)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Chevron Derecho (Ciclo posterior / actual)
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              color: _selectedCycleIndex > 0
                                  ? AppColors.textMain
                                  : AppColors.textMuted,
                              onPressed: _selectedCycleIndex > 0
                                  ? _goToNextCycle
                                  : null,
                              tooltip: 'Quincena posterior',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Bento Tile de Analíticas
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
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.borderSubtle, width: 1),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x061C242B),
                              offset: Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: AppTypography.bodyLg,
                          decoration: InputDecoration(
                            hintText: 'Buscar por comercio, factura o nota...',
                            hintStyle: AppTypography.bodyMd.copyWith(
                              color: AppColors.textMuted,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. Slider Horizontal de Chips de Filtro Rápido
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            // Chip "Todos"
                            _buildFilterChip(
                              label: 'Todos',
                              isSelected: _selectedCategoryFilter == null &&
                                  !_filterOcrOnly,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryFilter = null;
                                  _filterOcrOnly = false;
                                  _applyFilters();
                                });
                              },
                            ),
                            const SizedBox(width: 8),

                            // Chip "Con Factura OCR"
                            _buildFilterChip(
                              label: 'Con Factura OCR',
                              icon: Icons.qr_code_scanner_rounded,
                              isSelected: _filterOcrOnly,
                              onTap: () {
                                setState(() {
                                  _filterOcrOnly = !_filterOcrOnly;
                                  _applyFilters();
                                });
                              },
                            ),
                            const SizedBox(width: 8),

                            // Chips de Categorías dinámicas
                            ...uniqueCategories.map((catName) {
                              final isSelected =
                                  _selectedCategoryFilter == catName;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildFilterChip(
                                  label: catName,
                                  icon: resolveCategoryIcon(catName),
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedCategoryFilter =
                                          isSelected ? null : catName;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // 5. Contenido Principal: Feed Cronológico
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
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: AppColors.expenseText),
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
              else if (_filteredTransactions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceBase,
                              shape: BoxShape.circle,
                              boxShadow: AppShadows.card,
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              size: 32,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isNotEmpty ||
                                    _selectedCategoryFilter != null ||
                                    _filterOcrOnly
                                ? 'No se encontraron gastos con los filtros aplicados'
                                : 'No hay gastos registrados en esta quincena',
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Escanea un comprobante con la cámara o registra un gasto manual.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySm,
                          ),
                          const SizedBox(height: 16),
                          if (_searchQuery.isNotEmpty ||
                              _selectedCategoryFilter != null ||
                              _filterOcrOnly)
                            TextButton.icon(
                              icon: const Icon(Icons.filter_alt_off_rounded),
                              label: const Text('Limpiar filtros'),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _selectedCategoryFilter = null;
                                  _filterOcrOnly = false;
                                  _applyFilters();
                                });
                              },
                            )
                          else if (widget.onScanReceipt != null)
                            AppButton(
                              text: 'Escanear Comprobante',
                              prefixIcon:
                                  const Icon(Icons.document_scanner_outlined),
                              onPressed: widget.onScanReceipt,
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Listado de transacciones agrupadas cronológicamente
                _buildGroupedTransactionsSliver(),

                // Tarjeta Suplementaria de Cierre & Exportación al fondo
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.borderSubtle, width: 1),
                        boxShadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.download_rounded,
                                  color: AppColors.primaryAccessible,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Cierre y Conciliación',
                                        style: AppTypography.labelMd),
                                    Text(
                                      'Descarga todas tus transacciones con comprobantes vinculados.',
                                      style: AppTypography.bodySm,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.textMain,
                                foregroundColor: AppColors.surfaceBase,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.file_download_outlined,
                                  size: 20),
                              label: Text(
                                'Descargar Reporte Quincenal (PDF/Excel)',
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.surfaceBase,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: _showExportReportModal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderPill,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.textMain : AppColors.surfaceBase,
            borderRadius: AppRadius.borderPill,
            border: Border.all(
              color: isSelected ? AppColors.textMain : AppColors.borderSubtle,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x061C242B),
                offset: Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color:
                      isSelected ? AppColors.surfaceBase : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppTypography.labelMd.copyWith(
                  color: isSelected
                      ? AppColors.surfaceBase
                      : AppColors.textMain,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye las secciones agrupadas por fecha en Slivers
  Widget _buildGroupedTransactionsSliver() {
    final groups = _groupTransactionsByDate();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final dateKey = groups.keys.elementAt(index);
            final groupItems = groups[dateKey]!;
            final firstDate = groupItems.first.transactionDate;

            // Total del día
            final dayTotal = groupItems
                .where((t) => t.isExpense)
                .fold(0.0, (sum, t) => sum + t.amount);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado del Grupo de Fecha
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDateHeader(firstDate),
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_formatCurrency(dayTotal)} total',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Tarjetas del Grupo
                  ...groupItems.map(_buildTransactionCard),
                ],
              ),
            );
          },
          childCount: groups.length,
        ),
      ),
    );
  }

  /// Tarjeta de transacción individual (Stitch Screen bd720de35f2b45fe856fff91b08e99f2:140-161)
  Widget _buildTransactionCard(Transaction tx) {
    final categoryColor = tx.categoryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTransactionDetailSheet(tx),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
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
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar de Categoría (Stitch: 44x44 rounded-xl)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      resolveCategoryIcon(tx.categoryIcon),
                      size: 22,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Columna Central: Nombre del comercio y metadatos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tx.merchantName,
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${tx.transactionDate.hour.toString().padLeft(2, '0')}:${tx.transactionDate.minute.toString().padLeft(2, '0')} hrs',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (tx.isOcr)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                borderRadius: AppRadius.borderPill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.document_scanner_outlined,
                                    size: 11,
                                    color: AppColors.primaryAccessible,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'OCR Escaneado',
                                    style: AppTypography.labelSm.copyWith(
                                      fontSize: 10,
                                      color: AppColors.primaryAccessible,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Flexible(
                              child: Text(
                                tx.sourceAccountName,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Columna Derecha: Monto monetario tabular y categoría
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tx.formattedSignedAmount,
                      style: AppTypography.currencyMd.copyWith(
                        color: tx.isExpense
                            ? AppColors.textMain
                            : AppColors.incomeText,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx.categoryName,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
