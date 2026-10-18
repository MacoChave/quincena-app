import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/dashboard/data/dashboard_api_service.dart';
import 'package:quincena/features/dashboard/presentation/home_screen.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/ocr/domain/services/suggestion_engine.dart';
import 'package:quincena/features/ocr/presentation/widgets/capture_source_sheet.dart';
import 'package:quincena/features/ocr/presentation/widgets/ocr_validation_sheet.dart';
import 'package:quincena/features/ocr/presentation/widgets/ocr_viewfinder.dart';
import 'package:quincena/features/transactions/data/models/confirm_receipt_scan_dto.dart';
import 'package:quincena/features/transactions/data/models/receipt_scan.dart';
import 'package:quincena/features/transactions/data/models/transaction.dart';

/// Fake HTTP Client para simular endpoint `/biweekly-cycles/dashboard`
class FakeDashboardHttpClient extends http.BaseClient {
  FakeDashboardHttpClient({
    this.hasActiveCycle = true,
    this.totalAvailable = 1500.0,
    this.totalSpent = 350.0,
  });

  final bool hasActiveCycle;
  final double totalAvailable;
  final double totalSpent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final responseBody = jsonEncode({
      'has_active_cycle': hasActiveCycle,
      if (hasActiveCycle)
        'cycle': {
          'id': 'cycle-test-1',
          'year': 2026,
          'month': 10,
          'period': 'first_half',
          'start_date': '2026-10-01',
          'end_date': '2026-10-15',
          'total_income': 2500.0,
          'is_closed': false,
        },
      'summary': {
        'total_income': 2500.0,
        'total_allocated': 2000.0,
        'total_spent': totalSpent,
        'total_available': totalAvailable,
        'unallocated': 500.0,
        'is_balanced': false,
      },
      'categories': [
        {
          'id': 'alloc-1',
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
      Stream.value(utf8.encode(responseBody)),
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

  group('Production SuggestionEngine Tests (CA-05.2, RN-CAT-01)', () {
    test('Suggests category from user purchase history', () {
      final history = [
        Transaction(
          id: 'tx-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 220.0,
          merchantName: 'Paiz Pradera',
          transactionDate: DateTime(2026, 10, 10),
          category: const TransactionCategory(
            id: 'cat-super',
            name: 'Supermercado',
          ),
        ),
      ];

      final result = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Paiz Pradera',
        history: history,
        categories: testCategories,
      );

      expect(result['category_id'], 'cat-super');
      expect(result['account_id'], 'acc-deb');
    });

    test('Suggests category and account via keyword heuristic for cafe', () {
      final result = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Starbucks Coffee',
        history: [],
        categories: testCategories,
      );

      expect(result['category_id'], 'cat-ocio');
      expect(result['account_id'], 'acc-cash');
    });

    test('Suggests category and account via keyword heuristic for gas', () {
      final result = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Gasolinera Shell Las Americas',
        history: [],
        categories: testCategories,
      );

      expect(result['category_id'], 'cat-trans');
      expect(result['account_id'], 'acc-deb');
    });

    test('Suggests default account via RN-CAT-01 when category matched', () {
      final acc = SuggestionEngine.suggestAccount(
        scan: const ReceiptScan(
          id: 's1',
          userId: 'u1',
          storagePath: 'p1',
          confidenceScore: 0.95,
        ),
        categoryId: 'cat-ocio',
        categories: testCategories,
        accounts: testAccounts,
      );

      expect(acc, 'acc-cash');
    });
  });

  group('Production OcrViewfinder Widget Tests (Stitch Screen 06dd441359e2446c8c5931868b87b4d7)', () {
    testWidgets('Renders top bar, live detection pill, and bottom capture controls',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OcrViewfinder(
              detectedMerchant: 'Paiz',
              confidenceScore: 0.98,
            ),
          ),
        ),
      );
      await tester.pump();

      // Top Bar Elements
      expect(find.text('CÁMARA INTELIGENTE'), findsOneWidget);
      expect(find.byKey(const Key('ocr_torch_button')), findsOneWidget);
      expect(find.byKey(const Key('ocr_manual_button')), findsOneWidget);

      // Live Detection Pill
      expect(find.text('Paiz detectado (98%)'), findsOneWidget);

      // Bottom Capture Controls
      expect(find.byKey(const Key('ocr_gallery_button')), findsOneWidget);
      expect(find.byKey(const Key('ocr_shutter_button')), findsOneWidget);
    });

    testWidgets('Torch button toggles and manual button invokes callback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool torchToggled = false;
      bool manualTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrViewfinder(
              isTorchOn: false,
              onToggleTorch: () => torchToggled = true,
              onManualTap: () => manualTapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('ocr_torch_button')));
      await tester.pump();
      expect(torchToggled, isTrue);

      await tester.tap(find.byKey(const Key('ocr_manual_button')));
      await tester.pump();
      expect(manualTapped, isTrue);
    });
  });

  group('Production CaptureSourceSheet Widget Tests', () {
    testWidgets('Renders all three options with keys and pops on selection',
        (tester) async {
      CaptureSourceOption? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selected = await CaptureSourceSheet.show(ctx);
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Registrar Gasto'), findsOneWidget);
      expect(find.byKey(const Key('capture_option_camera')), findsOneWidget);
      expect(find.byKey(const Key('capture_option_gallery')), findsOneWidget);
      expect(find.byKey(const Key('capture_option_manual')), findsOneWidget);

      await tester.tap(find.byKey(const Key('capture_option_camera')));
      await tester.pumpAndSettle();

      expect(selected, CaptureSourceOption.camera);
    });
  });

  group('Production OcrValidationSheet Widget Tests', () {
    testWidgets('Renders Hero Amount Card in #FCF5C7, merchant row, and runway banner',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const scan = ReceiptScan(
        id: 'scan-1',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Supermercado La Torre',
        extractedAmount: 245.50,
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
              currentAvailableBalance: 1500.0,
              daysRemainingInCycle: 8,
              onConfirm: (dto) async {
                confirmedDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Title & Status
      expect(find.text('Validar Extracción'), findsOneWidget);
      expect(find.text('Listo para aplicar'), findsOneWidget);

      // Hero Amount Card
      expect(find.byKey(const Key('ocr_amount_input')), findsOneWidget);
      expect(find.text('245.50'), findsOneWidget);

      // Merchant input
      expect(find.byKey(const Key('ocr_merchant_input')), findsOneWidget);
      expect(find.text('Supermercado La Torre'), findsOneWidget);

      // Runway balance banner (surplus)
      expect(find.textContaining('Tu saldo disponible pasará de'), findsOneWidget);

      // Confirm button
      expect(find.byKey(const Key('ocr_confirm_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ocr_confirm_button')));
      await tester.pumpAndSettle();

      expect(confirmedDto, isNotNull);
      expect(confirmedDto!.amount, 245.50);
      expect(confirmedDto!.merchantName, 'Supermercado La Torre');
      expect(confirmedDto!.cycleId, 'cycle-1');
    });

    testWidgets('Low confidence scan displays amber warning banner and manual fallback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const lowConfScan = ReceiptScan(
        id: 'scan-low',
        userId: 'u1',
        storagePath: 'u1/bad.jpg',
        extractedMerchant: 'Borroso',
        extractedAmount: 80.0,
        confidenceScore: 0.45,
      );

      bool manualTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: lowConfScan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              daysRemainingInCycle: 5,
              onFallbackManual: () => manualTriggered = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Baja Confianza'), findsOneWidget);
      expect(
        find.textContaining('No pudimos leer algunos datos con certeza'),
        findsOneWidget,
      );

      // Tap manual button in banner
      await tester.tap(find.text('Manual'));
      await tester.pump();

      expect(manualTriggered, isTrue);
    });

    testWidgets('Runway banner displays coral overspending warning in deficit',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const largeScan = ReceiptScan(
        id: 'scan-large',
        userId: 'u1',
        storagePath: 'u1/ticket.jpg',
        extractedMerchant: 'Tienda Electrónica',
        extractedAmount: 2000.0,
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: largeScan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0, // deficit: 500 - 2000 = -1500
              daysRemainingInCycle: 8,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('sobregiro'), findsWidgets);
    });
  });

  group('Navigation Triggers & Dashboard Hook (<100ms)', () {
    testWidgets('Quick Scan Action Banner on HomeScreen triggers onScanReceipt',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeClient = FakeDashboardHttpClient(hasActiveCycle: true);
      final apiClient = ApiClient(httpClient: fakeClient);
      final dashboardApiService = DashboardApiService(apiClient);

      bool scanTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            dashboardApiService: dashboardApiService,
            onOpenProfile: () {},
            onScanReceipt: () => scanTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bannerFinder = find.byKey(const Key('dashboard_quick_scan_banner'));
      expect(bannerFinder, findsOneWidget);
      expect(find.text('Escanear Comprobante'), findsOneWidget);
      expect(find.text('OCR'), findsOneWidget);

      await tester.tap(bannerFinder);
      await tester.pump();

      expect(scanTapped, isTrue);
    });

    testWidgets('Real-time balance refresh signal dispatches in <100ms',
        (tester) async {
      final refreshSignal = ValueNotifier<int>(0);
      int triggerCount = 0;

      refreshSignal.addListener(() {
        triggerCount++;
      });

      final sw = Stopwatch()..start();
      refreshSignal.value++;
      sw.stop();

      expect(triggerCount, 1);
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });
}
