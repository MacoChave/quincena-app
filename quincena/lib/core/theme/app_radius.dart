import 'package:flutter/material.dart';

/// Tokens de radio de esquina (BorderRadius) para Quincena.
///
/// Define formas redondeadas, táctiles y consistentes según el sistema Stitch.
abstract final class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double card = 16.0;
  static const double hero = 20.0;
  static const double pill = 9999.0;

  // BorderRadius precalculados para uso con 'const'
  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius borderHero = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius borderPill = BorderRadius.all(Radius.circular(pill));

  // Radios para modales y bottom sheets (solo esquinas superiores)
  static const BorderRadius borderBottomSheet = BorderRadius.vertical(top: Radius.circular(hero));
}
