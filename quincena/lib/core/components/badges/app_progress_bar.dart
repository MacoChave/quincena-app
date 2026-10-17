import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// Barra de progreso de presupuesto por categoría.
///
/// Cambia dinámicamente de color según el porcentaje de consumo:
/// - `< 70%`: Soft Sky Blue (#79ADDC) -> Gasto bajo control.
/// - `70% - 90%`: Soft Sunshine (#FFEE93) -> Alerta de umbral cercano.
/// - `> 90%`: Muted Coral (#FFC09F) -> Límite alcanzado o sobrepasado.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.trackColor = AppColors.progressTrack,
    this.customFillColor,
  });

  /// Progreso de 0.0 a 1.0 (puede ser mayor si hay sobregiro)
  final double progress;
  final double height;
  final Color trackColor;
  final Color? customFillColor;

  Color _resolveColor(double clamped) {
    if (customFillColor != null) return customFillColor!;
    if (clamped < 0.70) return AppColors.primary;
    if (clamped < 0.90) return AppColors.warningBg;
    return AppColors.expenseBg;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final fillColor = _resolveColor(progress);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: AppRadius.borderPill,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth * clamped;
          return Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: barWidth,
              height: height,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: AppRadius.borderPill,
              ),
            ),
          );
        },
      ),
    );
  }
}
