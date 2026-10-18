import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';

/// Acciones posibles seleccionables desde el selector de captura de comprobantes
enum CaptureSourceAction {
  camera,
  gallery,
  pdf,
  manual,
}

/// Selector modal de origen para la captura de comprobantes o entrada manual (Spec #3, #6).
///
/// Permite al usuario elegir entre:
/// - Captura directa con la cámara del dispositivo.
/// - Selección de imagen existente desde la galería (JPG/PNG).
/// - Selección de archivo PDF digital.
/// - Registro directo en el formulario manual sin comprobante.
class CaptureSourceSheet extends StatelessWidget {
  const CaptureSourceSheet({super.key});

  /// Despliega la hoja modal inferior y retorna la acción seleccionada
  static Future<CaptureSourceAction?> show(BuildContext context) {
    return showModalBottomSheet<CaptureSourceAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const CaptureSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Registrar Gasto Quincenal',
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Elige cómo deseas registrar tu comprobante o partida:',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 18),

          // 1. Cámara en vivo
          _buildOptionTile(
            context: context,
            icon: Icons.photo_camera_rounded,
            iconBg: AppColors.primarySubtle,
            iconColor: AppColors.primaryAccessible,
            title: 'Tomar Foto del Comprobante',
            subtitle: 'Usa la cámara inteligente con escaneo OCR automático',
            action: CaptureSourceAction.camera,
          ),

          const SizedBox(height: 10),

          // 2. Galería de imágenes
          _buildOptionTile(
            context: context,
            icon: Icons.photo_library_outlined,
            iconBg: AppColors.incomeBg.withValues(alpha: 0.35),
            iconColor: AppColors.incomeText,
            title: 'Seleccionar de Galería',
            subtitle: 'Sube una foto de ticket en formato JPG o PNG',
            action: CaptureSourceAction.gallery,
          ),

          const SizedBox(height: 10),

          // 3. Documento PDF
          _buildOptionTile(
            context: context,
            icon: Icons.picture_as_pdf_outlined,
            iconBg: AppColors.warningBg.withValues(alpha: 0.35),
            iconColor: AppColors.warningText,
            title: 'Subir Comprobante PDF',
            subtitle: 'Facturas electrónicas y recibos digitales PDF',
            action: CaptureSourceAction.pdf,
          ),

          const SizedBox(height: 10),

          // 4. Registro manual
          _buildOptionTile(
            context: context,
            icon: Icons.edit_note_rounded,
            iconBg: AppColors.surfaceSubtle,
            iconColor: AppColors.textMain,
            title: 'Registrar Gasto Manual',
            subtitle: 'Ingresa monto y categoría sin comprobante',
            action: CaptureSourceAction.manual,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required CaptureSourceAction action,
  }) {
    return Material(
      color: AppColors.surfaceSubtle,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
