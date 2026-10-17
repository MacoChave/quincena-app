import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../badges/app_badge.dart';

/// Tarjeta Hero destacada para la pantalla principal de Quincena ("Quincena Activa").
///
/// Especificaciones Stitch:
/// - Fondo Warm Cream (#FCF5C7).
/// - Radio de 16px/20px y sombra ambiental cálida.
/// - Cifra destacada tabular (`AppTypography.currencyHero`).
/// - Badges de Ingreso (#ADF7B6) y Gasto (#FFC09F) con texto de alto contraste (#1C242B).
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    super.key,
    required this.availableAmount,
    required this.incomeAmount,
    required this.expenseAmount,
    this.title = 'DISPONIBLE ESTA QUINCENA',
    this.periodLabel,
    this.onPeriodTap,
    this.footerChild,
  });

  final String availableAmount;
  final String incomeAmount;
  final String expenseAmount;
  final String title;
  final String? periodLabel;
  final VoidCallback? onPeriodTap;
  final Widget? footerChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingHeroCard,
      decoration: BoxDecoration(
        color: AppColors.surfaceHero,
        borderRadius: AppRadius.borderHero,
        border: Border.all(
          color: const Color(0x141C242B), // sutil 8% border
          width: 1,
        ),
        boxShadow: AppShadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila superior: Título y selector de periodo opcional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (periodLabel != null)
                InkWell(
                  onTap: onPeriodTap,
                  borderRadius: AppRadius.borderPill,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          periodLabel!,
                          style: AppTypography.captionBadge.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (onPeriodTap != null) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.textMain,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Monto principal disponible
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              availableAmount,
              style: AppTypography.currencyHero,
            ),
          ),
          const SizedBox(height: 16),

          // Fila de píldoras / métricas secundarias
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppBadge.income(
                text: 'Ingreso: $incomeAmount',
                prefixIcon: const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.incomeText),
              ),
              AppBadge.expense(
                text: 'Gastado: $expenseAmount',
                prefixIcon: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.expenseText),
              ),
            ],
          ),

          if (footerChild != null) ...[
            const SizedBox(height: 16),
            footerChild!,
          ],
        ],
      ),
    );
  }
}
