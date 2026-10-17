import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/theme.dart';
import '../../../auth/data/auth_session_manager.dart';

/// Modal para cambio seguro de contraseña de usuario autenticado (RF-AUTH-02, CA-A2.3).
class UpdatePasswordSheet extends StatefulWidget {
  const UpdatePasswordSheet({
    super.key,
    required this.sessionManager,
  });

  final AuthSessionManager sessionManager;

  @override
  State<UpdatePasswordSheet> createState() => _UpdatePasswordSheetState();
}

class _UpdatePasswordSheetState extends State<UpdatePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.sessionManager.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.showSuccess(context, 'Contraseña actualizada con éxito.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiException.extractMessage(e);
      });
      AppToast.showError(context, e);
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
              Text('Actualizar Contraseña', style: AppTypography.headlineSm),
              const SizedBox(height: 4),
              Text(
                'Ingresa tu contraseña actual y define una nueva.',
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
                controller: _currentPasswordController,
                label: 'Contraseña actual',
                hintText: '••••••••',
                obscureText: true,
                validator: (v) => v == null || v.isEmpty ? 'Ingresa tu contraseña actual' : null,
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _newPasswordController,
                label: 'Nueva contraseña',
                hintText: 'Mínimo 8 caracteres',
                obscureText: true,
                helperText: 'Debe incluir mayúscula, minúscula y un número',
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Ingresa la nueva contraseña';
                  if (val.length < 8) return 'Mínimo 8 caracteres';
                  if (val == _currentPasswordController.text) {
                    return 'La nueva contraseña no puede ser idéntica a la actual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: _confirmPasswordController,
                label: 'Confirmar nueva contraseña',
                hintText: '••••••••',
                obscureText: true,
                validator: (v) => v == null || v.isEmpty ? 'Confirma la nueva contraseña' : null,
              ),
              const SizedBox(height: 24),

              AppButton(
                text: 'Guardar Contraseña',
                isLoading: _isLoading,
                onPressed: _submitUpdatePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
