import '../../../financial_accounts/models/financial_account.dart';
import 'category.dart';

/// Período quincenal para plantillas maestras y ciclos (RF-04)
enum QuincenaPeriod {
  firstHalf(
    value: 'first_half',
    label: '1ra Quincena',
    description: 'Días 1 al 15 del mes',
  ),
  secondHalf(
    value: 'second_half',
    label: '2da Quincena',
    description: 'Días 16 al fin de mes',
  );

  const QuincenaPeriod({
    required this.value,
    required this.label,
    required this.description,
  });

  final String value;
  final String label;
  final String description;

  static QuincenaPeriod fromValue(String? val) {
    if (val == 'second_half') return QuincenaPeriod.secondHalf;
    return QuincenaPeriod.firstHalf;
  }
}

/// Modelo de partida de plantilla maestra para 1ra o 2da Quincena (RF-04)
class BudgetTemplate {
  const BudgetTemplate({
    required this.id,
    required this.period,
    required this.categoryId,
    this.destinationAccountId,
    required this.defaultAmount,
    this.category,
    this.destinationAccount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final QuincenaPeriod period;
  final String categoryId;
  final String? destinationAccountId;
  final double defaultAmount;
  final Category? category;
  final FinancialAccount? destinationAccount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BudgetTemplate.fromJson(Map<String, dynamic> json) {
    final catJson = json['categories'] ?? json['category'];
    final destJson = json['destination_account'] ?? json['financial_account'];

    return BudgetTemplate(
      id: json['id'] as String? ?? '',
      period: QuincenaPeriod.fromValue(json['period'] as String?),
      categoryId: json['category_id'] as String? ?? '',
      destinationAccountId: json['destination_account_id'] as String? ??
          json['financial_account_id'] as String?,
      defaultAmount: (json['default_amount'] as num?)?.toDouble() ?? 0.0,
      category: catJson is Map<String, dynamic> ? Category.fromJson(catJson) : null,
      destinationAccount:
          destJson is Map<String, dynamic> ? FinancialAccount.fromJson(destJson) : null,
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
      'period': period.value,
      'category_id': categoryId,
      'destination_account_id': destinationAccountId,
      'default_amount': defaultAmount,
    };
  }

  BudgetTemplate copyWith({
    String? id,
    QuincenaPeriod? period,
    String? categoryId,
    String? destinationAccountId,
    double? defaultAmount,
    Category? category,
    FinancialAccount? destinationAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetTemplate(
      id: id ?? this.id,
      period: period ?? this.period,
      categoryId: categoryId ?? this.categoryId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      category: category ?? this.category,
      destinationAccount: destinationAccount ?? this.destinationAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
