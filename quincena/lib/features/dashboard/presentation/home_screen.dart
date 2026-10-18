import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/theme/theme.dart';
import '../data/dashboard_api_service.dart';
import '../data/models/dashboard_data.dart';

/// Screen 1: Pantalla Principal / Dashboard ("Quincena Activa")
///
/// Implementa las directrices de Stitch:
/// - Tarjeta Hero en Warm Cream (#FCF5C7) con saldo disponible en tipografía tabular.
/// - Badges de Ingreso (#ADF7B6) y Gastado (#FFC09F).
/// - Lista modular de categorías con barras de progreso y semáforo dinámico de consumo.
/// - Integración total con la API REST de NestJS.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dashboardApiService,
    required this.onOpenProfile,
    this.onScanReceipt,
    this.refreshListenable,
  });

  final DashboardApiService dashboardApiService;
  final VoidCallback onOpenProfile;
  final VoidCallback? onScanReceipt;
  final Listenable? refreshListenable;

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late Future<DashboardData> _dashboardFuture;
  bool _isInitializingCycle = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    widget.refreshListenable?.addListener(_loadDashboard);
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshListenable != oldWidget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_loadDashboard);
      widget.refreshListenable?.addListener(_loadDashboard);
    }
  }

  @override
  void dispose() {
    widget.refreshListenable?.removeListener(_loadDashboard);
    super.dispose();
  }

  /// Método público para forzar recarga inmediata (<100ms)
  void refresh() => _loadDashboard();

  void _loadDashboard() {
    setState(() {
      _dashboardFuture = widget.dashboardApiService.getDashboard();
    });
  }

  Future<void> _initCurrentCycle() async {
    setState(() => _isInitializingCycle = true);
    try {
      await widget.dashboardApiService.initCurrentCycle();
      if (!mounted) return;
      _loadDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Quincena activa iniciada con éxito!'),
          backgroundColor: AppColors.incomeText,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar quincena: $e'),
          backgroundColor: AppColors.expenseText,
        ),
      );
    } finally {
      if (mounted) setState(() => _isInitializingCycle = false);
    }
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  IconData _mapCategoryIcon(String iconKey) {
    switch (iconKey.toLowerCase()) {
      case 'shopping-bag':
      case 'shopping_bag':
      case 'cart':
      case 'supermercado':
        return Icons.shopping_bag_outlined;
      case 'home':
      case 'renta':
      case 'hogar':
        return Icons.home_work_outlined;
      case 'bolt':
      case 'servicios':
      case 'utilities':
        return Icons.bolt_rounded;
      case 'restaurant':
      case 'comida':
      case 'salidas':
      case 'ocio':
        return Icons.restaurant_outlined;
      case 'car':
      case 'gasolina':
      case 'transporte':
        return Icons.directions_car_outlined;
      case 'savings':
      case 'ahorro':
        return Icons.savings_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Color _parseCategoryColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primaryAccessible;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: FutureBuilder<DashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppColors.surfaceSubtle,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryAccessible),
              ),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: AppColors.surfaceSubtle,
              appBar: const AppAppBar(title: 'Quincena Activa'),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 54, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text('Error al cargar datos', style: AppTypography.headlineSm),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}'.replaceFirst('ApiException: ', ''),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMd,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Reintentar',
                        isFullWidth: false,
                        onPressed: _loadDashboard,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final periodLabel = data.cycle?.periodFormatted ??
              (data.suggestedPeriod != null
                  ? '${data.suggestedPeriod!.startDate} al ${data.suggestedPeriod!.endDate}'
                  : 'Quincena Actual');

          return Scaffold(
            backgroundColor: AppColors.surfaceSubtle,
            appBar: AppAppBar(
              title: 'Quincena Activa',
              periodLabel: periodLabel,
              onPeriodTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ciclo actual: $periodLabel')),
                );
              },
              actions: [
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No hay nuevas notificaciones')),
                    );
                  },
                  icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textMain),
                  tooltip: 'Notificaciones',
                ),
                IconButton(
                  onPressed: widget.onOpenProfile,
                  icon: const Icon(Icons.account_circle_outlined, color: AppColors.textMain),
                  tooltip: 'Mi Perfil',
                ),
              ],
            ),
            body: RefreshIndicator(
              color: AppColors.primaryAccessible,
              backgroundColor: AppColors.surfaceBase,
              onRefresh: () async => _loadDashboard(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // CASO 1: No hay ciclo activo iniciado
                  if (!data.hasActiveCycle) ...[
                    AppCard(
                      backgroundColor: AppColors.surfaceHero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: AppRadius.borderSm,
                                ),
                                child: const Icon(Icons.calendar_today_rounded,
                                    color: AppColors.primaryAccessible, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Nueva Quincena por Iniciar',
                                        style: AppTypography.labelLg),
                                    Text(periodLabel, style: AppTypography.bodySm),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tienes un ciclo activo para este periodo. Puedes iniciarlo ahora para registrar ingresos, distribuir tus bolsas y controlar tus gastos.',
                            style: AppTypography.bodyMd.copyWith(color: AppColors.textMain),
                          ),
                          const SizedBox(height: 20),
                          AppButton(
                            text: 'Iniciar Quincena Actual',
                            isLoading: _isInitializingCycle,
                            onPressed: _initCurrentCycle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]
                  // CASO 2: Ciclo activo presente
                  else ...[
                    // 1. Hero Card: Balance Disponible Quincenal
                    AppHeroCard(
                      title: 'Disponible esta quincena',
                      availableAmount: _formatCurrency(data.summary.totalAvailable),
                      incomeAmount: _formatCurrency(data.summary.totalIncome),
                      expenseAmount: _formatCurrency(data.summary.totalSpent),
                      periodLabel: periodLabel,
                      onPeriodTap: () {},
                      footerChild: data.summary.unallocated > 0
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: AppColors.warningText),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Por asignar: ${_formatCurrency(data.summary.unallocated)}',
                                    style: AppTypography.captionBadge.copyWith(
                                      color: AppColors.warningText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                    if (widget.onScanReceipt != null) ...[
                      const SizedBox(height: 16),
                      _buildQuickScanBanner(context),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 24),

                    // 2. Presupuestos por Categoría
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Presupuesto por Categoría',
                          style: AppTypography.headlineSm,
                        ),
                        if (data.categories.isNotEmpty)
                          Text(
                            '${data.categories.length} categorías',
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Lista de Categorías
                    if (data.categories.isEmpty)
                      AppCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                const Icon(Icons.pie_chart_outline_rounded,
                                    size: 40, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  'Aún no hay categorías asignadas',
                                  style: AppTypography.labelLg,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configura tus bolsas desde la pestaña Presupuesto.',
                                  style: AppTypography.bodySm,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...data.categories.map((cat) {
                        final icon = _mapCategoryIcon(cat.icon);
                        final accentColor = _parseCategoryColor(cat.colorHex);

                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.15),
                                          borderRadius: AppRadius.borderSm,
                                        ),
                                        child: Icon(icon, color: accentColor, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(cat.name, style: AppTypography.labelLg),
                                    ],
                                  ),
                                  Text(
                                    '${_formatCurrency(cat.spentAmount)} / ${_formatCurrency(cat.allocatedAmount)}',
                                    style: AppTypography.numericRow,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              AppProgressBar(progress: cat.progressRatio),
                            ],
                          ),
                        );
                      }),
                  ],

                  const SizedBox(height: 80), // Margen para el Bottom Navigation Bar y FAB
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickScanBanner(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('dashboard_quick_scan_banner'),
        onTap: widget.onScanReceipt,
        borderRadius: AppRadius.borderCard,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: AppRadius.borderCard,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.borderSm,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.textMain,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Escanear Comprobante',
                          style: AppTypography.labelLg.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.incomeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OCR',
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.incomeText,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Registra gastos al instante con tu cámara',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

