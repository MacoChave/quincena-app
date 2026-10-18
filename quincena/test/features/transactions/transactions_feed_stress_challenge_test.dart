import 'dart:convert';
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
import 'package:quincena/features/transactions/presentation/feed/widgets/feed_search_bar.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/filter_chips_bar.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/grouped_feed_view.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/transaction_card.dart';

// ============================================================================
// TEST DOUBLES & MOCKS FOR EMPIRICAL STRESS TESTING
// ============================================================================

class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('{}')),
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
                id: 'cycle-active-stress-1',
                year: 2026,
                month: 10,
                period: 'second_half',
                startDate: DateTime(2026, 10, 16),
                endDate: DateTime(2026, 10, 31),
                totalIncome: 5000.0,
                isClosed: false,
              ),
              summary: const DashboardSummary(
                totalIncome: 5000.0,
                totalAllocated: 4000.0,
                totalSpent: 1200.0,
                totalAvailable: 2800.0,
                unallocated: 1000.0,
                isBalanced: false,
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

// Helper to construct test categories
List<Category> _buildTestCategories() {
  return const [
    Category(
      id: 'cat-1',
      name: 'Alimentación',
      icon: 'restaurant',
      colorHex: '#79ADDC',
    ),
    Category(
      id: 'cat-2',
      name: 'Transporte',
      icon: 'directions_car',
      colorHex: '#FFEE93',
    ),
    Category(
      id: 'cat-3',
      name: 'Servicios',
      icon: 'bolt',
      colorHex: '#FFC09F',
    ),
    Category(
      id: 'cat-4',
      name: 'Entretenimiento',
      icon: 'movie',
      colorHex: '#ADF7B6',
    ),
    Category(
      id: 'cat-5',
      name: 'Salud',
      icon: 'local_hospital',
      colorHex: '#FCF5C7',
    ),
  ];
}

// Helper to construct test financial accounts
List<FinancialAccount> _buildTestAccounts() {
  return const [
    FinancialAccount(
      id: 'acc-1',
      name: 'Cuenta Monetaria BI',
      accountType: AccountType.checking,
      currency: 'GTQ',
      colorHex: '#79ADDC',
      icon: 'account_balance',
      isDefault: true,
      isArchived: false,
      initialBalance: 3000.0,
      currentBalance: 2450.0,
    ),
    FinancialAccount(
      id: 'acc-2',
      name: 'Tarjeta de Crédito',
      accountType: AccountType.creditCard,
      currency: 'GTQ',
      colorHex: '#FFC09F',
      icon: 'credit_card',
      isDefault: false,
      isArchived: false,
      initialBalance: 0.0,
      currentBalance: -550.0,
    ),
    FinancialAccount(
      id: 'acc-3',
      name: 'Efectivo Billetera',
      accountType: AccountType.cash,
      currency: 'GTQ',
      colorHex: '#ADF7B6',
      icon: 'payments',
      isDefault: false,
      isArchived: false,
      initialBalance: 500.0,
      currentBalance: 320.0,
    ),
  ];
}

// Helper to construct 225 simulated transactions across 15 distinct days
List<Transaction> _build225TransactionsOver15Days() {
  final List<Transaction> list = [];
  final categories = _buildTestCategories();
  final accounts = _buildTestAccounts();

  // 15 days from Oct 16 to Oct 30, 2026
  for (int dayOffset = 0; dayOffset < 15; dayOffset++) {
    final dayNumber = 30 - dayOffset; // 30 down to 16
    final date = DateTime(2026, 10, dayNumber);

    // 15 transactions per day = 225 transactions total
    for (int i = 0; i < 15; i++) {
      final hour = 8 + (i % 12);
      final minute = (i * 4) % 60;
      final txTime = DateTime(date.year, date.month, date.day, hour, minute);

      final cat = categories[(dayOffset + i) % categories.length];
      final acc = accounts[(dayOffset + i) % accounts.length];
      final isOcr = (i % 3 == 0); // 1 in 3 is OCR

      list.add(
        Transaction(
          id: 'tx-d$dayNumber-i$i',
          userId: 'user-stress',
          cycleId: 'cycle-active-stress-1',
          sourceAccountId: acc.id,
          amount: 10.0 + (dayOffset * 2.0) + (i * 1.5),
          merchantName: 'Comercio D$dayNumber Item $i',
          transactionDate: txTime,
          entryMethod: isOcr ? EntryMethod.ocr : EntryMethod.manual,
          receiptScanId: isOcr ? 'scan-d$dayNumber-i$i' : null,
          category: TransactionCategory(
            id: cat.id,
            name: cat.name,
            icon: cat.icon,
            colorHex: cat.colorHex,
          ),
          sourceAccount: TransactionSourceAccount(
            id: acc.id,
            name: acc.name,
            colorHex: acc.colorHex,
          ),
        ),
      );
    }
  }

  return list;
}

// ============================================================================
// MAIN ADVERSARIAL TEST SUITE
// ============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHALLENGE 1: Search Input Regex, Unicode Emoji & Overflow Resilience', () {
    test('FeedFilterCriteria handles special regex characters safely without unhandled RegExp exceptions', () {
      final txRegex1 = Transaction(
        id: 'tx-rgx-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 45.0,
        merchantName: 'Restaurante [El Corral] (50% + 10%) *PROMO*',
        transactionDate: DateTime(2026, 10, 25, 14, 0),
        notes: r'Factura con caracteres regex: .*+?^${}()|[]\',
      );

      final txNormal = Transaction(
        id: 'tx-norm-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 20.0,
        merchantName: 'Farmacia Galeno',
        transactionDate: DateTime(2026, 10, 25, 15, 0),
        notes: 'Compra normal de medicamentos',
      );

      final transactions = [txRegex1, txNormal];

      // 1. Full regex characters string
      const fullRegexQuery = r'.*+?^${}()|[]\';
      final filteredFull = const FeedFilterCriteria(searchQuery: fullRegexQuery).apply(transactions);
      expect(filteredFull.length, 1);
      expect(filteredFull.first.id, 'tx-rgx-1');

      // 2. Unclosed brackets and wildcard tokens
      for (final dangerousToken in ['[', ']', '(', ')', '*', '+', '?', '^', r'$', r'\', '|', '{', '}']) {
        expect(() {
          final res = FeedFilterCriteria(searchQuery: dangerousToken).apply(transactions);
          expect(res, isNotNull);
        }, returnsNormally);
      }

      // 3. Substring matching with brackets and percentage
      final matchBrackets = const FeedFilterCriteria(searchQuery: '[El Corral]').apply(transactions);
      expect(matchBrackets.length, 1);
      expect(matchBrackets.first.id, 'tx-rgx-1');

      final matchCalc = const FeedFilterCriteria(searchQuery: '(50% + 10%)').apply(transactions);
      expect(matchCalc.length, 1);
      expect(matchCalc.first.id, 'tx-rgx-1');

      // 4. FeedSearchBar.filterTransactions static helper resilience
      final searchBarRes = FeedSearchBar.filterTransactions(
        transactions: transactions,
        query: r'regex: .*+?^${}()|[]\',
      );
      expect(searchBarRes.length, 1);
      expect(searchBarRes.first.id, 'tx-rgx-1');
    });

    testWidgets('Live UI search input handles regex characters without crashing or throwing FormatException', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final txRegex = Transaction(
        id: 'tx-rgx-ui',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 65.0,
        merchantName: r'Tienda Especial (RegEx) [Item] $100 + TAX',
        transactionDate: DateTime(2026, 10, 30, 12, 0),
        notes: r'Detalle especial \d+ .*',
      );

      final txOther = Transaction(
        id: 'tx-other-ui',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 30.0,
        merchantName: 'Supermercado La Colonia',
        transactionDate: DateTime(2026, 10, 30, 11, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            initialTransactions: [txRegex, txOther],
            initialCategories: _buildTestCategories(),
            initialAccounts: _buildTestAccounts(),
            referenceDate: DateTime(2026, 10, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially both visible
      expect(find.byType(TransactionCard), findsNWidgets(2));

      // Enter dangerous regex characters into the live search input
      final searchFinder = find.byKey(const Key('feed_search_input'));
      expect(searchFinder, findsOneWidget);

      await tester.enterText(searchFinder, r'(RegEx) [Item]');
      await tester.pumpAndSettle();

      // Only the regex-matching transaction should remain
      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionCard), findsOneWidget);
      expect(find.text(r'Tienda Especial (RegEx) [Item] $100 + TAX'), findsOneWidget);
      expect(find.text('Supermercado La Colonia'), findsNothing);

      // Clear search via clear button
      final clearBtnFinder = find.byKey(const Key('feed_search_clear_btn'));
      expect(clearBtnFinder, findsOneWidget);
      await tester.tap(clearBtnFinder);
      await tester.pumpAndSettle();

      // Both transactions reappear
      expect(find.byType(TransactionCard), findsNWidgets(2));
    });

    testWidgets('Live UI search input handles unicode emojis and multi-byte runes correctly', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final txEmoji1 = Transaction(
        id: 'tx-emo-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 85.0,
        merchantName: 'Supermercado 🥑 Orgánico',
        transactionDate: DateTime(2026, 10, 30, 10, 0),
        notes: 'Compras de verduras y frutas 🛒',
      );

      final txEmoji2 = Transaction(
        id: 'tx-emo-2',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 140.0,
        merchantName: 'Sushi Express 🍣',
        transactionDate: DateTime(2026, 10, 30, 13, 0),
        notes: 'Cena familiar 🍱',
      );

      final txEmoji3 = Transaction(
        id: 'tx-emo-3',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 200.0,
        merchantName: 'Gasolinera Puma ⛽',
        transactionDate: DateTime(2026, 10, 30, 15, 0),
        notes: 'Tanque lleno 🚗',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            initialTransactions: [txEmoji1, txEmoji2, txEmoji3],
            initialCategories: _buildTestCategories(),
            initialAccounts: _buildTestAccounts(),
            referenceDate: DateTime(2026, 10, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TransactionCard), findsNWidgets(3));

      // Search by emoji '🥑'
      final searchFinder = find.byKey(const Key('feed_search_input'));
      await tester.enterText(searchFinder, '🥑');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(TransactionCard), findsOneWidget);
      expect(find.text('Supermercado 🥑 Orgánico'), findsOneWidget);

      // Search by emoji in notes '🍱'
      await tester.enterText(searchFinder, '🍱');
      await tester.pumpAndSettle();

      expect(find.byType(TransactionCard), findsOneWidget);
      expect(find.text('Sushi Express 🍣'), findsOneWidget);

      // Search by non-matching emoji '🛸'
      await tester.enterText(searchFinder, '🛸');
      await tester.pumpAndSettle();

      expect(find.byType(TransactionCard), findsNothing);
      expect(find.text('No se encontraron gastos para los filtros seleccionados'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);

      // Tap 'Limpiar filtros' on empty state
      await tester.ensureVisible(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(find.byType(TransactionCard), findsNWidgets(3));
    });

    testWidgets('Live UI search input handles extreme query (>250 chars) without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tx = Transaction(
        id: 'tx-len-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 50.0,
        merchantName: 'Café Barista',
        transactionDate: DateTime(2026, 10, 30, 9, 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            initialTransactions: [tx],
            initialCategories: _buildTestCategories(),
            initialAccounts: _buildTestAccounts(),
            referenceDate: DateTime(2026, 10, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Construct a very long adversarial query (>250 characters)
      final extremeQuery = 'ComercioExtremadamenteLargoConMuchosCaracteresRepetidosQuePodrianCausarDesbordamientoEnElTextoDeLaBarraDeBusquedaSiNoEstaBienConfiguradoElTextFieldOElContenedor' * 2;
      expect(extremeQuery.length, greaterThan(250));

      // FeedFilterCriteria performance check
      final stopwatch = Stopwatch()..start();
      final res = FeedFilterCriteria(searchQuery: extremeQuery).apply([tx]);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(16));
      expect(res, isEmpty);

      // Type into UI
      final searchFinder = find.byKey(const Key('feed_search_input'));
      await tester.enterText(searchFinder, extremeQuery);
      await tester.pumpAndSettle();

      // Zero layout overflow exceptions
      expect(tester.takeException(), isNull);
      expect(find.text('No se encontraron gastos para los filtros seleccionados'), findsOneWidget);

      // Clear search
      final clearBtn = find.byKey(const Key('feed_search_clear_btn'));
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Café Barista'), findsOneWidget);
    });
  });

  group('CHALLENGE 2: Feed Rendering with 200+ Transactions across 15 Days', () {
    test('GroupedDateSection mathematical and chronological grouping across 15 distinct days', () {
      final transactions = _build225TransactionsOver15Days();
      expect(transactions.length, 225);

      final referenceDate = DateTime(2026, 10, 30, 23, 59, 59);
      final sections = GroupedDateSection.groupTransactions(
        transactions,
        referenceDate: referenceDate,
      );

      // Exactly 15 distinct day sections
      expect(sections.length, 15);

      // Day 0 is "Hoy - 30 Octubre"
      expect(sections[0].headerTitle, 'Hoy - 30 Octubre');
      expect(sections[0].transactions.length, 15);

      // Day 1 is "Ayer - 29 Octubre"
      expect(sections[1].headerTitle, 'Ayer - 29 Octubre');
      expect(sections[1].transactions.length, 15);

      // Day 2 is "28 Octubre 2026"
      expect(sections[2].headerTitle, '28 Octubre 2026');

      // Day 14 is "16 Octubre 2026"
      expect(sections[14].headerTitle, '16 Octubre 2026');

      // Strictly descending chronological order
      for (int i = 0; i < sections.length - 1; i++) {
        expect(
          sections[i].date.isAfter(sections[i + 1].date),
          isTrue,
          reason: 'Section $i date (${sections[i].date}) must be strictly after section ${i + 1} (${sections[i + 1].date})',
        );
      }

      // Mathematical exactness of dayTotal across all 15 sections
      for (final sec in sections) {
        final expectedSum = sec.transactions.fold<double>(
          0.0,
          (sum, t) => sum + t.amount,
        );
        final roundedExpected = double.parse(expectedSum.toStringAsFixed(2));
        expect(
          sec.dayTotal,
          roundedExpected,
          reason: 'Section ${sec.headerTitle} total mismatch',
        );
      }
    });

    testWidgets('Feed renders 200+ simulated transactions without layout overflows and survives rapid scrolling', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final transactions = _build225TransactionsOver15Days();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            initialTransactions: transactions,
            initialCategories: _buildTestCategories(),
            initialAccounts: _buildTestAccounts(),
            referenceDate: DateTime(2026, 10, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero layout overflow exceptions upon initial render
      expect(tester.takeException(), isNull);

      // Header components verify
      expect(find.text('Historial de Gastos'), findsOneWidget);
      expect(find.text('Historial de Transacciones'), findsOneWidget);
      expect(find.text('Hoy - 30 Octubre'), findsOneWidget);

      // Scroll stress test: Perform 8 consecutive fast fling/drag operations down the list
      final scrollableFinder = find.byType(CustomScrollView);
      expect(scrollableFinder, findsOneWidget);

      for (int step = 0; step < 8; step++) {
        await tester.drag(scrollableFinder, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Scroll back up to the top
      for (int step = 0; step < 8; step++) {
        await tester.drag(scrollableFinder, const Offset(0, 600));
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Top header should be back in view
      expect(find.text('Historial de Gastos'), findsOneWidget);
      expect(find.text('Hoy - 30 Octubre'), findsOneWidget);
    });
  });

  group('CHALLENGE 3: Rapid Filter Switching Under Load', () {
    testWidgets('Rapidly switching between Todos, categories, and Con Factura OCR under 200+ transaction load', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final transactions = _build225TransactionsOver15Days();
      final categories = _buildTestCategories();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            initialTransactions: transactions,
            initialCategories: categories,
            initialAccounts: _buildTestAccounts(),
            referenceDate: DateTime(2026, 10, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Filter by "Con Factura OCR"
      final ocrChipFinder = find.byKey(const Key('chip_ocr_only'));
      expect(ocrChipFinder, findsOneWidget);
      await tester.tap(ocrChipFinder);
      await tester.pumpAndSettle();

      // Verify all rendered cards on screen are OCR
      final cardsAfterOcr = tester.widgetList<TransactionCard>(find.byType(TransactionCard));
      expect(cardsAfterOcr, isNotEmpty);
      for (final card in cardsAfterOcr) {
        expect(card.transaction.isOcr, isTrue);
      }

      // 2. Filter by Category 1 ('Alimentación') while OCR is active
      final cat1ChipFinder = find.byKey(const Key('chip_cat_cat-1'));
      expect(cat1ChipFinder, findsOneWidget);
      await tester.ensureVisible(cat1ChipFinder);
      await tester.tap(cat1ChipFinder);
      await tester.pumpAndSettle();

      final cardsAfterCat1AndOcr = tester.widgetList<TransactionCard>(find.byType(TransactionCard));
      expect(cardsAfterCat1AndOcr, isNotEmpty);
      for (final card in cardsAfterCat1AndOcr) {
        expect(card.transaction.isOcr, isTrue);
        expect(card.transaction.category?.id, 'cat-1');
      }

      // 3. Switch Category to Category 2 ('Transporte')
      final cat2ChipFinder = find.byKey(const Key('chip_cat_cat-2'));
      expect(cat2ChipFinder, findsOneWidget);
      await tester.ensureVisible(cat2ChipFinder);
      await tester.tap(cat2ChipFinder);
      await tester.pumpAndSettle();

      final cardsAfterCat2AndOcr = tester.widgetList<TransactionCard>(find.byType(TransactionCard));
      expect(cardsAfterCat2AndOcr, isNotEmpty);
      for (final card in cardsAfterCat2AndOcr) {
        expect(card.transaction.isOcr, isTrue);
        expect(card.transaction.category?.id, 'cat-2');
      }

      // 4. Tap "Todos" to reset all active filters
      final todosChipFinder = find.byKey(const Key('chip_todos'));
      expect(todosChipFinder, findsOneWidget);
      await tester.ensureVisible(todosChipFinder);
      await tester.pumpAndSettle();
      await tester.tap(todosChipFinder);
      await tester.pumpAndSettle();

      // Verify that non-OCR transactions are back
      final cardsAfterReset = tester.widgetList<TransactionCard>(find.byType(TransactionCard));
      final hasManual = cardsAfterReset.any((c) => !c.transaction.isOcr);
      expect(hasManual, isTrue);

      // 5. Stress Burst: 15 rapid filter changes without settling between taps
      final chipsSequence = [
        find.byKey(const Key('chip_ocr_only')),
        find.byKey(const Key('chip_cat_cat-1')),
        find.byKey(const Key('chip_cat_cat-2')),
        find.byKey(const Key('chip_todos')),
        find.byKey(const Key('chip_cat_cat-3')),
        find.byKey(const Key('chip_ocr_only')),
        find.byKey(const Key('chip_todos')),
        find.byKey(const Key('chip_ocr_only')),
        find.byKey(const Key('chip_cat_cat-4')),
        find.byKey(const Key('chip_todos')),
      ];

      for (final chip in chipsSequence) {
        if (chip.evaluate().isNotEmpty) {
          await tester.ensureVisible(chip);
          await tester.pump(const Duration(milliseconds: 10));
          await tester.tap(chip);
          await tester.pump(const Duration(milliseconds: 10));
        }
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('CHALLENGE 4: Clean Transition to EmptyFeedState.noTransactionsInCycle upon Deletion', () {
    testWidgets('Deleting the only transaction in a cycle cleanly transitions to EmptyFeedState.noTransactionsInCycle', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final singleTx = Transaction(
        id: 'tx-solitary-1',
        userId: 'u1',
        cycleId: 'cycle-active-stress-1',
        sourceAccountId: 'acc-1',
        amount: 89.99,
        merchantName: 'Supermercado Solitario',
        transactionDate: DateTime(2026, 10, 30, 11, 0),
        category: const TransactionCategory(
          id: 'cat-1',
          name: 'Alimentación',
          icon: 'restaurant',
          colorHex: '#79ADDC',
        ),
      );

      final fakeTxService = FakeTransactionApiService(
        initialTransactions: [singleTx],
      );
      final fakeDashService = FakeDashboardApiService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            transactionApiService: fakeTxService,
            dashboardApiService: fakeDashService,
            referenceDate: DateTime(2026, 10, 30),
            onScanReceipt: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the single transaction card is displayed initially
      expect(find.text('Supermercado Solitario'), findsOneWidget);
      expect(find.byType(TransactionCard), findsOneWidget);
      expect(find.text('No hay gastos registrados en esta quincena'), findsNothing);

      // Trigger deletion via card's delete icon button
      final deleteBtnFinder = find.byTooltip('Eliminar gasto');
      expect(deleteBtnFinder, findsOneWidget);
      await tester.tap(deleteBtnFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('¿Eliminar transacción?'), findsOneWidget);
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Eliminar');
      expect(confirmBtnFinder, findsOneWidget);

      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      // Verify API service recorded the deletion and has 0 remaining transactions
      expect(fakeTxService.deletedIds, contains('tx-solitary-1'));
      expect(fakeTxService.currentTransactions, isEmpty);

      // EMPIRICAL ASSERTION: Clean transition to EmptyFeedState.noTransactionsInCycle
      expect(find.text('No hay gastos registrados en esta quincena'), findsOneWidget);
      expect(find.text('Comienza capturando un comprobante con la cámara o registrando un gasto manual.'), findsOneWidget);
      expect(find.text('Escanear comprobante'), findsOneWidget);

      // Ensure that EmptyFeedState.noFilterResults is NOT shown
      expect(find.text('No se encontraron gastos para los filtros seleccionados'), findsNothing);
      expect(find.byType(TransactionCard), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Deleting one of two transactions leaves remaining card; deleting the second transitions to EmptyFeedState.noTransactionsInCycle', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tx1 = Transaction(
        id: 'tx-pair-1',
        userId: 'u1',
        cycleId: 'cycle-active-stress-1',
        sourceAccountId: 'acc-1',
        amount: 25.0,
        merchantName: 'Primer Gasto Par',
        transactionDate: DateTime(2026, 10, 30, 14, 0),
        category: const TransactionCategory(
          id: 'cat-1',
          name: 'Alimentación',
        ),
      );

      final tx2 = Transaction(
        id: 'tx-pair-2',
        userId: 'u1',
        cycleId: 'cycle-active-stress-1',
        sourceAccountId: 'acc-1',
        amount: 50.0,
        merchantName: 'Segundo Gasto Par',
        transactionDate: DateTime(2026, 10, 30, 10, 0),
        category: const TransactionCategory(
          id: 'cat-2',
          name: 'Transporte',
        ),
      );

      final fakeTxService = FakeTransactionApiService(
        initialTransactions: [tx1, tx2],
      );
      final fakeDashService = FakeDashboardApiService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            transactionApiService: fakeTxService,
            dashboardApiService: fakeDashService,
            referenceDate: DateTime(2026, 10, 30),
            onScanReceipt: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TransactionCard), findsNWidgets(2));
      expect(find.text('Primer Gasto Par'), findsOneWidget);
      expect(find.text('Segundo Gasto Par'), findsOneWidget);

      // 1. Delete first transaction
      await tester.tap(find.byTooltip('Eliminar gasto').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
      await tester.pumpAndSettle();

      // Only second transaction remains, no empty state
      expect(find.byType(TransactionCard), findsOneWidget);
      expect(find.text('Segundo Gasto Par'), findsOneWidget);
      expect(find.text('Primer Gasto Par'), findsNothing);
      expect(find.text('No hay gastos registrados en esta quincena'), findsNothing);

      // 2. Delete second transaction (now the last transaction)
      await tester.tap(find.byTooltip('Eliminar gasto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
      await tester.pumpAndSettle();

      // Now transitions to empty cycle state
      expect(find.byType(TransactionCard), findsNothing);
      expect(find.text('No hay gastos registrados en esta quincena'), findsOneWidget);
      expect(find.text('Escanear comprobante'), findsOneWidget);
    });

    testWidgets('Deleting the last transaction via TransactionDetailSheet modal closes modal and transitions cleanly to EmptyFeedState.noTransactionsInCycle', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final tx = Transaction(
        id: 'tx-sheet-del-1',
        userId: 'u1',
        cycleId: 'cycle-active-stress-1',
        sourceAccountId: 'acc-1',
        amount: 110.0,
        merchantName: 'Gasto Para Eliminar en Sheet',
        transactionDate: DateTime(2026, 10, 30, 16, 0),
        category: const TransactionCategory(
          id: 'cat-1',
          name: 'Alimentación',
        ),
      );

      final fakeTxService = FakeTransactionApiService(
        initialTransactions: [tx],
      );
      final fakeDashService = FakeDashboardApiService();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TransactionsFeedScreen(
            apiClient: ApiClient(httpClient: _NoopHttpClient()),
            transactionApiService: fakeTxService,
            dashboardApiService: fakeDashService,
            referenceDate: DateTime(2026, 10, 30),
            onScanReceipt: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap card body to open TransactionDetailSheet
      await tester.tap(find.text('Gasto Para Eliminar en Sheet'));
      await tester.pumpAndSettle();

      // Modal bottom sheet should be open
      expect(find.text('Detalle de Gasto'), findsOneWidget);
      expect(find.text('Eliminar Gasto'), findsOneWidget);

      // Scroll to 'Eliminar Gasto' in modal
      await tester.ensureVisible(find.text('Eliminar Gasto'));
      await tester.pumpAndSettle();

      // Tap 'Eliminar Gasto' in modal
      await tester.tap(find.text('Eliminar Gasto'));
      await tester.pumpAndSettle();

      // Confirmation dialog should be open
      expect(find.text('¿Eliminar gasto?'), findsOneWidget);
      final confirmDeleteBtn = find.widgetWithText(ElevatedButton, 'Eliminar Gasto');
      expect(confirmDeleteBtn, findsOneWidget);

      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle();

      // Modal sheet should be closed
      expect(find.text('Detalle de Gasto'), findsNothing);

      // Clean transition to EmptyFeedState.noTransactionsInCycle
      expect(find.text('No hay gastos registrados en esta quincena'), findsOneWidget);
      expect(find.text('Escanear comprobante'), findsOneWidget);
      expect(fakeTxService.deletedIds, contains('tx-sheet-del-1'));
    });
  });
}
