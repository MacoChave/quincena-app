import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/network/api_exception.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/budget_allocation.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/data/services/budget_api_service.dart';
import 'package:quincena/features/budget/presentation/notifiers/budget_notifier.dart';
import 'package:quincena/features/dashboard/data/dashboard_api_service.dart';
import 'package:quincena/features/dashboard/presentation/home_screen.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'package:quincena/features/transactions/presentation/manual/manual_expense_form_sheet.dart';
import 'transaction_test_doubles.dart';

/// Fake HTTP client for Dashboard that supports dynamic balance updating
class DynamicDashboardHttpClient extends http.BaseClient {
  DynamicDashboardHttpClient({
    this.totalIncome = 3000.0,
    this.totalAllocated = 2500.0,
    this.totalSpent = 500.0,
  });

  double totalIncome;
  double totalAllocated;
  double totalSpent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final available = totalAllocated - totalSpent;
    final body = jsonEncode({
      'has_active_cycle': true,
      'cycle': {
        'id': 'cycle-dyn-1',
        'year': 2026,
        'month': 10,
        'period': 'first_half',
        'start_date': '2026-10-01',
        'end_date': '2026-10-15',
        'total_income': totalIncome,
        'is_closed': false,
      },
      'summary': {
        'total_income': totalIncome,
        'total_allocated': totalAllocated,
        'total_spent': totalSpent,
        'total_available': available,
        'unallocated': totalIncome - totalAllocated,
        'is_balanced': (totalIncome - totalAllocated).abs() < 0.01,
      },
      'metrics': {
        'total_income': totalIncome,
        'total_allocated': totalAllocated,
        'total_spent': totalSpent,
        'total_available': available,
        'unallocated': totalIncome - totalAllocated,
        'is_balanced': (totalIncome - totalAllocated).abs() < 0.01,
      },
      'categories': [
        {
          'id': 'alloc-dyn-1',
          'category_id': 'cat-super',
          'name': 'Supermercado',
          'icon': 'shopping_cart',
          'color_hex': '#79ADDC',
          'allocated_amount': 1000.0,
          'spent_amount': totalSpent,
          'available_amount': 1000.0 - totalSpent,
          'spent_percentage': (totalSpent / 1000.0) * 100,
        }
      ],
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  final testCategories = [
    const Category(
      id: 'cat-super',
      name: 'Supermercado',
      icon: 'shopping_cart',
      colorHex: '#ADF7B6',
      defaultAccountId: 'acc-deb',
    ),
    const Category(
      id: 'cat-ocio',
      name: 'Ocio & Café',
      icon: 'local_cafe',
      colorHex: '#FFEE93',
      defaultAccountId: 'acc-cash',
    ),
  ];

  final testAccounts = [
    const FinancialAccount(
      id: 'acc-deb',
      name: 'Tarjeta Débito BAC',
      accountType: AccountType.checking,
      currency: 'GTQ',
      colorHex: '#79ADDC',
      icon: 'account_balance',
      isDefault: true,
      isArchived: false,
      initialBalance: 2000.0,
      currentBalance: 1500.0,
    ),
    const FinancialAccount(
      id: 'acc-cash',
      name: 'Efectivo Billetera',
      accountType: AccountType.cash,
      currency: 'GTQ',
      colorHex: '#ADF7B6',
      icon: 'payments',
      isDefault: false,
      isArchived: false,
      initialBalance: 300.0,
      currentBalance: 300.0,
    ),
  ];

  group('Adversarial Challenge 1: Duplicate Detection Interception & Bypass Flows (RN-03)', () {
    testWidgets('1.1 Full integration: 409 Conflict triggers DuplicateWarningDialog with conflicting expense details',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-adv-1',
        initialTransactions: [
          {
            'id': 'tx-prior-1',
            'user_id': 'u1',
            'cycle_id': 'cycle-adv-1',
            'source_account_id': 'acc-deb',
            'amount': 45.00,
            'merchant_name': 'Café Barista',
            'transaction_date': '2026-10-18',
          }
        ],
      );
      final apiClient = ApiClient(httpClient: mockHttp);
      final transactionApiService = TransactionApiService(apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-adv-1',
              transactionApiService: transactionApiService,
              categories: testCategories,
              accounts: testAccounts,
              initialCategoryId: 'cat-ocio',
              initialAccountId: 'acc-cash',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter duplicate data
      await tester.enterText(find.byKey(const Key('manual_amount_input')), '45.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Café Barista');
      await tester.pump();

      // Save expense -> triggers POST /transactions
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pumpAndSettle();

      // Verify DuplicateWarningDialog is presented
      expect(find.byKey(const Key('duplicate_warning_dialog')), findsOneWidget);
      expect(find.text('REGLA RN-03'), findsOneWidget);
      expect(find.text('Posible Gasto Duplicado'), findsOneWidget);
      expect(find.text('Café Barista'), findsAtLeastNWidgets(1));
      expect(find.text('\$45.00'), findsOneWidget);
      expect(find.byKey(const Key('btn_cancel_duplicate')), findsOneWidget);
      expect(find.byKey(const Key('btn_force_duplicate')), findsOneWidget);
      expect(mockHttp.duplicateWarningHits, 1);
    });

    testWidgets('1.2 User selects Cancel: dialog dismisses, manual form remains open with all user inputs intact, and 0 transactions created',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-adv-1',
        initialTransactions: [
          {
            'id': 'tx-prior-1',
            'user_id': 'u1',
            'cycle_id': 'cycle-adv-1',
            'source_account_id': 'acc-deb',
            'amount': 45.00,
            'merchant_name': 'Café Barista',
            'transaction_date': '2026-10-18',
          }
        ],
      );
      final apiClient = ApiClient(httpClient: mockHttp);
      final transactionApiService = TransactionApiService(apiClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-adv-1',
              transactionApiService: transactionApiService,
              categories: testCategories,
              accounts: testAccounts,
              initialCategoryId: 'cat-ocio',
              initialAccountId: 'acc-cash',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '45.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Café Barista');
      await tester.enterText(find.byKey(const Key('manual_notes_input')), 'Reunión con cliente');
      await tester.pump();

      // Submit
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('duplicate_warning_dialog')), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const Key('btn_cancel_duplicate')));
      await tester.pumpAndSettle();

