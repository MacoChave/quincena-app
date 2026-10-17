import 'package:flutter/material.dart';

/// Tipos de cuentas financieras según la especificación DERCAS 1.2 / 1.3
enum AccountType {
  checking(
    value: 'checking',
    label: 'Monetaria / Corriente',
    iconData: Icons.account_balance_outlined,
  ),
  savings(
    value: 'savings',
    label: 'Cuenta de Ahorro',
    iconData: Icons.savings_outlined,
  ),
  cash(
    value: 'cash',
    label: 'Efectivo / Billetera',
    iconData: Icons.payments_outlined,
  ),
  creditCard(
    value: 'credit_card',
    label: 'Tarjeta de Crédito',
    iconData: Icons.credit_card_outlined,
  ),
  digitalWallet(
    value: 'digital_wallet',
    label: 'Billetera Digital',
    iconData: Icons.account_balance_wallet_outlined,
  );

  const AccountType({
    required this.value,
    required this.label,
    required this.iconData,
  });

  final String value;
  final String label;
  final IconData iconData;

  static AccountType fromValue(String? val) {
    return AccountType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => AccountType.checking,
    );
  }
}

/// Modelo de entidad de Cuenta Financiera (Cuentas Destino) - RF-01
class FinancialAccount {
  const FinancialAccount({
    required this.id,
    required this.name,
    required this.accountType,
    required this.currency,
    required this.colorHex,
    required this.icon,
    required this.isDefault,
    required this.isArchived,
    required this.initialBalance,
    required this.currentBalance,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final AccountType accountType;
  final String currency;
  final String colorHex;
  final String icon;
  final bool isDefault;
  final bool isArchived;
  final double initialBalance;
  final double currentBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Retorna el [Color] a partir del string hexadecimal (#RRGGBB)
  Color get parsedColor {
    final hexCode = colorHex.replaceAll('#', '');
    if (hexCode.length == 6) {
      return Color(int.parse('FF$hexCode', radix: 16));
    }
    return const Color(0xFF79ADDC);
  }

  /// Retorna el icono apropiado según el tipo y el string de icon
  IconData get displayIcon => accountType.iconData;

  factory FinancialAccount.fromJson(Map<String, dynamic> json) {
    final initial = (json['initial_balance'] as num?)?.toDouble() ?? 0.0;
    final current = (json['current_balance'] as num?)?.toDouble() ?? initial;

    return FinancialAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      accountType: AccountType.fromValue(json['account_type'] as String?),
      currency: json['currency'] as String? ?? 'GTQ',
      colorHex: json['color_hex'] as String? ?? '#79ADDC',
      icon: json['icon'] as String? ?? 'account_balance',
      isDefault: json['is_default'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      initialBalance: initial,
      currentBalance: current,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'account_type': accountType.value,
      'currency': currency,
      'color_hex': colorHex,
      'icon': icon,
      'is_default': isDefault,
      'is_archived': isArchived,
      'initial_balance': initialBalance,
      'current_balance': currentBalance,
    };
  }

  FinancialAccount copyWith({
    String? id,
    String? name,
    AccountType? accountType,
    String? currency,
    String? colorHex,
    String? icon,
    bool? isDefault,
    bool? isArchived,
    double? initialBalance,
    double? currentBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinancialAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      currency: currency ?? this.currency,
      colorHex: colorHex ?? this.colorHex,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
