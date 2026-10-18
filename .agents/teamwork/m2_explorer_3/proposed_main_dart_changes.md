# Proposed Changes for MainShell (`quincena/lib/main.dart`) & BudgetScreen (`quincena/lib/features/budget/presentation/budget_screen.dart`)

## Rationale
1. Central FAB in `AppBottomNavBar` (`onFabPressed`) currently displays an `AppToast`. It must open `CaptureSourceSheet`, offering Camera, Gallery, and Manual options.
2. `HomeScreen(onScanReceipt)` currently displays an `AppToast`. It must directly trigger the OCR scan workflow.
3. Coordinated Real-Time State:
   - `MainShell` maintains:
     * `DashboardApiService _dashboardApiService`
     * `BudgetApiService _budgetApiService`
     * `BudgetNotifier _budgetNotifier`
     * `ValueNotifier<int> _dashboardRefreshSignal`
   - When a transaction or OCR scan is confirmed, `_handleBalanceRefresh()` is executed:
     * `_dashboardRefreshSignal.value++;` -> Triggers `HomeScreen` reload immediately.
     * `_budgetNotifier.refreshAllocations();` -> Triggers `BudgetNotifier` recalculation immediately.
   - Result: Both screens update reactively with zero lag (<100ms).

## 1. BudgetScreen Changes (`quincena/lib/features/budget/presentation/budget_screen.dart`)

Allow passing an existing `BudgetNotifier` instance while preserving default initialization for standalone tests:

```dart
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({
    super.key,
    required this.apiClient,
    this.sessionManager,
    this.budgetNotifier,
  });

  final ApiClient apiClient;
  final AuthSessionManager? sessionManager;
  final BudgetNotifier? budgetNotifier;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late final BudgetApiService _apiService;
  late final BudgetNotifier _notifier;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _apiService = BudgetApiService(widget.apiClient);
    _notifier = widget.budgetNotifier ?? BudgetNotifier(apiService: _apiService);
    _tabController = TabController(length: 2, vsync: this);
    if (widget.budgetNotifier == null) {
      _notifier.loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (widget.budgetNotifier == null) {
      _notifier.dispose();
    }
    super.dispose();
  }
```

## 2. Main.dart Changes (`quincena/lib/main.dart`)

### Added Imports:
```dart
import 'package:image_picker/image_picker.dart';
import 'features/budget/data/services/budget_api_service.dart';
import 'features/budget/presentation/notifiers/budget_notifier.dart';
import 'features/ocr/presentation/ocr_scanner_screen.dart';
import 'features/ocr/presentation/widgets/capture_source_sheet.dart';
```

### Updated `_MainShellState`:
```dart
class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final DashboardApiService _dashboardApiService;
  late final BudgetApiService _budgetApiService;
  late final BudgetNotifier _budgetNotifier;
  final ValueNotifier<int> _dashboardRefreshSignal = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _dashboardApiService = DashboardApiService(widget.apiClient);
    _budgetApiService = BudgetApiService(widget.apiClient);
    _budgetNotifier = BudgetNotifier(apiService: _budgetApiService);
    _budgetNotifier.loadData();
  }

  @override
  void dispose() {
    _budgetNotifier.dispose();
    _dashboardRefreshSignal.dispose();
    super.dispose();
  }

  /// Recarga en tiempo real de métricas en Dashboard y Asignaciones en Presupuesto (<100ms)
  void _handleBalanceRefresh() {
    _dashboardRefreshSignal.value++;
    _budgetNotifier.refreshAllocations();
  }

  /// Abre el selector modal de fuente de captura (FAB central)
  Future<void> _openCaptureSourceSheet() async {
    final selectedOption = await CaptureSourceSheet.show(context);
    if (!mounted || selectedOption == null) return;

    switch (selectedOption) {
      case CaptureSourceOption.camera:
        await _openOcrScannerFlow(ImageSource.camera);
        break;
      case CaptureSourceOption.gallery:
        await _openOcrScannerFlow(ImageSource.gallery);
        break;
      case CaptureSourceOption.manual:
        await _openManualExpenseFlow();
        break;
    }
  }

  /// Abre el visor / flujo de escaneo OCR
  Future<void> _openOcrScannerFlow([ImageSource? initialSource]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => OcrScannerScreen(
          apiClient: widget.apiClient,
          initialSource: initialSource,
          onManualRequested: () {
            Navigator.of(context).pop();
            _openManualExpenseFlow();
          },
          onTransactionConfirmed: _handleBalanceRefresh,
        ),
      ),
    );

    if (result == true) {
      _handleBalanceRefresh();
    }
  }

  /// Abre el modal de registro manual de gasto (RF-04 / RF-06)
  Future<void> _openManualExpenseFlow() async {
    // Si la pantalla de formulario manual (M4) ya está disponible:
    // Al guardar exitosamente, llama a _handleBalanceRefresh();
    AppToast.showInfo(context, 'Acción: Abrir Formulario de Gasto Manual');
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        dashboardApiService: _dashboardApiService,
        refreshListenable: _dashboardRefreshSignal,
        onOpenProfile: () => setState(() => _currentIndex = 3),
        onScanReceipt: () => _openOcrScannerFlow(ImageSource.camera),
      ),
      BudgetScreen(
        apiClient: widget.apiClient,
        sessionManager: widget.sessionManager,
        budgetNotifier: _budgetNotifier,
      ),
      const PlaceholderView(title: 'Historial de Transacciones'),
      ProfileScreen(
        sessionManager: widget.sessionManager,
        onLoggedOut: () {
          setState(() => _currentIndex = 0);
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        onFabPressed: _openCaptureSourceSheet,
      ),
    );
  }
}
```