      // 1. Dialog is dismissed
      expect(find.byKey(const Key('duplicate_warning_dialog')), findsNothing);

      // 2. Manual form is STILL OPEN and visible
      expect(find.text('Nuevo Gasto Manual'), findsOneWidget);

      // 3. User data remains 100% intact
      final amountField = tester.widget<TextField>(find.byKey(const Key('manual_amount_input')));
      final merchantField = tester.widget<TextField>(find.byKey(const Key('manual_merchant_input')));
      final notesField = tester.widget<TextField>(find.byKey(const Key('manual_notes_input')));
      expect(amountField.controller?.text, '45.00');
      expect(merchantField.controller?.text, 'Café Barista');
      expect(notesField.controller?.text, 'Reunión con cliente');

      // 4. Zero new transactions created in database (length remains 1)
      expect(mockHttp.transactionsDb.length, 1);
    });

    testWidgets('1.3 User selects Registrar de todas formas: issues POST /transactions?force=true, persists transaction, and closes modal',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-adv-1',
        initialTransactions: [
          {
            'id': 'tx-prior-1',
            'user_id': 'u1',
            'cycle_id': 'cycle-adv-1',
            'source_account_id': 'acc-deb',
            'amount': 45.00,
            'merchant_name': 'Café Barista',
            'transaction_date': '2026-10-18',
          }
        ],
      );
      final apiClient = ApiClient(httpClient: mockHttp);
      final transactionApiService = TransactionApiService(apiClient);

      dynamic createdTx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  key: const Key('btn_open_modal'),
                  onPressed: () async {
                    createdTx = await ManualExpenseFormSheet.show(
                      context: ctx,
                      cycleId: 'cycle-adv-1',
                      transactionApiService: transactionApiService,
                      categories: testCategories,
                      accounts: testAccounts,
                      initialCategoryId: 'cat-ocio',
                      initialAccountId: 'acc-cash',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const Key('btn_open_modal')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '45.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Café Barista');
      await tester.pump();

      // Submit
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('duplicate_warning_dialog')), findsOneWidget);

      // Tap Registrar de todas formas
      await tester.tap(find.byKey(const Key('btn_force_duplicate')));
      await tester.pumpAndSettle();

      // 1. Force bypass parameter sent
      expect(mockHttp.forceBypassHits, 1);

      // 2. Database contains both transactions now
      expect(mockHttp.transactionsDb.length, 2);

      // 3. Modal closed and returned the created transaction
      expect(find.byKey(const Key('duplicate_warning_dialog')), findsNothing);
      expect(find.text('Nuevo Gasto Manual'), findsNothing);
      expect(createdTx, isNotNull);
      expect(createdTx?.amount, 45.00);
      expect(createdTx?.merchantName, 'Café Barista');
    });

    testWidgets('1.4 Multi-item duplicate rendering: displays list of all conflicting historical expenses',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final duplicatesList = [
        DuplicateTransactionItem(
          id: 'dup-101',
          merchantName: 'Supermercado Central',
          amount: 120.0,
          transactionDate: DateTime(2026, 10, 18, 9, 30),
        ),
        DuplicateTransactionItem(
          id: 'dup-102',
          merchantName: 'Supermercado Central',
          amount: 120.0,
          transactionDate: DateTime(2026, 10, 18, 14, 15),
        ),
        DuplicateTransactionItem(
          id: 'dup-103',
          merchantName: 'Supermercado Central',
          amount: 120.0,
          transactionDate: DateTime(2026, 10, 17, 18, 0),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DuplicateWarningDialog(
              existingTransactions: duplicatesList,
              merchantName: 'Supermercado Central',
              amount: 120.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('duplicate_item_dup-101')), findsOneWidget);
      expect(find.byKey(const Key('duplicate_item_dup-102')), findsOneWidget);
      expect(find.byKey(const Key('duplicate_item_dup-103')), findsOneWidget);
      expect(find.text('\$120.00'), findsNWidgets(3));
    });

    testWidgets('1.5 Error resilience during forced bypass: displays error message without crash or data loss',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int callCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-adv-err',
              categories: testCategories,
              accounts: testAccounts,
              initialCategoryId: 'cat-super',
              initialAccountId: 'acc-deb',
              onSave: (dto, {force = false}) async {
                callCount++;
                if (!force) {
                  throw DuplicateTransactionException(
                    message: 'Posible duplicado detectado',
                    existingTransactions: [
                      DuplicateTransactionItem(
                        id: 'dup-prior',
                        merchantName: 'Farmacia Galeno',
                        amount: 30.0,
                        transactionDate: DateTime(2026, 10, 18),
                      ),
                    ],
                  );
                } else {
                  // Simulate 500 error on forced retry
                  throw ApiException(
                    statusCode: 500,
                    message: 'Error interno del servidor al forzar registro.',
                  );
                }
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '30.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Farmacia Galeno');
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pumpAndSettle();

      // Tap Registrar de todas formas
      await tester.tap(find.byKey(const Key('btn_force_duplicate')));
      await tester.pumpAndSettle();

      expect(callCount, 2);
      // Dialog dismissed
      expect(find.byKey(const Key('duplicate_warning_dialog')), findsNothing);
      // Form displays error message
      expect(find.text('Error interno del servidor al forzar registro.'), findsOneWidget);
      // User entered text is STILL INTACT
      final amountField = tester.widget<TextField>(find.byKey(const Key('manual_amount_input')));
      expect(amountField.controller?.text, '30.00');
    });
  });

  group('Adversarial Challenge 2: Duplicate Detection Boundary Stress Testing (RN-03)', () {
    final baseDate = DateTime(2026, 10, 18, 12, 0, 0);
    final existingTxs = [
      Transaction(
        id: 'tx-base',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 88.50,
        merchantName: 'Tienda La Esperanza',
        transactionDate: baseDate,
      ),
    ];

    test('2.1 Exactly -24 hours boundary is flagged as duplicate', () {
      final minus24h = baseDate.subtract(const Duration(hours: 24)); // 2026-10-17 12:00:00
      final dups = DuplicateDetector.findDuplicates(
        existing: existingTxs,
        merchantName: 'Tienda La Esperanza',
        amount: 88.50,
        transactionDate: minus24h,
      );
      expect(dups, isNotEmpty);
    });

    test('2.2 -24 hours and 1 second is NOT flagged as duplicate', () {
      final minus24h1s = baseDate.subtract(const Duration(hours: 24, seconds: 1));
      final dups = DuplicateDetector.findDuplicates(
        existing: existingTxs,
        merchantName: 'Tienda La Esperanza',
        amount: 88.50,
        transactionDate: minus24h1s,
      );
      expect(dups, isEmpty);
    });

    test('2.3 Exactly +24 hours boundary is flagged as duplicate', () {
      final plus24h = baseDate.add(const Duration(hours: 24)); // 2026-10-19 12:00:00
      final dups = DuplicateDetector.findDuplicates(
        existing: existingTxs,
        merchantName: 'Tienda La Esperanza',
        amount: 88.50,
        transactionDate: plus24h,
      );
      expect(dups, isNotEmpty);
    });

    test('2.4 +24 hours and 1 second is NOT flagged as duplicate', () {
      final plus24h1s = baseDate.add(const Duration(hours: 24, seconds: 1));
      final dups = DuplicateDetector.findDuplicates(
        existing: existingTxs,
        merchantName: 'Tienda La Esperanza',
        amount: 88.50,
        transactionDate: plus24h1s,
      );
      expect(dups, isEmpty);
    });

    test('2.5 Whitespace padding and casing differences are normalized for duplicate detection', () {
      final dups = DuplicateDetector.findDuplicates(
        existing: existingTxs,
        merchantName: '   TIENDA LA ESPERANZA   ',
        amount: 88.50,
        transactionDate: baseDate,
      );
      expect(dups, isNotEmpty);
    });

    test('2.6 Floating point epsilon handles 88.5000000001 as duplicate', () {
      final dups = DuplicateDetector.findDuplicates(
        existing: existingTxs,
        merchantName: 'Tienda La Esperanza',
        amount: 88.5000001,
        transactionDate: baseDate,
      );
      expect(dups, isNotEmpty);
    });

    test('2.7 Difference above epsilon (88.51) is NOT duplicate', () {
      final dups = DuplicateDetector.findDuplicates(
        existing: existingTxs,
        merchantName: 'Tienda La Esperanza',
        amount: 88.51,
        transactionDate: baseDate,
      );
      expect(dups, isEmpty);
    });
  });

  group('Adversarial Challenge 3: Balance Synchronization Latency Benchmarks (<10ms & <100ms)', () {
    test('3.1 BudgetNotifier.deductExpense executes in <10ms across 1,000 runs', () {
      final mockBudgetApi = BudgetApiService(ApiClient());
      final notifier = BudgetNotifier(apiService: mockBudgetApi);

      // Benchmark 1,000 sequential deductExpense invocations
      final latenciesMs = <double>[];

      for (int i = 0; i < 1000; i++) {
        final sw = Stopwatch()..start();
        notifier.deductExpense(allocationId: 'alloc-${i % 15}', amount: 2.50);
        sw.stop();
        latenciesMs.add(sw.elapsedMicroseconds / 1000.0);
      }

      final maxLatency = latenciesMs.reduce((a, b) => a > b ? a : b);
      final avgLatency = latenciesMs.reduce((a, b) => a + b) / latenciesMs.length;

      // Assert SLA constraints:
      // Required SLA: < 10ms
      expect(maxLatency, lessThan(10.0), reason: 'Max latency was $maxLatency ms');
      expect(avgLatency, lessThan(1.0), reason: 'Average latency was $avgLatency ms');
    });

    test('3.2 ManualSyncService.deductFromAllocationsList executes in <10ms with 50 allocations', () {
      final allocations = List.generate(50, (i) {
        return BudgetAllocation(
          id: 'alloc-$i',
          cycleId: 'cycle-bench',
          categoryId: 'cat-$i',
          allocatedAmount: 2000.0,
          spentAmount: 300.0,
          availableAmount: 1700.0,
        );
      });

      final sw = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        ManualSyncService.deductFromAllocationsList(
          allocations: allocations,
          targetAllocationOrCategoryId: 'alloc-${i % 50}',
          expenseAmount: 15.0,
        );
      }
      sw.stop();

      final avgLatencyPerCall = (sw.elapsedMicroseconds / 1000.0) / 1000.0;
      expect(avgLatencyPerCall, lessThan(1.0));
      expect(sw.elapsedMilliseconds, lessThan(100)); // 1,000 runs total well under 100ms
    });

    testWidgets('3.3 HomeScreen hero balance updates in <100ms without page reload',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dynamicHttpClient = DynamicDashboardHttpClient(
        totalIncome: 3000.0,
        totalAllocated: 2000.0,
        totalSpent: 500.0, // Available = 1500.0
      );
      final apiClient = ApiClient(httpClient: dynamicHttpClient);
      final dashboardApiService = DashboardApiService(apiClient);
      final refreshSignal = ValueNotifier<int>(0);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(
            dashboardApiService: dashboardApiService,
            onOpenProfile: () {},
            refreshListenable: refreshSignal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial hero balance: $1,500.00
      expect(find.text('\$1,500.00'), findsOneWidget);
      expect(find.text('Gastado: \$500.00'), findsOneWidget);

      // Now an expense of $150.00 occurs: totalSpent becomes 650.0, totalAvailable becomes 1350.0
      dynamicHttpClient.totalSpent = 650.0;

      // Benchmark elapsed time from refresh signal trigger to widget rebuild rendering new balance
      final sw = Stopwatch()..start();
      refreshSignal.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
      sw.stop();

      // Verify latency is strictly < 100ms SLA
      expect(sw.elapsedMilliseconds, lessThan(100),
          reason: 'UI balance sync latency was ${sw.elapsedMilliseconds} ms');

      // Verify hero balance updated reactively without page reload
      expect(find.text('\$1,350.00'), findsOneWidget);
      expect(find.text('Gastado: \$650.00'), findsOneWidget);
    });
  });
}
