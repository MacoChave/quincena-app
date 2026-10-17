import '../../../financial_accounts/models/financial_account.dart';
import 'category.dart';

/// Modelo de partida o bolsa presupuestaria para un ciclo quincenal (RF-03)
class BudgetAllocation {
  const BudgetAllocation({
    required this.id,
    required this.cycleId,
    required this.categoryId,
    this.destinationAccountId,
    required this.allocatedAmount,
    this.spentAmount = 0.0,
    this.availableAmount,
    this.spentPercentage,
    this.category,
    this.destinationAccount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String cycleId;
  final String categoryId;
  final String? destinationAccountId;
  final double allocatedAmount;
  final double spentAmount;
  final double? availableAmount;
  final double? spentPercentage;
  final Category? category;
  final FinancialAccount? destinationAccount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Saldo disponible real en la partida (allocated - spent)
  double get computedAvailable => availableAmount ?? (allocatedAmount - spentAmount);

  /// Porcentaje de ejecución del presupuesto (0% a 100%+)
  double get computedPercentage {
    if (spentPercentage != null) return spentPercentage!;
    if (allocatedAmount <= 0) return 0.0;
    return (spentAmount / allocatedAmount) * 100.0;
  }

  /// Ratio de progreso entre 0.0 y 1.0 (para barras de progreso)
  double get progressRatio {
    if (allocatedAmount <= 0) return 0.0;
    final ratio = spentAmount / allocatedAmount;
    return ratio > 1.0 ? 1.0 : (ratio < 0 ? 0.0 : ratio);
  }

  factory BudgetAllocation.fromJson(Map<String, dynamic> json) {
    final catJson = json['categories'] ?? json['category'];
    final destJson = json['destination_account'] ?? json['financial_account'];

    final allocated = (json['allocated_amount'] as num?)?.toDouble() ?? 0.0;
    final spent = (json['spent_amount'] as num?)?.toDouble() ?? 0.0;
    final available = (json['available_amount'] as num?)?.toDouble() ?? (allocated - spent);
    final percentage = (json['spent_percentage'] as num?)?.toDouble() ??
        (allocated > 0 ? (spent / allocated) * 100.0 : 0.0);

    return BudgetAllocation(
      id: json['id'] as String? ?? '',
      cycleId: json['cycle_id'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
      destinationAccountId: json['destination_account_id'] as String? ??
          json['financial_account_id'] as String?,
      allocatedAmount: allocated,
      spentAmount: spent,
      availableAmount: available,
      spentPercentage: percentage,
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
      'cycle_id': cycleId,
      'category_id': categoryId,
      'destination_account_id': destinationAccountId,
      'allocated_amount': allocatedAmount,
    };
  }

  BudgetAllocation copyWith({
    String? id,
    String? cycleId,
    String? categoryId,
    String? destinationAccountId,
    double? allocatedAmount,
    double? spentAmount,
    double? availableAmount,
    double? spentPercentage,
    Category? category,
    FinancialAccount? destinationAccount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetAllocation(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      categoryId: categoryId ?? this.categoryId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      availableAmount: availableAmount ?? this.availableAmount,
      spentPercentage: spentPercentage ?? this.spentPercentage,
      category: category ?? this.category,
      destinationAccount: destinationAccount ?? this.destinationAccount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Resumen financiero del ciclo para Presupuesto Base Cero (CA-02.1)
class AllocationsSummary {
  const AllocationsSummary({
    this.totalIncome = 0.0,
    this.totalAllocated = 0.0,
    this.unallocated = 0.0,
    this.totalSpent = 0.0,
    this.totalAvailable = 0.0,
    this.isBalanced = false,
    this.isClosed = false,
  });

  final double totalIncome;
  final double totalAllocated;
  final double unallocated; // "Por Asignar"
  final double totalSpent;
  final double totalAvailable;
  final bool isBalanced;
  final bool isClosed;

  /// Superávit: Por Asignar >= 0.01
  bool get hasSurplus => unallocated >= 0.01;

  /// Base cero exacto: abs(unallocated) < 0.01
  bool get isBaseZero => isBalanced || (unallocated.abs() < 0.01);

  /// Déficit / Sobreasignado: Por Asignar <= -0.01
  bool get hasDeficit => unallocated <= -0.01;

  factory AllocationsSummary.fromJson(Map<String, dynamic> json) {
    final income = (json['total_income'] as num?)?.toDouble() ?? 0.0;
    final allocated = (json['total_allocated'] as num?)?.toDouble() ?? 0.0;
    final unalloc = (json['unallocated'] as num?)?.toDouble() ?? (income - allocated);
    final spent = (json['total_spent'] as num?)?.toDouble() ?? 0.0;
    final available = (json['total_available'] as num?)?.toDouble() ?? (allocated - spent);
    final balanced = json['is_balanced'] as bool? ?? (unalloc.abs() < 0.01);
    final closed = json['is_closed'] as bool? ?? false;

    return AllocationsSummary(
      totalIncome: income,
      totalAllocated: allocated,
      unallocated: unalloc,
      totalSpent: spent,
      totalAvailable: available,
      isBalanced: balanced,
      isClosed: closed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_income': totalIncome,
      'total_allocated': totalAllocated,
      'unallocated': unallocated,
      'total_spent': totalSpent,
      'total_available': totalAvailable,
      'is_balanced': isBalanced,
      'is_closed': isClosed,
    };
  }

  AllocationsSummary copyWith({
    double? totalIncome,
    double? totalAllocated,
    double? unallocated,
    double? totalSpent,
    double? totalAvailable,
    bool? isBalanced,
    bool? isClosed,
  }) {
    return AllocationsSummary(
      totalIncome: totalIncome ?? this.totalIncome,
      totalAllocated: totalAllocated ?? this.totalAllocated,
      unallocated: unallocated ?? this.unallocated,
      totalSpent: totalSpent ?? this.totalSpent,
      totalAvailable: totalAvailable ?? this.totalAvailable,
      isBalanced: isBalanced ?? this.isBalanced,
      isClosed: isClosed ?? this.isClosed,
    );
  }
}
