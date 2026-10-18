import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../../financial_accounts/models/financial_account.dart';
import '../../data/models/models.dart';
import 'icon_helper.dart';
import 'zero_base_header_card.dart';

/// Modal Bottom Sheet para crear o editar una partida presupuestaria (RF-03)
class AllocationFormSheet extends StatefulWidget {
  const AllocationFormSheet({
    super.key,
    this.allocation,
    required this.categories,
    required this.accounts,
    required this.currentUnallocated,
    required this.onSave,
    this.onCreateCategoryRequested,
  });

  final BudgetAllocation? allocation;
  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final double currentUnallocated;
  final Future<void> Function({
    required String categoryId,
    required double allocatedAmount,
    String? destinationAccountId,
  }) onSave;
  final Future<Category?> Function()? onCreateCategoryRequested;

  @override
  State<AllocationFormSheet> createState() => _AllocationFormSheetState();
}

class _AllocationFormSheetState extends State<AllocationFormSheet> {
  late final TextEditingController _amountController;
  late List<Category> _categories;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _isSaving = false;
  String? _error;

  double get _initialAllocated => widget.allocation?.allocatedAmount ?? 0.0;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    final initialAmount = widget.allocation != null
        ? widget.allocation!.allocatedAmount.toStringAsFixed(2)
        : '';
    _amountController = TextEditingController(text: initialAmount);

    if (widget.allocation != null) {
      _selectedCategoryId = widget.allocation!.categoryId;
      _selectedAccountId = widget.allocation!.destinationAccountId;
    } else if (_categories.isNotEmpty) {
      _selectedCategoryId = _categories.first.id;
      final defaultAcc = _categories.first.defaultAccountId;
      if (defaultAcc != null && defaultAcc.isNotEmpty) {
        _selectedAccountId = defaultAcc;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double _parseCurrentAmount() {
    final text = _amountController.text.trim().replaceAll(',', '');
    return double.tryParse(text) ?? 0.0;
  }

  double _computeProjectedUnallocated() {
    final newAmount = _parseCurrentAmount();
    // Por asignar proyectado: actual + inicial - nuevo
    return widget.currentUnallocated + _initialAllocated - newAmount;
  }

  Future<void> _submit() async {
    if (_selectedCategoryId == null) {
      setState(() => _error = 'Por favor selecciona una categoría');
      return;
    }

    final amount = _parseCurrentAmount();
    if (amount < 0) {
      setState(() => _error = 'El monto no puede ser negativo');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSave(
        categoryId: _selectedCategoryId!,
        allocatedAmount: amount,
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
    final isEditing = widget.allocation != null;
    final projectedUnallocated = _computeProjectedUnallocated();
    final isBaseZero = projectedUnallocated.abs() < 0.01;
    final isDeficit = projectedUnallocated <= -0.01;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Editar Partida Presupuestaria' : 'Nueva Partida Quincenal',
                  style: AppTypography.headlineSm,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selector de Categoría
            Text('Categoría', style: AppTypography.labelMd),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategoryId,
                  isExpanded: true,
                  hint: const Text('Seleccionar categoría'),
                  items: _categories.map((cat) {
                    final catColor = cat.parsedColor;
                    final catIcon = resolveCategoryIcon(cat.icon);
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.18),
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: Icon(catIcon, size: 16, color: catColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: AppTypography.bodyLg.copyWith(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: isEditing
                      ? null // En edición, la categoría permanece fija para mantener identidad
                      : (val) {
                          setState(() {
                            _selectedCategoryId = val;
                            final cat = _categories.where((c) => c.id == val).firstOrNull;
                            if (cat != null && cat.defaultAccountId != null && cat.defaultAccountId!.isNotEmpty) {
                              _selectedAccountId = cat.defaultAccountId;
                            }
                          });
                        },
                ),
              ),
            ),
            if (!isEditing && widget.onCreateCategoryRequested != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primaryAccessible),
                  label: Text(
                    '+ Nueva Categoría',
                    style: AppTypography.captionBadge.copyWith(
                      color: AppColors.primaryAccessible,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () async {
                    final newCat = await widget.onCreateCategoryRequested!();
                    if (newCat != null && mounted) {
                      setState(() {
                        _categories.add(newCat);
                        _selectedCategoryId = newCat.id;
                        if (newCat.defaultAccountId != null && newCat.defaultAccountId!.isNotEmpty) {
                          _selectedAccountId = newCat.defaultAccountId;
                        }
                      });
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Entrada de Monto
            AppAmountInput(
              controller: _amountController,
              label: 'Monto presupuestado',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Previsualización dinámica de Presupuesto Base Cero
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBaseZero
                    ? AppColors.incomeBg.withValues(alpha: 0.3)
                    : (isDeficit
                        ? AppColors.expenseBg.withValues(alpha: 0.3)
                        : AppColors.primarySubtle),
                borderRadius: AppRadius.borderMd,
                border: Border.all(
                  color: isBaseZero
                      ? AppColors.incomeText.withValues(alpha: 0.3)
                      : (isDeficit
                          ? AppColors.expenseText.withValues(alpha: 0.3)
                          : AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isBaseZero
                        ? Icons.check_circle_outline_rounded
                        : (isDeficit
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded),
                    size: 18,
                    color: isBaseZero
                        ? AppColors.incomeText
                        : (isDeficit ? AppColors.expenseText : AppColors.primaryAccessible),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBaseZero
                          ? 'Resultado proyectado: ¡Base Cero (\$0.00)!'
                          : (isDeficit
                              ? 'Proyección: Déficit de ${formatMoney(projectedUnallocated)}'
                              : 'Por asignar restante: +${formatMoney(projectedUnallocated)}'),
                      style: AppTypography.bodySm.copyWith(
                        color: isBaseZero
                            ? AppColors.incomeText
                            : (isDeficit ? AppColors.expenseText : AppColors.textMain),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cuenta Financiera de Fondeo (Destino)
            Text('Cuenta Financiera de Fondeo (Destino)', style: AppTypography.labelMd),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedAccountId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Row(
                        children: [
                          Icon(
                            Icons.money_off_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 10),
                          Text('Sin cuenta asignada / Efectivo'),
                        ],
                      ),
                    ),
                    ...widget.accounts.map((acc) {
                      return DropdownMenuItem<String?>(
                        value: acc.id,
                        child: Row(
                          children: [
                            Icon(acc.displayIcon, size: 18, color: acc.parsedColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                acc.name,
                                style: AppTypography.bodyLg.copyWith(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatMoney(acc.currentBalance),
                              style: AppTypography.numericRow.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTypography.bodySm.copyWith(color: AppColors.expenseText),
              ),
            ],

            const SizedBox(height: 24),

            // Botón de guardar
            AppButton(
              text: isEditing ? 'Guardar Cambios' : 'Crear Partida',
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
