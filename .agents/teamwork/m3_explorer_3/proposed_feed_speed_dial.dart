import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';

/// Floating Speed Dial para acciones rápidas en la pantalla de Historial de Transacciones (RF-04 / RF-06).
///
/// Permite al usuario desplegar con animación fluida dos acciones directas:
/// 1. "Escanear Ticket" (dispara la cámara OCR o selector de comprobante)
/// 2. "Gasto Manual" (abre el formulario modal de registro de gasto sin comprobante)
class FeedSpeedDial extends StatefulWidget {
  const FeedSpeedDial({
    super.key,
    required this.onScanReceipt,
    required this.onAddManualExpense,
  });

  final VoidCallback onScanReceipt;
  final VoidCallback onAddManualExpense;

  @override
  State<FeedSpeedDial> createState() => _FeedSpeedDialState();
}

class _FeedSpeedDialState extends State<FeedSpeedDial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotationAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _isOpen ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        curve: Curves.easeOut,
        parent: _controller,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        // Touch barrier cuando está abierto
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
              child: Container(
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),
          ),

        // Contenedor de opciones flotantes
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Opción 2: Escanear Ticket (OCR)
              _buildStepItem(
                label: 'Escanear Ticket OCR',
                icon: Icons.document_scanner_rounded,
                iconColor: AppColors.primaryAccessible,
                bgColor: AppColors.primarySubtle,
                offsetFactor: 2.0,
                onTap: () {
                  _close();
                  widget.onScanReceipt();
                },
              ),
              const SizedBox(height: 12),

              // Opción 1: Gasto Manual
              _buildStepItem(
                label: 'Nuevo Gasto Manual',
                icon: Icons.edit_note_rounded,
                iconColor: AppColors.textMain,
                bgColor: AppColors.surfaceHero,
                offsetFactor: 1.0,
                onTap: () {
                  _close();
                  widget.onAddManualExpense();
                },
              ),
              const SizedBox(height: 14),

              // Botón Disparador Principal (FAB)
              Container(
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
                    onTap: _toggle,
                    customBorder: const CircleBorder(),
                    child: Center(
                      child: RotationTransition(
                        turns: _rotationAnimation,
                        child: const Icon(
                          Icons.add_rounded,
                          size: 30,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required double offsetFactor,
    required VoidCallback onTap,
  }) {
    return ScaleTransition(
      scale: _expandAnimation,
      child: FadeTransition(
        opacity: _expandAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.borderPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.borderPill,
                boxShadow: AppShadows.card,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
