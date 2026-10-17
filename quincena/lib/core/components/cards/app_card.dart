import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

/// Tarjeta base modular para inyección de cualquier contenido.
///
/// Implementa:
/// - Superficie blanca (`AppColors.surfaceBase`).
/// - Esquinas redondeadas de 16px (`AppRadius.borderCard`).
/// - Sombra ambiente sutil cálida (`AppShadows.card`).
/// - Interacción táctil opcional con `onTap` e `InkWell`.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.paddingCard,
    this.margin,
    this.backgroundColor = AppColors.surfaceBase,
    this.borderRadius = AppRadius.borderCard,
    this.border,
    this.boxShadow = AppShadows.card,
    this.onTap,
  });

  /// Slot para contenido libre inyectado por el desarrollador
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget cardBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: AppColors.borderHairline),
        boxShadow: boxShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      cardBody = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: cardBody,
        ),
      );
    }

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: cardBody,
      );
    }

    return cardBody;
  }
}
