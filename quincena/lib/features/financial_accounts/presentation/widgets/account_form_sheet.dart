import 'package:flutter/material.dart';
import '../../../../core/components/app_components.dart';
import '../../../../core/theme/theme.dart';
import '../../models/financial_account.dart';

/// Modal Bottom Sheet para Crear o Editar una Cuenta Financiera (CA-01.1)
class AccountFormSheet extends StatefulWidget {
  const AccountFormSheet({
    super.key,
    this.accountToEdit,
    required this.onSave,
  });

  final FinancialAccount? accountToEdit;
  final Future<void> Function({
    required String name,
    required AccountType accountType,
    required String currency,
    required String colorHex,
    required String icon,
    required bool isDefault,
    required double initialBalance,
  }) onSave;

  @override
  State<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  late AccountType _selectedType;
  late String _selectedCurrency;
  late String _selectedColorHex;
  late bool _isDefault;
  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _paletteColors = [
    '#79ADDC', // Soft Sky Blue
    '#ADF7B6', // Mint Pastel
    '#FFEE93', // Soft Sunshine
    '#FFC09F', // Muted Coral
    '#D8B4F8', // Lavender Pastel
    '#A0E7E5', // Aqua Pastel
    '#FDE2E4', // Blush Rose
    '#E2ECE9', // Sage Light
  ];

  static const List<String> _availableCurrencies = ['GTQ', 'USD', 'MXN', 'EUR'];

  @override
  void initState() {
    super.initState();
    final edit = widget.accountToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _amountController = TextEditingController(
      text: edit != null && edit.initialBalance > 0
          ? edit.initialBalance.toStringAsFixed(2)
          : '',
    );
    _selectedType = edit?.accountType ?? AccountType.checking;
    _selectedCurrency = edit?.currency ?? 'GTQ';
    _selectedColorHex = edit?.colorHex ?? _paletteColors.first;
    _isDefault = edit?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Color _parseHex(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return AppColors.primary;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final balance = double.tryParse(_amountController.text.trim()) ?? 0.0;
      await widget.onSave(
        name: _nameController.text.trim(),
        accountType: _selectedType,
        currency: _selectedCurrency,
        colorHex: _selectedColorHex,
        icon: _selectedType.value,
        isDefault: _isDefault,
        initialBalance: balance,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.accountToEdit != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: AppRadius.borderBottomSheet,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Manija decorativa del modal
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.borderSubtle,
                      borderRadius: AppRadius.borderPill,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                // Encabezado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Editar Cuenta' : 'Nueva Cuenta Financiera',
                      style: AppTypography.headlineMd,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  isEditing
                      ? 'Actualiza los datos o color de tu cuenta destino.'
                      : 'Registra tus cuentas bancarias, billeteras o efectivo.',
                  style: AppTypography.bodyMd,
                ),
                const SizedBox(height: AppSpacing.spaceLg),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.spaceSm),
                    decoration: BoxDecoration(
                      color: AppColors.expenseBg.withValues(alpha: 0.3),
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: AppColors.expenseBg,
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.expenseText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceMd),
                ],

                // 1. Selector de Tipo de Cuenta
                Text(
                  'Tipo de Cuenta',
                  style: AppTypography.captionBadge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceXs),
                Wrap(
                  spacing: AppSpacing.spaceXs,
                  runSpacing: AppSpacing.spaceXs,
                  children: AccountType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            type.iconData,
                            size: 16,
                            color: isSelected
                                ? AppColors.textMain
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(type.label),
                        ],
                      ),
                      labelStyle: AppTypography.captionBadge.copyWith(
                        color: isSelected
                            ? AppColors.textMain
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      selectedColor: AppColors.surfaceHero,
                      backgroundColor: AppColors.surfaceSubtle,
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryAccessible
                            : AppColors.borderSubtle,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedType = type);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // 2. Nombre de la Cuenta
                AppTextField(
                  controller: _nameController,
                  label: 'Nombre de la cuenta',
                  hintText: 'ej. Monetaria Banrural, Ahorro BAC, Billetera',
                  prefixIcon: const Icon(Icons.label_outline_rounded,
                      color: AppColors.textSecondary, size: 20),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un nombre para la cuenta';
                    }
                    if (value.trim().length > 80) {
                      return 'El nombre no puede exceder 80 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // 3. Saldo Inicial y Moneda
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de Moneda
                    SizedBox(
                      width: 100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Moneda',
                            style: AppTypography.captionBadge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.spaceXs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.spaceSm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBase,
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCurrency,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: AppColors.textSecondary),
                                items: _availableCurrencies
                                    .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                            c,
                                            style: AppTypography.numericRow,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCurrency = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spaceMd),
                    // Saldo Inicial
                    Expanded(
                      child: AppAmountInput(
                        controller: _amountController,
                        label: isEditing
                            ? 'Saldo Inicial (No editable)'
                            : 'Saldo Inicial (Opcional)',
                        currencySymbol: _selectedCurrency,
                        readOnly: isEditing,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // 4. Selector de Color Distintivo
                Text(
                  'Color de la Cuenta',
                  style: AppTypography.captionBadge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceXs),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _paletteColors.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.spaceSm),
                    itemBuilder: (context, index) {
                      final hex = _paletteColors[index];
                      final color = _parseHex(hex);
                      final isSelected = _selectedColorHex.toUpperCase() ==
                          hex.toUpperCase();

                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorHex = hex),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.textMain
                                  : AppColors.borderSubtle,
                              width: isSelected ? 2.5 : 1.0,
                            ),
                            boxShadow: isSelected ? AppShadows.card : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 20, color: AppColors.textMain)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),

                // 5. Switch: Predeterminada (CA-01.2)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.spaceMd,
                    vertical: AppSpacing.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Cuenta Predeterminada',
                      style: AppTypography.bodyLg,
                    ),
                    subtitle: const Text(
                      'Se usará por defecto para ingresos y presupuestos',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    value: _isDefault,
                    activeThumbColor: AppColors.primaryAccessible,
                    onChanged: (val) => setState(() => _isDefault = val),
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceXl),

                // 6. Botón de Acción
                AppButton(
                  text: isEditing ? 'Guardar Cambios' : 'Crear Cuenta',
                  isLoading: _isLoading,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
