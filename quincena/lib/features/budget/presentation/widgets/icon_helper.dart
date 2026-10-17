import 'package:flutter/material.dart';

/// Helper para mapear nombres de iconos de categorías a [IconData] de Material Icons
IconData resolveCategoryIcon(String? iconName) {
  final name = (iconName ?? '').toLowerCase().trim();
  switch (name) {
    case 'restaurant':
    case 'comida':
    case 'food':
      return Icons.restaurant_rounded;
    case 'home':
    case 'casa':
    case 'alquiler':
    case 'rent':
      return Icons.home_rounded;
    case 'directions_car':
    case 'transporte':
    case 'transport':
    case 'auto':
      return Icons.directions_car_rounded;
    case 'shopping_cart':
    case 'supermercado':
    case 'groceries':
      return Icons.shopping_cart_rounded;
    case 'local_hospital':
    case 'salud':
    case 'health':
    case 'medicina':
      return Icons.local_hospital_rounded;
    case 'school':
    case 'educacion':
    case 'education':
      return Icons.school_rounded;
    case 'savings':
    case 'ahorro':
    case 'inversion':
      return Icons.savings_rounded;
    case 'movie':
    case 'entretenimiento':
    case 'ocio':
      return Icons.movie_filter_rounded;
    case 'fitness_center':
    case 'deporte':
    case 'gym':
      return Icons.fitness_center_rounded;
    case 'bolt':
    case 'servicios':
    case 'utilities':
    case 'luz':
      return Icons.bolt_rounded;
    case 'credit_card':
    case 'tarjeta':
    case 'deuda':
      return Icons.credit_card_rounded;
    default:
      return Icons.category_rounded;
  }
}
