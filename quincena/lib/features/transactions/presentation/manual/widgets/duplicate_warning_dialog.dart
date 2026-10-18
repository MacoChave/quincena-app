import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/transactions/data/models/transaction.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

/// Modal Alert Dialog para advertencia preventiva de gastos duplicados (RN-03).
///
/// Se despliega cuando el backend responde con HTTP 409 Conflict y
/// `duplicate_warning: true` al intentar registrar un gasto con idéntico monto,
/// comercio y fecha dentro de un rango de ±24 horas.
///
/// Acciones:
/// - "Cancelar": Cierra el diálogo y retorna `false`, manteniendo abierto el formulario
///   manual con todos sus campos intactos para que el usuario pueda corregirlos.
/// - "Registrar de todas formas": Cierra el diálogo y retorna `true`, permitiendo al
///   invocador re-enviar la solicitud con el parámetro `?force=true` para omitir la validación.
class DuplicateWarningDialog extends StatelessWidget {
  const DuplicateWarningDialog({
    super.key,
    this.existingTransactions = const [],
    this.existingTransaction,
    this.merchantName,
    this.amount,
    this.transactionDate,
    this.warningMessage,
    this.onCancel,
    this.onForceRegister,
    this.onConfirmForce,
  });

  /// Lista de transacciones preexistentes conflictivas retornadas por el backend (RN-03).
  final List<DuplicateTransactionItem> existingTransactions;

  /// Transacción individual preexistente (para compatibilidad con tests y llamadas directas).
  final Transaction? existingTransaction;

  /// Nombre del comercio de la transacción que se intentó registrar.
  final String? merchantName;

  /// Monto de la transacción que se intentó registrar.
  final double? amount;

  /// Fecha de la transacción que se intentó registrar.
  final String? transactionDate;

  /// Mensaje descriptivo opcional provisto por el backend o la excepción.
  final String? warningMessage;

  /// Callback invocado al presionar el botón "Cancelar".
  final VoidCallback? onCancel;

  /// Callback invocado al presionar el botón "Registrar de todas formas".
  final VoidCallback? onForceRegister;

  /// Alias de conveniencia para onForceRegister
  final VoidCallback? onConfirmForce;

  /// Método estático de conveniencia para mostrar el diálogo modal.
  ///
  /// Retorna `true` si el usuario decidió forzar el registro.
  /// Retorna `false` si el usuario canceló o cerró el diálogo.
  static Future<bool> show({
    required BuildContext context,
    List<DuplicateTransactionItem> existingTransactions = const [],
    Transaction? existingTransaction,
    String? merchantName,
    double? amount,
    String? transactionDate,
    DuplicateTransactionException? exception,
    String? customMessage,
    VoidCallback? onCancel,
    VoidCallback? onConfirmForce,
  }) async {
    final effectiveDuplicates = existingTransactions.isNotEmpty
        ? existingTransactions
        : (exception?.existingTransactions ?? const []);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DuplicateWarningDialog(
        existingTransactions: effectiveDuplicates,
        existingTransaction: existingTransaction,
        merchantName: merchantName ?? existingTransaction?.merchantName,
        amount: amount ?? existingTransaction?.amount,
        transactionDate: transactionDate,
        warningMessage: customMessage ?? exception?.message,
        onCancel: onCancel != null
            ? () {
                onCancel();
                Navigator.of(ctx).pop(false);
              }
            : () => Navigator.of(ctx).pop(false),
        onForceRegister: onConfirmForce != null
            ? () {
                onConfirmForce();
                Navigator.of(ctx).pop(true);
              }
            : () => Navigator.of(ctx).pop(true),
      ),
    );

