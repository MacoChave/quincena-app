import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/core/theme/app_colors.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/ocr/domain/services/suggestion_engine.dart';
import 'package:quincena/features/ocr/presentation/widgets/ocr_validation_sheet.dart';
import 'package:quincena/features/transactions/data/models/confirm_receipt_scan_dto.dart';
import 'package:quincena/features/transactions/data/models/receipt_scan.dart';
import 'package:quincena/features/transactions/data/models/transaction.dart';

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
    const Category(
      id: 'cat-salud',
      name: 'Salud & Farmacia',
      icon: 'local_pharmacy',
      colorHex: '#79ADDC',
      defaultAccountId: 'acc-deb',
    ),
  ];

  final testAccounts = [
    const FinancialAccount(
      id: 'acc-deb',
      name: 'Tarjeta Débito BAC',
      accountType: AccountType.checking,
      currency: 'USD',
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
      currency: 'USD',
      colorHex: '#ADF7B6',
      icon: 'payments',
      isDefault: false,
      isArchived: false,
      initialBalance: 300.0,
      currentBalance: 300.0,
    ),
  ];

  group('Adversarial SuggestionEngine Tests', () {
    test('Empty categories list returns null without throwing', () {
      // 1. suggestCategory with empty list
      final catSuggestion = SuggestionEngine.suggestCategory(
        merchantName: 'Walmart',
        categories: [],
      );
      expect(catSuggestion, isNull);

      // 2. suggestCategoryAndAccount with empty list
      final catAccSuggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Walmart',
        history: [],
        categories: [],
      );
      expect(catAccSuggestion['category_id'], isNull);
      expect(catAccSuggestion['account_id'], isNull);
    });

    test('Empty accounts list returns null without throwing', () {
      const scan = ReceiptScan(
        id: 'scan-test',
        userId: 'u1',
        storagePath: 'p1',
        confidenceScore: 0.95,
      );

      final accountSuggestion = SuggestionEngine.suggestAccount(
        scan: scan,
        categoryId: 'cat-super',
        categories: testCategories,
        accounts: [],
      );
      expect(accountSuggestion, isNull);
    });

    test('Emojis and Unicode in merchant name are handled gracefully', () {
      // Emojis with grocery keyword
      final resSuper = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '🛒 Supermercado Paiz 🥑',
        history: [],
        categories: testCategories,
      );
      expect(resSuper['category_id'], 'cat-super');

      // Accent and emoji with cafe keyword
      final resCafe = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '☕ Café & Bakery Dulce 🥐',
        history: [],
        categories: testCategories,
      );
      expect(resCafe['category_id'], 'cat-ocio');

      // Non-Latin scripts (Chinese / Arabic / Cyrillic) should not crash
      final resUnicode = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '超市 🏪 123',
        history: [],
        categories: testCategories,
      );
      expect(resUnicode, isA<Map<String, String?>>());
    });

    test('Conflicting keywords resolve deterministically according to precedence', () {
      // Merchant string containing keywords for Supermercado, Cafe, Gas, and Farmacia
      final conflictingMerchant = 'Supermercado Cafe Gasolinera Farmacia Express';
      final res = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: conflictingMerchant,
        history: [],
        categories: testCategories,
      );

      // In the implementation, 'super' is evaluated first in the if-else cascade
      expect(res['category_id'], 'cat-super');
      expect(res['account_id'], 'acc-deb');
    });

    test('Adversarial History: Empty merchant in transaction history does NOT hijack unrelated scans', () {
      // If a transaction in history has an empty merchantName, clean.contains("") is true in Dart!
      // This test stress-tests whether an empty merchant transaction hijacks category suggestion.
      final adversarialHistory = [
        Transaction(
          id: 'tx-bogus',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-cash',
          amount: 50.0,
          merchantName: '', // Adversarial empty string
          transactionDate: DateTime(2026, 10, 1),
          category: const TransactionCategory(
            id: 'cat-ocio',
            name: 'Ocio & Café',
          ),
        ),
      ];

      final res = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Supermercado La Torre',
        history: adversarialHistory,
        categories: testCategories,
      );

      // It must suggest Supermercado (via keywords), NOT hijack into 'cat-ocio'
      expect(
        res['category_id'],
        'cat-super',
        reason: 'Empty merchant in past history must not cause clean.contains("") to match false positives',
      );
    });

    test('Adversarial History: Whitespace-only merchant in history does NOT hijack incoming scans', () {
      final adversarialHistory = [
        Transaction(
          id: 'tx-spaces',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-cash',
          amount: 15.0,
          merchantName: '   ', // Adversarial whitespace
          transactionDate: DateTime(2026, 10, 2),
          category: const TransactionCategory(
            id: 'cat-salud',
            name: 'Salud & Farmacia',
          ),
        ),
      ];

      final res = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Gasolinera Shell',
        history: adversarialHistory,
        categories: testCategories,
      );

      expect(
        res['category_id'],
        'cat-trans',
        reason: 'Whitespace-only merchant in past history must not hijack gasolinera to salud',
      );
    });
  });

  group('Adversarial Runway Balance & Coral Deficit Banner Tests', () {
    testWidgets('Deficit banner displays coral (#FFC09F) when available balance is ZERO',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const scan = ReceiptScan(
        id: 'scan-def-1',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'La Torre',
        extractedAmount: 65.00,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 0.0, // Available is exactly ZERO
              daysRemainingInCycle: 7,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify deficit warning text
      expect(
        find.textContaining('Alerta: Este gasto provocará un sobregiro'),
        findsWidgets,
      );
      expect(
        find.textContaining('sobregiro de \$65.00'),
        findsOneWidget,
      );

      // Verify coral border/background styling (#FFC09F)
      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCoralBanner = containers.any((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          final border = dec.border;
          if (border is Border) {
            return border.top.color == AppColors.expenseBg;
          }
        }
        return false;
      });
      expect(hasCoralBanner, isTrue, reason: 'Banner must use coral AppColors.expenseBg (#FFC09F)');
    });

    testWidgets('Deficit banner displays coral (#FFC09F) when available balance is NEGATIVE',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const scan = ReceiptScan(
        id: 'scan-def-2',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Farmacia Galeno',
        extractedAmount: 25.00,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: -40.0, // Already negative balance
              daysRemainingInCycle: 5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Projected balance: -40 - 25 = -65.00
      expect(
        find.textContaining('sobregiro de \$65.00'),
        findsOneWidget,
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasCoralBanner = containers.any((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          final border = dec.border;
          if (border is Border) {
            return border.top.color == AppColors.expenseBg;
          }
        }
        return false;
      });
      expect(hasCoralBanner, isTrue);
    });

    testWidgets('Deficit banner displays coral (#FFC09F) when transaction exceeds positive balance',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const scan = ReceiptScan(
        id: 'scan-def-3',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Electrónica Max',
        extractedAmount: 750.00,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 200.0, // 200 - 750 = -550
              daysRemainingInCycle: 10,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('sobregiro de \$550.00'),
        findsOneWidget,
      );
    });

    testWidgets('Surplus banner (non-deficit) when transaction is within balance',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const scan = ReceiptScan(
        id: 'scan-surplus',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Paiz',
        extractedAmount: 100.00,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0, // 500 - 100 = 400
              daysRemainingInCycle: 6,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must NOT contain sobregiro
      expect(find.textContaining('sobregiro'), findsNothing);
      expect(
        find.textContaining('Tu saldo disponible pasará de \$500.00 a \$400.00'),
        findsOneWidget,
      );
    });

    testWidgets('Exact zero remaining balance does NOT trigger deficit alert',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const scan = ReceiptScan(
        id: 'scan-exact-zero',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Gasolinera Texaco',
        extractedAmount: 50.00,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 50.0, // 50 - 50 = 0.00
              daysRemainingInCycle: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero remaining is balanced, not deficit
      expect(find.textContaining('sobregiro'), findsNothing);
      expect(
        find.textContaining('Tu saldo disponible pasará de \$50.00 a \$0.00'),
        findsOneWidget,
      );
    });

    testWidgets('Dynamic recalculation: typing a higher amount switches banner from surplus to deficit',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const scan = ReceiptScan(
        id: 'scan-dyn',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Supermercado',
        extractedAmount: 50.00,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 100.0, // Initially 100 - 50 = 50 (surplus)
              daysRemainingInCycle: 4,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Tu saldo disponible pasará de \$100.00 a \$50.00'), findsOneWidget);

      // Now enter 150.00 in the amount field (100 - 150 = -50 deficit)
      await tester.enterText(find.byKey(const Key('ocr_amount_input')), '150.00');
      await tester.pumpAndSettle();

      expect(find.textContaining('sobregiro de \$50.00'), findsOneWidget);
    });
  });

  group('Adversarial Validation Sheet Form Validation Tests', () {
    testWidgets('Validation blocks submission when amount is \$0.00',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool confirmed = false;

      const scan = ReceiptScan(
        id: 'scan-zero-amt',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Café Bar',
        extractedAmount: 0.0,
        confidenceScore: 0.90,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (_) async {
                confirmed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure amount field is 0.00 or empty
      await tester.enterText(find.byKey(const Key('ocr_amount_input')), '0.00');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmed, isFalse, reason: 'Must not confirm with amount \$0.00');
      expect(find.text('El monto debe ser mayor a 0.00'), findsOneWidget);
    });

    testWidgets('Validation blocks submission when amount is negative',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool confirmed = false;

      const scan = ReceiptScan(
        id: 'scan-neg-amt',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Café Bar',
        extractedAmount: 10.0,
        confidenceScore: 0.90,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (_) async {
                confirmed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('ocr_amount_input')), '-45.50');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmed, isFalse, reason: 'Must not confirm with negative amount');
      expect(find.text('El monto debe ser mayor a 0.00'), findsOneWidget);
    });

    testWidgets('Validation blocks submission when merchant name is missing or whitespace',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool confirmed = false;

      const scan = ReceiptScan(
        id: 'scan-missing-merch',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: '',
        extractedAmount: 50.0,
        confidenceScore: 0.90,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (_) async {
                confirmed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear merchant input or enter whitespace
      await tester.enterText(find.byKey(const Key('ocr_merchant_input')), '   ');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmed, isFalse, reason: 'Must not confirm with empty/whitespace merchant name');
      expect(find.text('El comercio es obligatorio'), findsOneWidget);
    });

    testWidgets('Validation blocks submission when no account is selected',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool confirmed = false;

      const scan = ReceiptScan(
        id: 'scan-no-account',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Comercio General',
        extractedAmount: 50.0,
        confidenceScore: 0.90,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: [], // Empty accounts list prevents auto-selection
              currentAvailableBalance: 500.0,
              onConfirm: (_) async {
                confirmed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmed, isFalse, reason: 'Must not confirm without an account selected');
      expect(find.text('Seleccione una cuenta de débito'), findsOneWidget);
    });
  });

  group('Adversarial Date Picker & Edge Dates Tests', () {
    testWidgets('Leap year February 29, 2024 is correctly displayed and serialized',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ConfirmReceiptScanDto? confirmedDto;

      final leapYearDate = DateTime(2024, 2, 29);
      final scan = ReceiptScan(
        id: 'scan-leap-2024',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Walmart',
        extractedAmount: 120.0,
        extractedDate: leapYearDate,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (dto) async {
                confirmedDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify date display formatting: '29 Febrero, 2024'
      expect(find.text('29 Febrero, 2024'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmedDto, isNotNull);
      expect(confirmedDto!.transactionDate, '2024-02-29');
    });

    testWidgets('Future leap year February 29, 2028 is correctly serialized',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ConfirmReceiptScanDto? confirmedDto;

      final leapYear2028 = DateTime(2028, 2, 29);
      final scan = ReceiptScan(
        id: 'scan-leap-2028',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Shell',
        extractedAmount: 85.0,
        extractedDate: leapYear2028,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (dto) async {
                confirmedDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('29 Febrero, 2028'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmedDto, isNotNull);
      expect(confirmedDto!.transactionDate, '2028-02-29');
    });

    testWidgets('Century boundary / non-leap year (e.g. 2100) or historical receipts handling',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Century year 2000 was a leap year, but 1900/2100 are not.
      // Date bounds in _pickDate are [DateTime(2020), DateTime.now() + 365 days].
      // Verify date presentation and serialization for December 31 boundary
      final boundaryDate = DateTime(2025, 12, 31);
      final scan = ReceiptScan(
        id: 'scan-boundary',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'La Torre',
        extractedAmount: 50.0,
        extractedDate: boundaryDate,
        confidenceScore: 0.95,
      );

      ConfirmReceiptScanDto? confirmedDto;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (dto) async {
                confirmedDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('31 Diciembre, 2025'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmedDto, isNotNull);
      expect(confirmedDto!.transactionDate, '2025-12-31');
    });
  });
}
