import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/core/components/badges/app_progress_bar.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/models.dart';
import 'package:quincena/features/budget/presentation/widgets/zero_base_header_card.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';

void main() {
  group('Adversarial Zero-Base Math: Floating Point & Cent Rounding', () {
    test('3-way split: \$333.33 + \$333.33 + \$333.34 = \$1,000.00 exact base zero', () {
      final allocs = [
        const BudgetAllocation(id: '1', cycleId: 'c', categoryId: '1', allocatedAmount: 333.33),
        const BudgetAllocation(id: '2', cycleId: 'c', categoryId: '2', allocatedAmount: 333.33),
        const BudgetAllocation(id: '3', cycleId: 'c', categoryId: '3', allocatedAmount: 333.34),
      ];

      final totalAllocated = allocs.fold<double>(0.0, (sum, a) => sum + a.allocatedAmount);
      const totalIncome = 1000.0;
      final unallocated = totalIncome - totalAllocated;

      final summary = AllocationsSummary(
        totalIncome: totalIncome,
        totalAllocated: totalAllocated,
        unallocated: unallocated,
        isBalanced: unallocated.abs() < 0.01,
      );

      expect(summary.totalAllocated, 1000.0);
      expect(summary.unallocated, 0.0);
      expect(summary.isBaseZero, isTrue);
      expect(summary.hasSurplus, isFalse);
      expect(summary.hasDeficit, isFalse);
      expect(formatMoney(summary.unallocated), '\$0.00');
    });

    test('IEEE-754 precision: sum of 0.1, 0.2, 0.3 against 0.6 income handles float drift', () {
      final allocs = [
        const BudgetAllocation(id: '1', cycleId: 'c', categoryId: '1', allocatedAmount: 0.1),
        const BudgetAllocation(id: '2', cycleId: 'c', categoryId: '2', allocatedAmount: 0.2),
        const BudgetAllocation(id: '3', cycleId: 'c', categoryId: '3', allocatedAmount: 0.3),
      ];

      final totalAllocated = allocs.fold<double>(0.0, (sum, a) => sum + a.allocatedAmount);
      const totalIncome = 0.6;
      final unallocated = totalIncome - totalAllocated;

      final summary = AllocationsSummary(
        totalIncome: totalIncome,
        totalAllocated: totalAllocated,
        unallocated: unallocated,
        isBalanced: unallocated.abs() < 0.01,
      );

      // TotalAllocated in IEEE-754 is 0.6000000000000001
      // unallocated is -1.1102230246251565e-16
      expect(summary.isBaseZero, isTrue);
      expect(summary.hasSurplus, isFalse);
      expect(summary.hasDeficit, isFalse);
      // formatMoney must not output negative zero '-$0.00'
      expect(formatMoney(summary.unallocated), '\$0.00');
    });

    test('7-way division: 7 * \$14.28 + \$0.04 = \$100.00 exact base zero', () {
      final allocs = [
        for (int i = 0; i < 7; i++)
          BudgetAllocation(id: '$i', cycleId: 'c', categoryId: 'cat_$i', allocatedAmount: 14.28),
        const BudgetAllocation(id: '7', cycleId: 'c', categoryId: 'cat_7', allocatedAmount: 0.04),
      ];

      final totalAllocated = allocs.fold<double>(0.0, (sum, a) => sum + a.allocatedAmount);
      const totalIncome = 100.0;
      final unallocated = totalIncome - totalAllocated;

      final summary = AllocationsSummary(
        totalIncome: totalIncome,
        totalAllocated: totalAllocated,
        unallocated: unallocated,
        isBalanced: unallocated.abs() < 0.01,
      );

      expect(summary.isBaseZero, isTrue);
      expect(summary.hasSurplus, isFalse);
      expect(summary.hasDeficit, isFalse);
    });

    test('Threshold boundaries: \$0.0099 surplus vs \$0.01 surplus', () {
      const subCentSummary = AllocationsSummary(
        totalIncome: 100.0,
        totalAllocated: 99.991,
        unallocated: 0.009,
      );
      // Below 0.01 threshold, treated as Base Zero
      expect(subCentSummary.isBaseZero, isTrue);
      expect(subCentSummary.hasSurplus, isFalse);

      const centSummary = AllocationsSummary(
        totalIncome: 100.0,
        totalAllocated: 99.99,
        unallocated: 0.01,
      );
      expect(centSummary.isBaseZero, isFalse);
      expect(centSummary.hasSurplus, isTrue);
      expect(centSummary.hasDeficit, isFalse);
    });

    test('Threshold boundaries: -\$0.009 deficit vs -\$0.01 deficit', () {
      const subCentDeficit = AllocationsSummary(
        totalIncome: 100.0,
        totalAllocated: 100.009,
        unallocated: -0.009,
      );
      // Below 0.01 absolute, considered Base Zero
      expect(subCentDeficit.isBaseZero, isTrue);
      expect(subCentDeficit.hasDeficit, isFalse);

      const centDeficit = AllocationsSummary(
        totalIncome: 100.0,
        totalAllocated: 100.01,
        unallocated: -0.01,
      );
      expect(centDeficit.isBaseZero, isFalse);
      expect(centDeficit.hasDeficit, isTrue);
      expect(centDeficit.hasSurplus, isFalse);
    });
  });

  group('Adversarial Boundary Conditions', () {
    test('Zero income (0.00) and zero allocation (0.00) is valid Base Zero', () {
      const summary = AllocationsSummary(
        totalIncome: 0.0,
        totalAllocated: 0.0,
        unallocated: 0.0,
        isBalanced: true,
      );

      expect(summary.isBaseZero, isTrue);
      expect(summary.hasSurplus, isFalse);
      expect(summary.hasDeficit, isFalse);
      expect(formatMoney(summary.unallocated), '\$0.00');
    });

    test('Zero income (0.00) with any positive allocation is Deficit', () {
      const summary = AllocationsSummary(
        totalIncome: 0.0,
        totalAllocated: 0.01,
        unallocated: -0.01,
      );

      expect(summary.hasDeficit, isTrue);
      expect(summary.isBaseZero, isFalse);
      expect(formatMoney(summary.unallocated), '-\$0.01');
    });

    test('Holding allocation with allocatedAmount == 0.0 does not affect unallocated', () {
      const alloc = BudgetAllocation(
        id: 'hold-1',
        cycleId: 'c1',
        categoryId: 'cat-zero',
        allocatedAmount: 0.0,
        spentAmount: 0.0,
      );

      expect(alloc.computedAvailable, 0.0);
      expect(alloc.computedPercentage, 0.0);
      expect(alloc.progressRatio, 0.0);
    });

    test('Holding allocation with allocatedAmount == 0.0 and spentAmount > 0.0 handles zero-division gracefully', () {
      const alloc = BudgetAllocation(
        id: 'hold-2',
        cycleId: 'c1',
        categoryId: 'cat-zero',
        allocatedAmount: 0.0,
        spentAmount: 75.0,
      );

      expect(alloc.computedAvailable, -75.0);
      expect(alloc.computedPercentage, 0.0); // Guards against division by zero
      expect(alloc.progressRatio, 0.0); // Clamped without NaN or infinity
    });
  });

  group('Extreme Surplus & Extreme Deficit Conditions', () {
    test('Extreme surplus: \$10,000.00 income, \$100.00 allocated', () {
      const summary = AllocationsSummary(
        totalIncome: 10000.0,
        totalAllocated: 100.0,
        unallocated: 9900.0,
      );

      expect(summary.hasSurplus, isTrue);
      expect(summary.isBaseZero, isFalse);
      expect(summary.hasDeficit, isFalse);
      expect(formatMoney(summary.unallocated), '\$9,900.00');
    });

    test('Extreme deficit: \$1,000.00 income, \$10,000.00 allocated', () {
      const summary = AllocationsSummary(
        totalIncome: 1000.0,
        totalAllocated: 10000.0,
        unallocated: -9000.0,
      );

      expect(summary.hasDeficit, isTrue);
      expect(summary.isBaseZero, isFalse);
      expect(summary.hasSurplus, isFalse);
      expect(formatMoney(summary.unallocated), '-\$9,000.00');
    });

    test('Mega numbers: \$10,000,000.00 with multi-comma formatting', () {
      expect(formatMoney(10000000.0), '\$10,000,000.00');
      expect(formatMoney(-10000000.0), '-\$10,000,000.00');
      expect(formatMoney(999999999.99), '\$999,999,999.99');
    });
  });

  group('Scale & Stress: Large List of Allocations (50+ Items)', () {
    test('50 allocations of \$20.00 accurately balance \$1,000.00 income', () {
      final allocs = List.generate(
        50,
        (i) => BudgetAllocation(
          id: 'alloc-$i',
          cycleId: 'cycle-stress',
          categoryId: 'cat-$i',
          allocatedAmount: 20.0,
        ),
      );

      final totalAllocated = allocs.fold<double>(0.0, (sum, a) => sum + a.allocatedAmount);
      const totalIncome = 1000.0;
      final unallocated = totalIncome - totalAllocated;

      final summary = AllocationsSummary(
        totalIncome: totalIncome,
        totalAllocated: totalAllocated,
        unallocated: unallocated,
        isBalanced: unallocated.abs() < 0.01,
      );

      expect(summary.totalAllocated, 1000.0);
      expect(summary.unallocated, 0.0);
      expect(summary.isBaseZero, isTrue);
    });

    test('100 allocations of \$19.99 accurately balance \$1,999.00 income', () {
      final allocs = List.generate(
        100,
        (i) => BudgetAllocation(
          id: 'alloc-$i',
          cycleId: 'cycle-stress',
          categoryId: 'cat-$i',
          allocatedAmount: 19.99,
        ),
      );

      final totalAllocated = allocs.fold<double>(0.0, (sum, a) => sum + a.allocatedAmount);
      const totalIncome = 1999.0;
      final unallocated = totalIncome - totalAllocated;

      final summary = AllocationsSummary(
        totalIncome: totalIncome,
        totalAllocated: totalAllocated,
        unallocated: unallocated,
        isBalanced: unallocated.abs() < 0.01,
      );

      // In double math, 100 * 19.99 = 1999.0000000000005
      expect(summary.isBaseZero, isTrue);
      expect(summary.hasSurplus, isFalse);
      expect(summary.hasDeficit, isFalse);
    });
  });

  group('Funding Account Grouping: Complex Edge Scenarios', () {
    const accA = FinancialAccount(
      id: 'acc-A',
      name: 'Banco A',
      accountType: AccountType.checking,
      currency: 'GTQ',
      colorHex: '#79ADDC',
      icon: 'account_balance',
      isDefault: true,
      isArchived: false,
      currentBalance: 500.0,
      initialBalance: 500.0,
    );

    const accB = FinancialAccount(
      id: 'acc-B',
      name: 'Banco B',
      accountType: AccountType.savings,
      currency: 'GTQ',
      colorHex: '#ADF7B6',
      icon: 'savings',
      isDefault: false,
      isArchived: false,
      currentBalance: 2000.0,
      initialBalance: 2000.0,
    );

    test('All allocations have null destination account (All unassigned)', () {
      final allocs = List.generate(
        5,
        (i) => BudgetAllocation(
          id: 'a$i',
          cycleId: 'c1',
          categoryId: 'cat$i',
          destinationAccountId: null,
          allocatedAmount: 100.0,
        ),
      );

      final groups = FundingAccountSummary.groupFromAllocations(
        allocations: allocs,
        knownAccounts: [accA, accB],
      );

      expect(groups.length, 1);
      expect(groups.first.account, isNull);
      expect(groups.first.displayName, 'Sin cuenta asignada / Efectivo');
      expect(groups.first.totalAllocated, 500.0);
      expect(groups.first.allocations.length, 5);
    });

    test('Single destination account used for all allocations', () {
      final allocs = List.generate(
        8,
        (i) => BudgetAllocation(
          id: 'a$i',
          cycleId: 'c1',
          categoryId: 'cat$i',
          destinationAccountId: 'acc-A',
          allocatedAmount: 50.0,
          destinationAccount: accA,
        ),
      );

      final groups = FundingAccountSummary.groupFromAllocations(
        allocations: allocs,
        knownAccounts: [accA, accB],
      );

      expect(groups.length, 1);
      expect(groups.first.account?.id, 'acc-A');
      expect(groups.first.totalAllocated, 400.0);
      expect(groups.first.isCovered, isTrue); // balance 500 >= 400
      expect(groups.first.shortage, 0.0);
    });

    test('Multiple accounts + null accounts sorting order (descending totalAllocated with unassigned strictly at end)', () {
      final allocs = [
        // accA total = 200
        const BudgetAllocation(id: '1', cycleId: 'c', categoryId: '1', destinationAccountId: 'acc-A', allocatedAmount: 200.0),
        // accB total = 800
        const BudgetAllocation(id: '2', cycleId: 'c', categoryId: '2', destinationAccountId: 'acc-B', allocatedAmount: 500.0),
        const BudgetAllocation(id: '3', cycleId: 'c', categoryId: '3', destinationAccountId: 'acc-B', allocatedAmount: 300.0),
        // null total = 1000 (even though larger than accB, null account must be sorted to the very end)
        const BudgetAllocation(id: '4', cycleId: 'c', categoryId: '4', destinationAccountId: null, allocatedAmount: 1000.0),
      ];

      final groups = FundingAccountSummary.groupFromAllocations(
        allocations: allocs,
        knownAccounts: [accA, accB],
      );

      expect(groups.length, 3);
      // 1st: accB with 800
      expect(groups[0].account?.id, 'acc-B');
      expect(groups[0].totalAllocated, 800.0);
      // 2nd: accA with 200
      expect(groups[1].account?.id, 'acc-A');
      expect(groups[1].totalAllocated, 200.0);
      // 3rd: unassigned with 1000 at the end
      expect(groups[2].account, isNull);
      expect(groups[2].totalAllocated, 1000.0);
    });

    test('Orphaned account ID: destinationAccountId not in knownAccounts and no joined account', () {
      const alloc = BudgetAllocation(
        id: 'orphan-1',
        cycleId: 'c1',
        categoryId: 'cat-1',
        destinationAccountId: 'deleted-acc-id',
        allocatedAmount: 350.0,
      );

      final groups = FundingAccountSummary.groupFromAllocations(
        allocations: [alloc],
        knownAccounts: [accA, accB],
      );

      expect(groups.length, 1);
      expect(groups.first.account, isNull);
      expect(groups.first.totalAllocated, 350.0);
      expect(groups.first.displayName, 'Sin cuenta asignada / Efectivo');
    });

    test('Empty allocations returns empty groups list', () {
      final groups = FundingAccountSummary.groupFromAllocations(
        allocations: [],
        knownAccounts: [accA, accB],
      );
      expect(groups, isEmpty);
    });
  });

  group('Progress Bar Thresholds & Semaphorization (Widget Tests)', () {
    Future<Color> getBarColor(WidgetTester tester, double progress) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: AppProgressBar(progress: progress),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animatedContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = animatedContainer.decoration as BoxDecoration;
      return decoration.color!;
    }

    testWidgets('Progress < 70% resolves to AppColors.primary (#79ADDC)', (tester) async {
      final colorZero = await getBarColor(tester, 0.0);
      expect(colorZero, AppColors.primary);

      final colorMid = await getBarColor(tester, 0.50);
      expect(colorMid, AppColors.primary);

      final colorNear = await getBarColor(tester, 0.699);
      expect(colorNear, AppColors.primary);
    });

    testWidgets('Progress exactly 70% resolves to AppColors.warningBg (#FFEE93)', (tester) async {
      final color70 = await getBarColor(tester, 0.70);
      expect(color70, AppColors.warningBg);
    });

    testWidgets('Progress between 70% and 89.9% resolves to AppColors.warningBg (#FFEE93)', (tester) async {
      final color80 = await getBarColor(tester, 0.80);
      expect(color80, AppColors.warningBg);

      final colorNear90 = await getBarColor(tester, 0.899);
      expect(colorNear90, AppColors.warningBg);
    });

    testWidgets('Progress exactly 90% resolves to AppColors.expenseBg (#FFC09F)', (tester) async {
      final color90 = await getBarColor(tester, 0.90);
      expect(color90, AppColors.expenseBg);
    });

    testWidgets('Progress at 100% and over-budget (150%) resolves to AppColors.expenseBg (#FFC09F)', (tester) async {
      final color100 = await getBarColor(tester, 1.00);
      expect(color100, AppColors.expenseBg);

      final color150 = await getBarColor(tester, 1.50);
      expect(color150, AppColors.expenseBg);
    });

    test('BudgetAllocation progressRatio clamps correctly without overflowing width', () {
      const normal = BudgetAllocation(
        id: '1', cycleId: 'c', categoryId: '1',
        allocatedAmount: 100.0, spentAmount: 60.0,
      );
      expect(normal.progressRatio, 0.6);

      const overBudget = BudgetAllocation(
        id: '2', cycleId: 'c', categoryId: '2',
        allocatedAmount: 100.0, spentAmount: 180.0,
      );
      // Ratio clamped to 1.0 for progress bar drawing
      expect(overBudget.progressRatio, 1.0);
      // Computed percentage preserves real value (180.0%)
      expect(overBudget.computedPercentage, 180.0);

      const negativeSpent = BudgetAllocation(
        id: '3', cycleId: 'c', categoryId: '3',
        allocatedAmount: 100.0, spentAmount: -20.0,
      );
      // Negative spent (refund) clamped to 0.0
      expect(negativeSpent.progressRatio, 0.0);
    });
  });
}
