import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/presentation/widgets/icon_helper.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/models.dart';

/// Criterios de filtrado reactivos para el feed de transacciones
class FeedFilterCriteria {
  const FeedFilterCriteria({
    this.searchQuery,
    this.selectedCategoryId,
    this.selectedAccountId,
    this.ocrOnly = false,
  });

  final String? searchQuery;
  final String? selectedCategoryId;
  final String? selectedAccountId;
  final bool ocrOnly;

  /// Retorna si todos los filtros se encuentran en su estado por defecto
  bool get isDefault =>
      (searchQuery == null || searchQuery!.trim().isEmpty) &&
      selectedCategoryId == null &&
      selectedAccountId == null &&
      !ocrOnly;

  FeedFilterCriteria copyWith({
    String? searchQuery,
    String? selectedCategoryId,
    String? selectedAccountId,
    bool? ocrOnly,
    bool clearSearch = false,
    bool clearCategory = false,
    bool clearAccount = false,
  }) {
    return FeedFilterCriteria(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      selectedAccountId:
          clearAccount ? null : (selectedAccountId ?? this.selectedAccountId),
      ocrOnly: ocrOnly ?? this.ocrOnly,
    );
  }

  /// Aplica los criterios combinados a una lista de transacciones en memoria (<16ms)
  List<Transaction> apply(
    List<Transaction> transactions, {
    Map<String, String>? scanAuthNumbers,
  }) {
    return transactions.where((tx) {
      // 1. Filtro de comprobante OCR
      if (ocrOnly && tx.entryMethod != EntryMethod.ocr) {
        return false;
      }

      // 2. Filtro de categoría
      if (selectedCategoryId != null &&
          selectedCategoryId!.isNotEmpty &&
          selectedCategoryId != 'all') {
        if (tx.category?.id != selectedCategoryId &&
            tx.allocationId != selectedCategoryId) {
          return false;
        }
      }

      // 3. Filtro de cuenta financiera
      if (selectedAccountId != null &&
          selectedAccountId!.isNotEmpty &&
          selectedAccountId != 'all') {
        if (tx.sourceAccountId != selectedAccountId) {
          return false;
        }
      }

      // 4. Búsqueda por texto (comercio, notas o número de autorización)
      if (searchQuery != null && searchQuery!.trim().isNotEmpty) {
        final q = searchQuery!.trim().toLowerCase();
        final merchantMatch = tx.merchantName.toLowerCase().contains(q);
        final notesMatch = tx.notes?.toLowerCase().contains(q) ?? false;
        bool authMatch = false;

        if (tx.receiptScanId != null) {
          authMatch = tx.receiptScanId!.toLowerCase().contains(q);
          if (!authMatch && scanAuthNumbers != null) {
            final authNum = scanAuthNumbers[tx.receiptScanId];
            if (authNum != null && authNum.toLowerCase().contains(q)) {
              authMatch = true;
            }
          }
        }

        if (!merchantMatch && !notesMatch && !authMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

/// Barra deslizante horizontal de chips de filtrado (RF-04 / RF-06).
///
/// Especificación de diseño: Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:102-127`.
/// - Chip "Todos": Píldora destacada en Dark Navy (`#1C242B`) cuando está activa.
/// - Chip "Con Factura OCR": Ícono `document_scanner` en Soft Blue (`#79ADDC`).
/// - Chips de Categoría: Íconos y fondos tintados con el color pastel de cada bolsa.
/// - Chips de Cuentas Financieras: Íconos de cuenta bancaria / efectivo con su etiqueta.
/// - Permite combinaciones y conmutaciones simultáneas.
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.categories,
    required this.accounts,
    this.selectedCategoryId,
    this.selectedAccountId,
    this.ocrOnly = false,
    required this.onFilterChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final String? selectedCategoryId;
  final String? selectedAccountId;
  final bool ocrOnly;
  final ValueChanged<FeedFilterCriteria> onFilterChanged;
  final EdgeInsetsGeometry padding;

  bool get _isAllSelected =>
      selectedCategoryId == null && selectedAccountId == null && !ocrOnly;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // 1. Chip "Todos"
          _PillChip(
            key: const Key('chip_todos'),
            label: 'Todos',
            isSelected: _isAllSelected,
            activeBackgroundColor: AppColors.textMain,
            activeForegroundColor: AppColors.surfaceBase,
            onTap: () {
              onFilterChanged(
                FeedFilterCriteria(
                  selectedCategoryId: null,
                  selectedAccountId: null,
                  ocrOnly: false,
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // 2. Chip "Con Factura OCR"
          _PillChip(
            key: const Key('chip_ocr_only'),
            label: 'Con Factura OCR',
            icon: Icons.document_scanner_rounded,
            isSelected: ocrOnly,
            activeBackgroundColor: AppColors.primary.withValues(alpha: 0.25),
            activeForegroundColor: AppColors.primaryAccessible,
            activeBorderColor: AppColors.primaryAccessible,
            iconColor: ocrOnly ? AppColors.primaryAccessible : AppColors.primaryAccessible,
            onTap: () {
              onFilterChanged(
                FeedFilterCriteria(
                  selectedCategoryId: selectedCategoryId,
                  selectedAccountId: selectedAccountId,
                  ocrOnly: !ocrOnly,
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // 3. Chips de Categorías
          ...categories.map((cat) {
            final isSelected = selectedCategoryId == cat.id;
            final catColor = cat.parsedColor;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PillChip(
                key: Key('chip_cat_${cat.id}'),
                label: cat.name,
                icon: resolveCategoryIcon(cat.icon),
                isSelected: isSelected,
                activeBackgroundColor: catColor.withValues(alpha: 0.35),
                activeForegroundColor: AppColors.textMain,
                activeBorderColor: catColor,
                iconColor: catColor,
                onTap: () {
                  onFilterChanged(
                    FeedFilterCriteria(
                      selectedCategoryId: isSelected ? null : cat.id,
                      selectedAccountId: selectedAccountId,
                      ocrOnly: ocrOnly,
                    ),
                  );
                },
              ),
            );
          }),

          // 4. Chips de Cuentas Financieras
          ...accounts.map((acc) {
            final isSelected = selectedAccountId == acc.id;
            final accColor = acc.parsedColor;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PillChip(
                key: Key('chip_acc_${acc.id}'),
                label: acc.name,
                icon: acc.displayIcon,
                isSelected: isSelected,
                activeBackgroundColor: accColor.withValues(alpha: 0.25),
                activeForegroundColor: AppColors.textMain,
                activeBorderColor: accColor,
                iconColor: accColor,
                onTap: () {
                  onFilterChanged(
                    FeedFilterCriteria(
                      selectedCategoryId: selectedCategoryId,
                      selectedAccountId: isSelected ? null : acc.id,
                      ocrOnly: ocrOnly,
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Widget interno para píldoras táctiles con micro-interacción y soporte de accesibilidad
class _PillChip extends StatelessWidget {
  const _PillChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.activeBackgroundColor,
    this.activeForegroundColor,
    this.activeBorderColor,
    this.iconColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? activeBackgroundColor;
  final Color? activeForegroundColor;
  final Color? activeBorderColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? (activeBackgroundColor ?? AppColors.textMain)
        : AppColors.surfaceBase;
    final fgColor = isSelected
        ? (activeForegroundColor ?? AppColors.surfaceBase)
        : AppColors.textMain;
    final borderColor = isSelected
        ? (activeBorderColor ?? bgColor)
        : AppColors.borderSubtle;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1.0),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0x121C242B)
                      : const Color(0x081C242B),
                  blurRadius: isSelected ? 6 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? (activeForegroundColor ?? fgColor)
                        : (iconColor ?? AppColors.textSecondary),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: fgColor,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
