import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tokens de tipografía para Quincena.
///
/// Utiliza Plus Jakarta Sans con soporte estricto de cifras tabulares (`FontFeature.tabularFigures()`)
/// para evitar brincos en el layout al comparar montos y fechas.
abstract final class AppTypography {
  // Features numéricas tabulares
  static const List<FontFeature> _tabularFeatures = [
    FontFeature.tabularFigures(),
  ];

  /// Balance principal / Hero Currency en pantalla completa (38px, Bold 800)
  static TextStyle get currencyHero => GoogleFonts.plusJakartaSans(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 44 / 38,
        letterSpacing: -0.03 * 38,
        color: AppColors.textMain,
        fontFeatures: _tabularFeatures,
      );

  /// Balance principal para móviles compactos (32px, Bold 800)
  static TextStyle get currencyHeroMobile => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 38 / 32,
        letterSpacing: -0.03 * 32,
        color: AppColors.textMain,
        fontFeatures: _tabularFeatures,
      );

  /// Cifras intermedias destacadas (18px, Bold 700)
  static TextStyle get currencyMd => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 24 / 18,
        letterSpacing: -0.01 * 18,
        color: AppColors.textMain,
        fontFeatures: _tabularFeatures,
      );

  /// Cifras monetarias en listas de transacciones (14px, Medium 500)
  static TextStyle get numericRow => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        color: AppColors.textMain,
        fontFeatures: _tabularFeatures,
      );

  // --- Encabezados ---
  static TextStyle get headlineXl => GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 44 / 36,
        letterSpacing: -0.02 * 36,
        color: AppColors.textMain,
      );

  static TextStyle get headlineLg => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 34 / 26,
        letterSpacing: -0.015 * 26,
        color: AppColors.textMain,
      );

  static TextStyle get headlineMd => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        letterSpacing: -0.01 * 20,
        color: AppColors.textMain,
      );

  static TextStyle get headlineSm => GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 24 / 17,
        color: AppColors.textMain,
      );

  // --- Cuerpo de texto ---
  static TextStyle get bodyLg => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.textMain,
      );

  static TextStyle get bodyMd => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodySm => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.textSecondary,
      );

  // --- Etiquetas, botones y chips ---
  static TextStyle get labelLg => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 20 / 15,
        color: AppColors.textMain,
      );

  static TextStyle get labelMd => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 18 / 13,
        color: AppColors.textMain,
      );

  static TextStyle get labelSm => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.04 * 11,
        color: AppColors.textSecondary,
      );

  /// Etiquetas pequeñas para fechas, tags y subtítulos (12px, Medium 500)
  static TextStyle get captionBadge => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        color: AppColors.textSecondary,
      );
}
