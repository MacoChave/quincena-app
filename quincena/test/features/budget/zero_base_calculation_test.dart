import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/features/budget/data/models/models.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';

void main() {
  group('Zero-Based Budget Calculation Tests (RF-03 / R1)', () {
    test('Calculates positive unallocated (surplus) correctly', () {
      const summary = AllocationsSummary(
        totalIncome: 3000.0,
        totalAllocated: 2500.0,
        unallocated: 500.0,
      );

      expect(summary.totalIncome, 3000.0);
      expect(summary.totalAllocated, 2500.0);
      expect(summary.unallocated, 500.0);
      expect(summary.hasSurplus, isTrue);
      expect(summary.isBaseZero, isFalse);
      expect(summary.hasDeficit, isFalse);
    });

    test('Detects exact Base Cero (\$0.00) condition', () {
      const summary = AllocationsSummary(
        totalIncome: 2500.0,
        totalAllocated: 2500.0,
        unallocated: 0.0,
        isBalanced: true,
      );

      expect(summary.unallocated, 0.0);
      expect(summary.isBaseZero, isTrue);
      expect(summary.hasSurplus, isFalse);
      expect(summary.hasDeficit, isFalse);
    });

    test('Detects negative unallocated (deficit / over-allocated)', () {
      const summary = AllocationsSummary(
        totalIncome: 2000.0,
        totalAllocated: 2400.0,
        unallocated: -400.0,
      );

      expect(summary.unallocated, -400.0);
      expect(summary.hasDeficit, isTrue);
      expect(summary.isBaseZero, isFalse);
      expect(summary.hasSurplus, isFalse);
    });

    test('Deserializes AllocationsSummary from API JSON correctly', () {
      final json = {
        'total_income': 5000.0,
        'total_allocated': 4200.0,
        'unallocated': 800.0,
        'total_spent': 1500.0,
        'total_available': 2700.0,
        'is_balanced': false,
        'is_closed': false,
      };

      final summary = AllocationsSummary.fromJson(json);

      expect(summary.totalIncome, 5000.0);
      expect(summary.totalAllocated, 4200.0);
      expect(summary.unallocated, 800.0);
      expect(summary.totalSpent, 1500.0);
      expect(summary.totalAvailable, 2700.0);
      expect(summary.isBalanced, isFalse);
      expect(summary.isClosed, isFalse);
      expect(summary.hasSurplus, isTrue);
    });
  });

  group('Funding Account Grouping Tests (RF-03 / R1)', () {
    const acc1 = FinancialAccount(
      id: 'acc-1',
      name: 'Monetaria BI',
      accountType: AccountType.checking,
      currency: 'GTQ',
      colorHex: '#79ADDC',
      icon: 'account_balance',
      isDefault: true,
      isArchived: false,
      initialBalance: 2000.0,
      currentBalance: 1500.0,
    );

    const acc2 = FinancialAccount(
      id: 'acc-2',
      name: 'Billetera BAC',
      accountType: AccountType.savings,
      currency: 'GTQ',
      colorHex: '#ADF7B6',
      icon: 'savings',
      isDefault: false,
      isArchived: false,
      initialBalance: 500.0,
      currentBalance: 300.0,
    );

    test('Groups allocations by destination account and calculates required funding', () {
      final allocations = [
        const BudgetAllocation(
          id: 'a1',
          cycleId: 'cycle-1',
          categoryId: 'cat-1',
          destinationAccountId: 'acc-1',
          allocatedAmount: 1000.0,
          spentAmount: 200.0,
          destinationAccount: acc1,
        ),
        const BudgetAllocation(
          id: 'a2',
          cycleId: 'cycle-1',
          categoryId: 'cat-2',
          destinationAccountId: 'acc-1',
          allocatedAmount: 300.0,
          spentAmount: 50.0,
          destinationAccount: acc1,
        ),
        const BudgetAllocation(
          id: 'a3',
          cycleId: 'cycle-1',
          categoryId: 'cat-3',
          destinationAccountId: 'acc-2',
          allocatedAmount: 400.0,
          spentAmount: 0.0,
          destinationAccount: acc2,
        ),
        const BudgetAllocation(
          id: 'a4',
          cycleId: 'cycle-1',
          categoryId: 'cat-4',
          destinationAccountId: null, // Sin cuenta asignada
          allocatedAmount: 250.0,
          spentAmount: 100.0,
        ),
      ];

      final groups = FundingAccountSummary.groupFromAllocations(
        allocations: allocations,
        knownAccounts: [acc1, acc2],
      );

      expect(groups.length, 3);

      // Primer grupo: Monetaria BI (total 1300.0)
      final biGroup = groups.firstWhere((g) => g.account?.id == 'acc-1');
      expect(biGroup.totalAllocated, 1300.0);
      expect(biGroup.allocations.length, 2);
      expect(biGroup.currentBalance, 1500.0);
      expect(biGroup.isCovered, isTrue);
      expect(biGroup.shortage, 0.0);

      // Segundo grupo: Billetera BAC (total 400.0, balance 300.0 -> shortage 100.0)
      final bacGroup = groups.firstWhere((g) => g.account?.id == 'acc-2');
      expect(bacGroup.totalAllocated, 400.0);
      expect(bacGroup.allocations.length, 1);
      expect(bacGroup.currentBalance, 300.0);
      expect(bacGroup.isCovered, isFalse);
      expect(bacGroup.shortage, 100.0);

      // Tercer grupo: Sin cuenta asignada (total 250.0)
      final unassignedGroup = groups.firstWhere((g) => g.account == null);
      expect(unassignedGroup.totalAllocated, 250.0);
      expect(unassignedGroup.allocations.length, 1);
      expect(unassignedGroup.displayName, 'Sin cuenta asignada / Efectivo');
    });

    test('Calculates available amount and progress ratio on BudgetAllocation', () {
      const alloc = BudgetAllocation(
        id: 'a1',
        cycleId: 'c1',
        categoryId: 'cat1',
        allocatedAmount: 500.0,
        spentAmount: 250.0,
      );

      expect(alloc.computedAvailable, 250.0);
      expect(alloc.computedPercentage, 50.0);
      expect(alloc.progressRatio, 0.5);
    });
  });
}
