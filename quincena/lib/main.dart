import 'package:flutter/material.dart';
import 'core/components/app_components.dart';
import 'core/network/api_client.dart';
import 'core/theme/theme.dart';
import 'features/auth/data/auth_session_manager.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/budget/presentation/budget_screen.dart';
import 'features/dashboard/data/dashboard_api_service.dart';
import 'features/dashboard/presentation/home_screen.dart';
import 'features/profile/presentation/profile_screen.dart';

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

/// Contenedor de navegación principal con Bottom Navigation Bar y FAB central
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

  @override
  void initState() {
    super.initState();
    _dashboardApiService = DashboardApiService(widget.apiClient);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        dashboardApiService: _dashboardApiService,
        onOpenProfile: () => setState(() => _currentIndex = 3),
        onScanReceipt: () {
          AppToast.showInfo(context, 'Acción: Escaneo OCR de Comprobantes');
        },
      ),
      BudgetScreen(
        apiClient: widget.apiClient,
        sessionManager: widget.sessionManager,
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
        onFabPressed: () {
          AppToast.showInfo(context, 'Acción: Abrir Escáner OCR de Tickets');
        },
      ),
    );
  }
}

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
