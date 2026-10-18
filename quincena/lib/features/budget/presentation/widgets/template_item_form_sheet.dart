import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../../financial_accounts/models/financial_account.dart';
import '../../data/models/models.dart';
import 'icon_helper.dart';

/// Screen C3: Nueva Partida en Plantilla (Modal Bottom Sheet)
///
/// Implementa las especificaciones de Stitch y DERCAS 1.4 (RF-PLANT-02):
/// - Header con badge de quincena ("Configurando para: 1ra Quincena (1 - 15)" / "2da Quincena (16 - Fin de mes)").
/// - Selector enriquecido de categoría con buscador integrado.
/// - Opción destacada "+ Crear nueva categoría" (CA-C1.4) que dispara Screen C2 en contexto.
/// - Auto-herencia de cuenta predeterminada desde la categoría (RN-CAT-01).
/// - Validación de duplicidad en plantilla (CA-P2.2).
/// - Input de alto impacto para monto con formateo tabular y chips de atajo (+50, +100, +250).
/// - Selector de cuenta destino predeterminada con posibilidad de sobrescritura (RN-CAT-01).
/// - Feedback inmediato de total asignado en plantilla y balance (CA-P2.3).
class TemplateItemFormSheet extends StatefulWidget {
  const TemplateItemFormSheet({
    super.key,
    this.template,
    required this.period,
    required this.existingTemplates,
    required this.categories,
    required this.accounts,
    this.estimatedIncome = 0.0,
    required this.onSave,
    this.onCreateCategoryRequested,
  });

  final BudgetTemplate? template;
  final QuincenaPeriod period;
  final List<BudgetTemplate> existingTemplates;
  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final double estimatedIncome;
  final Future<void> Function({
    required QuincenaPeriod period,
    required String categoryId,
    required double defaultAmount,
    String? destinationAccountId,
  }) onSave;
  final Future<Category?> Function()? onCreateCategoryRequested;

  @override
  State<TemplateItemFormSheet> createState() => _TemplateItemFormSheetState();
}

