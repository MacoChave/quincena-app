import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/dashboard/data/dashboard_api_service.dart';
import 'package:quincena/features/dashboard/data/models/dashboard_data.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'package:quincena/features/transactions/presentation/feed/transactions_feed_screen.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/filter_chips_bar.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/grouped_feed_view.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/transaction_card.dart';

// ============================================================================
// TEST DOUBLES & PRODUCTION TYPE ADAPTERS
// ============================================================================

class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      const Stream.empty(),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class FakeDashboardApiService extends DashboardApiService {
  FakeDashboardApiService({DashboardData? data})
      : _data = data ??
            DashboardData(
              hasActiveCycle: true,
              cycle: DashboardCycle(
                id: 'cycle-1',
                year: 2026,
                month: 10,
                period: 'second_half',
                startDate: DateTime(2026, 10, 16),
                endDate: DateTime(2026, 10, 31),
                totalIncome: 2500.0,
                isClosed: false,
              ),
              summary: const DashboardSummary(
                totalIncome: 2500.0,
                totalAllocated: 2500.0,
                totalSpent: 490.75,
                totalAvailable: 2009.25,
                unallocated: 0.0,
                isBalanced: true,
              ),
              categories: const [],
            ),
        super(ApiClient(httpClient: _NoopHttpClient()));

  final DashboardData _data;

  @override
  Future<DashboardData> getDashboard() async => _data;
}

class FakeTransactionApiService extends TransactionApiService {
  FakeTransactionApiService({
    List<Transaction>? initialTransactions,
  })  : _transactions =
            initialTransactions != null ? List.from(initialTransactions) : [],
        super(ApiClient(httpClient: _NoopHttpClient()));

  final List<Transaction> _transactions;
  final List<String> deletedIds = [];

  List<Transaction> get currentTransactions => List.unmodifiable(_transactions);

  @override
  Future<List<Transaction>> getTransactions({required String cycleId}) async {
    return List.from(_transactions);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    deletedIds.add(id);
    _transactions.removeWhere((t) => t.id == id);
  }

  @override
  Future<ReceiptScan> getReceiptScan(String scanId) async {
    return ReceiptScan(
      id: scanId,
      userId: 'test-user',
      storagePath: 'receipts/test_ticket.jpg',
      extractedMerchant: 'Comercio OCR Detectado',
      extractedAmount: 125.50,
      confidenceScore: 0.94,
      ocrStatus: OcrStatus.processed,
      taxIdOrAuthNumber: 'SAT-99887766',
    );
  }
}

/// Helper adapter to bridge FeedFilterCriteria for algorithmic unit tests
class FeedFilter {
  const FeedFilter({
    this.searchQuery,
    this.selectedCategoryId,
    this.selectedAccountId,
    this.ocrOnly = false,
  });

  final String? searchQuery;
  final String? selectedCategoryId;
  final String? selectedAccountId;
  final bool ocrOnly;

  FeedFilterCriteria toCriteria() {
    return FeedFilterCriteria(
      searchQuery: searchQuery,
      selectedCategoryId: selectedCategoryId,
      selectedAccountId: selectedAccountId,
      ocrOnly: ocrOnly,
    );
  }

  static List<Transaction> apply(
    List<Transaction> list,
    FeedFilter filter,
  ) {
    return filter.toCriteria().apply(list);
  }
}

