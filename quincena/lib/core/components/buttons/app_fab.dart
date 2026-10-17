import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_shadows.dart';

/// Floating Action Button (FAB) característico de Quincena.
///
/// Diseñado para la acción central de escaneo OCR (+ Escanear Gasto):
/// - Diámetro de 56px (ó versión extendida).
/// - Fondo Soft Sky Blue (#79ADDC) con icono en Deep Navy (#1C242B).
/// - Sombra cálida elevada `AppShadows.fab`.
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.qr_code_scanner_rounded,
    this.tooltip = 'Escanear comprobante',
    this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(9999)),
          boxShadow: AppShadows.fab,
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textMain,
          elevation: 0,
          highlightElevation: 0,
          tooltip: tooltip,
          icon: Icon(icon, size: 24, color: AppColors.textMain),
          label: Text(
            label!,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.fab,
      ),
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              size: 26,
              color: AppColors.textMain,
            ),
          ),
        ),
      ),
    );
  }
}
