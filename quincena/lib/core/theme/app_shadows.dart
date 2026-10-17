import 'package:flutter/material.dart';

/// Tokens de elevación y sombras según la especificación de diseño Stitch.
///
/// Sustituye sombras duras por sutiles gradientes de profundidad cálidos y limpios.
abstract final class AppShadows {
  /// Sombra nivel 1: Tarjetas estándar y módulos blancos
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A1C242B), // ~4% opacity
      offset: Offset(0, 4),
      blurRadius: 16,
    ),
    BoxShadow(
      color: Color(0x051C242B), // ~2% opacity
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Sombra nivel 2: Tarjeta Hero (resplandor cálido sutil #FCF5C7)
  static const List<BoxShadow> hero = [
    BoxShadow(
      color: Color(0x73FCF5C7), // ~45% opacity warm cast
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
    BoxShadow(
      color: Color(0x0A1C242B),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  /// Sombra nivel 3: Floating Action Button (FAB) con halo de marca
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: Color(0x5979ADDC), // ~35% primary glow
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// Sombra nivel 4: Modales, Bottom Sheets y elementos flotantes elevados
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1F1C242B), // ~12% opacity
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
    BoxShadow(
      color: Color(0x0F1C242B), // ~6% opacity
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];
}
