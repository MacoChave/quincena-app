import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';

/// Visor de Cámara y Marco de Alineación OCR para la App Quincena.
///
/// Implementa fielmente las especificaciones de Stitch Screen `06dd441359e2446c8c5931868b87b4d7`:
/// - Barra superior con indicador pulsante "CÁMARA INTELIGENTE", toggle de linterna y atajo a "Manual".
/// - Máscara oscura semitransparente (`rgba(28, 36, 43, 0.60)` / `bg-inverse-surface/40`).
/// - Ventana central de escaneo con esquinas redondeadas de 16px.
/// - Guías de encuadre en las 4 esquinas en Soft Sky Blue (#79ADDC, trazo de 3.5px).
/// - Barra láser animada de escaneo con gradiente luminoso y sombra fluorescente.
/// - Badge flotante superior con confianza de detección en vivo (e.g. "Paiz detectado (98%)").
/// - Botón disparador central ergonómico y selector de galería fotográfica.
class OcrViewfinder extends StatefulWidget {
  const OcrViewfinder({
    super.key,
    this.cameraPreview,
    this.isTorchOn = false,
    this.onToggleTorch,
    this.onManualTap,
    this.onCapture,
    this.onPickGallery,
    this.detectedMerchant,
    this.confidenceScore,
    this.isProcessing = false,
    this.statusMessage,
  });

  /// Widget opcional que provee el stream en vivo de la cámara del dispositivo.
  /// Si es nulo, se despliega una textura simulada de comprobante de alta fidelidad.
  final Widget? cameraPreview;

  /// Estado actual de la linterna del dispositivo.
  final bool isTorchOn;

  /// Callback emitido al pulsar el botón de linterna.
  final VoidCallback? onToggleTorch;

  /// Callback emitido al pulsar el botón "Manual" en la barra de utilidades.
  final VoidCallback? onManualTap;

  /// Callback emitido al pulsar el disparador principal de captura.
  final VoidCallback? onCapture;

  /// Callback emitido al pulsar el botón de selección desde galería/archivos.
  final VoidCallback? onPickGallery;

  /// Nombre del comercio detectado en tiempo real en el visor.
  final String? detectedMerchant;

  /// Porcentaje de confianza detectado (0.0 a 1.0).
  final double? confidenceScore;

  /// Indica si el comprobante se encuentra en proceso de subida o extracción OCR.
  final bool isProcessing;

  /// Mensaje de estado inferior (ej. "Alinee el comprobante en el recuadro").
  final String? statusMessage;

  @override
  State<OcrViewfinder> createState() => _OcrViewfinderState();
}

