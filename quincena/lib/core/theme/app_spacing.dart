import 'package:flutter/material.dart';

/// Tokens de espaciado y márgenes según la cuadrícula base de 4px/8px de Quincena.
abstract final class AppSpacing {
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;

  // Insets y paddings comunes
  static const EdgeInsets paddingScreen = EdgeInsets.symmetric(horizontal: spaceMd);
  static const EdgeInsets paddingCard = EdgeInsets.all(spaceMd);
  static const EdgeInsets paddingHeroCard = EdgeInsets.all(20.0);
  static const EdgeInsets paddingInput = EdgeInsets.symmetric(horizontal: spaceMd, vertical: 14.0);
  static const EdgeInsets paddingChip = EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0);
}
