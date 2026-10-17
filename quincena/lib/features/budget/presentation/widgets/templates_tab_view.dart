import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../../financial_accounts/models/financial_account.dart';
import '../../data/models/models.dart';
import 'icon_helper.dart';
import 'zero_base_header_card.dart';

/// Vista de Plantillas Maestras para 1ra y 2da Quincena (RF-04)
class TemplatesTabView extends StatelessWidget {
  const TemplatesTabView({
    super.key,
    required this.selectedPeriod,
    required this.templates,
    required this.categories,
    required this.accounts,
    required this.hasActiveCycle,
    required this.activeCycleHasAllocations,
    required this.onPeriodChanged,
    required this.onAddTemplateItem,
    required this.onEditTemplateItem,
    required this.onDeleteTemplateItem,
    required this.onApplyTemplate,
    required this.onSaveCycleAsTemplate,
    this.isActionLoading = false,
  });

  final QuincenaPeriod selectedPeriod;
  final List<BudgetTemplate> templates;
  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final bool hasActiveCycle;
  final bool activeCycleHasAllocations;
  final ValueChanged<QuincenaPeriod> onPeriodChanged;
  final VoidCallback onAddTemplateItem;
  final ValueChanged<BudgetTemplate> onEditTemplateItem;
  final ValueChanged<BudgetTemplate> onDeleteTemplateItem;
  final Future<void> Function({required bool overwrite}) onApplyTemplate;
  final Future<void> Function() onSaveCycleAsTemplate;
  final bool isActionLoading;

  double get _totalDefaultAmount =>
      templates.fold<double>(0.0, (sum, t) => sum + t.defaultAmount);

