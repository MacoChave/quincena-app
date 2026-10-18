import 'package:flutter/material.dart';

/// Helper para mapear nombres de iconos de categorías a [IconData] de Material Icons
IconData resolveCategoryIcon(String? iconName) {
  final name = (iconName ?? '').toLowerCase().trim();
  switch (name) {
    case 'restaurant':
    case 'comida':
    case 'food':
    case 'alimentacion':
    case 'alimentación':
      return Icons.restaurant_rounded;
    case 'home':
    case 'casa':
    case 'alquiler':
    case 'rent':
    case 'renta':
    case 'vivienda':
    case 'vivienda & servicios':
      return Icons.home_rounded;
    case 'directions_car':
    case 'transporte':
    case 'transport':
    case 'auto':
    case 'coche':
    case 'gasolina':
      return Icons.directions_car_rounded;
    case 'shopping_cart':
    case 'supermercado':
    case 'groceries':
    case 'despensa':
      return Icons.shopping_cart_rounded;
    case 'medical_services':
    case 'local_hospital':
    case 'salud':
    case 'health':
    case 'medicina':
    case 'farmacia':
      return Icons.medical_services_rounded;
    case 'fitness_center':
    case 'deporte':
    case 'gym':
    case 'gimnasio':
    case 'bienestar':
      return Icons.fitness_center_rounded;
    case 'school':
    case 'educacion':
    case 'educación':
    case 'estudio':
    case 'libro':
      return Icons.school_rounded;
    case 'flight_takeoff':
    case 'viajes':
    case 'vuelo':
    case 'vacaciones':
      return Icons.flight_takeoff_rounded;
    case 'pets':
    case 'mascotas':
    case 'perro':
    case 'veterinario':
      return Icons.pets_rounded;
    case 'local_cafe':
    case 'cafe':
    case 'café':
    case 'ocio':
    case 'ocio & salidas':
    case 'salidas':
      return Icons.local_cafe_rounded;
    case 'savings':
    case 'ahorro':
    case 'inversion':
    case 'inversión':
      return Icons.savings_rounded;
    case 'bolt':
    case 'servicios':
    case 'utilities':
    case 'luz':
    case 'agua':
    case 'gas':
      return Icons.bolt_rounded;
    case 'credit_card':
    case 'tarjeta':
    case 'deuda':
    case 'debito':
    case 'débito':
      return Icons.credit_card_rounded;
    case 'payments':
    case 'efectivo':
    case 'dinero':
      return Icons.payments_rounded;
    case 'account_balance':
    case 'banco':
    case 'monetaria':
      return Icons.account_balance_rounded;
    case 'receipt_long':
    case 'factura':
    case 'ticket':
      return Icons.receipt_long_rounded;
    case 'movie':
    case 'entretenimiento':
      return Icons.movie_filter_rounded;
    default:
      return Icons.category_rounded;
  }
}
