import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/create_transaction_dto.dart';
import 'package:quincena/features/transactions/data/models/transaction.dart';
import 'package:quincena/features/transactions/presentation/manual/manual_expense_form_sheet.dart';

void main() {
  final testCategories = [
    const Category(
      id: 'cat-groceries',
      name: 'Supermercado',
      icon: 'shopping_cart',
      colorHex: '#ADF7B6',
      defaultAccountId: 'acc-deb',
    ),
    const Category(
      id: 'cat-dining',
      name: 'Restaurantes',
      icon: 'restaurant',
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

  Widget buildTestHost({
    required Widget child,
    Size? physicalSize,
    EdgeInsets? viewInsets,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Builder(
        builder: (context) {
          Widget current = child;
          if (viewInsets != null) {
            current = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: viewInsets,
                size: physicalSize != null
                    ? physicalSize / MediaQuery.of(context).devicePixelRatio
                    : MediaQuery.of(context).size,
              ),
              child: current,
            );
          }
          return Scaffold(body: current);
        },
      ),
    );
  }

  group('CHALLENGE 1: Amount Inputs & DecimalCurrencyInputFormatter Stress Testing', () {
    const formatter = DecimalCurrencyInputFormatter(decimalRange: 2);

    test(r'1.1 DecimalCurrencyInputFormatter: $0.001 is clamped / rejected when exceeding 2 decimals', () {
      // Starting from 0.00, attempting to add 1 -> 0.001 (rejected, keeps 0.00)
      final res = formatter.formatEditUpdate(
        const TextEditingValue(text: '0.00'),
        const TextEditingValue(text: '0.001'),
      );
      expect(res.text, '0.00');

      // Direct entry of 0.001 on empty field is rejected
      final resEmpty = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '0.001'),
      );
      expect(resEmpty.text, '');
    });

    test('1.2 DecimalCurrencyInputFormatter: commas as decimal separators (12,50) normalized to 12.50', () {
      final res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12,50'),
      );
      expect(res.text, '12.50');

      // Single comma after 12
      final resComma = formatter.formatEditUpdate(
        const TextEditingValue(text: '12'),
        const TextEditingValue(text: '12,'),
      );
      expect(resComma.text, '12.');
    });

    test('1.3 DecimalCurrencyInputFormatter: multiple dots (12.34.56) rejected', () {
      final res = formatter.formatEditUpdate(
        const TextEditingValue(text: '12.34'),
        const TextEditingValue(text: '12.34.56'),
      );
      expect(res.text, '12.34');

      final resFromEmpty = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12.34.56'),
      );
      expect(resFromEmpty.text, '');
    });

    test('1.4 DecimalCurrencyInputFormatter: extreme values like 99999999.99 allowed', () {
      final res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '99999999.99'),
      );
      expect(res.text, '99999999.99');
    });

    test(r'1.5 DecimalCurrencyInputFormatter: raw $99,999,999.99 with dollar sign and multiple commas is sanitized/rejected', () {
      // Characters like '$' and multiple commas normalized to multiple dots are rejected
      final res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: r'$99,999,999.99'),
      );
      expect(res.text, '');
    });

    testWidgets(r'1.6 Widget: Submitting $0.00 is blocked with explicit validation error', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool saveCalled = false;
      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) async {
              saveCalled = true;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '0.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Walmart Supercenter');
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(saveCalled, isFalse);
      expect(find.text('El monto debe ser mayor a 0.00'), findsOneWidget);
    });

    testWidgets(r'1.7 Widget: Extreme amount $99,999,999.99 (entered as 99999999.99) parses and submits cleanly to DTO without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      CreateTransactionDto? capturedDto;
      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) async {
              capturedDto = dto;
              return Transaction(
                id: 'tx-mega',
                userId: 'user-1',
                cycleId: dto.cycleId,
                sourceAccountId: dto.sourceAccountId,
                amount: dto.amount,
                merchantName: dto.merchantName,
                transactionDate: DateTime.parse(dto.transactionDate),
                createdAt: DateTime.now(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '99999999.99');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Inversión Inmobiliaria');
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(capturedDto, isNotNull);
      expect(capturedDto!.amount, 99999999.99);
      expect(capturedDto!.merchantName, 'Inversión Inmobiliaria');
    });

    testWidgets('1.8 Widget: Comma decimal input (12,50) submits accurately as double 12.50', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      CreateTransactionDto? capturedDto;
      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) async {
              capturedDto = dto;
              return Transaction(
                id: 'tx-comma',
                userId: 'user-1',
                cycleId: dto.cycleId,
                sourceAccountId: dto.sourceAccountId,
                amount: dto.amount,
                merchantName: dto.merchantName,
                transactionDate: DateTime.parse(dto.transactionDate),
                createdAt: DateTime.now(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '12,50');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Farmacia Cruz');
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(capturedDto, isNotNull);
      expect(capturedDto!.amount, 12.50);
    });
  });

  group('CHALLENGE 2: Merchant Names Resilience (Regex, Emojis, Long Strings)', () {
    testWidgets('2.1 Special regex characters in merchant name submit without escaping errors', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      CreateTransactionDto? capturedDto;
      const specialMerchant = r'Costco [Branch #42] (Special Deal!) $5.00 + 10% *promo* ^start? | \ {vip}';

      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) async {
              capturedDto = dto;
              return Transaction(
                id: 'tx-special',
                userId: 'user-1',
                cycleId: dto.cycleId,
                sourceAccountId: dto.sourceAccountId,
                amount: dto.amount,
                merchantName: dto.merchantName,
                transactionDate: DateTime.parse(dto.transactionDate),
                createdAt: DateTime.now(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '42.50');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), specialMerchant);
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(capturedDto, isNotNull);
      expect(capturedDto!.merchantName, specialMerchant);
    });

    testWidgets('2.2 Unicode emojis in merchant name render and submit successfully', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      CreateTransactionDto? capturedDto;
      const emojiMerchant = '🛒 Supermercado Don Pedro 🥑🌮🍻 100% Calidad';

      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) async {
              capturedDto = dto;
              return Transaction(
                id: 'tx-emoji',
                userId: 'user-1',
                cycleId: dto.cycleId,
                sourceAccountId: dto.sourceAccountId,
                amount: dto.amount,
                merchantName: dto.merchantName,
                transactionDate: DateTime.parse(dto.transactionDate),
                createdAt: DateTime.now(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '75.20');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), emojiMerchant);
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(capturedDto, isNotNull);
      expect(capturedDto!.merchantName, emojiMerchant);
    });

    testWidgets('2.3 Boundary: 120 chars allowed, 121 chars rejected by validation', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int saveCalls = 0;
      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) async {
              saveCalls++;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '30.00');

      // Test 121 chars -> Rejected
      final string121 = 'A' * 121;
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), string121);
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(saveCalls, 0);
      expect(find.text('El comercio no puede exceder 120 caracteres'), findsOneWidget);

      // Test 120 chars -> Accepted
      final string120 = 'B' * 120;
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), string120);
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(saveCalls, 1);
    });
  });

  group('CHALLENGE 3: Rapid Double-Tap on Submit CTA (Debounce & Loading Lock)', () {
    testWidgets('3.1 In-flight submit locks CTA and ignores subsequent rapid taps', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int executionCount = 0;
      final completer = Completer<Transaction>();

      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) {
              executionCount++;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '85.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Tienda Express');
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));

      // First tap triggers submission
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump(); // Start execution, setState updates _isSubmitting = true

      expect(executionCount, 1);

      // Verify button entered loading state
      final appButton = tester.widget<AppButton>(find.byKey(const Key('manual_save_button')));
      expect(appButton.isLoading, isTrue);

      // Second tap while still in-flight
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      // Third rapid tap while in-flight
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      // Ensure executionCount NEVER increased beyond 1
      expect(executionCount, 1);

      // Complete the pending request
      completer.complete(
        Transaction(
          id: 'tx-locked',
          userId: 'user-1',
          cycleId: 'cycle-1',
          sourceAccountId: 'acc-deb',
          amount: 85.0,
          merchantName: 'Tienda Express',
          transactionDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('3.2 Pre-pump rapid double tap before first frame rebuild', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int executionCount = 0;
      final completer = Completer<Transaction>();

      await tester.pumpWidget(
        buildTestHost(
          child: ManualExpenseFormSheet(
            cycleId: 'cycle-1',
            categories: testCategories,
            accounts: testAccounts,
            initialCategoryId: 'cat-groceries',
            initialAccountId: 'acc-deb',
            onSave: (dto, {force = false}) {
              executionCount++;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '85.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Tienda Express');
      await tester.ensureVisible(find.byKey(const Key('manual_save_button')));

      // Rapid double tap without pumping between taps
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.tap(find.byKey(const Key('manual_save_button')));
      await tester.pump();

      expect(executionCount, 1);

      completer.complete(
        Transaction(
          id: 'tx-locked-2',
          userId: 'user-1',
          cycleId: 'cycle-1',
          sourceAccountId: 'acc-deb',
          amount: 85.0,
          merchantName: 'Tienda Express',
          transactionDate: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  group('CHALLENGE 4: Layout Rendering on Tight Mobile Viewports with Virtual Keyboard Open', () {
    const viewports = [
      {'name': 'Compact 360x640', 'width': 360.0, 'height': 640.0, 'keyboard': 280.0},
      {'name': 'Standard 375x812 (iPhone X/11)', 'width': 375.0, 'height': 812.0, 'keyboard': 320.0},
      {'name': 'Tall 400x800', 'width': 400.0, 'height': 800.0, 'keyboard': 300.0},
    ];

    for (final vp in viewports) {
      testWidgets('4. Viewport ${vp['name']} with keyboard (${vp['keyboard']}px) has zero RenderFlex overflows and all fields scrollable', (tester) async {
        final physicalWidth = vp['width']! as double;
        final physicalHeight = vp['height']! as double;
        final keyboardHeight = vp['keyboard']! as double;

        tester.view.physicalSize = Size(physicalWidth, physicalHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildTestHost(
            physicalSize: Size(physicalWidth, physicalHeight),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
            child: ManualExpenseFormSheet(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              infoBannerMessage: 'Fallback activo desde comprobante OCR',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify header exists and is rendered
        expect(find.text('Nuevo Gasto Manual'), findsOneWidget);

        // 2. Verify all inputs exist and can be scrolled into view without any RenderFlex overflow
        final keysToVerify = [
          const Key('manual_amount_input'),
          const Key('manual_merchant_input'),
          const Key('manual_date_picker_tile'),
          const Key('manual_category_dropdown'),
          const Key('manual_account_dropdown'),
          const Key('manual_notes_input'),
          const Key('manual_save_button'),
        ];

        for (final key in keysToVerify) {
          await tester.ensureVisible(find.byKey(key));
          await tester.pump();
          expect(find.byKey(key), findsOneWidget);
        }

        // 3. Verify drag / scroll behavior inside SingleChildScrollView
        final scrollableFinder = find.byType(SingleChildScrollView);
        expect(scrollableFinder, findsOneWidget);

        // Scroll back to top
        await tester.drag(scrollableFinder, const Offset(0, 300));
        await tester.pump();
        expect(find.byKey(const Key('manual_amount_input')), findsOneWidget);

        // Scroll down to submit button
        await tester.drag(scrollableFinder, const Offset(0, -500));
        await tester.pump();
        expect(find.byKey(const Key('manual_save_button')), findsOneWidget);
      });
    }
  });
}
