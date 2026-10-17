import 'package:flutter/material.dart';
import '../../../core/components/app_components.dart';
import '../../../core/theme/theme.dart';
import '../data/auth_session_manager.dart';

/// Screen A4: Modal / Pantalla de Baja y Eliminación de Cuenta (RF-AUTH-04).
///
/// Implementa el doble factor de confirmación (CA-A4.2):
/// - Contraseña actual del usuario.
/// - Palabra explícita 'ELIMINAR'.
/// Invoca el borrado en cascada y purga los datos del dispositivo (RN-AUTH-02).
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.sessionManager,
    this.onAccountDeleted,
  });

  final AuthSessionManager sessionManager;
  final VoidCallback? onAccountDeleted;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _passwordController.text.isNotEmpty &&
        _confirmationController.text.trim() == 'ELIMINAR';
  }

  Future<void> _submitDeleteAccount() async {
    if (!_canSubmit) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.sessionManager.deleteAccount(
        currentPassword: _passwordController.text,
        confirmationKeyword: _confirmationController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onAccountDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('ApiException: ', '');
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
            const SizedBox(height: 20),

            // Encabezado con Icono en Soft Coral #FFC09F
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.expenseBg,
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.expenseText,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Dar de baja tu cuenta',
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.textMain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bloque de Advertencia (Card en Warm Cream #FCF5C7)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHero,
                borderRadius: AppRadius.borderCard,
                border: Border.all(color: const Color(0x261C242B)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.expenseText,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esta acción es permanente e irreversible. Se eliminarán todas tus transacciones, presupuestos, categorías e imágenes de facturas escaneadas.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textMain,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
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

            // Campo 1: Contraseña actual
            AppTextField(
              controller: _passwordController,
              label: '1. Ingresa tu contraseña actual',
              hintText: '••••••••',
              obscureText: _obscurePassword,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 16),

            // Campo 2: Escribe 'ELIMINAR' para confirmar
            AppTextField(
              controller: _confirmationController,
              label: "2. Escribe 'ELIMINAR' para confirmar",
              hintText: 'ELIMINAR',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Botón Primario de Peligro (Fondo #FFC09F, texto #1C242B)
            Material(
              color: _canSubmit && !_isLoading
                  ? AppColors.expenseBg
                  : AppColors.surfaceSubtle,
              borderRadius: AppRadius.borderMd,
              child: InkWell(
                onTap: _canSubmit && !_isLoading ? _submitDeleteAccount : null,
                borderRadius: AppRadius.borderMd,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.expenseText),
                          ),
                        )
                      : Text(
                          'Eliminar definitivamente mi cuenta',
                          style: AppTypography.labelLg.copyWith(
                            color: _canSubmit ? AppColors.textMain : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botón Cancelar
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Conservar mi cuenta',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