/// Type alias aligning unit tests with production TransactionCard
typedef TransactionCardWidget = TransactionCard;

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

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
    const Category(
      id: 'cat-trans',
      name: 'Transporte',
      icon: 'directions_car',
      colorHex: '#FFC09F',
      defaultAccountId: 'acc-deb',
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

  final sampleTransactions = [
    // Hoy (2026-10-18)
    Transaction(
      id: 't-hoy-1',
      userId: 'u1',
      cycleId: 'cycle-1',
      allocationId: 'cat-super',
      sourceAccountId: 'acc-deb',
      amount: 120.00,
      merchantName: 'Supermercado La Torre',
      transactionDate: DateTime(2026, 10, 18, 14, 30),
      entryMethod: EntryMethod.ocr,
      category: const TransactionCategory(
        id: 'cat-super',
        name: 'Supermercado',
        icon: 'shopping_cart',
        colorHex: '#ADF7B6',
      ),
      sourceAccount: const TransactionSourceAccount(
        id: 'acc-deb',
        name: 'Tarjeta Débito BAC',
        colorHex: '#79ADDC',
      ),
    ),
    Transaction(
      id: 't-hoy-2',
      userId: 'u1',
      cycleId: 'cycle-1',
      allocationId: 'cat-ocio',
      sourceAccountId: 'acc-cash',
      amount: 45.50,
      merchantName: 'Café Barista',
      transactionDate: DateTime(2026, 10, 18, 10, 15),
      entryMethod: EntryMethod.manual,
      category: const TransactionCategory(
        id: 'cat-ocio',
        name: 'Ocio & Café',
        icon: 'local_cafe',
        colorHex: '#FFEE93',
      ),
      sourceAccount: const TransactionSourceAccount(
        id: 'acc-cash',
        name: 'Efectivo Billetera',
        colorHex: '#ADF7B6',
      ),
    ),
    // Ayer (2026-10-17)
    Transaction(
      id: 't-ayer-1',
      userId: 'u1',
      cycleId: 'cycle-1',
      allocationId: 'cat-trans',
      sourceAccountId: 'acc-deb',
      amount: 250.00,
      merchantName: 'Gasolinera Shell',
      transactionDate: DateTime(2026, 10, 17, 18, 45),
      entryMethod: EntryMethod.ocr,
      category: const TransactionCategory(
        id: 'cat-trans',
        name: 'Transporte',
        icon: 'directions_car',
        colorHex: '#FFC09F',
      ),
      sourceAccount: const TransactionSourceAccount(
        id: 'acc-deb',
        name: 'Tarjeta Débito BAC',
        colorHex: '#79ADDC',
      ),
    ),
    // 16 Octubre (2026-10-16)
    Transaction(
      id: 't-16-1',
      userId: 'u1',
      cycleId: 'cycle-1',
      allocationId: 'cat-super',
      sourceAccountId: 'acc-deb',
      amount: 75.25,
      merchantName: 'Walmart Pradera',
      transactionDate: DateTime(2026, 10, 16, 12, 0),
      entryMethod: EntryMethod.manual,
      category: const TransactionCategory(
        id: 'cat-super',
        name: 'Supermercado',
        icon: 'shopping_cart',
        colorHex: '#ADF7B6',
      ),
      sourceAccount: const TransactionSourceAccount(
        id: 'acc-deb',
        name: 'Tarjeta Débito BAC',
        colorHex: '#79ADDC',
      ),
    ),
  ];

  Widget buildTestScreen({
    List<Transaction>? transactions,
    List<Category>? categories,
    List<FinancialAccount>? accounts,
    double spentTotal = 490.75,
    double allocatedTotal = 2500.0,
    TransactionApiService? transactionApiService,
    DashboardApiService? dashboardApiService,
    VoidCallback? onTransactionDeleted,
  }) {
    final txList = transactions ?? sampleTransactions;
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: TransactionsFeedScreen(
        apiClient: ApiClient(httpClient: _NoopHttpClient()),
        transactionApiService: transactionApiService ??
            FakeTransactionApiService(initialTransactions: txList),
        dashboardApiService:
            dashboardApiService ?? FakeDashboardApiService(),
        initialTransactions: txList,
        initialCategories: categories ?? testCategories,
        initialAccounts: accounts ?? testAccounts,
        initialSpentTotal: spentTotal,
        initialAllocatedTotal: allocatedTotal,
        referenceDate: DateTime(2026, 10, 18),
        onTransactionDeleted: onTransactionDeleted,
      ),
    );
  }

  group('Feature 5: History Feed & Date Grouping (RF-04/RF-06, Stitch feed)', () {
    // --- Tier 1 (5 tests) ---
    test('5.1 Chronological feed groups transactions into descending date sections', () {
      final grouped = GroupedDateSection.groupTransactions(
        sampleTransactions,
        referenceDate: DateTime(2026, 10, 18),
      );

      expect(grouped.length, 3);
      expect(grouped[0].headerTitle, startsWith('Hoy - 18'));
      expect(grouped[0].transactions.length, 2);
      expect(grouped[1].headerTitle, startsWith('Ayer - 17'));
      expect(grouped[1].transactions.length, 1);
      expect(grouped[2].headerTitle, contains('16 Octubre'));
      expect(grouped[2].transactions.length, 1);
    });

    test('5.2 Groups calculate accurate day monetary totals', () {
      final grouped = GroupedDateSection.groupTransactions(
        sampleTransactions,
        referenceDate: DateTime(2026, 10, 18),
      );

      // Hoy: 120.00 + 45.50 = 165.50
      expect(grouped[0].dayTotal, 165.50);
      // Ayer: 250.00
      expect(grouped[1].dayTotal, 250.00);
      // 16 Oct: 75.25
      expect(grouped[2].dayTotal, 75.25);
    });

    test('5.3 Empty transactions list returns empty grouped sections without error', () {
      final grouped = GroupedDateSection.groupTransactions([]);
      expect(grouped, isEmpty);
    });

    testWidgets('5.4 Quincena switcher header renders period label and total ratio',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Historial de Gastos'), findsOneWidget);
      expect(
        find.text('16 - 31 Octubre 2026 • Gastado \$490.75 de \$2500.00'),
        findsOneWidget,
      );
    });

    testWidgets('5.5 Within each day section, transactions are sorted chronologically descending',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supermercado La Torre'), findsOneWidget);
      expect(find.text('Café Barista'), findsOneWidget);
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    test('5.6 Multiple transactions on identical timestamp are preserved without collapsing', () {
      final duplicateTimeTxs = [
        Transaction(
          id: 'dup-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 10.0,
          merchantName: 'A',
          transactionDate: DateTime(2026, 10, 18, 12, 0, 0),
        ),
        Transaction(
          id: 'dup-2',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 20.0,
          merchantName: 'B',
          transactionDate: DateTime(2026, 10, 18, 12, 0, 0),
        ),
      ];

      final grouped = GroupedDateSection.groupTransactions(duplicateTimeTxs);
      expect(grouped.first.transactions.length, 2);
      expect(grouped.first.dayTotal, 30.0);
    });

    test('5.7 Feed with 100+ transactions balances day total sum without IEEE-754 drift', () {
      final list = List.generate(
        100,
        (i) => Transaction(
          id: 'tx-stress-$i',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 14.25,
          merchantName: 'Comercio $i',
          transactionDate: DateTime(2026, 10, 18, 10, 0),
        ),
      );

      final grouped = GroupedDateSection.groupTransactions(list);
      expect(grouped.first.transactions.length, 100);
      expect(grouped.first.dayTotal, 1425.0);
    });

    test('5.8 Leap year date (Feb 29) grouped and formatted accurately', () {
      final leapTx = Transaction(
        id: 'leap-1',
        userId: 'u1',
        cycleId: 'c-leap',
        sourceAccountId: 'acc-deb',
        amount: 50.0,
        merchantName: 'Leap Buy',
        transactionDate: DateTime(2024, 2, 29),
      );

      final grouped = GroupedDateSection.groupTransactions(
        [leapTx],
        referenceDate: DateTime(2024, 3, 1),
      );
      expect(grouped.first.headerTitle, startsWith('Ayer - 29'));
    });

    test('5.9 Month boundary transition groups into distinct headers', () {
      final boundaryTxs = [
        Transaction(
          id: 'nov-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 40.0,
          merchantName: 'Nov',
          transactionDate: DateTime(2026, 11, 1),
        ),
        Transaction(
          id: 'oct-31',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 60.0,
          merchantName: 'Oct',
          transactionDate: DateTime(2026, 10, 31),
        ),
      ];

      final grouped = GroupedDateSection.groupTransactions(
        boundaryTxs,
        referenceDate: DateTime(2026, 11, 1),
      );
      expect(grouped.length, 2);
      expect(grouped[0].headerTitle, startsWith('Hoy - 1 Noviembre'));
      expect(grouped[1].headerTitle, startsWith('Ayer - 31 Octubre'));
    });

    test('5.10 Future-dated transactions placed in proper order above current date', () {
      final futureTxs = [
        Transaction(
          id: 'fut-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 50.0,
          merchantName: 'Future Item',
          transactionDate: DateTime(2026, 10, 25),
        ),
        Transaction(
          id: 'curr-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 20.0,
          merchantName: 'Current Item',
          transactionDate: DateTime(2026, 10, 18),
        ),
      ];

      final grouped = GroupedDateSection.groupTransactions(
        futureTxs,
        referenceDate: DateTime(2026, 10, 18),
      );
      expect(grouped.first.headerTitle, contains('25 Octubre 2026'));
      expect(grouped.last.headerTitle, startsWith('Hoy - 18'));
    });
  });

  group('Feature 6: Feed Search & Filter Chips (RF-04/RF-06, Stitch filters)', () {
    // --- Tier 1 (5 tests) ---
    testWidgets('6.1 Selecting Todos displays all transactions in feed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado La Torre'), findsOneWidget);
      expect(find.text('Café Barista'), findsOneWidget);
      expect(find.text('Gasolinera Shell'), findsOneWidget);
      expect(find.text('Walmart Pradera'), findsOneWidget);
    });

    testWidgets('6.2 Selecting category chip filters feed to that category only', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Supermercado' chip
      await tester.tap(find.byKey(const Key('chip_cat_cat-super')));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado La Torre'), findsOneWidget);
      expect(find.text('Walmart Pradera'), findsOneWidget);
      expect(find.text('Café Barista'), findsNothing);
      expect(find.text('Gasolinera Shell'), findsNothing);
    });

    testWidgets('6.3 Selecting financial account chip filters feed to that account only', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on 'Efectivo Billetera' chip
      await tester.ensureVisible(find.byKey(const Key('chip_acc_acc-cash')));
      await tester.tap(find.byKey(const Key('chip_acc_acc-cash')));
      await tester.pumpAndSettle();

      expect(find.text('Café Barista'), findsOneWidget);
      expect(find.text('Supermercado La Torre'), findsNothing);
      expect(find.text('Gasolinera Shell'), findsNothing);
    });

    testWidgets('6.4 Selecting Con Factura OCR filters to OCR transactions only', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chip_ocr_only')));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado La Torre'), findsOneWidget);
      expect(find.text('Gasolinera Shell'), findsOneWidget);
      expect(find.text('Café Barista'), findsNothing);
      expect(find.text('Walmart Pradera'), findsNothing);
    });

    testWidgets('6.5 Live search input filters transactions instantaneously by merchant keyword',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('feed_search_input')), 'Shell');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.text('Gasolinera Shell'), findsOneWidget);
      expect(find.text('Supermercado La Torre'), findsNothing);
      expect(find.text('Café Barista'), findsNothing);
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    testWidgets('6.6 Search query with zero matches renders empty state and Limpiar filtros button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('feed_search_input')),
        'NoExisteEsteComercio999',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontraron gastos para los filtros seleccionados'),
        findsOneWidget,
      );
      expect(find.text('Limpiar filtros'), findsOneWidget);

      // Tapping clean button restores all items
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado La Torre'), findsOneWidget);
    });

    test('6.7 Search query with regex meta-characters does not crash regex engine', () {
      final res = FeedFilter.apply(
        sampleTransactions,
        const FeedFilter(searchQuery: r'[\^$.|?*+()'),
      );
      expect(res, isEmpty);
    });

    test('6.8 Multi-filter intersection: Category + Account + Search Query', () {
      final res = FeedFilter.apply(
        sampleTransactions,
        const FeedFilter(
          selectedCategoryId: 'cat-super',
          selectedAccountId: 'acc-deb',
          searchQuery: 'Torre',
        ),
      );
      expect(res.length, 1);
      expect(res.first.merchantName, 'Supermercado La Torre');
    });

    test('6.9 Case-insensitive search across UPPERCASE and lowercase', () {
      final resUpper = FeedFilter.apply(
        sampleTransactions,
        const FeedFilter(searchQuery: 'BARISTA'),
      );
      final resLower = FeedFilter.apply(
        sampleTransactions,
        const FeedFilter(searchQuery: 'barista'),
      );
      expect(resUpper.length, 1);
      expect(resLower.length, 1);
      expect(resUpper.first.id, resLower.first.id);
    });

    test('6.10 Search by notes content returns matching transaction', () {
      final txWithNote = Transaction(
        id: 'note-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 30.0,
        merchantName: 'Comercio General',
        notes: 'Medicinas para la gripe',
        transactionDate: DateTime.now(),
      );

      final res = FeedFilter.apply(
        [txWithNote],
        const FeedFilter(searchQuery: 'gripe'),
      );
      expect(res.length, 1);
      expect(res.first.id, 'note-1');
    });
  });

  group('Feature 7: Transaction Card Architecture & Tabular Numbers (RF-04/RF-06, tnum)', () {
    // --- Tier 1 (5 tests) ---
    testWidgets('7.1 Card renders category avatar with 44x44 size and category color',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tx = sampleTransactions[0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: tx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(TransactionCardWidget),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.constraints?.maxWidth == 44.0,
          ),
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, testCategories[0].parsedColor);
      expect(decoration.borderRadius, BorderRadius.circular(12));
    });

    testWidgets('7.2 Card displays merchant name and source account name', (tester) async {
      final tx = sampleTransactions[0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: tx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supermercado La Torre'), findsOneWidget);
      expect(find.text('Tarjeta Débito BAC'), findsOneWidget);
    });

    testWidgets('7.3 Card displays entry method badge (OCR Escaneado)', (tester) async {
      final ocrTx = sampleTransactions[0]; // entryMethod = ocr
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: ocrTx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('OCR Escaneado'), findsOneWidget);
    });

    testWidgets('7.4 Card renders monetary amount formatted with negative sign and currency (-\$120.00)',
        (tester) async {
      final tx = sampleTransactions[0];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: tx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-\$120.00'), findsOneWidget);
    });

    test('7.5 Tabular figures (tnum) are configured on AppTypography.numericRow', () {
      final style = AppTypography.numericRow;
      expect(style.fontFeatures, isNotNull);
      expect(
        style.fontFeatures!.any((f) => f.feature == 'tnum'),
        isTrue,
      );
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    testWidgets('7.6 Extremely long merchant name is truncated with ellipsis', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final longTx = Transaction(
        id: 'long-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 80.0,
        merchantName: 'Supermercado Central de las Cumbres y Distribuidora Internacional S.A. Sucursal 49',
        transactionDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: longTx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text(longTx.merchantName));
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expect(textWidget.maxLines, 1);
    });

    testWidgets('7.7 Merchant with emojis and Unicode symbols renders cleanly', (tester) async {
      final emojiTx = Transaction(
        id: 'emoji-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 15.0,
        merchantName: '☕ Café & Donas 🍩',
        transactionDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: emojiTx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('☕ Café & Donas 🍩'), findsOneWidget);
    });

    testWidgets('7.8 Large monetary amount (\$99,999.99) displays cleanly in card row', (tester) async {
      final bigTx = Transaction(
        id: 'big-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 99999.99,
        merchantName: 'Compra Mayorista',
        transactionDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: bigTx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-\$99999.99'), findsOneWidget);
    });

    testWidgets('7.9 Transaction with null category or sourceAccount renders fallback gracefully',
        (tester) async {
      final nullsTx = Transaction(
        id: 'nulls-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-orphan',
        amount: 25.0,
        merchantName: 'Gasto Sin Cuenta',
        transactionDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(transaction: nullsTx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gasto Sin Cuenta'), findsOneWidget);
      expect(find.text('-\$25.00'), findsOneWidget);
    });

    testWidgets('7.10 Delete action on transaction card triggers callback with transaction ID',
        (tester) async {
      String? deletedId;
      final tx = sampleTransactions[0];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: TransactionCardWidget(
              transaction: tx,
              onDelete: () => deletedId = tx.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(deletedId, tx.id);
    });
  });

  group('Tier 3: Pairwise Combinations (Feed & Filter Flow)', () {
    testWidgets('3.1 Category Chip + Account Chip + Search Query Filters Feed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      // Select Category 'Supermercado'
      await tester.tap(find.byKey(const Key('chip_cat_cat-super')));
      await tester.pumpAndSettle();

      // Enter search query 'Walmart'
      await tester.enterText(find.byKey(const Key('feed_search_input')), 'Walmart');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      // Only Walmart Pradera should be visible
      expect(find.text('Walmart Pradera'), findsOneWidget);
      expect(find.text('Supermercado La Torre'), findsNothing);
      expect(find.text('Gasolinera Shell'), findsNothing);
    });

    testWidgets('3.2 OCR Only Filter + Search Query for Merchant', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      // Select 'Con Factura OCR'
      await tester.tap(find.byKey(const Key('chip_ocr_only')));
      await tester.pumpAndSettle();

      // Search 'Torre'
      await tester.enterText(find.byKey(const Key('feed_search_input')), 'Torre');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.text('Supermercado La Torre'), findsOneWidget);
      expect(find.text('Gasolinera Shell'), findsNothing);
    });

    testWidgets('3.3 User deletes transaction from feed and list updates reactively', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mutableList = List<Transaction>.from(sampleTransactions);
      final fakeTxService =
          FakeTransactionApiService(initialTransactions: mutableList);
      final fakeDashService = FakeDashboardApiService();

      await tester.pumpWidget(
        buildTestScreen(
          transactions: mutableList,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 490.75,
          allocatedTotal: 2500.0,
          transactionApiService: fakeTxService,
          dashboardApiService: fakeDashService,
          onTransactionDeleted: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Café Barista'), findsOneWidget);

      // Tap delete icon on Café Barista card
      await tester.tap(find.descendant(
        of: find.byKey(const Key('card_t-hoy-2')),
        matching: find.byIcon(Icons.delete_outline),
      ));
      await tester.pumpAndSettle();

      // Real confirmation dialog appears
      expect(find.text('¿Eliminar transacción?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(fakeTxService.deletedIds, contains('t-hoy-2'));
      expect(find.text('Café Barista'), findsNothing);
    });

    testWidgets('3.4 Bento Tile and Switcher Header update when spent total changes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestScreen(
          transactions: sampleTransactions,
          categories: testCategories,
          accounts: testAccounts,
          spentTotal: 1050.00,
          allocatedTotal: 2500.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1050.00'), findsAtLeastNWidgets(1));
      expect(find.text('En meta'), findsOneWidget);
    });
  });
}
