import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

enum AppButtonVariant {
  /// Botón principal con alto contraste (Fondo #1C242B, texto blanco, 52px de alto)
  primary,

  /// Botón secundario con borde sutil transparente y texto #1C242B
  secondary,

  /// Botón suave con tono de marca (#79ADDC)
  tinted,

  /// Botón plano/texto sin borde
  ghost,
}

/// Botón reutilizable optimizado para Quincena.
///
/// Cumple con las directrices ergonómicas de Stitch:
/// - Altura táctil estándar de 52px.
/// - Bordes redondeados de 12px (AppRadius.md).
/// - Estado de carga (`isLoading`) desacoplado y animado.
/// - Soporte para iconos prefijo/sufijo y ancho completo (`isFullWidth`).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.prefixIcon,
    this.suffixIcon,
    this.height = 52.0,
  });

  /// Constructor de conveniencia para botón secundario
  const AppButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.prefixIcon,
    this.suffixIcon,
    this.height = 52.0,
  }) : variant = AppButtonVariant.secondary;

  /// Constructor de conveniencia para botón con tinte suave
  const AppButton.tinted({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.prefixIcon,
    this.suffixIcon,
    this.height = 52.0,
  }) : variant = AppButtonVariant.tinted;

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double height;

  bool get _isEnabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final (backgroundColor, foregroundColor, borderSide) = _resolveStyle();

    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isLoading
          ? SizedBox(
              key: const ValueKey('loading'),
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
              ),
            )
          : Row(
              key: const ValueKey('content'),
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (prefixIcon != null) ...[
                  prefixIcon!,
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: AppTypography.labelLg.copyWith(
                      color: foregroundColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (suffixIcon != null) ...[
                  const SizedBox(width: 8),
                  suffixIcon!,
                ],
              ],
            ),
    );

    final button = Material(
      color: backgroundColor,
      borderRadius: AppRadius.borderMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isEnabled ? onPressed : null,
        borderRadius: AppRadius.borderMd,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: borderSide != null ? Border.fromBorderSide(borderSide) : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  (Color bg, Color fg, BorderSide? border) _resolveStyle() {
    if (!_isEnabled && !isLoading) {
      return (
        AppColors.surfaceSubtle,
        AppColors.textMuted,
        const BorderSide(color: AppColors.borderSubtle),
      );
    }

    switch (variant) {
      case AppButtonVariant.primary:
        return (AppColors.textMain, Colors.white, null);
      case AppButtonVariant.secondary:
        return (
          Colors.transparent,
          AppColors.textMain,
          const BorderSide(color: Color(0x261C242B), width: 1.5),
        );
      case AppButtonVariant.tinted:
        return (AppColors.primary, AppColors.textMain, null);
      case AppButtonVariant.ghost:
        return (Colors.transparent, AppColors.textMain, null);
    }
  }
}
