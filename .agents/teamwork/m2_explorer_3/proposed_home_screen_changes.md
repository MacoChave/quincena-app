# Proposed Changes for HomeScreen (`quincena/lib/features/dashboard/presentation/home_screen.dart`)

## Rationale
1. `onScanReceipt` is currently passed to `HomeScreen` in `HomeScreen(onScanReceipt: ...)`, but is never invoked anywhere in the widget tree.
2. In active cycle view (`data.hasActiveCycle == true`), adding a prominent Quick Scan banner directly below `AppHeroCard` provides immediate, single-tap access to OCR receipt capture.
3. For real-time balance refresh (<100ms), `HomeScreen` needs to respond to external refresh signals (e.g., when a transaction is confirmed via OCR or created manually). Making `HomeScreenState` public with a `refresh()` method and adding `final Listenable? refreshListenable` enables synchronous or reactive trigger with zero overhead.

## Exact Code Diffs

### 1. Update Constructor and State Definition (Lines 14–30)

**Before:**
```dart
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.dashboardApiService,
    required this.onOpenProfile,
    this.onScanReceipt,
  });

  final DashboardApiService dashboardApiService;
  final VoidCallback onOpenProfile;
  final VoidCallback? onScanReceipt;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
```

**After:**
```dart
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

  /// Señal reactiva opcional para actualizar el dashboard en tiempo real (<100ms)
  final Listenable? refreshListenable;

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
```

### 2. State Lifecycle Hooks & Refresh Method (Lines 34–45)

**Add inside `HomeScreenState`:**
```dart
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

  /// Método público para forzar la recarga inmediata del Dashboard (<100ms)
  void refresh() {
    _loadDashboard();
  }
```

### 3. Add Quick Scan Banner in Active Cycle View (after line 284)

**After `AppHeroCard` in `ListView` (Case 2: Active Cycle):**
```dart
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
                    const SizedBox(height: 16),

                    // Banner de Acción Rápida: Escanear Comprobante OCR (RF-03/05)
                    if (widget.onScanReceipt != null) ...[
                      _buildQuickScanBanner(context),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 24),

                    // 2. Presupuestos por Categoría
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
```

### 4. Implement `_buildQuickScanBanner` Method

```dart
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
```