class _OcrViewfinderState extends State<OcrViewfinder>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();

    // Pulso para el indicador de "Cámara Inteligente"
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    // Animación vertical del haz láser de escaneo
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _laserController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Barra de Utilidades Superior en el contexto del visor
        _buildTopUtilityBar(),

        const SizedBox(height: 8),

        // 2. Viewport de la Cámara con máscara, guías de esquina y haz láser
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa base: Vista de cámara o backdrop simulado de ticket
                  widget.cameraPreview ?? _buildSimulatedCameraFeed(),

                  // Capa intermedia: Máscara oscura con cutout central y esquinas #79ADDC
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ViewfinderOverlayPainter(
                          cornerColor: AppColors.primary,
                          cutoutRadius: 16.0,
                          cornerLength: 26.0,
                          strokeWidth: 3.5,
                        ),
                      );
                    },
                  ),

                  // Haz láser animado dentro del área de corte
                  _buildAnimatedLaserBar(),

                  // Pill de detección flotante en vivo (e.g. "Paiz detectado (98%)")
                  _buildDetectionPill(),

                  // Etiqueta flotante inferior informativa
                  _buildBottomFloatingGuide(),

                  // Overlay de procesamiento cuando se sube el comprobante
                  if (widget.isProcessing) _buildProcessingScrim(),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 3. Controles Inferiores de Disparo y Selección de Galería
        _buildBottomCaptureControls(),

        const SizedBox(height: 12),
      ],
    );
  }

  /// Barra de utilidades: Indicador "CÁMARA INTELIGENTE", linterna y botón "Manual"
  Widget _buildTopUtilityBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lado izquierdo: Pulso verde y etiqueta
          Row(
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_pulseAnimation),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.incomeBg,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66ADF7B6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'CÁMARA INTELIGENTE',
                style: AppTypography.labelSm.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Lado derecho: Botón de linterna y botón de entrada manual
          Row(
            children: [
              // Botón de Linterna (Torch)
              Material(
                color: widget.isTorchOn ? AppColors.warningBg : AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(20),
                elevation: 1,
                child: InkWell(
                  onTap: widget.onToggleTorch,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    child: Icon(
                      widget.isTorchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      size: 20,
                      color: widget.isTorchOn
                          ? AppColors.textMain
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Botón directo "Manual"
              Material(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(20),
                elevation: 1,
                child: InkWell(
                  onTap: widget.onManualTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: AppColors.textMain,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Manual',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fondo simulado con textura de comprobante fotográfico cuando no hay feed de cámara nativo
  Widget _buildSimulatedCameraFeed() {
    return Container(
      color: const Color(0xFF1E252C),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Imagen de ticket o diseño estilizado con papel térmico
          Opacity(
            opacity: 0.22,
            child: Container(
              width: 240,
              height: 360,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 16,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 100,
                      height: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(width: 140, height: 8, color: Colors.black26),
                  const SizedBox(height: 6),
                  Container(width: 90, height: 8, color: Colors.black26),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 60, height: 10, color: Colors.black54),
                      Container(width: 50, height: 10, color: Colors.black87),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Haz láser horizontal con gradiente brillante animado arriba y abajo
  Widget _buildAnimatedLaserBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cutoutWidth = constraints.maxWidth * 0.82;
        final cutoutHeight = constraints.maxHeight * 0.78;
        final startY = (constraints.maxHeight - cutoutHeight) / 2;

        return Positioned(
          top: startY + (_laserAnimation.value * (cutoutHeight - 6)),
          left: (constraints.maxWidth - cutoutWidth) / 2,
          width: cutoutWidth,
          child: Container(
            height: 3.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  Color(0xFF79ADDC),
                  Color(0xFFCDE5FF),
                  Color(0xFF79ADDC),
                  Colors.transparent,
                ],
                stops: [0.0, 0.2, 0.5, 0.8, 1.0],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xCC79ADDC),
                  blurRadius: 12,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pill de detección superior dentro del encuadre
  Widget _buildDetectionPill() {
    final merchant = widget.detectedMerchant ?? 'Paiz';
    final confidence = widget.confidenceScore != null
        ? '${(widget.confidenceScore! * 100).toInt()}%'
        : '98%';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cutoutHeight = constraints.maxHeight * 0.78;
        final startY = (constraints.maxHeight - cutoutHeight) / 2;

        return Positioned(
          top: startY + 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.incomeBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppColors.incomeText,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$merchant detectado ($confidence)',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.incomeText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Guía informativa en la parte inferior del recuadro
  Widget _buildBottomFloatingGuide() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cutoutHeight = constraints.maxHeight * 0.78;
        final startY = (constraints.maxHeight - cutoutHeight) / 2;

        return Positioned(
          bottom: startY + 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.statusMessage ?? 'Alinee el comprobante en el recuadro',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Scrim oscuro con spinner al momento de subir o procesar
  Widget _buildProcessingScrim() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Procesando comprobante...',
            style: AppTypography.labelLg.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Controles inferiores: Botón de galería y obturador circular principal
  Widget _buildBottomCaptureControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Selector de Archivo / Galería
          Material(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.circular(24),
            elevation: 2,
            child: InkWell(
              onTap: widget.isProcessing ? null : widget.onPickGallery,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 22,
                  color: AppColors.textMain,
                ),
              ),
            ),
          ),

          // Disparador Principal de Captura (Shutter Button)
          GestureDetector(
            onTap: widget.isProcessing ? null : widget.onCapture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 3.5,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceBase,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: widget.isProcessing
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        size: 32,
                        color: AppColors.textMain,
                      ),
              ),
            ),
          ),

          // Espacio simétrico para mantener centrado el obturador
          const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}

/// CustomPainter que dibuja la máscara translúcida con recorte y guías de esquina `#79ADDC`
class _ViewfinderOverlayPainter extends CustomPainter {
  _ViewfinderOverlayPainter({
    required this.cornerColor,
    required this.cutoutRadius,
    required this.cornerLength,
    required this.strokeWidth,
  });

  final Color cornerColor;
  final double cutoutRadius;
  final double cornerLength;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutWidth = size.width * 0.82;
    final cutoutHeight = size.height * 0.78;
    final left = (size.width - cutoutWidth) / 2;
    final top = (size.height - cutoutHeight) / 2;
    final cutoutRect = Rect.fromLTWH(left, top, cutoutWidth, cutoutHeight);
    final cutoutRRect =
        RRect.fromRectAndRadius(cutoutRect, Radius.circular(cutoutRadius));

    // 1. Dibujar máscara oscura con recorte central
    final maskPaint = Paint()
      ..color = const Color(0x991C242B) // rgba(28,36,43,0.60)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cutoutRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, maskPaint);

    // 2. Dibujar guías de esquina en Soft Sky Blue (#79ADDC)
    final cornerPaint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final r = cutoutRadius;
    final cl = cornerLength;

    // Esquina Superior Izquierda (Top-Left)
    final tlPath = Path()
      ..moveTo(cutoutRect.left, cutoutRect.top + cl)
      ..lineTo(cutoutRect.left, cutoutRect.top + r)
      ..arcToPoint(
        Offset(cutoutRect.left + r, cutoutRect.top),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cutoutRect.left + cl, cutoutRect.top);
    canvas.drawPath(tlPath, cornerPaint);

    // Esquina Superior Derecha (Top-Right)
    final trPath = Path()
      ..moveTo(cutoutRect.right - cl, cutoutRect.top)
      ..lineTo(cutoutRect.right - r, cutoutRect.top)
      ..arcToPoint(
        Offset(cutoutRect.right, cutoutRect.top + r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cutoutRect.right, cutoutRect.top + cl);
    canvas.drawPath(trPath, cornerPaint);

    // Esquina Inferior Izquierda (Bottom-Left)
    final blPath = Path()
      ..moveTo(cutoutRect.left, cutoutRect.bottom - cl)
      ..lineTo(cutoutRect.left, cutoutRect.bottom - r)
      ..arcToPoint(
        Offset(cutoutRect.left + r, cutoutRect.bottom),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(cutoutRect.left + cl, cutoutRect.bottom);
    canvas.drawPath(blPath, cornerPaint);

    // Esquina Inferior Derecha (Bottom-Right)
    final brPath = Path()
      ..moveTo(cutoutRect.right - cl, cutoutRect.bottom)
      ..lineTo(cutoutRect.right - r, cutoutRect.bottom)
      ..arcToPoint(
        Offset(cutoutRect.right, cutoutRect.bottom - r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cutoutRect.right, cutoutRect.bottom - cl);
    canvas.drawPath(brPath, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.cornerColor != cornerColor ||
        oldDelegate.cutoutRadius != cutoutRadius ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
