import 'package:flutter/material.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

/// Diálogo modal de advertencia por posible gasto duplicado dentro de las últimas 24 horas (RN-03).
///
/// Se presenta cuando el backend retorna HTTP 409 Conflict (`duplicate_warning: true`).
/// Permite al usuario revisar la coincidencia y decidir si cancela o fuerza el registro (`?force=true`).
class DuplicateWarningDialog extends StatelessWidget {
  const DuplicateWarningDialog({
    super.key,
    required this.merchantName,
    required this.amount,
    this.existingTransactions = const [],
    this.message,
    this.onConfirmForce,
    this.onCancel,
  });

  final String merchantName;
  final double amount;
  final List<DuplicateTransactionItem> existingTransactions;
  final String? message;
  final VoidCallback? onConfirmForce;
  final VoidCallback? onCancel;

  /// Método estático de conveniencia para mostrar el diálogo modal
  static Future<bool?> show({
    required BuildContext context,
    required String merchantName,
    required double amount,
    List<DuplicateTransactionItem> existingTransactions = const [],
    String? message,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DuplicateWarningDialog(
        merchantName: merchantName,
        amount: amount,
        existingTransactions: existingTransactions,
        message: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = '\$${amount.toStringAsFixed(2)}';
    final existing = existingTransactions.firstOrNull;

    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.borderHero,
      ),
      backgroundColor: AppColors.surfaceBase,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icono de advertencia circular
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warningText,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Título
            Center(
              child: Text(
                'Posible Gasto Duplicado',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Badge de Regla de Negocio
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningBg.withValues(alpha: 0.5),
                  borderRadius: AppRadius.borderPill,
                ),
                child: Text(
                  'Regla RN-03 (±24 Horas)',
                  style: AppTypography.captionBadge.copyWith(
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Mensaje descriptivo
            Text(
              message ??
                  'Ya existe un gasto similar registrado recientemente con el mismo comercio y monto.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // Tarjeta con detalle de la coincidencia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.borderMd,
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
                          merchantName,
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedAmount,
                        style: AppTypography.currencyMd.copyWith(
                          color: AppColors.expenseText,
                        ),
                      ),
                    ],
                  ),
                  if (existing?.transactionDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Fecha detectada: ${existing!.transactionDate!.toIso8601String().split('T')[0]}',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Acciones: Forzar o Cancelar
            AppButton(
              key: const Key('duplicate_force_button'),
              text: 'Registrar de todas formas',
              prefixIcon: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () {
                if (onConfirmForce != null) {
                  onConfirmForce!();
                } else {
                  Navigator.of(context).pop(true);
                }
              },
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              key: const Key('duplicate_cancel_button'),
              text: 'Cancelar',
              onPressed: () {
                if (onCancel != null) {
                  onCancel!();
                } else {
                  Navigator.of(context).pop(false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
