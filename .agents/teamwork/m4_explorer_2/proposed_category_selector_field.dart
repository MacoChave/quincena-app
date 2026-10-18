import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/budget_allocation.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/presentation/widgets/icon_helper.dart';
import 'package:quincena/features/categories/data/categories_api_service.dart';
import 'package:quincena/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';

/// Formatea un monto monetario con separador de miles y 2 decimales para Quincena
String _formatCurrency(double amount) {
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

/// Selector visual y modal de Categorías para el registro de transacciones (Milestone 4).
///
/// Características y cumplimiento de especificación:
/// 1. Muestra la categoría seleccionada con nombre, icono financiero y badge con paleta pastel.
/// 2. Abre una hoja modal inferior (`_CategorySelectionSheet`) listando todas las categorías disponibles
///    y destacando las partidas presupuestarias del ciclo activo si están provistas.
/// 3. Incluye acceso directo contextual `+ Nueva Categoría` que abre `CategoryFormSheet` sin perder ni resetear
///    el estado previo del formulario padre.
/// 4. Al seleccionar una categoría, verifica si posee `default_account_id` (`RN-CAT-01`) y dispara
///    el callback [onAccountAutoSelected] para autoseleccionar esa cuenta si la cuenta actual está sin definir.
class CategorySelectorField extends StatefulWidget {
  const CategorySelectorField({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    this.selectedCategory,
    this.allocations,
    this.accounts = const [],
    this.currentAccountId,
    this.onChanged,
    this.onAccountAutoSelected,
    this.onCreateCategoryRequested,
    this.onSaveCategory,
    this.categoriesApiService,
    this.onCategoryCreated,
    this.errorText,
    this.isRequired = true,
    this.label = 'Categoría',
    this.hintText = 'Seleccionar categoría',
    this.enabled = true,
    this.fieldKey = const Key('manual_category_dropdown'),
    this.addCategoryKey = const Key('btn_add_new_category'),
    this.showAddButtonInHeader = true,
  });

  /// Lista de categorías disponibles para el usuario
  final List<Category> categories;

  /// ID de la categoría seleccionada actualmente
  final String? selectedCategoryId;

  /// Instancia de categoría seleccionada (opcional, fallback)
  final Category? selectedCategory;

  /// Partidas presupuestarias del ciclo activo (opcional, para enriquecer con saldos disponibles)
  final List<BudgetAllocation>? allocations;

  /// Cuentas financieras disponibles (para pasar al crear nueva categoría)
  final List<FinancialAccount> accounts;

  /// ID de la cuenta financiera actualmente seleccionada en el formulario (para evaluar RN-CAT-01)
  final String? currentAccountId;

  /// Callback emitido cuando la categoría seleccionada cambia
  final ValueChanged<Category?>? onChanged;

  /// Callback emitido cuando la categoría tiene una cuenta predeterminada configurada (RN-CAT-01)
  final ValueChanged<String>? onAccountAutoSelected;

  /// Callback externo para delegar la creación de una nueva categoría
  final Future<Category?> Function()? onCreateCategoryRequested;

  /// Función para persistir una categoría si se abre internamente [CategoryFormSheet]
  final Future<Category> Function({
    required String name,
    required String icon,
    required String colorHex,
    String? defaultAccountId,
  })? onSaveCategory;

  /// Servicio HTTP de categorías (alternativa para creación directa)
  final CategoriesApiService? categoriesApiService;

  /// Callback emitido cuando se crea exitosamente una nueva categoría
  final ValueChanged<Category>? onCategoryCreated;

  /// Mensaje de error para validación del formulario
  final String? errorText;

  /// Indica si el campo es obligatorio (agrega indicador visual en la etiqueta)
  final bool isRequired;

  /// Etiqueta superior del campo
  final String label;

  /// Placeholder mostrado cuando no hay ninguna categoría seleccionada
  final String hintText;

  /// Si el selector está activo o deshabilitado
  final bool enabled;

  /// Clave del widget de selección para pruebas automatizadas
  final Key? fieldKey;

  /// Clave del botón de nueva categoría para pruebas automatizadas
  final Key? addCategoryKey;

  /// Si se debe mostrar el botón "+ Nueva Categoría" en la fila superior
  final bool showAddButtonInHeader;

  @override
  State<CategorySelectorField> createState() => _CategorySelectorFieldState();
}

class _CategorySelectorFieldState extends State<CategorySelectorField> {
  late List<Category> _localCategories;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _localCategories = List<Category>.from(widget.categories);
    _selectedCategoryId = widget.selectedCategoryId ?? widget.selectedCategory?.id;
  }

  @override
  void didUpdateWidget(covariant CategorySelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategoryId != oldWidget.selectedCategoryId) {
      _selectedCategoryId = widget.selectedCategoryId;
    } else if (widget.selectedCategory?.id != oldWidget.selectedCategory?.id) {
      _selectedCategoryId = widget.selectedCategory?.id;
    }

    // Sincronizar lista si cambia desde el padre
    if (widget.categories != oldWidget.categories) {
      _localCategories = List<Category>.from(widget.categories);
    }
  }

  /// Retorna la categoría seleccionada actualmente
  Category? get _currentCategory {
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      return widget.selectedCategory;
    }
    return _localCategories
            .where((c) => c.id == _selectedCategoryId)
            .firstOrNull ??
        widget.selectedCategory;
  }

  /// Busca la partida presupuestaria del ciclo activo vinculada a la categoría dada
  BudgetAllocation? _getAllocationForCategory(String categoryId) {
    if (widget.allocations == null) return null;
    return widget.allocations!
        .where((a) => a.categoryId == categoryId)
        .firstOrNull;
  }

  /// Procesa la selección de una categoría e implementa RN-CAT-01
  void _handleCategorySelected(Category category) {
    setState(() {
      _selectedCategoryId = category.id;
    });

    widget.onChanged?.call(category);

    // RN-CAT-01: Herencia de cuenta predeterminada
    // Si la categoría tiene default_account_id y la cuenta actual en el formulario está sin definir,
    // se dispara la autoselección de dicha cuenta.
    final defaultAccId = category.defaultAccountId;
    if (defaultAccId != null && defaultAccId.trim().isNotEmpty) {
      final isCurrentAccountUnset = widget.currentAccountId == null ||
          widget.currentAccountId!.trim().isEmpty;
      if (isCurrentAccountUnset) {
        widget.onAccountAutoSelected?.call(defaultAccId.trim());
      }
    }
  }

  /// Abre el formulario contextual de creación de categoría (+ Nueva Categoría)
  Future<void> _openCreateCategory() async {
    if (!widget.enabled) return;

    Category? newCategory;

    if (widget.onCreateCategoryRequested != null) {
      newCategory = await widget.onCreateCategoryRequested!();
    } else if (widget.onSaveCategory != null || widget.categoriesApiService != null) {
      newCategory = await showModalBottomSheet<Category>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) => CategoryFormSheet(
          accounts: widget.accounts,
          onSave: widget.onSaveCategory ??
              ({
                required name,
                required icon,
                required colorHex,
                defaultAccountId,
              }) async {
                return await widget.categoriesApiService!.createCategory(
                  name: name,
                  icon: icon,
                  colorHex: colorHex,
                  defaultAccountId: defaultAccountId,
                );
              },
        ),
      );
    }

    final created = newCategory;
    if (created != null && mounted) {
      setState(() {
        if (!_localCategories.any((c) => c.id == created.id)) {
          _localCategories.add(created);
        }
      });

      widget.onCategoryCreated?.call(created);
      _handleCategorySelected(created);
    }
  }

  /// Abre la hoja modal para seleccionar una categoría
  Future<void> _openCategoryModal() async {
    if (!widget.enabled) return;

    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return _CategorySelectionSheet(
          categories: _localCategories,
          selectedCategoryId: _selectedCategoryId,
          allocations: widget.allocations,
          accounts: widget.accounts,
          onCreateNewCategory: _openCreateCategory,
        );
      },
    );

    if (picked != null && mounted) {
      _handleCategorySelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCat = _currentCategory;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final allocation = selectedCat != null ? _getAllocationForCategory(selectedCat.id) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila de Cabecera: Etiqueta y Botón Contextual "+ Nueva Categoría"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                if (widget.isRequired)
                  Text(
                    ' *',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.expenseText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (widget.showAddButtonInHeader)
              TextButton.icon(
                key: widget.addCategoryKey,
                onPressed: widget.enabled ? _openCreateCategory : null,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16,
                  color: AppColors.primaryAccessible,
                ),
                label: Text(
                  '+ Nueva Categoría',
                  style: AppTypography.captionBadge.copyWith(
                    color: AppColors.primaryAccessible,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Tarjeta interactiva del Selector
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: widget.fieldKey,
            borderRadius: AppRadius.borderMd,
            onTap: widget.enabled ? _openCategoryModal : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.enabled ? AppColors.surfaceSubtle : AppColors.surfaceSubtle.withValues(alpha: 0.5),
                borderRadius: AppRadius.borderMd,
                border: Border.all(
                  color: hasError
                      ? AppColors.expenseText
                      : (selectedCat != null ? AppColors.borderFocus : AppColors.borderSubtle),
                  width: hasError || selectedCat != null ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Icono / Avatar con color pastel distintivo
                  if (selectedCat != null) ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selectedCat.parsedColor.withValues(alpha: 0.22),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(
                          color: selectedCat.parsedColor.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        resolveCategoryIcon(selectedCat.icon),
                        size: 20,
                        color: selectedCat.parsedColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedCat.name,
                            style: AppTypography.labelLg.copyWith(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (allocation != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Disponible: ${_formatCurrency(allocation.computedAvailable)} en ciclo activo',
                              style: AppTypography.captionBadge.copyWith(
                                color: allocation.computedAvailable < 0
                                    ? AppColors.expenseText
                                    : AppColors.incomeText,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else if (selectedCat.defaultAccountId != null &&
                              selectedCat.defaultAccountId!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Cuenta predeterminada vinculada',
                              style: AppTypography.captionBadge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Estado vacío / Sin selección
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Icon(
                        Icons.category_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.hintText,
                        style: AppTypography.bodyLg.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],

                  // Indicador de desplegable
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: widget.enabled ? AppColors.textSecondary : AppColors.textMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Mensaje de Error
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              widget.errorText!,
              style: AppTypography.captionBadge.copyWith(
                color: AppColors.expenseText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Hoja modal deslizante para la selección de categorías de gasto
class _CategorySelectionSheet extends StatefulWidget {
  const _CategorySelectionSheet({
    required this.categories,
    required this.selectedCategoryId,
    this.allocations,
    this.accounts = const [],
    required this.onCreateNewCategory,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final List<BudgetAllocation>? allocations;
  final List<FinancialAccount> accounts;
  final VoidCallback onCreateNewCategory;

  @override
  State<_CategorySelectionSheet> createState() => _CategorySelectionSheetState();
}

class _CategorySelectionSheetState extends State<_CategorySelectionSheet> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  BudgetAllocation? _getAllocation(String categoryId) {
    if (widget.allocations == null) return null;
    return widget.allocations!
        .where((a) => a.categoryId == categoryId)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredCategories = widget.categories.where((cat) {
      if (query.isEmpty) return true;
      return cat.name.toLowerCase().contains(query);
    }).toList();

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Cabecera: Título y Botón Cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primarySubtle,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      size: 18,
                      color: AppColors.primaryAccessible,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Seleccionar Categoría',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Buscador rápido de categorías
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppTypography.bodyMd.copyWith(color: AppColors.textMain),
                    decoration: const InputDecoration(
                      hintText: 'Buscar categoría...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.cancel_rounded, size: 18, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Opción destacada "+ Nueva Categoría"
          InkWell(
            borderRadius: AppRadius.borderMd,
            onTap: () {
              Navigator.of(context).pop();
              widget.onCreateNewCategory();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Crear nueva categoría...',
                      style: AppTypography.labelLg.copyWith(
                        color: AppColors.primaryAccessible,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primaryAccessible),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Lista de categorías
          Expanded(
            child: filteredCategories.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.6)),
                          const SizedBox(height: 10),
                          Text(
                            'No se encontraron categorías',
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Intenta con otro término o crea una nueva.',
                            style: AppTypography.bodySm,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredCategories.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (ctx, index) {
                      final cat = filteredCategories[index];
                      final isSelected = cat.id == widget.selectedCategoryId;
                      final alloc = _getAllocation(cat.id);
                      final catColor = cat.parsedColor;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.18),
                            borderRadius: AppRadius.borderSm,
                            border: Border.all(
                              color: catColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            resolveCategoryIcon(cat.icon),
                            color: catColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.textMain,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        subtitle: alloc != null
                            ? Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: alloc.computedAvailable < 0
                                          ? AppColors.expenseBg
                                          : (alloc.computedAvailable == 0
                                              ? AppColors.warningBg
                                              : AppColors.incomeBg),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Disponible: ${_formatCurrency(alloc.computedAvailable)}',
                                    style: AppTypography.captionBadge.copyWith(
                                      color: alloc.computedAvailable < 0
                                          ? AppColors.expenseText
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : (cat.defaultAccount != null
                                ? Text(
                                    'Fondeo: ${cat.defaultAccount!.name}',
                                    style: AppTypography.captionBadge,
                                  )
                                : null),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryAccessible,
                                size: 22,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(cat),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
