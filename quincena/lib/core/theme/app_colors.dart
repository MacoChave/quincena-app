import 'package:flutter/material.dart';

/// Design tokens de color para la app Quincena.
///
/// Basado en el sistema de diseño Stitch: "Serene Bi-Weekly Finance".
/// Implementa paleta pastel equilibrada con contrastes accesibles (WCAG AA).
abstract final class AppColors {
  // --- Marca & Primarios ---
  /// Soft Sky Blue (#79ADDC): Identidad, FAB, barras activas (<70%)
  static const Color primary = Color(0xFF79ADDC);

  /// Variante más profunda para contraste accesible en textos/bordes sobre blanco (#4A80B0)
  static const Color primaryAccessible = Color(0xFF4A80B0);

  /// Fondo sutil para inputs y estados hover (#EBF3FA)
  static const Color primarySubtle = Color(0xFFEBF3FA);

  // --- Estados Financieros (Semántica) ---
  /// Mint Pastel (#ADF7B6): Ingresos, metas alcanzadas, saldo a favor
  static const Color incomeBg = Color(0xFFADF7B6);
  /// Texto e icono de ingreso sobre fondo blanco o badge (#236B31)
  static const Color incomeText = Color(0xFF236B31);

  /// Soft Sunshine (#FFEE93): Alertas de umbral (70% - 90%), precaución
  static const Color warningBg = Color(0xFFFFEE93);
  /// Texto e icono de advertencia accesible (#856404)
  static const Color warningText = Color(0xFF856404);

  /// Muted Coral (#FFC09F): Gastos, sobregiros (>90%), alertas críticas
  static const Color expenseBg = Color(0xFFFFC09F);
  /// Texto e icono de gasto accesible (#A33F19)
  static const Color expenseText = Color(0xFFA33F19);

  // --- Superficies y Fondos ---
  /// Warm Cream (#FCF5C7): Superficie de la tarjeta Hero ("Disponible esta quincena")
  static const Color surfaceHero = Color(0xFFFCF5C7);

  /// Superficie elevada para tarjetas y modales (#FFFFFF)
  static const Color surfaceBase = Color(0xFFFFFFFF);

  /// Fondo base del canvas/scaffold (#F8F9FA)
  static const Color surfaceSubtle = Color(0xFFF8F9FA);

  /// Fondo de la barra de progreso (#E9ECEF)
  static const Color progressTrack = Color(0xFFE9ECEF);

  // --- Tipografía y Neutros ---
  /// Deep Navy Charcoal (#1C242B): Cifras monetarias, títulos principales y botón primario
  /// REGLA: Nunca usar blanco sobre los tonos pasteles; usar textMain.
  static const Color textMain = Color(0xFF1C242B);

  /// Slate Gray (#5C6773): Metadatos, etiquetas secundarias, fechas
  static const Color textSecondary = Color(0xFF5C6773);

  /// Gris atenuado (#8C96A3): Placeholders, estados deshabilitados
  static const Color textMuted = Color(0xFF8C96A3);

  // --- Bordes ---
  /// Borde sutil para tarjetas e inputs (#E2E6EA)
  static const Color borderSubtle = Color(0xFFE2E6EA);

  /// Borde de foco o seleccionado (#79ADDC)
  static const Color borderFocus = Color(0xFF79ADDC);

  /// Borde estándar con opacidad sutil
  static const Color borderHairline = Color(0x1F1C242B);
}
