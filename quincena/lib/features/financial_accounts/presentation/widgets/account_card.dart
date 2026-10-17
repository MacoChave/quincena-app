import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../models/financial_account.dart';

/// Tarjeta visual para representar una Cuenta Financiera (RF-01 / DERCAS 1.2)
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.onEdit,
    required this.onSetDefault,
    required this.onArchive,
    this.onUnarchive,
  });

  final FinancialAccount account;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onArchive;
  final VoidCallback? onUnarchive;

  @override
  Widget build(BuildContext context) {
    final accountColor = account.parsedColor;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: AppRadius.borderCard,
        border: Border.all(
          color: account.isDefault ? AppColors.primary : AppColors.borderSubtle,
          width: account.isDefault ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banda decorativa superior si es predeterminada o con color distintivo
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accountColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                topRight: Radius.circular(AppRadius.card),
              ),
            ),
          ),
          Padding(
            padding: AppSpacing.paddingCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Icono de tipo, Nombre, Badges y Menú
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar con color distintivo y icono de la cuenta
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accountColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accountColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        account.displayIcon,
                        color: AppColors.textMain,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceSm),
                    // Título y Tipo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  account.name,
                                  style: AppTypography.headlineSm.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (account.isDefault) ...[
                                const SizedBox(width: AppSpacing.spaceXs),
                                const AppBadge.income(
                                  text: 'Predeterminada',
                                ),
                              ],
                              if (account.isArchived) ...[
                                const SizedBox(width: AppSpacing.spaceXs),
                                const AppBadge(
                                  text: 'Archivada',
                                  variant: AppBadgeVariant.neutral,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            account.accountType.label,
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menú de acciones contextuales
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.borderMd,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit();
                            break;
                          case 'default':
                            onSetDefault();
                            break;
                          case 'archive':
                            onArchive();
                            break;
                          case 'unarchive':
                            onUnarchive?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.textMain),
                              const SizedBox(width: AppSpacing.spaceSm),
                              Text('Editar cuenta',
                                  style: AppTypography.bodyMd),
                            ],
                          ),
                        ),
                        if (!account.isDefault && !account.isArchived)
                          PopupMenuItem(
                            value: 'default',
                            child: Row(
                              children: [
                                const Icon(Icons.star_outline_rounded,
                                    size: 18,
                                    color: AppColors.primaryAccessible),
                                const SizedBox(width: AppSpacing.spaceSm),
                                Text('Hacer predeterminada',
                                    style: AppTypography.bodyMd),
                              ],
                            ),
                          ),
                        if (!account.isArchived)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(Icons.archive_outlined,
                                    size: 18, color: AppColors.expenseText),
                                SizedBox(width: AppSpacing.spaceSm),
                                Text(
                                  'Archivar cuenta',
                                  style: TextStyle(
                                    color: AppColors.expenseText,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (onUnarchive != null)
                          const PopupMenuItem(
                            value: 'unarchive',
                            child: Row(
                              children: [
                                Icon(Icons.unarchive_outlined,
                                    size: 18, color: AppColors.incomeText),
                                SizedBox(width: AppSpacing.spaceSm),
                                Text(
                                  'Reactivar cuenta',
                                  style: TextStyle(
                                    color: AppColors.incomeText,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                // Divisor sutil
                const Divider(height: 1, color: AppColors.borderSubtle),
                const SizedBox(height: AppSpacing.spaceSm),
                // Fila Inferior: Saldos (Actual e Inicial) con formato tabular
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo Disponible',
                          style: AppTypography.captionBadge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${account.currency} ${account.currentBalance.toStringAsFixed(2)}',
                          style: AppTypography.currencyMd.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: account.currentBalance < 0
                                ? AppColors.expenseText
                                : AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                    if (account.initialBalance > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Saldo Inicial',
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${account.currency} ${account.initialBalance.toStringAsFixed(2)}',
                            style: AppTypography.numericRow.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
