import 'package:flutter/material.dart';
import '../../network/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Componente centralizado de Notificaciones Toast / SnackBar para Quincena.
///
/// Características:
/// - Limpia automáticamente mensajes de error técnicos (`ApiException(401):`, `Exception:`, etc.).
/// - Formato flotante y estilizado según el sistema de diseño Stitch.
/// - Variantes semánticas: Error, Éxito, Advertencia e Información.
abstract final class AppToast {
  /// Muestra un toast de error limpiando automáticamente cualquier prefijo técnico de excepción.
  static void showError(
    BuildContext context,
    dynamic error, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    final message = ApiException.extractMessage(error);
    _showSnackBar(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      backgroundColor: const Color(0xFF2C1B1A), // Fondo oscuro con tinte cálido
      iconColor: AppColors.expenseBg,
      borderColor: AppColors.expenseBg.withValues(alpha: 0.4),
      textColor: const Color(0xFFFFF0EC),
      duration: duration,
      action: action,
    );
  }

  /// Muestra un toast de éxito (operaciones completadas, guardado exitoso).
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      backgroundColor: const Color(0xFF1B291E), // Fondo oscuro con tinte verde
      iconColor: AppColors.incomeBg,
      borderColor: AppColors.incomeBg.withValues(alpha: 0.4),
      textColor: const Color(0xFFEDFCF1),
      duration: duration,
      action: action,
    );
  }

  /// Muestra un toast de advertencia (precaución, umbrales).
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFF2D2915),
      iconColor: AppColors.warningBg,
      borderColor: AppColors.warningBg.withValues(alpha: 0.4),
      textColor: const Color(0xFFFFFDEB),
      duration: duration,
      action: action,
    );
  }

  /// Muestra un toast informativo neutro.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      backgroundColor: AppColors.textMain,
      iconColor: AppColors.primary,
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      textColor: AppColors.surfaceBase,
      duration: duration,
      action: action,
    );
  }

  /// Oculta cualquier notificación activa inmediatamente
  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required Color borderColor,
    required Color textColor,
    required Duration duration,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        elevation: 4,
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceMd,
          vertical: AppSpacing.spaceMd,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.spaceMd,
          vertical: 12.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderCard,
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: AppSpacing.spaceSm + 2),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyMd.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: action,
      ),
    );
  }
}
