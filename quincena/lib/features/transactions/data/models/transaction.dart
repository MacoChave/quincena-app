import 'package:flutter/material.dart';

/// Tipo de transacción financiera según la especificación DERCAS 1.2
enum TransactionType {
  expense(
    value: 'expense',
    label: 'Gasto',
  ),
  incomeAdjustment(
    value: 'income_adjustment',
    label: 'Ajuste de Ingreso',
  ),
  transfer(
    value: 'transfer',
    label: 'Transferencia',
  );

  const TransactionType({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  static TransactionType fromValue(String? val) {
    return TransactionType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => TransactionType.expense,
    );
  }
}

/// Método de captura / registro de la transacción
enum EntryMethod {
  manual(
    value: 'manual',
    label: 'Registro Manual',
  ),
  ocr(
    value: 'ocr',
    label: 'Comprobante OCR',
  );

  const EntryMethod({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  static EntryMethod fromValue(String? val) {
    return EntryMethod.values.firstWhere(
      (e) => e.value == val,
      orElse: () => EntryMethod.manual,
    );
  }
}

/// Información de categoría unida (joined) en la transacción
class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.name,
    this.icon = 'category',
    this.colorHex = '#79ADDC',
  });

  final String id;
  final String name;
  final String icon;
  final String colorHex;

  Color get parsedColor {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.tryParse('FF$hex', radix: 16) ?? 0xFF79ADDC);
    }
    return const Color(0xFF79ADDC);
  }

  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin categoría',
      icon: json['icon'] as String? ?? 'category',
      colorHex: json['color_hex'] as String? ?? '#79ADDC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
    };
  }
}

/// Información de cuenta financiera unida (joined) en la transacción
class TransactionSourceAccount {
  const TransactionSourceAccount({
    required this.id,
    required this.name,
    this.colorHex = '#79ADDC',
  });

  final String id;
  final String name;
  final String colorHex;

  Color get parsedColor {
    final hex = colorHex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.tryParse('FF$hex', radix: 16) ?? 0xFF79ADDC);
    }
    return const Color(0xFF79ADDC);
  }

  factory TransactionSourceAccount.fromJson(Map<String, dynamic> json) {
    return TransactionSourceAccount(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Cuenta bancaria',
      colorHex: json['color_hex'] as String? ?? '#79ADDC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color_hex': colorHex,
    };
  }
}

/// Modelo de datos de Transacción Quincenal (RF-04 / RF-06)
class Transaction {
  const Transaction({
    required this.id,
    required this.userId,
    required this.cycleId,
    this.allocationId,
    this.receiptScanId,
    required this.sourceAccountId,
    required this.amount,
    required this.merchantName,
    required this.transactionDate,
    this.transactionType = TransactionType.expense,
    this.entryMethod = EntryMethod.manual,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.sourceAccount,
  });

  final String id;
  final String userId;
  final String cycleId;
  final String? allocationId;
  final String? receiptScanId;
  final String sourceAccountId;
  final double amount;
  final String merchantName;
  final DateTime transactionDate;
  final TransactionType transactionType;
  final EntryMethod entryMethod;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final TransactionCategory? category;
  final TransactionSourceAccount? sourceAccount;

  // --- Getters de conveniencia UI ---

  String get categoryName => category?.name ?? 'Sin categoría';
  String get categoryIcon => category?.icon ?? 'receipt_long_outlined';
  String get categoryColorHex => category?.colorHex ?? '#79ADDC';
  Color get categoryColor => category?.parsedColor ?? const Color(0xFF79ADDC);

  String get sourceAccountName => sourceAccount?.name ?? 'Cuenta origen';
  String get sourceAccountColorHex => sourceAccount?.colorHex ?? '#79ADDC';
  Color get sourceAccountColor =>
      sourceAccount?.parsedColor ?? const Color(0xFF79ADDC);

  bool get isOcr => entryMethod == EntryMethod.ocr;
  bool get isManual => entryMethod == EntryMethod.manual;
  bool get isExpense => transactionType == TransactionType.expense;

