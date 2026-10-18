import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';
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

/// Selector visual y modal de Cuentas Financieras para el registro de transacciones (Milestone 4).
///
/// Características y cumplimiento de especificación:
/// 1. Campo selector obligatorio para cuentas financieras origen/débito (Banco, Efectivo, Tarjeta, Billetera Digital).
/// 2. Muestra el icono de la cuenta, nombre, tipo de cuenta y saldo disponible con cifras tabulares (`tnum`).
/// 3. Soporta preselección externa (ej. herencia de cuenta predeterminada desde `CategorySelectorField` bajo `RN-CAT-01`).
/// 4. Despliega una hoja modal inferior (`_AccountSelectionSheet`) para explorar y cambiar de cuenta cómodamente.
/// 5. Diseño responsivo con `Flexible` y `TextOverflow.ellipsis` en la etiqueta de cabecera y títulos,
///    eliminando cualquier desbordamiento de RenderFlex en pantallas de 360px.
class AccountSelectorField extends StatefulWidget {
  const AccountSelectorField({
    super.key,
    required this.accounts,
    this.selectedAccountId,
    this.selectedAccount,
    this.onChanged,
    this.errorText,
    this.isRequired = true,
    this.label = 'Cuenta de Pago / Débito',
    this.hintText = 'Seleccionar cuenta de débito',
    this.enabled = true,
    this.fieldKey = const Key('manual_account_dropdown'),
  });

  /// Lista de cuentas financieras disponibles
  final List<FinancialAccount> accounts;

  /// ID de la cuenta financiera seleccionada
  final String? selectedAccountId;

  /// Instancia de la cuenta seleccionada (opcional, fallback)
  final FinancialAccount? selectedAccount;

  /// Callback emitido cuando la cuenta seleccionada cambia
  final ValueChanged<FinancialAccount?>? onChanged;

  /// Mensaje de error para validación del formulario
  final String? errorText;

  /// Si el campo es obligatorio (muestra asterisco en la etiqueta)
  final bool isRequired;

  /// Etiqueta superior del campo
  final String label;

  /// Texto de placeholder cuando no hay selección
  final String hintText;

  /// Si el campo está habilitado para interacción
  final bool enabled;

  /// Clave del widget de selección para pruebas automatizadas
  final Key? fieldKey;

  @override
  State<AccountSelectorField> createState() => _AccountSelectorFieldState();
}

class _AccountSelectorFieldState extends State<AccountSelectorField> {
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.selectedAccountId ?? widget.selectedAccount?.id;
  }

  @override
  void didUpdateWidget(covariant AccountSelectorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Permite que la preselección desde categoría (RN-CAT-01) actualice reactivamente este selector
    if (widget.selectedAccountId != oldWidget.selectedAccountId) {
      _selectedAccountId = widget.selectedAccountId;
    } else if (widget.selectedAccount?.id != oldWidget.selectedAccount?.id) {
      _selectedAccountId = widget.selectedAccount?.id;
    }
  }

  /// Retorna la cuenta seleccionada actualmente
  FinancialAccount? get _currentAccount {
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      return widget.selectedAccount;
    }
    return widget.accounts
            .where((a) => a.id == _selectedAccountId)
            .firstOrNull ??
        widget.selectedAccount;
  }

  /// Procesa la selección de una cuenta financiera
  void _handleAccountSelected(FinancialAccount account) {
    setState(() {
      _selectedAccountId = account.id;
    });
    widget.onChanged?.call(account);
  }

  /// Abre la hoja modal para seleccionar una cuenta financiera
  Future<void> _openAccountModal() async {
    if (!widget.enabled) return;

    final picked = await showModalBottomSheet<FinancialAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _AccountSelectionSheet(
          accounts: widget.accounts,
          selectedAccountId: _selectedAccountId,
        );
      },
    );

    if (picked != null && mounted) {
      _handleAccountSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedAcc = _currentAccount;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila de Cabecera / Etiqueta
        // El texto de la etiqueta está envuelto en Flexible con TextOverflow.ellipsis
        // para prevenir el desbordamiento de RenderFlex (11px) en pantallas compactas de 360px.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.label,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 6),

        // Tarjeta interactiva del Selector
        Material(
          color: Colors.transparent,
          child: InkWell(
            key: widget.fieldKey,
            borderRadius: AppRadius.borderMd,
            onTap: widget.enabled ? _openAccountModal : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? AppColors.surfaceSubtle
                    : AppColors.surfaceSubtle.withValues(alpha: 0.5),
                borderRadius: AppRadius.borderMd,
                border: Border.all(
                  color: hasError
                      ? AppColors.expenseText
                      : (selectedAcc != null
                          ? AppColors.borderFocus
                          : AppColors.borderSubtle),
                  width: hasError || selectedAcc != null ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  // Icono de la cuenta seleccionada
                  if (selectedAcc != null) ...[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selectedAcc.parsedColor.withValues(alpha: 0.2),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(
                          color: selectedAcc.parsedColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        selectedAcc.displayIcon,
                        size: 20,
                        color: selectedAcc.parsedColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selectedAcc.name,
                            style: AppTypography.labelLg.copyWith(
                              color: AppColors.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${selectedAcc.accountType.label} • Saldo: ${selectedAcc.currency} ${_formatCurrency(selectedAcc.currentBalance)}',
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        Icons.account_balance_wallet_outlined,
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

                  // Indicador de selector modal
                  Icon(
                    Icons.unfold_more_rounded,
                    color: widget.enabled
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                    size: 20,
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

/// Hoja modal deslizante para la selección de cuentas financieras
class _AccountSelectionSheet extends StatelessWidget {
  const _AccountSelectionSheet({
    required this.accounts,
    required this.selectedAccountId,
  });

  final List<FinancialAccount> accounts;
  final String? selectedAccountId;

  @override
  Widget build(BuildContext context) {
    // Ordenar cuentas: predeterminadas primero, luego por nombre
    final sortedAccounts = List<FinancialAccount>.from(accounts)
      ..sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
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

          // Cabecera: Título y Botón Cerrar (con Expanded para evitar overflow)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        size: 18,
                        color: AppColors.primaryAccessible,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seleccionar Cuenta de Débito',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Cuenta origen de los fondos para este gasto',
                            style: AppTypography.bodySm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lista de cuentas
          Expanded(
            child: sortedAccounts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 48,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No hay cuentas financieras registradas',
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Configura tus cuentas financieras para asignarlas a tus gastos.',
                            style: AppTypography.bodySm,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: sortedAccounts.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (ctx, index) {
                      final acc = sortedAccounts[index];
                      final isSelected = acc.id == selectedAccountId;
                      final accColor = acc.parsedColor;

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: accColor.withValues(alpha: 0.18),
                              borderRadius: AppRadius.borderSm,
                              border: Border.all(
                                color: accColor.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              acc.displayIcon,
                              color: accColor,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  acc.name,
                                  style: AppTypography.labelLg.copyWith(
                                    color: AppColors.textMain,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (acc.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySubtle,
                                    borderRadius: AppRadius.borderPill,
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Predeterminada',
                                    style: AppTypography.captionBadge.copyWith(
                                      color: AppColors.primaryAccessible,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    acc.accountType.label,
                                    style: AppTypography.captionBadge.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${acc.currency} ${_formatCurrency(acc.currentBalance)}',
                                  style: AppTypography.numericRow.copyWith(
                                    color: AppColors.textMain,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryAccessible,
                                  size: 22,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(acc),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
