import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

/// Barra superior (Toolbar / AppBar) para Quincena.
///
/// Soporta títulos con jerarquía clara, selectores de quincena/periodo
/// y acciones rápidas como notificaciones y perfil.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.periodLabel,
    this.onPeriodTap,
    this.leading,
    this.actions,
    this.showBottomDivider = false,
  });

  final String? title;
  final String? subtitle;
  final String? periodLabel;
  final VoidCallback? onPeriodTap;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBottomDivider;

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        border: showBottomDivider
            ? const Border(bottom: BorderSide(color: AppColors.borderSubtle))
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: AppTypography.headlineMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.captionBadge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (periodLabel != null) ...[
                      const SizedBox(height: 2),
                      InkWell(
                        onTap: onPeriodTap,
                        borderRadius: AppRadius.borderPill,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              periodLabel!,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primaryAccessible,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (onPeriodTap != null) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: AppColors.primaryAccessible,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...?actions,
            ],
          ),
        ),
      ),
    );
  }
}
