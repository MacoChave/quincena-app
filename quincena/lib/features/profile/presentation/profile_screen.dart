import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/theme/theme.dart';
import '../../auth/data/auth_session_manager.dart';
import '../../auth/presentation/delete_account_dialog.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../financial_accounts/data/financial_accounts_api_service.dart';
import '../../financial_accounts/presentation/financial_accounts_screen.dart';
import 'widgets/update_password_sheet.dart';

/// Screen A3: Pantalla de Perfil, Configuración y Cierre de Sesión (RF-AUTH-03).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.sessionManager,
    this.onLoggedOut,
  });

  final AuthSessionManager sessionManager;
  final VoidCallback? onLoggedOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    widget.sessionManager.refreshProfile();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderCard),
        title: Text('¿Cerrar sesión?', style: AppTypography.headlineSm),
        content: Text(
          'Se cerrará tu sesión activa y se limpiarán los datos temporales del dispositivo.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: AppTypography.labelMd),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Cerrar Sesión',
              style: AppTypography.labelMd.copyWith(color: AppColors.expenseText),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoggingOut = true);
    await widget.sessionManager.logout();
    if (!mounted) return;
    setState(() => _isLoggingOut = false);
    widget.onLoggedOut?.call();
  }

  void _openDeleteAccount() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeleteAccountDialog(
        sessionManager: widget.sessionManager,
        onAccountDeleted: () {
          widget.onLoggedOut?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu cuenta ha sido eliminada definitivamente.'),
              backgroundColor: AppColors.textMain,
            ),
          );
        },
      ),
    );
  }

  void _openUpdatePassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdatePasswordSheet(sessionManager: widget.sessionManager),
    );
  }

  void _changeCurrency() {
    final currentCurrency = widget.sessionManager.profile?.currency ?? 'GTQ';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: AppRadius.borderBottomSheet,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Seleccionar Moneda Principal', style: AppTypography.headlineSm),
            const SizedBox(height: 16),
            ...['GTQ', 'USD', 'MXN', 'EUR'].map((curr) {
              final isSelected = curr == currentCurrency;
              return ListTile(
                title: Text(
                  curr,
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryAccessible)
                    : null,
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await widget.sessionManager.updateProfile(currency: curr);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: const AppAppBar(
        title: 'Configuración de Cuenta',
      ),
      body: ListenableBuilder(
        listenable: widget.sessionManager,
        builder: (context, _) {
          final profile = widget.sessionManager.profile;
          final user = widget.sessionManager.user;
          final displayName = profile?.displayName ?? user?.fullName ?? 'Usuario Quincena';
          final email = profile?.email ?? user?.email ?? 'correo@ejemplo.com';
          final initials = profile?.initials ?? 'Q';
          final currency = profile?.currency ?? 'GTQ';

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // 1. Tarjeta de Usuario
              AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar con iniciales
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySubtle,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: AppTypography.headlineMd.copyWith(
                              color: AppColors.primaryAccessible,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: AppTypography.labelLg.copyWith(fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: AppTypography.bodySm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.borderSubtle),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Estado del plan',
                          style: AppTypography.captionBadge,
                        ),
                        const AppBadge.income(
                          text: 'Plan Quincenal Activo',
                          prefixIcon: Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.incomeText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Sección: Preferencias & Cuentas
              Text(
                'PREFERENCIAS',
                style: AppTypography.labelSm.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.account_balance_outlined,
                      title: 'Cuentas Financieras',
                      subtitle: 'Bancos, billeteras y efectivo (RF-01)',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FinancialAccountsScreen(
                              accountsService: FinancialAccountsApiService(
                                widget.sessionManager.apiClient,
                              ),
                              onBack: () => Navigator.of(context).pop(),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.category_outlined,
                      title: 'Categorías de Gastos',
                      subtitle: 'Etiquetas, colores e iconos (RF-CAT-01, Screen C1)',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => CategoriesScreen(
                              apiClient: widget.sessionManager.apiClient,
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.view_quilt_outlined,
                      title: 'Plantillas 1ra y 2da Quincena',
                      subtitle: 'Presupuestos predefinidos por periodo (RF-04)',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Módulo de Plantillas Quincenales')),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.payments_outlined,
                      title: 'Moneda principal',
                      subtitle: 'Moneda base del sistema',
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Text(
                          currency,
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.primaryAccessible,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      onTap: _changeCurrency,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Seguridad y Contraseña',
                      subtitle: 'Actualizar tu clave de acceso',
                      onTap: _openUpdatePassword,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 3. Zona de Salida y Seguridad
              // Botón de ancho completo: Cerrar Sesión (borde #79ADDC, texto #1C242B)
              Material(
                color: Colors.white,
                borderRadius: AppRadius.borderMd,
                child: InkWell(
                  onTap: _isLoggingOut ? null : _handleLogout,
                  borderRadius: AppRadius.borderMd,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: _isLoggingOut
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textMain),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: AppColors.textMain,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cerrar Sesión',
                                style: AppTypography.labelLg.copyWith(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Enlace al fondo en color muted: Dar de baja mi cuenta...
              Center(
                child: GestureDetector(
                  onTap: _openDeleteAccount,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Text(
                      'Dar de baja mi cuenta...',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: AppRadius.borderSm,
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(title, style: AppTypography.labelLg),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTypography.bodySm)
          : null,
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
    );
  }
}