  Future<void> _handleApplyTemplate(BuildContext context) async {
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La plantilla seleccionada no tiene partidas configuradas.'),
          backgroundColor: AppColors.textMain,
        ),
      );
      return;
    }

    if (!hasActiveCycle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay un ciclo activo para aplicar la plantilla.'),
          backgroundColor: AppColors.expenseText,
        ),
      );
      return;
    }

    if (!activeCycleHasAllocations) {
      // Ciclo vacío: aplicar directamente
      try {
        await onApplyTemplate(overwrite: false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Plantilla aplicada exitosamente al ciclo activo!'),
              backgroundColor: AppColors.incomeText,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al aplicar plantilla: $e'),
              backgroundColor: AppColors.expenseText,
            ),
          );
        }
      }
      return;
    }

    // Ciclo ya tiene asignaciones: mostrar modal de confirmación
    final shouldOverwrite = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderCard),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.expenseText),
            const SizedBox(width: 8),
            Text('Sobrescribir Ciclo', style: AppTypography.headlineSm),
          ],
        ),
        content: Text(
          'El ciclo activo ya contiene asignaciones presupuestarias.\n\n'
          '¿Deseas reemplazar todas las partidas existentes con las de esta plantilla?',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseText,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sobrescribir'),
          ),
        ],
      ),
    );

    if (shouldOverwrite == true && context.mounted) {
      try {
        await onApplyTemplate(overwrite: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Plantilla aplicada y partidas sobrescritas exitosamente!'),
              backgroundColor: AppColors.incomeText,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al sobrescribir plantilla: $e'),
              backgroundColor: AppColors.expenseText,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSaveCycleAsTemplate(BuildContext context) async {
    if (!hasActiveCycle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay un ciclo activo del cual capturar la plantilla.'),
          backgroundColor: AppColors.expenseText,
        ),
      );
      return;
    }

    if (!activeCycleHasAllocations) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El ciclo activo no tiene partidas registradas para guardar.'),
          backgroundColor: AppColors.textMain,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderCard),
        title: Row(
          children: [
            const Icon(Icons.bookmark_border_rounded, color: AppColors.primaryAccessible),
            const SizedBox(width: 8),
            Text('Guardar como Plantilla', style: AppTypography.headlineSm),
          ],
        ),
        content: Text(
          '¿Deseas actualizar la plantilla maestra de la ${selectedPeriod.label} '
          'con las partidas y montos del ciclo actual?\n\n'
          'Los ciclos históricos o cerrados no serán modificados.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textMain,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await onSaveCycleAsTemplate();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Plantilla de la ${selectedPeriod.label} actualizada exitosamente!'),
              backgroundColor: AppColors.incomeText,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar ciclo como plantilla: $e'),
              backgroundColor: AppColors.expenseText,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector Segmentado de Quincena [1ra Quincena] / [2da Quincena]
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: AppRadius.borderPill,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Expanded(
                child: _PeriodSegmentButton(
                  title: '1ra Quincena',
                  subtitle: '1 al 15',
                  isSelected: selectedPeriod == QuincenaPeriod.firstHalf,
                  onTap: () => onPeriodChanged(QuincenaPeriod.firstHalf),
                ),
              ),
              Expanded(
                child: _PeriodSegmentButton(
                  title: '2da Quincena',
                  subtitle: '16 al fin de mes',
                  isSelected: selectedPeriod == QuincenaPeriod.secondHalf,
                  onTap: () => onPeriodChanged(QuincenaPeriod.secondHalf),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Tarjeta resumen de la plantilla maestra
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceHero,
            borderRadius: AppRadius.borderCard,
            border: Border.all(color: const Color(0x141C242B)),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL BASE PLANTILLA',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(_totalDefaultAmount),
                    style: AppTypography.currencyHeroMobile,
                  ),
                  Text(
                    '${templates.length} ${templates.length == 1 ? "partida base" : "partidas base"}',
                    style: AppTypography.captionBadge,
                  ),
                ],
              ),
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textMain,
                ),
                onPressed: onAddTemplateItem,
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Agregar partida a plantilla',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Botones de acción masiva de RF-04
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                  side: const BorderSide(color: AppColors.primaryAccessible),
                  foregroundColor: AppColors.textMain,
                ),
                icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryAccessible),
                label: const Text('Aplicar al ciclo', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: isActionLoading ? null : () => _handleApplyTemplate(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                  side: const BorderSide(color: AppColors.borderSubtle),
                  foregroundColor: AppColors.textMain,
                ),
                icon: const Icon(Icons.bookmark_added_outlined, color: AppColors.textSecondary),
                label: const Text('Guardar ciclo', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: isActionLoading ? null : () => _handleSaveCycleAsTemplate(context),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Listado de partidas de la plantilla
        if (templates.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: AppRadius.borderCard,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome_mosaic_outlined,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin partidas en ${selectedPeriod.label}',
                    style: AppTypography.headlineSm,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Agrega categorías y montos sugeridos para precargar rápidamente esta quincena.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: '+ Agregar Partida Base',
                    isFullWidth: false,
                    onPressed: onAddTemplateItem,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = templates[index];
              return _TemplateItemCard(
                template: item,
                onEdit: () => onEditTemplateItem(item),
                onDelete: () => onDeleteTemplateItem(item),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PeriodSegmentButton extends StatelessWidget {
  const _PeriodSegmentButton({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderPill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.borderPill,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: AppTypography.labelMd.copyWith(
                color: AppColors.textMain,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.captionBadge.copyWith(
                color: isSelected ? AppColors.textMain : AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateItemCard extends StatelessWidget {
  const _TemplateItemCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cat = template.category;
    final account = template.destinationAccount;
    final catColor = cat?.parsedColor ?? AppColors.primary;
    final catIcon = resolveCategoryIcon(cat?.icon);

    return AppCard(
      onTap: onEdit,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.18),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(catIcon, color: catColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat?.name ?? 'Partida Base',
                  style: AppTypography.labelLg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      account != null ? account.displayIcon : Icons.money_off_rounded,
                      size: 12,
                      color: account?.parsedColor ?? AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        account?.name ?? 'Sin cuenta destino',
                        style: AppTypography.captionBadge.copyWith(
                          color: account?.parsedColor ?? AppColors.textSecondary,
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
          Text(
            formatMoney(template.defaultAmount),
            style: AppTypography.currencyMd,
          ),
          const SizedBox(width: 4),
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
                    Text('Editar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expenseText),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: AppColors.expenseText)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
