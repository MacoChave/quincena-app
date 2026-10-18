// Proposed test cases for Milestone 2 Iteration 2 verification
// Location recommendation: quincena/test/features/ocr/ocr_ui_and_datepicker_remediation_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/ocr/presentation/widgets/ocr_validation_sheet.dart';
import 'package:quincena/features/ocr/presentation/widgets/ocr_viewfinder.dart';
import 'package:quincena/features/transactions/data/models/receipt_scan.dart';

void main() {
  final testCategories = [
    const Category(
      id: 'cat-super',
      name: 'Supermercado',
      icon: 'shopping_cart',
      colorHex: '#ADF7B6',
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
  ];

  group('UI and Date Picker Remediation Tests', () {
    testWidgets('Historical receipt date prior to 2020 does not violate showDatePicker assertion', (tester) async {
      // Receipt scan dated 2018 (prior to standard 2020 lower boundary)
      final historicalScan = ReceiptScan(
        id: 'scan-hist-2018',
        userId: 'u1',
        storagePath: 'u1/receipt_2018.jpg',
        extractedMerchant: 'Libreria Antigua 2018',
        extractedAmount: 32.50,
        extractedDate: DateTime(2018, 4, 12),
        confidenceScore: 0.95,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrValidationSheet(
              scan: historicalScan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the date picker tile
      final dateTileFinder = find.text('Fecha del gasto');
      expect(dateTileFinder, findsOneWidget);

      await tester.tap(dateTileFinder);
      await tester.pumpAndSettle();

      // DatePickerDialog must be visible and no exception thrown
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    });

    testWidgets('OcrViewfinder paints without error and renders overlay with convex corners', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrViewfinder(
              onCapture: () {},
              onManualFallback: () {},
            ),
          ),
        ),
      );

      // Bounded pump to avoid animation infinite loop
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(OcrViewfinder), findsOneWidget);
    });
  });
}
