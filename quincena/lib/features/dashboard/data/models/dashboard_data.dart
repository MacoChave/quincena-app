/// Modelos de datos para el Dashboard de Quincena Activa.
class DashboardCycle {
  const DashboardCycle({
    required this.id,
    required this.year,
    required this.month,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.isClosed,
  });

  final String id;
  final int year;
  final int month;
  final String period; // 'first_half' | 'second_half'
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final bool isClosed;

  String get periodFormatted {
    final startDay = startDate.day;
    final endDay = endDate.day;
    final monthName = _monthNames[month - 1];
    return '$startDay - $endDay $monthName $year';
  }

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  factory DashboardCycle.fromJson(Map<String, dynamic> json) {
    return DashboardCycle(
      id: json['id'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      period: json['period'] as String? ?? 'first_half',
      startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date'] as String? ?? '') ?? DateTime.now(),
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    this.totalIncome = 0.0,
    this.totalAllocated = 0.0,
    this.totalSpent = 0.0,
    this.totalAvailable = 0.0,
    this.unallocated = 0.0,
    this.isBalanced = false,
  });

  final double totalIncome;
  final double totalAllocated;
  final double totalSpent;
  final double totalAvailable;
  final double unallocated;
  final bool isBalanced;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalAllocated: (json['total_allocated'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0.0,
      totalAvailable: (json['total_available'] as num?)?.toDouble() ?? 0.0,
      unallocated: (json['unallocated'] as num?)?.toDouble() ?? 0.0,
      isBalanced: json['is_balanced'] as bool? ?? false,
    );
  }
}

class DashboardCategory {
  const DashboardCategory({
    required this.id,
    required this.categoryId,
    required this.name,
    this.icon = 'category',
    this.colorHex = '#79ADDC',
    this.allocatedAmount = 0.0,
    this.spentAmount = 0.0,
    this.availableAmount = 0.0,
    this.spentPercentage = 0.0,
  });

  final String id;
  final String categoryId;
  final String name;
  final String icon;
  final String colorHex;
  final double allocatedAmount;
  final double spentAmount;
  final double availableAmount;
  final double spentPercentage;

  double get progressRatio {
    if (allocatedAmount <= 0) return 0.0;
    return spentAmount / allocatedAmount;
  }

  factory DashboardCategory.fromJson(Map<String, dynamic> json) {
    // Si viene anidado en 'categories'
    final catMap = json['categories'] as Map<String, dynamic>?;

    return DashboardCategory(
      id: json['id'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? catMap?['id'] as String? ?? '',
      name: json['name'] as String? ?? catMap?['name'] as String? ?? 'Categoría',
      icon: json['icon'] as String? ?? catMap?['icon'] as String? ?? 'category',
      colorHex: json['color_hex'] as String? ?? catMap?['color_hex'] as String? ?? '#79ADDC',
      allocatedAmount: (json['allocated_amount'] as num?)?.toDouble() ?? 0.0,
      spentAmount: (json['spent_amount'] as num?)?.toDouble() ?? 0.0,
      availableAmount: (json['available_amount'] as num?)?.toDouble() ?? 0.0,
      spentPercentage: (json['spent_percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class SuggestedPeriod {
  const SuggestedPeriod({
    required this.year,
    required this.month,
    required this.period,
    required this.startDate,
    required this.endDate,
  });

  final int year;
  final int month;
  final String period;
  final String startDate;
  final String endDate;

  factory SuggestedPeriod.fromJson(Map<String, dynamic> json) {
    return SuggestedPeriod(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      period: json['period'] as String? ?? 'first_half',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.hasActiveCycle,
    this.cycle,
    this.summary = const DashboardSummary(),
    this.categories = const [],
    this.suggestedPeriod,
  });

  final bool hasActiveCycle;
  final DashboardCycle? cycle;
  final DashboardSummary summary;
  final List<DashboardCategory> categories;
  final SuggestedPeriod? suggestedPeriod;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final hasActiveCycle = json['has_active_cycle'] as bool? ?? (json['cycle'] != null);
    final cycleMap = json['cycle'] as Map<String, dynamic>?;
    final summaryMap = json['summary'] as Map<String, dynamic>? ?? {};
    final catList = (json['categories'] as List<dynamic>?) ?? (json['allocations'] as List<dynamic>?) ?? [];
    final suggestedMap = json['suggested_period'] as Map<String, dynamic>?;

    return DashboardData(
      hasActiveCycle: hasActiveCycle,
      cycle: cycleMap != null ? DashboardCycle.fromJson(cycleMap) : null,
      summary: DashboardSummary.fromJson(summaryMap),
      categories: catList
          .map((item) => DashboardCategory.fromJson(item as Map<String, dynamic>))
          .toList(),
      suggestedPeriod: suggestedMap != null ? SuggestedPeriod.fromJson(suggestedMap) : null,
    );
  }
}
