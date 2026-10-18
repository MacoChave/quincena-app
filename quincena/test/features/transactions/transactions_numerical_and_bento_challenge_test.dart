import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/feed_analytics_bento.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/grouped_feed_view.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/transaction_card.dart';
import 'package:quincena/features/transactions/presentation/feed/widgets/transaction_detail_sheet.dart';

/// Fake HTTP client for TransactionDetailSheet API service dependency
class _MockTransactionHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final responseBytes = utf8.encode(jsonEncode({'message': 'ok'}));
    return http.StreamedResponse(
      Stream.value(responseBytes),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Helper to build test transactions with exact numeric parameters
Transaction _buildTx({
  String id = 'tx-test',
  required double amount,
  DateTime? date,
  String merchant = 'Comercio Test',
  TransactionType type = TransactionType.expense,
  EntryMethod method = EntryMethod.manual,
  String? receiptScanId,
}) {
  return Transaction(
    id: id,
    userId: 'user-adversarial-1',
    cycleId: 'cycle-2026-10-b',
    sourceAccountId: 'acc-1',
    amount: amount,
    merchantName: merchant,
    transactionDate: date ?? DateTime(2026, 10, 18, 12, 0),
    transactionType: type,
    entryMethod: method,
    receiptScanId: receiptScanId,
    category: const TransactionCategory(
      id: 'cat-test',
      name: 'Supermercado',
      icon: 'shopping_cart',
      colorHex: '#79ADDC',
    ),
    sourceAccount: const TransactionSourceAccount(
      id: 'acc-1',
      name: 'Tarjeta Débito',
      colorHex: '#79ADDC',
    ),
  );
}

/// Helper to check for FontFeature.tabularFigures ('tnum') in a TextStyle
bool _hasTabularFigures(TextStyle? style) {
  if (style == null || style.fontFeatures == null) return false;
  return style.fontFeatures!.any((f) => f.feature == 'tnum');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient mockApiClient;
  late TransactionApiService mockApiService;

  setUpAll(() {
    mockApiClient = ApiClient(
      baseUrl: 'http://localhost:3000/v1',
      httpClient: _MockTransactionHttpClient(),
    );
    mockApiService = TransactionApiService(mockApiClient);
  });

  // =========================================================================
  // SUITE 1: DAY TOTALS COMPUTATION & IEEE-754 FLOATING-POINT PRECISION
  // =========================================================================
  group('Empirical Challenge 1: Day Totals & Zero IEEE-754 Drift', () {
    test(
        r'Calculates exact sum for 100 fractional items: $0.01 + $0.02 + ... + $1.00 ($50.50)',
        () {
      // Mathematical sum: n*(n+1)/2 = 100 * 101 / 2 = 5050 cents = $50.50
      final txList = List.generate(100, (i) {
        final amount = (i + 1) / 100.0;
        return _buildTx(
          id: 'tx-cent-$i',
          amount: amount,
          date: DateTime(2026, 10, 18, 10, 0 + (i % 60)),
        );
      });

      final sections = GroupedDateSection.groupTransactions(
        txList,
        referenceDate: DateTime(2026, 10, 18),
      );

      expect(sections.length, 1);
      final section = sections.first;

      // Assert zero IEEE-754 drift (e.g. no 50.50000000000003 or 50.49999999999997)
      expect(section.dayTotal, 50.50);
      expect(section.dayTotal.toStringAsFixed(2), '50.50');
      expect(section.headerTitle, 'Hoy - 18 Octubre');
    });

    test(
        r'Floating-point representation trap: 100 items of $0.07 results in exactly $7.00',
        () {
      // In raw double arithmetic: 0.07 * 100 == 7.000000000000001
      final txList = List.generate(100, (i) {
        return _buildTx(
          id: 'tx-007-$i',
          amount: 0.07,
          date: DateTime(2026, 10, 18, 8, 30),
        );
      });

      final sections = GroupedDateSection.groupTransactions(
        txList,
        referenceDate: DateTime(2026, 10, 18),
      );

      expect(sections.length, 1);
      final section = sections.first;

      expect(section.dayTotal, 7.00);
      expect(section.dayTotal.toStringAsFixed(2), '7.00');
    });

    test(
        r'Floating-point representation trap: 100 items of $0.29 results in exactly $29.00',
        () {
      final txList = List.generate(100, (i) {
        return _buildTx(
          id: 'tx-029-$i',
          amount: 0.29,
          date: DateTime(2026, 10, 18, 11, 15),
        );
      });

      final sections = GroupedDateSection.groupTransactions(
        txList,
        referenceDate: DateTime(2026, 10, 18),
      );

      expect(sections.length, 1);
      expect(sections.first.dayTotal, 29.00);
    });

    test(
        'Stress Oracle: 1000 randomized cent amounts match exact integer cents sum',
        () {
      final rng = Random(42);
      int expectedTotalCents = 0;
      final txList = <Transaction>[];

      for (int i = 0; i < 1000; i++) {
        // Random amount between 1 cent ($0.01) and 9999 cents ($99.99)
        final cents = rng.nextInt(9999) + 1;
        expectedTotalCents += cents;
        final amount = cents / 100.0;

        txList.add(_buildTx(
          id: 'tx-rand-$i',
          amount: amount,
          date: DateTime(2026, 10, 18, 12, 0),
        ));
      }

      final sections = GroupedDateSection.groupTransactions(
        txList,
        referenceDate: DateTime(2026, 10, 18),
      );

      expect(sections.length, 1);
      final expectedTotal = expectedTotalCents / 100.0;
      expect(sections.first.dayTotal, expectedTotal);
      expect(sections.first.dayTotal.toStringAsFixed(2),
          expectedTotal.toStringAsFixed(2));
    });

    test('Multi-day chronological grouping and sorting preserves day boundaries',
        () {
      final refDate = DateTime(2026, 10, 18);
      final txToday1 = _buildTx(
        id: 't-today-1',
        amount: 15.50,
        date: DateTime(2026, 10, 18, 14, 0),
      );
      final txToday2 = _buildTx(
        id: 't-today-2',
        amount: 24.50,
        date: DateTime(2026, 10, 18, 9, 30),
      );
      final txYesterday = _buildTx(
        id: 't-yesterday',
        amount: 100.00,
        date: DateTime(2026, 10, 17, 18, 20),
      );
      final txOlder = _buildTx(
        id: 't-older',
        amount: 55.75,
        date: DateTime(2026, 10, 15, 12, 0),
      );

      final sections = GroupedDateSection.groupTransactions(
        [txYesterday, txToday2, txOlder, txToday1],
        referenceDate: refDate,
      );

      expect(sections.length, 3);

      // Section 1: Today
      expect(sections[0].headerTitle, 'Hoy - 18 Octubre');
      expect(sections[0].dayTotal, 40.00); // 15.50 + 24.50
      expect(sections[0].transactions.first.id, 't-today-1'); // latest first

      // Section 2: Yesterday
      expect(sections[1].headerTitle, 'Ayer - 17 Octubre');
      expect(sections[1].dayTotal, 100.00);

      // Section 3: Older
      expect(sections[2].headerTitle, '15 Octubre 2026');
      expect(sections[2].dayTotal, 55.75);
    });

    test('Edge case: Empty list and single cent transaction', () {
      expect(GroupedDateSection.groupTransactions([]), isEmpty);

      final singleTx = _buildTx(
        id: 't-single',
        amount: 0.01,
        date: DateTime(2026, 10, 18, 10, 0),
      );
      final sections = GroupedDateSection.groupTransactions(
        [singleTx],
        referenceDate: DateTime(2026, 10, 18),
      );

      expect(sections.length, 1);
      expect(sections.first.dayTotal, 0.01);
      expect(sections.first.dayTotal.toStringAsFixed(2), '0.01');
    });

    testWidgets('DateSectionHeader renders exact negative signed day total with tabular figures',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DateSectionHeader(
              title: 'Hoy - 18 Octubre',
              dayTotal: 50.50,
            ),
          ),
        ),
      );

      final titleFinder = find.text('Hoy - 18 Octubre');
      final amountFinder = find.text(r'-$50.50');

      expect(titleFinder, findsOneWidget);
      expect(amountFinder, findsOneWidget);

      final amountText = tester.widget<Text>(amountFinder);
      expect(_hasTabularFigures(amountText.style), isTrue);
    });
  });

  // =========================================================================
  // SUITE 2: FEED ANALYTICS BENTO METRICS & EDGE CASES
  // =========================================================================
  group('Empirical Challenge 2: FeedAnalyticsBento Edge Cases & Metrics', () {
    testWidgets(
        r'Case 1: $0.00 spent renders "En meta", zero daily average, blue progress bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: 0.00,
              totalBudgeted: 2500.00,
              daysElapsed: 5,
              totalDays: 15,
              ocrReceiptsCount: 0,
              availableBalance: 2500.00,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Status pill check
      expect(find.text('En meta'), findsOneWidget);
      expect(find.text('RITMO DE GASTO QUINCENAL'), findsOneWidget);

      // Hero Currency
      expect(find.text(r'$0.00'), findsOneWidget);

      // Days description
      expect(find.text('Total ejecutado en 5 días de ciclo'), findsOneWidget);

      // Sub-metrics
      expect(find.text(r'$0.00 / día'), findsOneWidget);
      expect(find.text('0 comprobantes'), findsOneWidget);

      // Progress bar color: < 70% must be AppColors.primary (#79ADDC)
      final animContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = animContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary);
    });

    testWidgets(
        'Case 2A: Negative available balance (overdrawn cycle) triggers "Sobrepasado" immediately',
        (WidgetTester tester) async {
      // Even if spent ratio is only 40% (1000/2500), availableBalance < 0 must force overspent status
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: 1000.00,
              totalBudgeted: 2500.00,
              daysElapsed: 5,
              totalDays: 15,
              availableBalance: -150.00, // Deficit / Overdrawn
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sobrepasado'), findsOneWidget);
      expect(find.text('En meta'), findsNothing);
      expect(find.text('Alerta'), findsNothing);

      // Since spent/budget ratio is 40% (<70%), progress bar remains AppColors.primary (#79ADDC)
      final animContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = animContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.primary);
    });

    testWidgets(
        r'Case 2B: Severe overspending ($3,500 of $2,500) clamps progress bar and uses Coral color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: 3500.00,
              totalBudgeted: 2500.00,
              daysElapsed: 15,
              totalDays: 15,
              availableBalance: -1000.00,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sobrepasado'), findsOneWidget);
      expect(find.text(r'$3,500.00'), findsOneWidget);

      // Progress bar color: > 90% must be AppColors.expenseBg (#FFC09F)
      final animContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = animContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.expenseBg);
    });

    testWidgets(
        r'Case 3: Exactly 100% budget spent ($2,500 of $2,500) renders "Sobrepasado" with Coral fill',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: 2500.00,
              totalBudgeted: 2500.00,
              daysElapsed: 15,
              totalDays: 15,
              availableBalance: 0.00,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sobrepasado'), findsOneWidget);
      expect(find.text(r'$2,500.00'), findsOneWidget);

      final animContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = animContainer.decoration as BoxDecoration;
      expect(decoration.color, AppColors.expenseBg);
    });

    testWidgets(
        r'Extreme edge case: Zero budgeted ($0.00) does not divide by zero or crash',
        (WidgetTester tester) async {
      // 0 spent of 0 budget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: 0.00,
              totalBudgeted: 0.00,
              daysElapsed: 0,
              totalDays: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('En meta'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // $50 spent of 0 budget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: 50.00,
              totalBudgeted: 0.00,
              daysElapsed: -2,
              totalDays: 15,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sobrepasado'), findsOneWidget);
      expect(find.text(r'$50.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Proportional pace status rules correctly flag accelerated spending as warning', () {
      // 60% spent on Day 2 of 15 days is accelerated pace
      const bentoEarlyWarning = FeedAnalyticsBento(
        totalSpent: 600.0,
        totalBudgeted: 1000.0,
        daysElapsed: 2,
        totalDays: 15,
      );
      expect(bentoEarlyWarning.paceStatus, ExpensePaceStatus.warning);

      // 60% spent on Day 14 of 15 days is safe/on track
      const bentoLateNormal = FeedAnalyticsBento(
        totalSpent: 600.0,
        totalBudgeted: 1000.0,
        daysElapsed: 14,
        totalDays: 15,
      );
      expect(bentoLateNormal.paceStatus, ExpensePaceStatus.onTrack);
    });
  });

  // =========================================================================
  // SUITE 3: FONT FEATURE TABULAR FIGURES ('tnum') INVARIANT VERIFICATION
  // =========================================================================
  group('Empirical Challenge 3: Tabular Figures Verification on Feed Amounts', () {
    testWidgets(
        'TransactionCard applies FontFeature.tabularFigures() on expense amounts',
        (WidgetTester tester) async {
      final tx = _buildTx(
        id: 'tx-card-1',
        amount: 48.50,
        type: TransactionType.expense,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: tx),
          ),
        ),
      );

      final amountFinder = find.text(r'-$48.50');
      expect(amountFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(amountFinder);
      expect(_hasTabularFigures(textWidget.style), isTrue,
          reason: 'TransactionCard amount must include FontFeature.tabularFigures()');
    });

    testWidgets(
        'TransactionCard applies FontFeature.tabularFigures() on positive income adjustments',
        (WidgetTester tester) async {
      final tx = _buildTx(
        id: 'tx-income-1',
        amount: 250.00,
        type: TransactionType.incomeAdjustment,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionCard(transaction: tx),
          ),
        ),
      );

      final amountFinder = find.text(r'+$250.00');
      expect(amountFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(amountFinder);
      expect(_hasTabularFigures(textWidget.style), isTrue);
    });

    testWidgets(
        'FeedAnalyticsBento applies tabular figures to Hero currency and sub-metrics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: 1050.00,
              totalBudgeted: 2500.00,
              daysElapsed: 5,
              totalDays: 15,
              ocrReceiptsCount: 7,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Hero Currency text ($1,050.00)
      final heroFinder = find.text(r'$1,050.00');
      expect(heroFinder, findsOneWidget);
      final heroText = tester.widget<Text>(heroFinder);
      expect(_hasTabularFigures(heroText.style), isTrue,
          reason: 'Bento hero currency must have FontFeature.tabularFigures()');

      // 2. Daily average text ($210.00 / día)
      final avgFinder = find.text(r'$210.00 / día');
      expect(avgFinder, findsOneWidget);
      final avgText = tester.widget<Text>(avgFinder);
      expect(_hasTabularFigures(avgText.style), isTrue,
          reason: 'Bento daily average must have FontFeature.tabularFigures()');

      // 3. Capturas count text (7 comprobantes)
      final ocrFinder = find.text('7 comprobantes');
      expect(ocrFinder, findsOneWidget);
      final ocrText = tester.widget<Text>(ocrFinder);
      expect(_hasTabularFigures(ocrText.style), isTrue,
          reason: 'Bento OCR count must have FontFeature.tabularFigures()');
    });

    testWidgets(
        'TransactionDetailSheet hero amount applies FontFeature.tabularFigures()',
        (WidgetTester tester) async {
      final tx = _buildTx(
        id: 'tx-detail-1',
        amount: 199.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionDetailSheet(
              transaction: tx,
              transactionApiService: mockApiService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heroAmountFinder = find.text(r'-$199.95');
      expect(heroAmountFinder, findsOneWidget);

      final heroText = tester.widget<Text>(heroAmountFinder);
      expect(_hasTabularFigures(heroText.style), isTrue,
          reason: 'Detail Sheet hero amount must have tabular figures');
    });

    testWidgets(
        'Fast-scroll stress harness: 100 TransactionCards with variable figure widths render jitter-free',
        (WidgetTester tester) async {
      // Alternating narrow ('1') and wide ('8') numbers to stress layout stability
      final txList = List.generate(100, (i) {
        final amount = (i % 2 == 0) ? 1111.11 : 8888.88;
        return _buildTx(
          id: 'tx-scroll-$i',
          amount: amount,
          merchant: 'Merchant $i',
          date: DateTime(2026, 10, 18, 10, i % 60),
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: txList.length,
              itemBuilder: (context, index) {
                return TransactionCard(transaction: txList[index]);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rapidly fling down and up
      await tester.fling(find.byType(ListView), const Offset(0, -800), 3000);
      await tester.pumpAndSettle();

      await tester.fling(find.byType(ListView), const Offset(0, 800), 3000);
      await tester.pumpAndSettle();

      // Zero exceptions occurred
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // SUITE 4: PROGRESS BAR COLOR SHIFTS (<70% BLUE, 70-90% YELLOW, >90% CORAL)
  // =========================================================================
  group('Empirical Challenge 4: Progress Bar Color Shifts & Threshold Boundaries', () {
    const budget = 1000.0;

    Future<Color> getRenderedBarColor(WidgetTester tester, double spent) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBento(
              totalSpent: spent,
              totalBudgeted: budget,
              daysElapsed: 8,
              totalDays: 15,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = animContainer.decoration as BoxDecoration;
      return decoration.color!;
    }

    testWidgets('Under 70% threshold: renders Blue (#79ADDC)', (WidgetTester tester) async {
      // 0.0% spent
      expect(await getRenderedBarColor(tester, 0.0), AppColors.primary);
      // 35.0% spent ($350)
      expect(await getRenderedBarColor(tester, 350.0), AppColors.primary);
      // 69.9% spent ($699)
      expect(await getRenderedBarColor(tester, 699.0), AppColors.primary);
      // 69.99% spent ($699.90)
      expect(await getRenderedBarColor(tester, 699.90), AppColors.primary);
    });

    testWidgets('70% - 90% threshold: renders Yellow (#FFEE93)', (WidgetTester tester) async {
      // Exact 70.0% ($700)
      expect(await getRenderedBarColor(tester, 700.0), AppColors.warningBg);
      // 80.0% spent ($800)
      expect(await getRenderedBarColor(tester, 800.0), AppColors.warningBg);
      // 89.9% spent ($899)
      expect(await getRenderedBarColor(tester, 899.0), AppColors.warningBg);
      // 89.99% spent ($899.90)
      expect(await getRenderedBarColor(tester, 899.90), AppColors.warningBg);
    });

    testWidgets('>= 90% threshold: renders Coral (#FFC09F)', (WidgetTester tester) async {
      // Exact 90.0% ($900)
      expect(await getRenderedBarColor(tester, 900.0), AppColors.expenseBg);
      // 95.0% spent ($950)
      expect(await getRenderedBarColor(tester, 950.0), AppColors.expenseBg);
      // Exact 100.0% ($1000)
      expect(await getRenderedBarColor(tester, 1000.0), AppColors.expenseBg);
      // 130.0% overspent ($1300)
      expect(await getRenderedBarColor(tester, 1300.0), AppColors.expenseBg);
    });

    test('Color tokens match exact hexadecimal design system requirements', () {
      expect(AppColors.primary, const Color(0xFF79ADDC));
      expect(AppColors.warningBg, const Color(0xFFFFEE93));
      expect(AppColors.expenseBg, const Color(0xFFFFC09F));
    });
  });
}
