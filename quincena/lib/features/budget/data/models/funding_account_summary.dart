import 'package:flutter/material.dart';
import '../../../financial_accounts/models/financial_account.dart';
import 'budget_allocation.dart';

/// Resumen agrupado por cuenta financiera de fondeo (RF-03 / R1)
/// Permite al usuario conocer cuánto saldo debe fondear o transferir a cada cuenta.
class FundingAccountSummary {
  const FundingAccountSummary({
    this.account,
    required this.totalAllocated,
    this.allocations = const [],
  });

  /// Cuenta financiera destino. `null` indica "Sin cuenta asignada / Efectivo general".
  final FinancialAccount? account;

  /// Monto total asignado a fondear en esta cuenta durante la quincena
  final double totalAllocated;

  /// Partidas que componen este fondeo
  final List<BudgetAllocation> allocations;

  /// Nombre para mostrar
  String get displayName => account?.name ?? 'Sin cuenta asignada / Efectivo';

  /// Icono de la cuenta o billetera por defecto
  IconData get displayIcon =>
      account?.displayIcon ?? Icons.account_balance_wallet_outlined;

  /// Color distintivo de la cuenta
  Color get parsedColor => account?.parsedColor ?? const Color(0xFF79ADDC);

  /// Saldo actual registrado en la cuenta
  double get currentBalance => account?.currentBalance ?? 0.0;

  /// Indica si el saldo actual cubre el total presupuestado a fondear
  bool get isCovered => currentBalance >= totalAllocated;

  /// Monto faltante por transferir si currentBalance < totalAllocated
  double get shortage => isCovered ? 0.0 : (totalAllocated - currentBalance);

  /// Agrupa una lista de asignaciones por cuenta financiera destino
  static List<FundingAccountSummary> groupFromAllocations({
    required List<BudgetAllocation> allocations,
    List<FinancialAccount> knownAccounts = const [],
  }) {
    // Mapa id -> account
    final accountMap = <String, FinancialAccount>{};
    for (final acc in knownAccounts) {
      accountMap[acc.id] = acc;
    }

    // Agrupar partidas por destinationAccountId (puede ser null)
    final groupedAllocations = <String?, List<BudgetAllocation>>{};
    for (final alloc in allocations) {
      final key = alloc.destinationAccountId;
      groupedAllocations.putIfAbsent(key, () => []).add(alloc);
    }

    final result = <FundingAccountSummary>[];

    // Primero las cuentas que tienen asignaciones
    for (final entry in groupedAllocations.entries) {
      final accId = entry.key;
      final allocs = entry.value;
      final total = allocs.fold<double>(0.0, (sum, a) => sum + a.allocatedAmount);

      FinancialAccount? targetAccount;
      if (accId != null) {
        targetAccount = accountMap[accId] ??
            allocs.firstWhere((a) => a.destinationAccount != null, orElse: () => allocs.first).destinationAccount;
      }

      result.add(
        FundingAccountSummary(
          account: targetAccount,
          totalAllocated: total,
          allocations: allocs,
        ),
      );
    }

    // Ordenar: primero cuentas con mayor monto a fondear, y "Sin cuenta" al final
    result.sort((a, b) {
      if (a.account == null) return 1;
      if (b.account == null) return -1;
      return b.totalAllocated.compareTo(a.totalAllocated);
    });

    return result;
  }
}
