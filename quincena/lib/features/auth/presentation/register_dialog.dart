import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/theme/theme.dart';
import '../data/auth_session_manager.dart';

/// Modal para creación de cuenta con validación estricta de política de contraseña (CA-A1.2).
class RegisterDialog extends StatefulWidget {
  const RegisterDialog({
    super.key,
    required this.sessionManager,
  });

  final AuthSessionManager sessionManager;

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    final success = await widget.sessionManager.register(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _nameController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada exitosamente. Revisa tu correo o inicia sesión.'),
          backgroundColor: AppColors.incomeText,
        ),
      );
    } else {
      setState(() {
        _errorMessage = widget.sessionManager.lastErrorMessage ??
            'Error al crear la cuenta. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: AppRadius.borderBottomSheet,
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
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

              Text('Crear cuenta en Quincena', style: AppTypography.headlineSm),
              const SizedBox(height: 4),
              Text(
                'Comienza a ordenar tu presupuesto quincenal',
                style: AppTypography.bodySm,
              ),
              const SizedBox(height: 20),

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

              AppTextField(
                controller: _nameController,
                label: 'Nombre completo',
                hintText: 'Ej. Juan Pérez',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                hintText: 'ejemplo@correo.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa tu correo';
                  if (!val.contains('@')) return 'Correo no válido';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _passwordController,
                label: 'Contraseña',
                hintText: 'Mínimo 8 caracteres',
                obscureText: _obscurePassword,
                helperText: 'Debe tener mayúscula, minúscula y un número',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Ingresa una contraseña';
                  if (val.length < 8) return 'Debe tener al menos 8 caracteres';
                  if (!RegExp(r'[A-Z]').hasMatch(val)) return 'Debe tener al menos una mayúscula';
                  if (!RegExp(r'[a-z]').hasMatch(val)) return 'Debe tener al menos una minúscula';
                  if (!RegExp(r'[0-9]').hasMatch(val)) return 'Debe tener al menos un número';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ListenableBuilder(
                listenable: widget.sessionManager,
                builder: (context, _) {
                  return AppButton(
                    text: 'Crear Cuenta',
                    isLoading: widget.sessionManager.isLoading,
                    onPressed: _submitRegister,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