    return result ?? false;
  }

  String _formatCurrency(double value) {
    final isNegative = value < 0;
    final absVal = value.abs();
    final parts = absVal.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final decimalPart = parts[1];
    return '${isNegative ? '-' : ''}\$$integerPart.$decimalPart';
  }

  String _formatDate(DateTime? dateTime, [String? fallbackDateStr]) {
    if (dateTime != null) {
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = _monthName(dateTime.month);
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final min = dateTime.minute.toString().padLeft(2, '0');
      if (dateTime.hour != 0 || dateTime.minute != 0) {
        return '$day $month $year • $hour:$min hrs';
      }
      return '$day $month $year';
    }

    if (fallbackDateStr != null && fallbackDateStr.isNotEmpty) {
      final parsed = DateTime.tryParse(fallbackDateStr);
      if (parsed != null) {
        return _formatDate(parsed);
      }
      return fallbackDateStr;
    }

    return 'Fecha no disponible';
  }

  String _monthName(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  void _handleCancel(BuildContext context) {
    if (onCancel != null) {
      onCancel!();
    } else {
      Navigator.of(context).pop(false);
    }
  }

  void _handleForce(BuildContext context) {
    final cb = onForceRegister ?? onConfirmForce;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = warningMessage ??
        'Detectamos un gasto previamente registrado con el mismo monto, comercio y fecha dentro de un rango de ±24 horas (Regla RN-03).';

    return Dialog(
      key: const Key('duplicate_warning_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      elevation: 8,
      backgroundColor: AppColors.surfaceBase,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420.0),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Icono de Advertencia y Encabezado
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.warningText.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warningText,
                      size: 28.0,
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            'REGLA RN-03',
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.warningText,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Posible Gasto Duplicado',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w700,
                            fontSize: 18.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16.0),

              // 2. Descripción de la regla
              Text(
                description,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 18.0),

              // 3. Contenedor con detalles de transacción(es) preexistente(s)
              if (existingTransactions.isNotEmpty) ...[
                Text(
                  'Transacción detectada en el sistema:',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8.0),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 12.0,
                    ),
                    itemCount: existingTransactions.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 16.0,
                      color: AppColors.borderSubtle,
                    ),
                    itemBuilder: (context, index) {
                      final item = existingTransactions[index];
                      return Row(
                        key: Key('duplicate_item_${item.id}'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: AppColors.expenseBg.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18.0,
                              color: AppColors.expenseText,
                            ),
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.merchantName.isNotEmpty
                                      ? item.merchantName
                                      : 'Comercio no especificado',
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMain,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  _formatDate(
                                    item.transactionDate ?? item.createdAt,
                                  ),
                                  style: AppTypography.captionBadge.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            _formatCurrency(item.amount),
                            style: AppTypography.numericRow.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                              fontSize: 15.0,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16.0),
              ] else if (existingTransaction != null) ...[
                // Caso con objeto Transaction individual
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existingTransaction!.merchantName,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                          Text(
                            existingTransaction!.transactionDate
                                .toIso8601String()
                                .split('T')[0],
                            style: AppTypography.captionBadge.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '-\$${existingTransaction!.amount.toStringAsFixed(2)}',
                        style: AppTypography.numericRow.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
              ] else if (merchantName != null || amount != null) ...[
                // Fallback con datos directos del intento
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warningText,
                        size: 20.0,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          '${merchantName ?? 'Gasto'}: ${_formatCurrency(amount ?? 0.0)} (${_formatDate(null, transactionDate)})',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
              ],

              // 4. Pregunta orientadora
              Text(
                '¿Deseas registrar este gasto de todas formas?',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 24.0),

              // 5. Botones de Acción
              Row(
                children: [
                  // Botón "Cancelar" (reconoce tanto Key('btn_cancel_duplicate') como Key('duplicate_dialog_cancel_button'))
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('btn_cancel_duplicate'),
                      child: OutlinedButton(
                        key: const Key('duplicate_dialog_cancel_button'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.borderSubtle,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14.0),
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () => _handleCancel(context),
                        child: Text(
                          'Cancelar',
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12.0),

                  // Botón "Registrar de todas formas" (reconoce tanto Key('btn_force_duplicate') como Key('duplicate_dialog_force_button'))
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('btn_force_duplicate'),
                      child: ElevatedButton(
                        key: const Key('duplicate_dialog_force_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textMain,
                          foregroundColor: AppColors.surfaceBase,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14.0,
                            horizontal: 8.0,
                          ),
                        ),
                        onPressed: () => _handleForce(context),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Registrar de todas formas',
                            style: AppTypography.labelLg.copyWith(
                              color: AppColors.surfaceBase,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
