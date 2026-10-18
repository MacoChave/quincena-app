import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    const Category(
      id: 'cat-archived',
      name: 'Vieja Categoría',
      icon: 'archive',
      colorHex: '#CCCCCC',
      isArchived: true,
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

  group('Adversarial Edge Cases 1: Empty History Scenarios', () {
    test('Empty history with empty merchant returns null category and account', () {
      final resEmpty = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '',
        history: [],
        categories: testCategories,
      );
      expect(resEmpty['category_id'], isNull);
      expect(resEmpty['account_id'], isNull);

      final resWhitespace = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '   \t\n  ',
        history: [],
        categories: testCategories,
      );
      expect(resWhitespace['category_id'], isNull);
      expect(resWhitespace['account_id'], isNull);
    });

    test('Empty history with completely unknown merchant returns null in suggestCategoryAndAccount', () {
      final resUnknown = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Acme Unknown XYZ 999',
        history: [],
        categories: testCategories,
      );
      expect(resUnknown['category_id'], isNull);
      expect(resUnknown['account_id'], isNull);
    });

    test('Empty history with known semantic keywords successfully resolves all categories', () {
      // Supermercado
      final resSuper = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'La Torre Zona 14',
        history: [],
        categories: testCategories,
      );
      expect(resSuper['category_id'], 'cat-super');
      expect(resSuper['account_id'], 'acc-deb');

      // Ocio & Cafe
      final resCafe = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Starbucks Coffee Las Américas',
        history: [],
        categories: testCategories,
      );
      expect(resCafe['category_id'], 'cat-ocio');
      expect(resCafe['account_id'], 'acc-cash');

      // Transporte
      final resGas = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Gasolinera Texaco El Trébol',
        history: [],
        categories: testCategories,
      );
      expect(resGas['category_id'], 'cat-trans');
      expect(resGas['account_id'], 'acc-deb');

      // Salud
      final resSalud = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Farmacia Galeno Médica',
        history: [],
        categories: testCategories,
      );
      expect(resSalud['category_id'], 'cat-salud');
      expect(resSalud['account_id'], 'acc-deb');
    });

    test('Empty history in suggestCategory falls back to first active category when unknown', () {
      final fallbackId = SuggestionEngine.suggestCategory(
        merchantName: 'Random Unmatched Shop 123',
        history: [],
        categories: testCategories,
      );
      // First active category is 'cat-super'
      expect(fallbackId, 'cat-super');
    });

    test('Empty history in suggestCategory matches category name substring when length >= 3', () {
      final resSub = SuggestionEngine.suggestCategory(
        merchantName: 'Transporte Escolar Express',
        history: [],
        categories: testCategories,
      );
      expect(resSub, 'cat-trans');

      // Substring < 3 chars must NOT falsely match
      final resShortSub = SuggestionEngine.suggestCategory(
        merchantName: 'Tr',
        history: [],
        categories: testCategories,
      );
      // 'Tr' length is 2 < 3, so it does not match 'Transporte', falls back to first active
      expect(resShortSub, 'cat-super');
    });
  });

  group('Adversarial Edge Cases 2: Single-Character & Short History Scenarios', () {
    test('1-char merchant in history matches exact 1-char incoming merchant', () {
      final history = [
        Transaction(
          id: 'tx-1-char',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-cash',
          amount: 5.0,
          merchantName: 'A',
          transactionDate: DateTime(2026, 10, 1),
          category: const TransactionCategory(
            id: 'cat-ocio',
            name: 'Ocio & Café',
          ),
        ),
      ];

      // Exact 1-character match: "A" (case-insensitive "a")
      final resExact = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'A',
        history: history,
        categories: testCategories,
      );
      expect(resExact['category_id'], 'cat-ocio');
      expect(resExact['account_id'], 'acc-cash');

      final resExactLower = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'a',
        history: history,
        categories: testCategories,
      );
      expect(resExactLower['category_id'], 'cat-ocio');
    });

    test('1-char merchant in history does NOT substring-hijack multi-char incoming merchants', () {
      final history = [
        Transaction(
          id: 'tx-char-a',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-cash',
          amount: 10.0,
          merchantName: 'A', // 1 character
          transactionDate: DateTime(2026, 10, 1),
          category: const TransactionCategory(
            id: 'cat-ocio',
            name: 'Ocio & Café',
          ),
        ),
        Transaction(
          id: 'tx-char-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-cash',
          amount: 10.0,
          merchantName: '1', // 1 character digit
          transactionDate: DateTime(2026, 10, 1),
          category: const TransactionCategory(
            id: 'cat-trans',
            name: 'Transporte',
          ),
        ),
      ];

      // "Walmart" contains 'a', but txMerchant 'a' has length 1 (< 3).
      // Must NOT match 'cat-ocio'! Must match 'cat-super' via keyword.
      final resWalmart = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Walmart',
        history: history,
        categories: testCategories,
      );
      expect(
        resWalmart['category_id'],
        'cat-super',
        reason: '1-char history "A" must not hijack "Walmart"',
      );

      // "Farmacia 1" contains both 'a' and '1'.
      // Must NOT match 'A' or '1' by substring. Must match 'cat-salud' via keyword.
      final resFarmacia = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Farmacia 1',
        history: history,
        categories: testCategories,
      );
      expect(
        resFarmacia['category_id'],
        'cat-salud',
        reason: '1-char history must not hijack "Farmacia 1"',
      );
    });

    test('1-char incoming merchant does NOT substring-match multi-char history', () {
      final history = [
        Transaction(
          id: 'tx-walmart',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 80.0,
          merchantName: 'Walmart',
          transactionDate: DateTime(2026, 10, 1),
          category: const TransactionCategory(
            id: 'cat-super',
            name: 'Supermercado',
          ),
        ),
      ];

      // Incoming "W" has length 1 (< 3). Even though "Walmart" contains "W",
      // it must not trigger substring match.
      final res = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'W',
        history: history,
        categories: testCategories,
      );
      // No keyword matches "W", so category_id should be null
      expect(
        res['category_id'],
        isNull,
        reason: '1-char incoming merchant must not substring-match multi-char history',
      );
    });

    test('2-char history: exact match succeeds, substring match blocked', () {
      final history = [
        Transaction(
          id: 'tx-ox',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-cash',
          amount: 25.0,
          merchantName: 'OX', // 2 characters
          transactionDate: DateTime(2026, 10, 1),
          category: const TransactionCategory(
            id: 'cat-ocio',
            name: 'Ocio & Café',
          ),
        ),
      ];

      // Exact match "OX"
      final resExact = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'OX',
        history: history,
        categories: testCategories,
      );
      expect(resExact['category_id'], 'cat-ocio');

      // Substring match attempt "OXXO" contains "ox"
      // But txMerchant length is 2 (< 3), so substring match is blocked
      final resSub = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'OXXO Store',
        history: history,
        categories: testCategories,
      );
      expect(
        resSub['category_id'],
        isNull,
        reason: '2-char history must not substring-match "OXXO Store"',
      );
    });

    test('History with archived category is ignored and falls back safely', () {
      final historyWithArchived = [
        Transaction(
          id: 'tx-archived',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-cash',
          amount: 50.0,
          merchantName: 'Old Store',
          transactionDate: DateTime(2026, 9, 1),
          category: const TransactionCategory(
            id: 'cat-archived',
            name: 'Vieja Categoría',
          ),
        ),
      ];

      final res = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Old Store',
        history: historyWithArchived,
        categories: testCategories,
      );
      // Archived category is filtered out, so it must not suggest 'cat-archived'
      expect(res['category_id'], isNull);
    });
  });

  group('Adversarial Edge Cases 3: Unicode, Emojis & Exotic Characters', () {
    test('Multi-byte and surrogate pair emojis in merchant names', () {
      // Grocery with cart and avocado emojis
      final res1 = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '🛒 Super Paiz 🥑',
        history: [],
        categories: testCategories,
      );
      expect(res1['category_id'], 'cat-super');

      // Coffee with croissant and hot beverage emojis
      final res2 = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '🥐 Café & Deli ☕️',
        history: [],
        categories: testCategories,
      );
      expect(res2['category_id'], 'cat-ocio');

      // Fuel with gas pump emoji
      final res3 = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '⛽️ Gasolinera Shell Express 🚗',
        history: [],
        categories: testCategories,
      );
      expect(res3['category_id'], 'cat-trans');

      // Pharmacy with pill and hospital emojis
      final res4 = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '💊 Farmacia Galeno 🏥',
        history: [],
        categories: testCategories,
      );
      expect(res4['category_id'], 'cat-salud');
    });

    test('Complex ZWJ emoji sequences and skin tone modifiers', () {
      // Family emoji (ZWJ sequence)
      final resFamily = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '👨‍👩‍👧‍👦 Supermercado Familiar',
        history: [],
        categories: testCategories,
      );
      expect(resFamily['category_id'], 'cat-super');

      // Skin tone modifier
      final resTaller = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '👍🏽 Taller Mecánico López',
        history: [],
        categories: testCategories,
      );
      expect(resTaller['category_id'], 'cat-trans');

      // Flag emojis
      final resFlag = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '🇬🇹 Panadería Guate Linda',
        history: [],
        categories: testCategories,
      );
      expect(resFlag['category_id'], 'cat-ocio');
    });

    test('Accented Spanish characters (uppercase & lowercase) normalized accurately', () {
      // Uppercase accents: SÚPERMERCADO LA UNIÓN
      final resUpperSuper = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'SÚPERMERCADO LA UNIÓN',
        history: [],
        categories: testCategories,
      );
      expect(resUpperSuper['category_id'], 'cat-super');

      // Uppercase accents: CAFETERÍA CENTRAL
      final resUpperCafe = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'CAFETERÍA CENTRAL',
        history: [],
        categories: testCategories,
      );
      expect(resUpperCafe['category_id'], 'cat-ocio');

      // Accented vowels: FARMACIA SAN JERÓNIMO
      final resFarmacia = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'FARMACIA SAN JERÓNIMO',
        history: [],
        categories: testCategories,
      );
      expect(resFarmacia['category_id'], 'cat-salud');

      // COMBINACIÓN: Abarrotería con tilde
      final resAbarroteria = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Abarrotería Don Chente',
        history: [],
        categories: testCategories,
      );
      expect(resAbarroteria['category_id'], 'cat-super');
    });

    test('Exotic scripts and regex metacharacters do not crash or corrupt state', () {
      // Regex special characters in merchant name: * + ? [ ] ( ) ^ $ . |
      final resRegex = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: r'*** [Super.Paiz] (VIP)? + $100 | ^Top ***',
        history: [],
        categories: testCategories,
      );
      expect(resRegex['category_id'], 'cat-super');

      // Non-Latin scripts (Cyrillic, Arabic, Chinese, Japanese)
      final resCyrillic = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Супермаркет Москва 123',
        history: [],
        categories: testCategories,
      );
      expect(resCyrillic, isA<Map<String, String?>>());

      final resArabic = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'سوبر ماركت الرياض',
        history: [],
        categories: testCategories,
      );
      expect(resArabic, isA<Map<String, String?>>());

      final resChinese = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '沃尔玛 超市 888',
        history: [],
        categories: testCategories,
      );
      expect(resChinese, isA<Map<String, String?>>());
    });
  });

  group('Adversarial Edge Cases 4: OcrValidationSheet Widget Integration', () {
    testWidgets('Validation Sheet initializes correctly with Unicode emojis and auto-suggests category',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ConfirmReceiptScanDto? confirmedDto;

      const scan = ReceiptScan(
        id: 'scan-emoji-test',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: '🛒 Super Paiz 🥑',
        extractedAmount: 95.50,
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
              daysRemainingInCycle: 8,
              onConfirm: (dto) async {
                confirmedDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Merchant with emojis is displayed in the input field
      expect(find.text('🛒 Super Paiz 🥑'), findsOneWidget);

      // Amount 95.50 is formatted
      expect(find.text('95.50'), findsOneWidget);

      // Confirm button submission
      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmedDto, isNotNull);
      expect(confirmedDto!.merchantName, '🛒 Super Paiz 🥑');
      expect(confirmedDto!.amount, 95.50);
      // Auto-suggested category for Super Paiz is 'cat-super'
      expect(confirmedDto!.allocationId, 'cat-super');
      // Auto-suggested account for 'cat-super' is 'acc-deb'
      expect(confirmedDto!.sourceAccountId, 'acc-deb');
    });

    testWidgets('Validation Sheet handles single-character merchant name without crash',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ConfirmReceiptScanDto? confirmedDto;

      const scan = ReceiptScan(
        id: 'scan-1char-test',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'K',
        extractedAmount: 15.00,
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
              currentAvailableBalance: 300.0,
              daysRemainingInCycle: 5,
              onConfirm: (dto) async {
                confirmedDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('K'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmedDto, isNotNull);
      expect(confirmedDto!.merchantName, 'K');
      expect(confirmedDto!.amount, 15.00);
    });
  });
}