class _TemplateItemFormSheetState extends State<TemplateItemFormSheet> {
  late final TextEditingController _amountController;
  late List<Category> _categories;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _isSaving = false;
  String? _error;
  bool _isCategoryMenuOpen = false;
  String _categorySearchQuery = '';

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);

    final initialAmount = widget.template != null
        ? widget.template!.defaultAmount.toStringAsFixed(2)
        : '0.00';
    _amountController = TextEditingController(text: initialAmount);

    if (widget.template != null) {
      _selectedCategoryId = widget.template!.categoryId;
      _selectedAccountId = widget.template!.destinationAccountId;
    } else {
      // Filtrar categorías que no estén ya en la plantilla
      final available = _categories.where((c) => !_isCategoryAlreadyInTemplate(c.id)).toList();
      if (available.isNotEmpty) {
        _onSelectCategory(available.first);
      } else if (_categories.isNotEmpty) {
        _onSelectCategory(_categories.first);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool _isCategoryAlreadyInTemplate(String categoryId) {
    if (widget.template != null && widget.template!.categoryId == categoryId) {
      return false; // Es la misma partida que estamos editando
    }
    return widget.existingTemplates.any((t) => t.categoryId == categoryId);
  }

  void _onSelectCategory(Category category) {
    setState(() {
      _selectedCategoryId = category.id;
      _isCategoryMenuOpen = false;

      // RN-CAT-01: Heredar cuenta destino por defecto de la categoría si no se ha elegido una
      if (category.defaultAccountId != null && category.defaultAccountId!.isNotEmpty) {
        _selectedAccountId = category.defaultAccountId;
      }
    });
  }

  double _parseCurrentAmount() {
    final text = _amountController.text.trim().replaceAll(',', '');
    return double.tryParse(text) ?? 0.0;
  }

  void _adjustAmount(double delta) {
    final current = _parseCurrentAmount();
    final updated = (current + delta).clamp(0.0, 9999999.0);
    setState(() {
      _amountController.text = updated.toStringAsFixed(2);
    });
  }

  void _setEquitableSplit() {
    if (widget.estimatedIncome <= 0) return;
    final totalItems = widget.existingTemplates.length + (widget.template == null ? 1 : 0);
    if (totalItems > 0) {
      final split = widget.estimatedIncome / totalItems;
      setState(() {
        _amountController.text = split.toStringAsFixed(2);
      });
    }
  }

  double get _currentTotalTemplateAssigned {
    double sum = 0.0;
    for (final t in widget.existingTemplates) {
      if (widget.template != null && t.id == widget.template!.id) {
        continue; // Reemplazar con el monto actual
      }
      sum += t.defaultAmount;
    }
    return sum + _parseCurrentAmount();
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Por favor selecciona una categoría');
      return;
    }

    // CA-P2.2: Validación de duplicidad en plantilla
    if (_isCategoryAlreadyInTemplate(_selectedCategoryId!)) {
      setState(() => _error = 'Esta categoría ya existe en esta plantilla. Edita la partida existente en lugar de duplicarla.');
      return;
    }

    final amount = _parseCurrentAmount();
    if (amount <= 0) {
      setState(() => _error = 'El monto base debe ser mayor a 0.00');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSave(
        period: widget.period,
        categoryId: _selectedCategoryId!,
        defaultAmount: amount,
        destinationAccountId: _selectedAccountId,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('ApiException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.template != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final periodLabel = widget.period == QuincenaPeriod.firstHalf
        ? '1ra Quincena (1 - 15)'
        : '2da Quincena (16 - Fin de mes)';

    final selectedCategory = _categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;

    final isDuplicate = _selectedCategoryId != null &&
        _isCategoryAlreadyInTemplate(_selectedCategoryId!);

    final totalAssigned = _currentTotalTemplateAssigned;
    final remainingVsIncome = widget.estimatedIncome - totalAssigned;

    final filteredCategories = _categories.where((cat) {
      if (_categorySearchQuery.isEmpty) return true;
      return cat.name.toLowerCase().contains(_categorySearchQuery.toLowerCase());
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

            // 1. Header del Modal (Screen C3 Stitch)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Editar Partida de Plantilla' : 'Agregar Partida a Plantilla',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_month_rounded, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Configurando para: $periodLabel',
                                  style: AppTypography.captionBadge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMain,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),

            // Formulario scrolleable
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campo 1: Selector Enriquecido de Categoría
                    Text(
                      'Categoría de gasto o destino',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dropdown Trigger Button
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isCategoryMenuOpen = !_isCategoryMenuOpen;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDuplicate ? AppColors.expenseText : AppColors.borderSubtle,
                            width: isDuplicate ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (selectedCategory != null) ...[
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: selectedCategory.parsedColor,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  resolveCategoryIcon(selectedCategory.icon),
                                  size: 20,
                                  color: AppColors.textMain,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedCategory.name,
                                      style: AppTypography.bodyLg.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      selectedCategory.defaultAccount?.name ?? 'Sin cuenta por defecto vinculada',
                                      style: AppTypography.captionBadge.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const Icon(Icons.category_outlined, color: AppColors.textMuted),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Selecciona una categoría...'),
                              ),
                            ],
                            Icon(
                              _isCategoryMenuOpen ? Icons.expand_less : Icons.expand_more,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Advertencia de Duplicidad en Plantilla (CA-P2.2)
                    if (isDuplicate) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.expenseBg.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.expenseText),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Esta categoría ya está agregada en la $periodLabel. Te sugerimos editar el monto existente.',
                                style: AppTypography.captionBadge.copyWith(
                                  color: AppColors.expenseText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Menú desplegable con buscador y "+ Crear nueva categoría" (CA-C1.4)
                    if (_isCategoryMenuOpen) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(28, 36, 43, 0.08),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            children: [
                            // Buscador de categorías
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: TextField(
                                      style: AppTypography.bodySm,
                                      decoration: const InputDecoration(
                                        hintText: 'Buscar categoría...',
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (val) {
                                        setState(() => _categorySearchQuery = val.trim());
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Lista de Categorías
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 180),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredCategories.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final cat = filteredCategories[idx];
                                  final isSelected = cat.id == _selectedCategoryId;
                                  final alreadyIn = _isCategoryAlreadyInTemplate(cat.id);

                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    leading: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: cat.parsedColor,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        resolveCategoryIcon(cat.icon),
                                        size: 16,
                                        color: AppColors.textMain,
                                      ),
                                    ),
                                    title: Text(
                                      cat.name,
                                      style: AppTypography.bodyMd.copyWith(
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: alreadyIn
                                        ? const Text(
                                            'Ya en plantilla',
                                            style: TextStyle(color: AppColors.expenseText, fontSize: 11),
                                          )
                                        : null,
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: AppColors.incomeText, size: 18)
                                        : null,
                                    onTap: () => _onSelectCategory(cat),
                                  );
                                },
                              ),
                            ),
                            const Divider(height: 16),

                            // Opción Destacada: "+ Crear nueva categoría" (CA-C1.4)
                            InkWell(
                              onTap: () async {
                                setState(() => _isCategoryMenuOpen = false);
                                if (widget.onCreateCategoryRequested != null) {
                                  final newCat = await widget.onCreateCategoryRequested!();
                                  if (newCat != null && mounted) {
                                    setState(() {
                                      _categories.add(newCat);
                                      _onSelectCategory(newCat);
                                    });
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primaryAccessible),
                                    const SizedBox(width: 8),
                                    Text(
                                      '+ Crear nueva categoría',
                                      style: AppTypography.labelMd.copyWith(
                                        color: AppColors.primaryAccessible,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ],
                    const SizedBox(height: 20),

                    // Campo 2: Monto Base Quincenal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Monto asignado para este ciclo',
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cálculo recurrente',
                          style: AppTypography.captionBadge.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Input Display de Alto Impacto (Screen C3 Stitch)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '\$',
                            style: AppTypography.currencyHeroMobile.copyWith(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: AppTypography.currencyHeroMobile.copyWith(
                                color: AppColors.textMain,
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.backspace_outlined, size: 20, color: AppColors.textMuted),
                            onPressed: () {
                              setState(() {
                                _amountController.text = '0.00';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Atajos Rápidos en Chips (+50, +100, +250, Dividir)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickAmountChip('+\$50', 50),
                          const SizedBox(width: 8),
                          _buildQuickAmountChip('+\$100', 100),
                          const SizedBox(width: 8),
                          _buildQuickAmountChip('+\$250', 250),
                          if (widget.estimatedIncome > 0) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _setEquitableSplit,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.splitscreen_rounded, size: 14, color: AppColors.primaryAccessible),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Dividir ingreso equitativo',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primaryAccessible,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo 3: Cuenta Destino Predeterminada (RN-CAT-01)
                    Text(
                      'Cuenta Destino Predeterminada',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cuenta de donde se planifica fondear esta bolsa en la quincena.',
                      style: AppTypography.captionBadge.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBase,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedAccountId,
                          isExpanded: true,
                          hint: const Text('Sin cuenta específica vinculada'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin cuenta específica vinculada'),
                            ),
                            ...widget.accounts.map((acc) {
                              return DropdownMenuItem<String?>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: acc.parsedColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        acc.name,
                                        style: AppTypography.bodyMd,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      acc.accountType.label,
                                      style: AppTypography.captionBadge.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedAccountId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Feedback Inmediato (CA-P2.3 Stitch)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Total Asignado en Plantilla:',
                                  style: AppTypography.captionBadge.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '\$${totalAssigned.toStringAsFixed(2)}',
                                style: AppTypography.currencyMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (widget.estimatedIncome > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Balance vs Ingreso Estimado:',
                                    style: AppTypography.captionBadge.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: remainingVsIncome >= 0
                                        ? AppColors.incomeBg.withValues(alpha: 0.3)
                                        : AppColors.expenseBg.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    remainingVsIncome >= 0
                                        ? 'Remanente: \$${remainingVsIncome.toStringAsFixed(2)}'
                                        : 'Déficit: \$${remainingVsIncome.abs().toStringAsFixed(2)}',
                                    style: AppTypography.captionBadge.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: remainingVsIncome >= 0
                                          ? AppColors.incomeText
                                          : AppColors.expenseText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Mensaje de Error
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.expenseBg.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: AppColors.expenseText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: AppTypography.captionBadge.copyWith(
                                  color: AppColors.expenseText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    AppButton(
                      text: isEditing
                          ? 'Guardar Cambios'
                          : 'Agregar a Plantilla',
                      isLoading: _isSaving,
                      onPressed: isDuplicate ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, double amount) {
    return InkWell(
      onTap: () => _adjustAmount(amount),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
      ),
    );
  }
}
