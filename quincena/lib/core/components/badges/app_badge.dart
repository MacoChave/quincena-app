import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

enum AppBadgeVariant {
  income,
  warning,
  expense,
  neutral,
  brand,
}

/// Badge o Chip en forma de píldora para estados financieros.
///
/// Implementa la regla estricta de accesibilidad de Quincena:
/// Nunca colocar texto blanco sobre los fondos pasteles.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.text,
    this.variant = AppBadgeVariant.neutral,
    this.prefixIcon,
    this.onTap,
  });

  const AppBadge.income({
    super.key,
    required this.text,
    this.prefixIcon,
    this.onTap,
  }) : variant = AppBadgeVariant.income;

  const AppBadge.warning({
    super.key,
    required this.text,
    this.prefixIcon,
    this.onTap,
  }) : variant = AppBadgeVariant.warning;

  const AppBadge.expense({
    super.key,
    required this.text,
    this.prefixIcon,
    this.onTap,
  }) : variant = AppBadgeVariant.expense;

  const AppBadge.brand({
    super.key,
    required this.text,
    this.prefixIcon,
    this.onTap,
  }) : variant = AppBadgeVariant.brand;

  final String text;
  final AppBadgeVariant variant;
  final Widget? prefixIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = _resolveColors();

    Widget badgeContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefixIcon != null) ...[
            prefixIcon!,
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTypography.captionBadge.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderPill,
          child: badgeContent,
        ),
      );
    }

    return badgeContent;
  }

  (Color bg, Color text) _resolveColors() {
    switch (variant) {
      case AppBadgeVariant.income:
        return (AppColors.incomeBg, AppColors.textMain);
      case AppBadgeVariant.warning:
        return (AppColors.warningBg, AppColors.textMain);
      case AppBadgeVariant.expense:
        return (AppColors.expenseBg, AppColors.textMain);
      case AppBadgeVariant.brand:
        return (AppColors.primary, AppColors.textMain);
      case AppBadgeVariant.neutral:
        return (AppColors.primarySubtle, AppColors.textMain);
    }
  }
}
