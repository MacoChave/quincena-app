import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

/// Campo de entrada de monto monetario con soporte tabular (`tnum`).
///
/// Optimizado para:
/// - Edición de monto detectado por OCR.
/// - Entrada rápida con teclado numérico/decimal.
/// - Legibilidad máxima con prefijo de moneda y tipografía destacada.
class AppAmountInput extends StatelessWidget {
  const AppAmountInput({
    super.key,
    this.controller,
    this.initialValue,
    this.label = 'Monto del gasto',
    this.currencySymbol = '\$',
    this.onChanged,
    this.autofocus = false,
    this.readOnly = false,
    this.errorText,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String currencySymbol;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool readOnly;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: errorText != null ? AppColors.expenseText : AppColors.borderSubtle,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                currencySymbol,
                style: AppTypography.currencyHeroMobile.copyWith(
                  color: AppColors.primaryAccessible,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  initialValue: initialValue,
                  autofocus: autofocus,
                  readOnly: readOnly,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.currencyHeroMobile.copyWith(
                    color: AppColors.textMain,
                  ),
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0.00',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: AppTypography.captionBadge.copyWith(
              color: AppColors.expenseText,
            ),
          ),
        ],
      ],
    );
  }
}
