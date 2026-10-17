import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class AppNavItem {
  const AppNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
}

/// Barra de navegación inferior (NavBar) con muesca o espacio para el FAB central.
///
/// Especificación Stitch:
/// - Altura base de 68px + safe area inset.
/// - 4 items de navegación repartidos equitativamente alrededor del centro.
/// - Fondo blanco con borde superior sutil.
/// - Estados activo (#1C242B) e inactivo (#5C6773).
class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = defaultItems,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  static const List<AppNavItem> defaultItems = [
    AppNavItem(
      label: 'Inicio',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    AppNavItem(
      label: 'Presupuesto',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    AppNavItem(
      label: 'Historial',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    AppNavItem(
      label: 'Perfil',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Dividir items en dos mitades para dejar el espacio central del FAB
    final halfCount = (items.length / 2).ceil();
    final leftItems = items.sublist(0, halfCount);
    final rightItems = items.sublist(halfCount);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        border: Border(
          top: BorderSide(
            color: Color(0x0D1C242B), // sutil 5%
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ...leftItems.asMap().entries.map(
                (entry) => _buildNavItem(entry.key, entry.value),
              ),
              // Espacio central para el FAB flotante
              const SizedBox(width: 56),
              ...rightItems.asMap().entries.map(
                (entry) => _buildNavItem(entry.key + halfCount, entry.value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, AppNavItem item) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.textMain : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: AppColors.primarySubtle,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? (item.activeIcon ?? item.icon) : item.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTypography.labelSm.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            // Indicador pip de selección
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
