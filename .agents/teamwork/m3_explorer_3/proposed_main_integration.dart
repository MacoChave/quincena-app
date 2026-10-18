import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'core/components/app_components.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme.dart';
import 'features/auth/data/auth_session_manager.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/budget/data/services/budget_api_service.dart';
import 'features/budget/presentation/budget_screen.dart';
import 'features/budget/presentation/notifiers/budget_notifier.dart';
import 'features/dashboard/data/dashboard_api_service.dart';
import 'features/dashboard/presentation/home_screen.dart';
import 'features/ocr/presentation/ocr_scanner_screen.dart';
import 'features/ocr/presentation/widgets/capture_source_sheet.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/transactions/data/services/transaction_api_service.dart';
import 'features/transactions/presentation/feed/transactions_feed_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiClient = ApiClient();
  final sessionManager = AuthSessionManager(apiClient: apiClient);

  runApp(QuincenaApp(apiClient: apiClient, sessionManager: sessionManager));
}

class QuincenaApp extends StatelessWidget {
  const QuincenaApp({
    super.key,
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final AuthSessionManager sessionManager;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quincena',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(
        apiClient: apiClient,
        sessionManager: sessionManager,
      ),
    );
  }
}

/// Enrutador principal de autenticación:
/// Si no está autenticado, muestra [LoginScreen].
/// Si está autenticado, muestra la navegación principal [MainShell].
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final AuthSessionManager sessionManager;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sessionManager,
      builder: (context, _) {
        if (!sessionManager.isAuthenticated) {
          return LoginScreen(
            sessionManager: sessionManager,
          );
        }

        return MainShell(
          apiClient: apiClient,
          sessionManager: sessionManager,
        );
      },
    );
  }
}

/// Contenedor de navegación principal con Bottom Navigation Bar y FAB central.
///
/// Gestiona la coordinación reactiva de saldos entre pestañas:
/// - Pestaña 0 (Inicio): Dashboard reactivo con saldos disponibles y quincena activa.
/// - Pestaña 1 (Presupuesto): Asignaciones quincenales y Presupuesto Base Cero.
/// - Pestaña 2 (Historial): Feed cronológico con filtro rápido y visor de transacciones/detalles.
/// - Pestaña 3 (Perfil): Datos del usuario y configuración de sesión.
///
/// Conserva el estado de navegación mediante [IndexedStack] y propaga actualizaciones
/// de balances en <100ms mediante [_handleBalanceRefresh] y [_dashboardRefreshSignal].
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.apiClient,
    required this.sessionManager,
  });

  final ApiClient apiClient;
  final AuthSessionManager sessionManager;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final DashboardApiService _dashboardApiService;
  late final BudgetApiService _budgetApiService;
  late final BudgetNotifier _budgetNotifier;
  late final TransactionApiService _transactionApiService;

  /// Señal reactiva unificada para invalidar caché y refrescar balances en <100ms
  final ValueNotifier<int> _dashboardRefreshSignal = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _dashboardApiService = DashboardApiService(widget.apiClient);
    _budgetApiService = BudgetApiService(widget.apiClient);
    _transactionApiService = TransactionApiService(widget.apiClient);
    _budgetNotifier = BudgetNotifier(apiService: _budgetApiService);
    _budgetNotifier.loadData();
  }

  @override
  void dispose() {
    _budgetNotifier.dispose();
    _dashboardRefreshSignal.dispose();
    super.dispose();
  }

  /// Sincronización inmediata entre pestañas (<100ms)
  /// Dispara recálculo de Dashboard, Budget Allocations y Feed de Transacciones.
  void _handleBalanceRefresh() {
    _dashboardRefreshSignal.value++;
    _budgetNotifier.refreshAllocations();
  }

  /// Despliega el selector modal de origen de captura (Cámara OCR, Galería/PDF o Registro Manual)
  Future<void> _openCaptureSourceSheet() async {
    final selected = await CaptureSourceSheet.show(context);
    if (!mounted || selected == null) return;

    switch (selected) {
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

  /// Abre la experiencia de escaneo OCR con visor de cámara o selector
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

  /// Abre el flujo de registro manual de gasto (Milestone 4 hook)
  Future<void> _openManualExpenseFlow() async {
    AppToast.showInfo(context, 'Acción: Abrir Formulario de Gasto Manual');
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      // Pestaña 0: Inicio / Dashboard
      HomeScreen(
        dashboardApiService: _dashboardApiService,
        refreshListenable: _dashboardRefreshSignal,
        onOpenProfile: () => setState(() => _currentIndex = 3),
        onScanReceipt: () => _openOcrScannerFlow(ImageSource.camera),
      ),

      // Pestaña 1: Presupuestos Quincenales
      BudgetScreen(
        apiClient: widget.apiClient,
        sessionManager: widget.sessionManager,
        budgetNotifier: _budgetNotifier,
      ),

      // Pestaña 2: Historial de Transacciones (Reemplazo de PlaceholderView)
      TransactionsFeedScreen(
        apiClient: widget.apiClient,
        transactionApiService: _transactionApiService,
        budgetApiService: _budgetApiService,
        refreshListenable: _dashboardRefreshSignal,
        onTransactionDeleted: _handleBalanceRefresh,
        onScanReceipt: () => _openOcrScannerFlow(ImageSource.camera),
        onAddManualExpense: _openManualExpenseFlow,
      ),

      // Pestaña 3: Perfil de Usuario
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

/// Vista auxiliar de reserva para módulos aún no implementados
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppAppBar(title: title),
      body: Center(
        child: Text(
          title,
          style: AppTypography.headlineSm.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
