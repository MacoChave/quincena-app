import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/theme/theme.dart';
import '../data/auth_session_manager.dart';
import 'forgot_password_screen.dart';
import 'register_dialog.dart';

/// Screen A1: Pantalla de Inicio de Sesión de Quincena (RF-AUTH-01).
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.sessionManager,
    this.onLoginSuccess,
  });

  final AuthSessionManager sessionManager;
  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.sessionManager.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      widget.onLoginSuccess?.call();
    } else {
      final errorMsg = widget.sessionManager.lastErrorMessage ??
          'Credenciales incorrectas o error de conexión.';
      AppToast.showError(context, errorMsg);
    }
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(sessionManager: widget.sessionManager),
      ),
    );
  }

  void _openRegister() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegisterDialog(sessionManager: widget.sessionManager),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Isotipo / Logo geométrico Quincena
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: AppRadius.borderCard,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 34,
                          color: AppColors.primaryAccessible,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Encabezado
                  Text(
                    'Bienvenido de nuevo',
                    style: AppTypography.headlineLg,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu presupuesto quincenal bajo control',
                    style: AppTypography.bodyMd,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),



                  // 3. Formulario: Correo electrónico
                  AppTextField(
                    controller: _emailController,
                    label: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon: const Icon(
                      Icons.mail_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa tu correo';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Ingresa un correo electrónico válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // 4. Formulario: Contraseña
                  AppTextField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    hintText: '••••••••',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitLogin(),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Ingresa tu contraseña';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Enlace a la derecha: ¿Olvidaste tu contraseña?
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _openForgotPassword,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '¿Olvidaste tu contraseña?',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primaryAccessible,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. Botón Primario: Iniciar Sesión (Fondo #1C242B, texto blanco)
                  ListenableBuilder(
                    listenable: widget.sessionManager,
                    builder: (context, _) {
                      return AppButton(
                        text: 'Iniciar Sesión',
                        isLoading: widget.sessionManager.isLoading,
                        onPressed: _submitLogin,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 6. Enlace inferior: Registrarse
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿Aún no tienes cuenta? ',
                        style: AppTypography.bodyMd,
                      ),
                      GestureDetector(
                        onTap: _openRegister,
                        child: Text(
                          'Regístrate gratis',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.primaryAccessible,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
