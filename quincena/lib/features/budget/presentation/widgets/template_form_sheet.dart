import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../../financial_accounts/models/financial_account.dart';
import '../../data/models/models.dart';
import 'icon_helper.dart';

/// Modal Bottom Sheet para crear o editar una partida en la plantilla maestra (RF-04)
class TemplateFormSheet extends StatefulWidget {
  const TemplateFormSheet({
    super.key,
    this.template,
    required this.period,
    required this.categories,
    required this.accounts,
    required this.onSave,
  });

  final BudgetTemplate? template;
  final QuincenaPeriod period;
  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final Future<void> Function({
    required QuincenaPeriod period,
    required String categoryId,
    required double defaultAmount,
    String? destinationAccountId,
  }) onSave;

  @override
  State<TemplateFormSheet> createState() => _TemplateFormSheetState();
}

class _TemplateFormSheetState extends State<TemplateFormSheet> {
  late final TextEditingController _amountController;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initialAmount = widget.template != null
        ? widget.template!.defaultAmount.toStringAsFixed(2)
        : '';
    _amountController = TextEditingController(text: initialAmount);

    if (widget.template != null) {
      _selectedCategoryId = widget.template!.categoryId;
      _selectedAccountId = widget.template!.destinationAccountId;
    } else if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first.id;
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing
                          ? 'Editar Partida de Plantilla'
                          : 'Nueva Partida en Plantilla',
                      style: AppTypography.headlineSm,
                    ),
                    Text(
                      'Plantilla para ${widget.period.label}',
                      style: AppTypography.bodySm,
                    ),
                  ],
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
                  items: widget.categories.map((cat) {
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
                      ? null
                      : (val) => setState(() => _selectedCategoryId = val),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Entrada de Monto Base
            AppAmountInput(
              controller: _amountController,
              label: 'Monto base predeterminado',
            ),
            const SizedBox(height: 16),

            // Cuenta Financiera de Fondeo (Destino)
            Text('Cuenta Destino Predeterminada', style: AppTypography.labelMd),
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
              text: isEditing ? 'Guardar Cambios' : 'Agregar a Plantilla',
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
