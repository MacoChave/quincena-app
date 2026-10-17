import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../data/models/models.dart';
import 'icon_helper.dart';
import 'zero_base_header_card.dart';

/// Tarjeta interactiva de partida presupuestaria (RF-03)
///
/// Muestra:
/// - Categoría (nombre, icono, color)
/// - Cuenta destino asociada (o "Sin cuenta / Efectivo")
/// - Monto presupuestado, gastado y disponible
/// - Barra de progreso con semáforo pastel (<70% #79ADDC, 70-90% #FFEE93, >90% #FFC09F)
/// - Acciones rápidas de edición y eliminación
class AllocationItemTile extends StatelessWidget {
  const AllocationItemTile({
    super.key,
    required this.allocation,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetAllocation allocation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final category = allocation.category;
    final account = allocation.destinationAccount;
    final catColor = category?.parsedColor ?? AppColors.primary;
    final catIcon = resolveCategoryIcon(category?.icon);

    final allocated = allocation.allocatedAmount;
    final spent = allocation.spentAmount;
    final available = allocation.computedAvailable;
    final percentage = allocation.computedPercentage;
    final progress = allocation.progressRatio;

    final accountName = account?.name ?? 'Sin cuenta asignada';
    final accountColor = account?.parsedColor ?? AppColors.textSecondary;

    return AppCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Icono, nombre de categoría, cuenta destino y menú de acciones
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.18),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(catIcon, color: catColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category?.name ?? 'Partida',
                      style: AppTypography.labelLg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          account != null
                              ? account.displayIcon
                              : Icons.money_off_rounded,
                          size: 13,
                          color: accountColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            accountName,
                            style: AppTypography.captionBadge.copyWith(
                              color: accountColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Monto asignado en cifra tabular
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(allocated),
                    style: AppTypography.currencyMd,
                  ),
                  Text(
                    '${percentage.toStringAsFixed(0)}% consumido',
                    style: AppTypography.captionBadge.copyWith(
                      color: percentage > 90
                          ? AppColors.expenseText
                          : (percentage >= 70
                              ? AppColors.warningText
                              : AppColors.textSecondary),
                      fontWeight: percentage >= 70 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              // Botón de menú
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onSelected: (val) {
                  if (val == 'edit') {
                    onEdit();
                  } else if (val == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: AppColors.textMain),
                        SizedBox(width: 8),
                        Text('Editar partida'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.expenseText),
                        SizedBox(width: 8),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: AppColors.expenseText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra de progreso con semáforo pastel
          AppProgressBar(
            progress: progress,
            height: 7,
          ),

          const SizedBox(height: 8),

          // Métricas de Gastado vs Disponible
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gastado: ${formatMoney(spent)}',
                style: AppTypography.numericRow.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                'Disponible: ${formatMoney(available)}',
                style: AppTypography.numericRow.copyWith(
                  color: available < 0 ? AppColors.expenseText : AppColors.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
