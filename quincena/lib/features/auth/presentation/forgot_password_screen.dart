import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/theme.dart';
import '../data/auth_session_manager.dart';

/// Screen A2: Recuperación de Contraseña (RF-AUTH-02).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.sessionManager,
  });

  final AuthSessionManager sessionManager;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final msg = await widget.sessionManager.requestPasswordReset(_emailController.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _successMessage = msg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiException.extractMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Icono representativo
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: AppColors.primaryAccessible,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Título y Subtítulo
                Text('Recuperar Contraseña', style: AppTypography.headlineLg),
                const SizedBox(height: 8),
                Text(
                  'Ingresa el correo asociado a tu cuenta para recibir un enlace de restablecimiento.',
                  style: AppTypography.bodyMd,
                ),
                const SizedBox(height: 32),

                // 3. Feedback de Éxito (In-screen Banner #FCF5C7)
                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHero,
                      borderRadius: AppRadius.borderCard,
                      border: Border.all(color: const Color(0x261C242B)),
                      boxShadow: AppShadows.hero,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.incomeText,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Instrucciones enviadas',
                                style: AppTypography.labelLg.copyWith(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _successMessage!,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Feedback de Error
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.expenseBg.withValues(alpha: 0.3),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.expenseText.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.expenseText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Input Correo
                AppTextField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  hintText: 'ejemplo@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitForgotPassword(),
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Ingresa tu correo';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // 5. Botón Enviar Instrucciones (Fondo #79ADDC, texto #1C242B)
                AppButton.tinted(
                  text: 'Enviar Instrucciones',
                  isLoading: _isLoading,
                  onPressed: _submitForgotPassword,
                ),
                const SizedBox(height: 16),

                // Botón Regresar a Login
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Volver al inicio de sesión',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
