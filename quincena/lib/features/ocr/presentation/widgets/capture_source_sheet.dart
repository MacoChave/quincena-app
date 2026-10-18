import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';

/// Opciones disponibles en el selector de captura de comprobantes (RF-03/05, RF-04/06).
enum CaptureSourceOption {
  camera,
  gallery,
  manual,
}

/// Selector modal de origen de captura de comprobantes (CaptureSourceSheet).
///
/// Permite al usuario elegir entre:
/// 1. Tomar foto con la cámara (Escáner OCR en vivo)
/// 2. Subir imagen de ticket o documento PDF desde la galería / almacenamiento
/// 3. Registro manual directo sin comprobante físico
class CaptureSourceSheet extends StatelessWidget {
  const CaptureSourceSheet({
    super.key,
    this.onCameraSelected,
    this.onGallerySelected,
    this.onManualSelected,
  });

  final VoidCallback? onCameraSelected;
  final VoidCallback? onGallerySelected;
  final VoidCallback? onManualSelected;

  static Future<CaptureSourceOption?> show(BuildContext context) {
    return showModalBottomSheet<CaptureSourceOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CaptureSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primaryAccessible,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar Gasto',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        Text(
                          'Selecciona cómo deseas registrar tu gasto o comprobante',
                          style: AppTypography.captionBadge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: 16),

              // 1. Tomar Foto (Cámara OCR)
              _buildOptionTile(
                context,
                key: const Key('capture_option_camera'),
                icon: Icons.camera_alt_rounded,
                iconBgColor: AppColors.primarySubtle,
                iconColor: AppColors.primaryAccessible,
                title: 'Tomar Foto',
                subtitle: 'Escaneo inteligente OCR con la cámara del dispositivo',
                badgeText: 'Recomendado',
                badgeBgColor: AppColors.incomeBg,
                badgeTextColor: AppColors.incomeText,
                onTap: () {
                  if (onCameraSelected != null) {
                    onCameraSelected!();
                  } else {
                    Navigator.of(context).pop(CaptureSourceOption.camera);
                  }
                },
              ),
              const SizedBox(height: 12),

              // 2. Subir de Galería o PDF
              _buildOptionTile(
                context,
                key: const Key('capture_option_gallery'),
                icon: Icons.photo_library_outlined,
                iconBgColor: AppColors.warningBg.withValues(alpha: 0.35),
                iconColor: AppColors.textMain,
                title: 'Subir de Galería o PDF',
                subtitle: 'Selecciona una imagen de ticket o archivo PDF digital',
                onTap: () {
                  if (onGallerySelected != null) {
                    onGallerySelected!();
                  } else {
                    Navigator.of(context).pop(CaptureSourceOption.gallery);
                  }
                },
              ),
              const SizedBox(height: 12),

              // 3. Registro Manual
              _buildOptionTile(
                context,
                key: const Key('capture_option_manual'),
                icon: Icons.edit_note_rounded,
                iconBgColor: AppColors.expenseBg.withValues(alpha: 0.35),
                iconColor: AppColors.textMain,
                title: 'Registro Manual',
                subtitle: 'Ingresar monto, categoría y cuenta sin comprobante físico',
                onTap: () {
                  if (onManualSelected != null) {
                    onManualSelected!();
                  } else {
                    Navigator.of(context).pop(CaptureSourceOption.manual);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? badgeBgColor,
    Color? badgeTextColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTypography.labelLg.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBgColor ?? AppColors.primarySubtle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badgeText,
                              style: AppTypography.captionBadge.copyWith(
                                color: badgeTextColor ?? AppColors.textMain,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
