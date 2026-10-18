import 'package:flutter/material.dart';
import '../../../financial_accounts/models/financial_account.dart';

/// Modelo de categoría de presupuesto (RF-03 / RF-04 / RF-CAT-01)
class Category {
  const Category({
    required this.id,
    required this.name,
    this.icon = 'category',
    this.colorHex = '#79ADDC',
    this.defaultAccountId,
    this.defaultAccount,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String icon;
  final String colorHex;
  final String? defaultAccountId;
  final FinancialAccount? defaultAccount;
  final bool isArchived;

  Color get parsedColor {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return const Color(0xFF79ADDC);
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    FinancialAccount? defaultAcc;
    if (json['default_account'] is Map<String, dynamic>) {
      defaultAcc = FinancialAccount.fromJson(
        json['default_account'] as Map<String, dynamic>,
      );
    }

    return Category(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin categoría',
      icon: json['icon'] as String? ?? 'category',
      colorHex: json['color_hex'] as String? ?? '#79ADDC',
      defaultAccountId: json['default_account_id'] as String?,
      defaultAccount: defaultAcc,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      if (defaultAccountId != null) 'default_account_id': defaultAccountId,
      'is_archived': isArchived,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? colorHex,
    String? defaultAccountId,
    FinancialAccount? defaultAccount,
    bool? isArchived,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      defaultAccount: defaultAccount ?? this.defaultAccount,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