  /// Retorna el monto formateado con signo negativo para gastos
  String get formattedSignedAmount {
    final prefix = isExpense ? '-' : '+';
    return '$prefix\$${amount.abs().toStringAsFixed(2)}';
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // 1. Resolver categoría unida (soporta varias estructuras de join de Supabase y NestJS)
    TransactionCategory? parsedCategory;
    if (json['category'] is Map<String, dynamic>) {
      parsedCategory =
          TransactionCategory.fromJson(json['category'] as Map<String, dynamic>);
    } else if (json['categories'] is Map<String, dynamic>) {
      parsedCategory = TransactionCategory.fromJson(
          json['categories'] as Map<String, dynamic>);
    } else if (json['budget_allocations'] is Map<String, dynamic>) {
      final alloc = json['budget_allocations'] as Map<String, dynamic>;
      if (alloc['categories'] is Map<String, dynamic>) {
        parsedCategory = TransactionCategory.fromJson(
            alloc['categories'] as Map<String, dynamic>);
      } else if (alloc['category'] is Map<String, dynamic>) {
        parsedCategory = TransactionCategory.fromJson(
            alloc['category'] as Map<String, dynamic>);
      }
    }

    // 2. Resolver cuenta financiera unida
    TransactionSourceAccount? parsedAccount;
    if (json['source_account'] is Map<String, dynamic>) {
      parsedAccount = TransactionSourceAccount.fromJson(
          json['source_account'] as Map<String, dynamic>);
    } else if (json['financial_accounts'] is Map<String, dynamic>) {
      parsedAccount = TransactionSourceAccount.fromJson(
          json['financial_accounts'] as Map<String, dynamic>);
    } else if (json['financial_account'] is Map<String, dynamic>) {
      parsedAccount = TransactionSourceAccount.fromJson(
          json['financial_account'] as Map<String, dynamic>);
    }

    // 3. Resolver fecha de transacción
    DateTime txDate = DateTime.now();
    final txDateStr = json['transaction_date'] ?? json['transactionDate'];
    if (txDateStr != null) {
      final parsed = DateTime.tryParse(txDateStr.toString());
      if (parsed != null) txDate = parsed;
    }

    final createdStr = json['created_at'] ?? json['createdAt'];
    final updatedStr = json['updated_at'] ?? json['updatedAt'];

    return Transaction(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      cycleId: json['cycle_id'] as String? ?? json['cycleId'] as String? ?? '',
      allocationId: json['allocation_id'] as String? ??
          json['allocationId'] as String?,
      receiptScanId: json['receipt_scan_id'] as String? ??
          json['receiptScanId'] as String?,
      sourceAccountId: json['source_account_id'] as String? ??
          json['sourceAccountId'] as String? ??
          '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchantName: json['merchant_name'] as String? ??
          json['merchantName'] as String? ??
          'Sin nombre',
      transactionDate: txDate,
      transactionType: TransactionType.fromValue(
          json['transaction_type'] as String? ??
              json['transactionType'] as String?),
      entryMethod: EntryMethod.fromValue(json['entry_method'] as String? ??
          json['entryMethod'] as String?),
      notes: json['notes'] as String?,
      createdAt: createdStr != null
          ? DateTime.tryParse(createdStr.toString())
          : null,
      updatedAt: updatedStr != null
          ? DateTime.tryParse(updatedStr.toString())
          : null,
      category: parsedCategory,
      sourceAccount: parsedAccount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'cycle_id': cycleId,
      if (allocationId != null) 'allocation_id': allocationId,
      if (receiptScanId != null) 'receipt_scan_id': receiptScanId,
      'source_account_id': sourceAccountId,
      'amount': amount,
      'merchant_name': merchantName,
      'transaction_date':
          transactionDate.toIso8601String().split('T')[0],
      'transaction_type': transactionType.value,
      'entry_method': entryMethod.value,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (category != null) 'category': category!.toJson(),
      if (sourceAccount != null) 'source_account': sourceAccount!.toJson(),
    };
  }

  Transaction copyWith({
    String? id,
    String? userId,
    String? cycleId,
    String? allocationId,
    String? receiptScanId,
    String? sourceAccountId,
    double? amount,
    String? merchantName,
    DateTime? transactionDate,
    TransactionType? transactionType,
    EntryMethod? entryMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    TransactionCategory? category,
    TransactionSourceAccount? sourceAccount,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      cycleId: cycleId ?? this.cycleId,
      allocationId: allocationId ?? this.allocationId,
      receiptScanId: receiptScanId ?? this.receiptScanId,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      amount: amount ?? this.amount,
      merchantName: merchantName ?? this.merchantName,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionType: transactionType ?? this.transactionType,
      entryMethod: entryMethod ?? this.entryMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      sourceAccount: sourceAccount ?? this.sourceAccount,
    );
  }
}
