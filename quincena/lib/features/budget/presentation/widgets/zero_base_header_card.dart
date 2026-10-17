import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../../dashboard/data/models/dashboard_data.dart';
import '../../data/models/models.dart';

/// Formatea un número monetario con separadores de miles y 2 decimales
String formatMoney(double amount) {
  final isNeg = amount < -0.009;
  final absVal = amount.abs();
  final fixed = absVal.toStringAsFixed(2);
  final splitParts = fixed.split('.');
  final integerPart = splitParts[0];
  final decimalPart = splitParts[1];

  final buffer = StringBuffer();
  for (int i = 0; i < integerPart.length; i++) {
    if (i > 0 && (integerPart.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(integerPart[i]);
  }

  final formatted = '\$${buffer.toString()}.$decimalPart';
  return isNeg ? '-$formatted' : formatted;
}

/// Tarjeta Hero de Presupuesto Base Cero (RF-03 / R1)
///
/// Calcula y muestra en tiempo real el indicador "Por Asignar" con
/// semaforización pastel según el balance:
/// - Exactamente $0.00 (Base Cero): Fondo verde pastel (#ADF7B6), texto #236B31 / #1C242B, icono check.
/// - Superávit (> $0.00): Fondo azul pastel (#79ADDC) o crema, texto #1C242B.
/// - Déficit / Sobreasignado (< $0.00): Fondo coral pastel (#FFC09F), texto #A33F19, alerta visual.
class ZeroBaseHeaderCard extends StatelessWidget {
  const ZeroBaseHeaderCard({
    super.key,
    required this.summary,
    this.cycle,
  });

  final AllocationsSummary summary;
  final DashboardCycle? cycle;

  @override
  Widget build(BuildContext context) {
    final unallocated = summary.unallocated;
    final isBaseZero = summary.isBaseZero;
    final hasDeficit = summary.hasDeficit;

    // Resuelve color y estilo del badge dinámico
    final Color badgeBg;
    final Color badgeTextColor;
    final IconData badgeIcon;
    final String badgeLabel;
    final String statusMessage;

    if (isBaseZero) {
      badgeBg = AppColors.incomeBg; // #ADF7B6
      badgeTextColor = AppColors.incomeText; // #236B31
      badgeIcon = Icons.check_circle_rounded;
      badgeLabel = 'Base Cero: \$0.00';
      statusMessage = '¡Presupuesto Base Cero logrado! Cada centavo tiene un destino asignado.';
    } else if (hasDeficit) {
      badgeBg = AppColors.expenseBg; // #FFC09F
      badgeTextColor = AppColors.expenseText; // #A33F19
      badgeIcon = Icons.warning_amber_rounded;
      badgeLabel = 'Déficit: ${formatMoney(unallocated)}';
      statusMessage = 'Has asignado más de tu ingreso quincenal. Rebalancea tus bolsas.';
    } else {
      badgeBg = AppColors.primary; // #79ADDC
      badgeTextColor = AppColors.textMain; // #1C242B
      badgeIcon = Icons.account_balance_wallet_outlined;
      badgeLabel = 'Por Asignar: +${formatMoney(unallocated)}';
      statusMessage = 'Fondos disponibles por asignar a tus categorías o metas de ahorro.';
    }

    final periodTitle = cycle != null ? cycle!.periodFormatted : 'Quincena Activa';

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingHeroCard,
      decoration: BoxDecoration(
        color: AppColors.surfaceHero, // Warm Cream #FCF5C7
        borderRadius: AppRadius.borderHero,
        border: Border.all(
          color: const Color(0x141C242B),
          width: 1,
        ),
        boxShadow: AppShadows.hero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila superior: Título y período
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'POR ASIGNAR (BASE CERO)',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x0F1C242B),
                  borderRadius: AppRadius.borderPill,
                ),
                child: Text(
                  periodTitle,
                  style: AppTypography.captionBadge.copyWith(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cifra principal destacada tabular
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(unallocated),
              style: AppTypography.currencyHero,
            ),
          ),
          const SizedBox(height: 12),

          // Badge dinámico según estado de balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: AppRadius.borderPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 16, color: badgeTextColor),
                const SizedBox(width: 6),
                Text(
                  badgeLabel,
                  style: AppTypography.captionBadge.copyWith(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Mensaje de estado descriptivo
          Text(
            statusMessage,
            style: AppTypography.bodySm.copyWith(
              color: hasDeficit ? AppColors.expenseText : AppColors.textSecondary,
              fontWeight: hasDeficit ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),

          // Fila de métricas secundarias
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppBadge.income(
                text: 'Ingreso: ${formatMoney(summary.totalIncome)}',
                prefixIcon: const Icon(
                  Icons.arrow_downward_rounded,
                  size: 14,
                  color: AppColors.incomeText,
                ),
              ),
              AppBadge(
                text: 'Asignado: ${formatMoney(summary.totalAllocated)}',
                variant: AppBadgeVariant.neutral,
                prefixIcon: const Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 14,
                  color: AppColors.textMain,
                ),
              ),
              if (summary.totalSpent > 0)
                AppBadge.expense(
                  text: 'Gastado: ${formatMoney(summary.totalSpent)}',
                  prefixIcon: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 14,
                    color: AppColors.expenseText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
