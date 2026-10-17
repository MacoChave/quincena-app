import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../data/models/models.dart';
import 'zero_base_header_card.dart';

/// Sección de resumen de distribución agrupada por cuenta financiera de fondeo (RF-03 / R1)
/// Permite al usuario saber cuánto dinero debe tener o transferir a cada cuenta en la quincena.
class FundingAccountsSummarySection extends StatelessWidget {
  const FundingAccountsSummarySection({
    super.key,
    required this.summaries,
  });

  final List<FundingAccountSummary> summaries;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 18,
              color: AppColors.primaryAccessible,
            ),
            const SizedBox(width: 8),
            Text(
              'Cuentas de Fondeo de la Quincena',
              style: AppTypography.headlineSm,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Saldo requerido a depositar o mantener en cada cuenta para cubrir las partidas presupuestadas.',
          style: AppTypography.bodySm,
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: summaries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return _FundingAccountCard(summary: summary);
          },
        ),
      ],
    );
  }
}

class _FundingAccountCard extends StatelessWidget {
  const _FundingAccountCard({
    required this.summary,
  });

  final FundingAccountSummary summary;

  @override
  Widget build(BuildContext context) {
    final account = summary.account;
    final isUnassigned = account == null;

    final badgeColor = summary.isCovered
        ? AppColors.incomeBg
        : (summary.shortage > 0 ? AppColors.expenseBg : AppColors.warningBg);

    final badgeTextColor = summary.isCovered
        ? AppColors.incomeText
        : (summary.shortage > 0 ? AppColors.expenseText : AppColors.warningText);

    final badgeText = summary.isCovered
        ? 'Cubierto'
        : 'Falta: ${formatMoney(summary.shortage)}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono con color de cuenta
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isUnassigned
                      ? AppColors.primarySubtle
                      : summary.parsedColor.withValues(alpha: 0.18),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(
                  summary.displayIcon,
                  color: isUnassigned
                      ? AppColors.textSecondary
                      : summary.parsedColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              // Nombre de la cuenta y cantidad de partidas
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.displayName,
                      style: AppTypography.labelLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${summary.allocations.length} ${summary.allocations.length == 1 ? "partida" : "partidas"} vinculadas',
                      style: AppTypography.bodySm,
                    ),
                  ],
                ),
              ),

              // Total a fondear en cifra tabular
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(summary.totalAllocated),
                    style: AppTypography.currencyMd,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'A fondear',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Comparativa con saldo actual si no es "Sin cuenta asignada"
          if (!isUnassigned) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Saldo actual: ',
                      style: AppTypography.bodySm,
                    ),
                    Text(
                      formatMoney(summary.currentBalance),
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: AppRadius.borderPill,
                  ),
                  child: Text(
                    badgeText,
                    style: AppTypography.captionBadge.copyWith(
                      color: badgeTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
