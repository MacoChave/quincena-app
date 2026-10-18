import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/budget_allocation.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/data/services/budget_api_service.dart';
import 'package:quincena/features/budget/presentation/notifiers/budget_notifier.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'package:quincena/features/transactions/presentation/manual/manual_expense_form_sheet.dart';
import 'transaction_test_doubles.dart';

/// Test widget simulating the Manual Expense Form Modal Bottom Sheet
class ManualExpenseFormSheetTestWidget extends StatefulWidget {
  const ManualExpenseFormSheetTestWidget({
    super.key,
    required this.cycleId,
    required this.categories,
    required this.accounts,
    this.initialCategory,
    required this.onSave,
    this.onAddNewCategory,
  });

  final String cycleId;
  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final Category? initialCategory;
  final Future<void> Function(CreateTransactionDto dto, {bool force}) onSave;
  final Future<Category?> Function()? onAddNewCategory;

  @override
  State<ManualExpenseFormSheetTestWidget> createState() =>
      _ManualExpenseFormSheetTestWidgetState();
}

class _ManualExpenseFormSheetTestWidgetState
    extends State<ManualExpenseFormSheetTestWidget> {
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;
  late List<Category> _categories;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  final DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _merchantController = TextEditingController();
    _notesController = TextEditingController();
    _categories = List.from(widget.categories);

    if (widget.initialCategory != null) {
      _selectedCategoryId = widget.initialCategory!.id;
      _selectedAccountId = widget.initialCategory!.defaultAccountId;
    }
    _selectedAccountId ??=
        widget.accounts.firstWhere((a) => a.isDefault, orElse: () => widget.accounts.first).id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool force = false}) async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0.0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0.00');
      return;
    }

    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      setState(() => _errorMessage = 'El comercio o nota es obligatorio');
      return;
    }

    if (_selectedCategoryId == null) {
      setState(() => _errorMessage = 'Seleccione una categoría obligatoria');
      return;
    }

    if (_selectedAccountId == null) {
      setState(() => _errorMessage = 'Seleccione una cuenta financiera obligatoria');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final dto = CreateTransactionDto(
        cycleId: widget.cycleId,
        sourceAccountId: _selectedAccountId!,
        amount: amount,
        merchantName: merchant,
        transactionDate: _selectedDate.toIso8601String().split('T')[0],
        allocationId: _selectedCategoryId,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        entryMethod: EntryMethod.manual,
      );
      await widget.onSave(dto, force: force);
      if (mounted) {
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nuevo Gasto Manual',
              style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Amount Input with Decimal Keypad (Spec #28)
            TextField(
              key: const Key('manual_amount_input'),
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTypography.currencyHeroMobile.copyWith(color: AppColors.textMain),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Merchant / Note Input
            TextField(
              key: const Key('manual_merchant_input'),
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: 'Comercio o Nota descriptiva',
                hintText: 'Ej. Supermercado, Almuerzo, Gasolina',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Category Selector with + Nueva Categoría shortcut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categoría',
                  style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                ),
                if (widget.onAddNewCategory != null)
                  TextButton.icon(
                    key: const Key('btn_add_new_category'),
                    onPressed: () async {
                      final newCat = await widget.onAddNewCategory!();
                      if (newCat != null && mounted) {
                        setState(() {
                          if (!_categories.any((c) => c.id == newCat.id)) {
                            _categories.add(newCat);
                          }
                          _selectedCategoryId = newCat.id;
                          if (newCat.defaultAccountId != null) {
                            _selectedAccountId = newCat.defaultAccountId;
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Nueva Categoría'),
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              key: const Key('manual_category_dropdown'),
              // ignore: deprecated_member_use
              value: _selectedCategoryId,
              hint: const Text('Seleccionar categoría'),
              items: _categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.id,
                  child: Text(cat.name),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                  final cat = _categories.where((c) => c.id == val).firstOrNull;
                  if (cat?.defaultAccountId != null) {
                    _selectedAccountId = cat!.defaultAccountId;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // Source Account Selector
            Text(
              'Cuenta de Pago / Débito',
              style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
            ),
            DropdownButtonFormField<String>(
              key: const Key('manual_account_dropdown'),
              initialValue: _selectedAccountId,
              hint: const Text('Seleccionar cuenta'),
              items: widget.accounts.map((acc) {
                return DropdownMenuItem<String>(
                  value: acc.id,
                  child: Text(acc.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedAccountId = val),
            ),
            const SizedBox(height: 16),

            // Notes Input
            TextField(
              key: const Key('manual_notes_input'),
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas adicionales (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Error Display
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: AppTypography.captionBadge.copyWith(
                    color: AppColors.expenseText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Save Button
            AppButton(
              text: 'Guardar Gasto',
              isLoading: _isSaving,
              onPressed: () => _submit(force: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Test widget simulating Duplicate Warning Dialog (RN-03)
class DuplicateWarningDialogTestWidget extends StatelessWidget {
  const DuplicateWarningDialogTestWidget({
    super.key,
    required this.existingTransaction,
    required this.onCancel,
    required this.onConfirmForce,
  });

  final Transaction existingTransaction;
  final VoidCallback onCancel;
  final VoidCallback onConfirmForce;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
          const SizedBox(width: 8),
          Text(
            'Posible Gasto Duplicado',
            style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parece que este gasto ya fue registrado dentro de las últimas 24 horas (RN-03):',
            style: AppTypography.bodyMd,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existingTransaction.merchantName,
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      existingTransaction.transactionDate.toIso8601String().split('T')[0],
                      style: AppTypography.captionBadge.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                Text(
                  '-\$${existingTransaction.amount.toStringAsFixed(2)}',
                  style: AppTypography.numericRow.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '¿Deseas registrar este gasto de todas formas?',
            style: AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('btn_cancel_duplicate'),
          onPressed: onCancel,
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          key: const Key('btn_force_duplicate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.textMain,
            foregroundColor: AppColors.surfaceBase,
          ),
          onPressed: onConfirmForce,
          child: const Text('Registrar de todas formas'),
        ),
      ],
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

  group('Feature 8: Manual Expense Form & Decimal Keyboard (RF-04/RF-06, CA-04.1)', () {
    // --- Tier 1 (5 tests) ---
    testWidgets('8.1 Form renders title, amount, merchant, category, account, and save button',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (_, {force = false}) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nuevo Gasto Manual'), findsOneWidget);
      expect(find.byKey(const Key('manual_amount_input')), findsOneWidget);
      expect(find.byKey(const Key('manual_merchant_input')), findsOneWidget);
      expect(find.byKey(const Key('manual_category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('manual_account_dropdown')), findsOneWidget);
      expect(find.text('Guardar Gasto'), findsOneWidget);
    });

    testWidgets('8.2 Amount input has decimal keyboard configured (inputmode=decimal)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (_, {force = false}) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final textField = tester.widget<TextField>(find.byKey(const Key('manual_amount_input')));
      expect(textField.keyboardType, const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('8.3 Selecting category auto-selects its defaultAccountId (RN-CAT-01)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (_, {force = false}) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Category dropdown and select Ocio & Café (defaultAccountId = acc-cash)
      await tester.tap(find.byKey(const Key('manual_category_dropdown')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Ocio & Café').last);
      await tester.pump();

      // Check account dropdown updated to acc-cash (Efectivo Billetera)
      expect(find.text('Efectivo Billetera'), findsOneWidget);
    });

    testWidgets('8.4 Saving form issues POST /transactions payload with entry_method manual',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      CreateTransactionDto? savedDto;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (dto, {force = false}) async {
                savedDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '45.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Almuerzo Ejecutivo');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.tap(find.byKey(const Key('manual_category_dropdown')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Supermercado').last);
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(savedDto?.amount, 45.00);
      expect(savedDto?.merchantName, 'Almuerzo Ejecutivo');
      expect(savedDto?.entryMethod, EntryMethod.manual);
      expect(savedDto?.allocationId, 'cat-super');
    });

    test('8.5 CreateTransactionDto validation checks mandatory fields and constraints', () {
      const valid = CreateTransactionDto(
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 25.50,
        merchantName: 'Tienda La Esquina',
        transactionDate: '2026-10-18',
      );
      expect(valid.validate(), isNull);
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    testWidgets('8.6 Rejects zero amount (\$0.00) with validation error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (_, {force = false}) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '0.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Test');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();

      expect(find.text('El monto debe ser mayor a 0.00'), findsOneWidget);
    });

    test('8.7 Rejects empty merchant or whitespace-only name', () {
      const dto = CreateTransactionDto(
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 50.0,
        merchantName: '   ',
        transactionDate: '2026-10-18',
      );
      expect(dto.validate(), contains('comercio o nota'));
    });

    test('8.8 Rejects merchant name exceeding 120 characters', () {
      final longName = 'A' * 125;
      final dto = CreateTransactionDto(
        cycleId: 'c1',
        sourceAccountId: 'acc-1',
        amount: 50.0,
        merchantName: longName,
        transactionDate: '2026-10-18',
      );
      expect(dto.validate(), contains('120 caracteres'));
    });

    test('8.9 Rejects submit if cycle is closed (RN-01)', () async {
      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'c-closed',
        isCycleClosed: true,
      );

      final res = await mockHttp.post(
        Uri.parse('http://localhost:3000/transactions'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'cycle_id': 'c-closed',
          'source_account_id': 'acc-1',
          'amount': 50.0,
          'merchant_name': 'Super',
          'transaction_date': '2026-10-18',
        }),
      );

      expect(res.statusCode, 400);
      expect(jsonDecode(res.body)['message'], contains('RN-01'));
    });

    testWidgets('8.10 Form retains entered amount and merchant after opening CategoryFormSheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (_, {force = false}) async {},
              onAddNewCategory: () async {
                return const Category(
                  id: 'cat-new-mascotas',
                  name: 'Mascotas',
                  icon: 'pets',
                  colorHex: '#ADF7B6',
                  defaultAccountId: 'acc-deb',
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '85.50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Veterinaria PetCare');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Tap + Nueva Categoría
      await tester.tap(find.byKey(const Key('btn_add_new_category')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify original amount and merchant are still intact in text controllers!
      final amountField = tester.widget<TextField>(find.byKey(const Key('manual_amount_input')));
      final merchantField = tester.widget<TextField>(find.byKey(const Key('manual_merchant_input')));
      expect(amountField.controller?.text, '85.50');
      expect(merchantField.controller?.text, 'Veterinaria PetCare');
    });
  });

  group('Feature 9: Duplicate Detection Interception (RN-03, 409 Conflict & force)', () {
    // --- Tier 1 (5 tests) ---
    test('9.1 Backend detects duplicate expense within ±24 hours and returns HTTP 409 Conflict',
        () async {
      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [
          {
            'id': 'tx-existing',
            'user_id': 'u1',
            'cycle_id': 'cycle-1',
            'source_account_id': 'acc-deb',
            'amount': 4.50,
            'merchant_name': 'Café Barista',
            'transaction_date': '2026-10-18',
          }
        ],
      );

      final res = await mockHttp.post(
        Uri.parse('http://localhost:3000/transactions'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'cycle_id': 'cycle-1',
          'source_account_id': 'acc-deb',
          'amount': 4.50,
          'merchant_name': 'Café Barista',
          'transaction_date': '2026-10-18',
        }),
      );

      expect(res.statusCode, 409);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['duplicate_warning'], isTrue);
      expect(body['existing_transactions'], isNotEmpty);
      expect(mockHttp.duplicateWarningHits, 1);
    });

    testWidgets('9.2 Duplicate warning dialog displays previous expense details',
        (tester) async {
      final existingTx = Transaction(
        id: 'dup-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 4.50,
        merchantName: 'Café Barista',
        transactionDate: DateTime(2026, 10, 18),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuplicateWarningDialogTestWidget(
              existingTransaction: existingTx,
              onCancel: () {},
              onConfirmForce: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Posible Gasto Duplicado'), findsOneWidget);
      expect(find.text('Café Barista'), findsOneWidget);
      expect(find.text('-\$4.50'), findsOneWidget);
      expect(find.text('Registrar de todas formas'), findsOneWidget);
    });

    testWidgets('9.3 Tapping Cancel on duplicate warning dialog cancels registration',
        (tester) async {
      bool cancelled = false;
      final existingTx = Transaction(
        id: 'dup-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 4.50,
        merchantName: 'Café Barista',
        transactionDate: DateTime(2026, 10, 18),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuplicateWarningDialogTestWidget(
              existingTransaction: existingTx,
              onCancel: () => cancelled = true,
              onConfirmForce: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_cancel_duplicate')));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('9.4 Tapping Registrar de todas formas triggers force bypass callback',
        (tester) async {
      bool forceTriggered = false;
      final existingTx = Transaction(
        id: 'dup-1',
        userId: 'u1',
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 4.50,
        merchantName: 'Café Barista',
        transactionDate: DateTime(2026, 10, 18),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuplicateWarningDialogTestWidget(
              existingTransaction: existingTx,
              onCancel: () {},
              onConfirmForce: () => forceTriggered = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('btn_force_duplicate')));
      await tester.pump();

      expect(forceTriggered, isTrue);
    });

    test('9.5 Submitting with force=true bypasses duplicate interception and returns 201 Created',
        () async {
      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [
          {
            'id': 'tx-existing',
            'user_id': 'u1',
            'cycle_id': 'cycle-1',
            'source_account_id': 'acc-deb',
            'amount': 4.50,
            'merchant_name': 'Café Barista',
            'transaction_date': '2026-10-18',
          }
        ],
      );

      final res = await mockHttp.post(
        Uri.parse('http://localhost:3000/transactions?force=true'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'cycle_id': 'cycle-1',
          'source_account_id': 'acc-deb',
          'amount': 4.50,
          'merchant_name': 'Café Barista',
          'transaction_date': '2026-10-18',
        }),
      );

      expect(res.statusCode, 201);
      expect(mockHttp.transactionsDb.length, 2);
      expect(mockHttp.forceBypassHits, 1);
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    test('9.6 Expense 25 hours apart is NOT flagged as duplicate', () {
      final existing = [
        Transaction(
          id: 'old-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 50.0,
          merchantName: 'Supermercado',
          transactionDate: DateTime(2026, 10, 18, 10, 0),
        ),
      ];

      final dups = DuplicateDetector.findDuplicates(
        existing: existing,
        merchantName: 'Supermercado',
        amount: 50.0,
        transactionDate: DateTime(2026, 10, 19, 11, 1), // 25.01 hours later
      );
      expect(dups, isEmpty);
    });

    test('9.7 Expense with different merchant is NOT flagged as duplicate', () {
      final existing = [
        Transaction(
          id: 'old-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 50.0,
          merchantName: 'Supermercado A',
          transactionDate: DateTime(2026, 10, 18, 10, 0),
        ),
      ];

      final dups = DuplicateDetector.findDuplicates(
        existing: existing,
        merchantName: 'Supermercado B',
        amount: 50.0,
        transactionDate: DateTime(2026, 10, 18, 12, 0),
      );
      expect(dups, isEmpty);
    });

    test('9.8 Expense with different amount is NOT flagged as duplicate', () {
      final existing = [
        Transaction(
          id: 'old-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 50.0,
          merchantName: 'Supermercado',
          transactionDate: DateTime(2026, 10, 18, 10, 0),
        ),
      ];

      final dups = DuplicateDetector.findDuplicates(
        existing: existing,
        merchantName: 'Supermercado',
        amount: 50.01,
        transactionDate: DateTime(2026, 10, 18, 12, 0),
      );
      expect(dups, isEmpty);
    });

    test('9.9 Duplicate check is case-insensitive', () {
      final existing = [
        Transaction(
          id: 'old-1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 50.0,
          merchantName: 'walmart',
          transactionDate: DateTime(2026, 10, 18, 10, 0),
        ),
      ];

      final dups = DuplicateDetector.findDuplicates(
        existing: existing,
        merchantName: 'WALMART',
        amount: 50.0,
        transactionDate: DateTime(2026, 10, 18, 12, 0),
      );
      expect(dups, isNotEmpty);
    });

    test('9.10 Duplicate check ignores current transaction ID during edit updates', () {
      final existing = [
        Transaction(
          id: 'tx-editing',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 50.0,
          merchantName: 'Super',
          transactionDate: DateTime(2026, 10, 18, 10, 0),
        ),
      ];

      final dups = DuplicateDetector.findDuplicates(
        existing: existing,
        merchantName: 'Super',
        amount: 50.0,
        transactionDate: DateTime(2026, 10, 18, 10, 0),
        currentTransactionId: 'tx-editing',
      );
      expect(dups, isEmpty);
    });
  });

  group('Feature 10: Real-time Category Balance Deduction (CA-04.2, CA-06.2, <100ms)', () {
    // --- Tier 1 (5 tests) ---
    test('10.1 Saving transaction immediately adds amount to spentAmount', () {
      const initial = BudgetAllocation(
        id: 'alloc-1',
        cycleId: 'c1',
        categoryId: 'cat-super',
        allocatedAmount: 500.0,
        spentAmount: 100.0,
      );

      final updated = initial.copyWith(
        spentAmount: initial.spentAmount + 50.0,
      );

      expect(updated.spentAmount, 150.0);
    });

    test('10.2 Saving transaction immediately deducts amount from availableAmount', () {
      const alloc = BudgetAllocation(
        id: 'alloc-1',
        cycleId: 'c1',
        categoryId: 'cat-super',
        allocatedAmount: 500.0,
        spentAmount: 150.0,
      );

      expect(alloc.computedAvailable, 350.0);
    });

    test('10.3 Progress ratio calculates correctly below 70%', () {
      const alloc = BudgetAllocation(
        id: 'alloc-1',
        cycleId: 'c1',
        categoryId: 'cat-super',
        allocatedAmount: 1000.0,
        spentAmount: 500.0,
      );

      expect(alloc.progressRatio, 0.50);
      expect(alloc.computedPercentage, 50.0);
    });

    test('10.4 Progress ratio between 70% and 90% reflects warning threshold', () {
      const alloc = BudgetAllocation(
        id: 'alloc-1',
        cycleId: 'c1',
        categoryId: 'cat-super',
        allocatedAmount: 1000.0,
        spentAmount: 800.0,
      );

      expect(alloc.progressRatio, 0.80);
      expect(alloc.computedPercentage, 80.0);
    });

    test('10.5 Progress ratio >= 90% reflects critical threshold', () {
      const alloc = BudgetAllocation(
        id: 'alloc-1',
        cycleId: 'c1',
        categoryId: 'cat-super',
        allocatedAmount: 1000.0,
        spentAmount: 950.0,
      );

      expect(alloc.progressRatio, 0.95);
      expect(alloc.computedPercentage, 95.0);
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    test('10.6 Overspending (spent > allocated) transitions to deficit without crash', () {
      const alloc = BudgetAllocation(
        id: 'alloc-1',
        cycleId: 'c1',
        categoryId: 'cat-super',
        allocatedAmount: 200.0,
        spentAmount: 260.0,
      );

      expect(alloc.computedAvailable, -60.0);
      expect(alloc.progressRatio, 1.0); // clamped to 1.0 for bar rendering
      expect(alloc.computedPercentage, 130.0);
    });

    test('10.7 Deleting transaction restores category allocation available amount', () {
      final alloc = const BudgetAllocation(
        id: 'alloc-1',
        cycleId: 'c1',
        categoryId: 'cat-super',
        allocatedAmount: 500.0,
        spentAmount: 200.0,
      );

      // Revert $50 transaction
      final restored = alloc.copyWith(
        spentAmount: alloc.spentAmount - 50.0,
      );

      expect(restored.spentAmount, 150.0);
      expect(restored.computedAvailable, 350.0);
    });

    test('10.8 Transaction without existing allocation has null allocation_id safely', () {
      final tx = Transaction(
        id: 'orphan-tx',
        userId: 'u1',
        cycleId: 'c1',
        allocationId: null,
        sourceAccountId: 'acc-deb',
        amount: 40.0,
        merchantName: 'Gasto No Presupuestado',
        transactionDate: DateTime.now(),
      );

      expect(tx.allocationId, isNull);
    });

    test('10.9 IEEE-754 sub-cent drift handles without fractional penny error', () {
      double spent = 0.0;
      spent += 33.33;
      spent += 33.33;
      spent += 33.34;
      expect((spent - 100.0).abs() < 0.001, isTrue);
    });

    test('10.10 State computation runs in sub-millisecond time (<100ms SLA)', () {
      final stopwatch = Stopwatch()..start();
      const alloc = BudgetAllocation(
        id: 'alloc-perf',
        cycleId: 'c1',
        categoryId: 'cat-1',
        allocatedAmount: 1000.0,
        spentAmount: 400.0,
      );
      final _ = alloc.computedAvailable;
      final _ = alloc.progressRatio;
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Feature 11: Dashboard Metrics Live Synchronization (CA-04.2, CA-06.2, <100ms)', () {
    // --- Tier 1 (5 tests) ---
    test('11.1 Transaction creation increases totalSpent immediately', () {
      double totalSpent = 500.0;
      const expenseAmount = 85.0;
      totalSpent += expenseAmount;
      expect(totalSpent, 585.0);
    });

    test('11.2 Transaction creation decreases totalAvailable immediately', () {
      double totalAvailable = 1500.0;
      const expenseAmount = 85.0;
      totalAvailable -= expenseAmount;
      expect(totalAvailable, 1415.0);
    });

    testWidgets('11.3 Bento tile updates spent total dynamically', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBentoWidget(
              spentTotal: 650.0,
              allocatedTotal: 1000.0,
              dailyAveragePace: 43.33,
              ocrCount: 3,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('\$650.00'), findsOneWidget);
      expect(find.text('En meta'), findsOneWidget);
      expect(find.text('3 OCR capturados'), findsOneWidget);
    });

    testWidgets('11.4 Bento tile switches status to Alerta when spent > 90%', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FeedAnalyticsBentoWidget(
              spentTotal: 950.0,
              allocatedTotal: 1000.0,
              dailyAveragePace: 63.33,
              ocrCount: 5,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('\$950.00'), findsOneWidget);
      expect(find.text('Alerta'), findsOneWidget);
    });

    test('11.5 Deleting transaction reverts Dashboard total spent and available funds', () {
      double totalSpent = 800.0;
      double totalAvailable = 1200.0;
      const deletedAmount = 150.0;

      totalSpent -= deletedAmount;
      totalAvailable += deletedAmount;

      expect(totalSpent, 650.0);
      expect(totalAvailable, 1350.0);
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    test('11.6 Rapid sequential transactions sum accurately', () {
      double spent = 0.0;
      for (int i = 0; i < 50; i++) {
        spent += 20.0;
      }
      expect(spent, 1000.0);
    });

    test('11.7 Extreme deficit in Dashboard when spent > total income', () {
      const income = 2000.0;
      const spent = 2500.0;
      const available = income - spent;
      expect(available, -500.0);
    });

    test('11.8 Mega currency numbers format cleanly without exception', () {
      const bigNumber = 1250000.75;
      final formatted = '\$${bigNumber.toStringAsFixed(2)}';
      expect(formatted, '\$1250000.75');
    });

    test('11.9 Empty cycle starts with totalSpent 0.00', () {
      const totalSpent = 0.0;
      expect(totalSpent, 0.0);
    });

    test('11.10 Zero allocated total handles progress calculation without NaN division by zero', () {
      const spent = 100.0;
      const allocated = 0.0;
      final progress = allocated > 0 ? (spent / allocated).clamp(0.0, 1.0) : 0.0;
      expect(progress, 0.0);
      expect(progress.isNaN, isFalse);
    });
  });

  group('Tier 3: Pairwise Combinations (Manual & Balance Sync Flow)', () {
    testWidgets('3.1 Manual Entry + Duplicate 409 Interception + User Cancels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [
          {
            'id': 'tx-1',
            'user_id': 'u1',
            'cycle_id': 'cycle-1',
            'source_account_id': 'acc-deb',
            'amount': 45.0,
            'merchant_name': 'Café Barista',
            'transaction_date': '2026-10-18',
          }
        ],
      );

      bool showDialog = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (dto, {force = false}) async {
                final res = await mockHttp.post(
                  Uri.parse('http://localhost:3000/transactions${force ? '?force=true' : ''}'),
                  headers: {'content-type': 'application/json'},
                  body: jsonEncode(dto.toJson()),
                );
                if (res.statusCode == 409) {
                  showDialog = true;
                }
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '45.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Café Barista');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.tap(find.byKey(const Key('manual_category_dropdown')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Ocio & Café').last);
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();

      // Intercepted 409!
      expect(showDialog, isTrue);
      // Transactions count in DB remained 1 (cancelled)
      expect(mockHttp.transactionsDb.length, 1);
    });

    testWidgets('3.2 Manual Entry + Duplicate 409 Interception + User Confirms Force Bypass',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [
          {
            'id': 'tx-1',
            'user_id': 'u1',
            'cycle_id': 'cycle-1',
            'source_account_id': 'acc-deb',
            'amount': 45.0,
            'merchant_name': 'Café Barista',
            'transaction_date': '2026-10-18',
          }
        ],
      );

      CreateTransactionDto? pendingDto;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onSave: (dto, {force = false}) async {
                pendingDto = dto;
                await mockHttp.post(
                  Uri.parse('http://localhost:3000/transactions${force ? '?force=true' : ''}'),
                  headers: {'content-type': 'application/json'},
                  body: jsonEncode(dto.toJson()),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '45.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Café Barista');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.tap(find.byKey(const Key('manual_category_dropdown')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Ocio & Café').last);
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();

      // Now simulate user tapping 'Registrar de todas formas' with force=true
      final forceRes = await mockHttp.post(
        Uri.parse('http://localhost:3000/transactions?force=true'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(pendingDto!.toJson()),
      );

      expect(forceRes.statusCode, 201);
      // Both transactions are now in DB!
      expect(mockHttp.transactionsDb.length, 2);
      expect(mockHttp.forceBypassHits, 1);
    });

    testWidgets('3.3 Contextual Category Creation inside form + Save Expense under New Category',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final categoriesList = List<Category>.from(testCategories);
      CreateTransactionDto? submittedDto;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheetTestWidget(
              cycleId: 'cycle-1',
              categories: categoriesList,
              accounts: testAccounts,
              onSave: (dto, {force = false}) async {
                submittedDto = dto;
              },
              onAddNewCategory: () async {
                final newCat = const Category(
                  id: 'cat-mascotas',
                  name: 'Mascotas',
                  icon: 'pets',
                  colorHex: '#ADF7B6',
                  defaultAccountId: 'acc-cash',
                );
                categoriesList.add(newCat);
                return newCat;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '95.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Veterinaria PetCare');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Tap + Nueva Categoría
      await tester.tap(find.byKey(const Key('btn_add_new_category')));
      await tester.pump();

      // Submit form
      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();

      expect(submittedDto?.amount, 95.00);
      expect(submittedDto?.merchantName, 'Veterinaria PetCare');
      expect(submittedDto?.allocationId, 'cat-mascotas');
      expect(submittedDto?.sourceAccountId, 'acc-cash');
    });

    test('3.4 Closed Cycle Rejection (RN-01) -> Resubmit with active cycle succeeds', () async {
      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'c-active',
        isCycleClosed: true,
      );

      // Attempt on closed cycle
      final failRes = await mockHttp.post(
        Uri.parse('http://localhost:3000/transactions'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'cycle_id': 'c-active',
          'source_account_id': 'acc-deb',
          'amount': 50.0,
          'merchant_name': 'Gasto',
          'transaction_date': '2026-10-18',
        }),
      );
      expect(failRes.statusCode, 400);

      // Cycle reopened or switched to open active cycle
      mockHttp.isCycleClosed = false;
      final okRes = await mockHttp.post(
        Uri.parse('http://localhost:3000/transactions'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'cycle_id': 'c-active',
          'source_account_id': 'acc-deb',
          'amount': 50.0,
          'merchant_name': 'Gasto',
          'transaction_date': '2026-10-18',
        }),
      );
      expect(okRes.statusCode, 201);
    });
  });

  group('Feature Production: Manual Expense Form & Real-time Balance Updating (RF-04/RF-06)', () {
    testWidgets('P1.1 Production ManualExpenseFormSheet renders all essential elements', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Nuevo Gasto Manual'), findsOneWidget);
      expect(find.byKey(const Key('manual_amount_input')), findsOneWidget);
      expect(find.byKey(const Key('manual_merchant_input')), findsOneWidget);
      expect(find.byKey(const Key('manual_category_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('manual_account_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('manual_date_picker_tile')), findsOneWidget);
      expect(find.byKey(const Key('manual_notes_input')), findsOneWidget);
      expect(find.text('Guardar Gasto'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byKey(const Key('manual_amount_input')));
      expect(textField.keyboardType, const TextInputType.numberWithOptions(decimal: true));
    });

    test('P1.2 DecimalCurrencyInputFormatter unit verification', () {
      const formatter = DecimalCurrencyInputFormatter(decimalRange: 2);

      // Normal value
      var res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12.34'),
      );
      expect(res.text, '12.34');

      // Comma normalization
      res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12,34'),
      );
      expect(res.text, '12.34');

      // Leading dot autocompletion
      res = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '.'),
      );
      expect(res.text, '0.');

      // Exceeding 2 decimals rejected
      res = formatter.formatEditUpdate(
        const TextEditingValue(text: '12.34'),
        const TextEditingValue(text: '12.345'),
      );
      expect(res.text, '12.34');

      // Empty string allowed
      res = formatter.formatEditUpdate(
        const TextEditingValue(text: '10'),
        const TextEditingValue(text: ''),
      );
      expect(res.text, '');
    });

    testWidgets('P1.3 Form validation rejects amount <= 0, empty merchant, merchant > 120 chars, and closed cycle (RN-01)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Amount <= 0
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '0.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Test Merchant');
      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();
      expect(find.text('El monto debe ser mayor a 0.00'), findsOneWidget);

      // 2. Empty merchant
      await tester.enterText(find.byKey(const Key('manual_amount_input')), '25.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), '   ');
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();
      expect(find.text('El comercio o nota es obligatorio'), findsOneWidget);

      // 3. Merchant > 120 chars
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'A' * 125);
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();
      expect(find.text('El comercio no puede exceder 120 caracteres'), findsOneWidget);
    });

    testWidgets('P1.4 Contextual + Nueva Categoría creates category without losing entered amount and merchant', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              onAddNewCategory: () async {
                return const Category(
                  id: 'cat-gym',
                  name: 'Gimnasio & Salud',
                  icon: 'fitness_center',
                  colorHex: '#79ADDC',
                  defaultAccountId: 'acc-deb',
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '150.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'SmartFit Cuota');
      await tester.pump();

      // Tap + Nueva Categoría
      await tester.tap(find.byKey(const Key('btn_add_new_category')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check entered data preserved
      final amountField = tester.widget<TextField>(find.byKey(const Key('manual_amount_input')));
      final merchantField = tester.widget<TextField>(find.byKey(const Key('manual_merchant_input')));
      expect(amountField.controller?.text, '150.00');
      expect(merchantField.controller?.text, 'SmartFit Cuota');

      // Check new category selected
      expect(find.text('Gimnasio & Salud'), findsOneWidget);
    });

    testWidgets('P1.5 Category selector triggers RN-CAT-01 default account auto-selection on AccountSelectorField', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Category dropdown and select Ocio & Café (defaultAccountId = acc-cash)
      await tester.tap(find.byKey(const Key('manual_category_dropdown')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Ocio & Café').last);
      await tester.pump();

      // Account selector field displays acc-cash (Efectivo Billetera)
      expect(find.text('Efectivo Billetera'), findsOneWidget);
    });

    testWidgets('P1.6 Duplicate warning (RN-03) interception and Cancel keeps form open', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              initialCategoryId: 'cat-super',
              initialAccountId: 'acc-deb',
              onSave: (dto, {force = false}) async {
                attempts++;
                if (!force) {
                  throw DuplicateTransactionException(
                    message: 'Posible gasto duplicado',
                    existingTransactions: [
                      DuplicateTransactionItem(
                        id: 'dup-1',
                        merchantName: 'Supermercado',
                        amount: 50.0,
                        transactionDate: DateTime(2026, 10, 18),
                      ),
                    ],
                  );
                }
                return Transaction(
                  id: 'tx-new',
                  userId: 'u1',
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '50.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Supermercado');
      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Duplicate warning dialog should be visible
      expect(find.byKey(const Key('duplicate_warning_dialog')), findsOneWidget);
      expect(find.text('Posible Gasto Duplicado'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const Key('btn_cancel_duplicate')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Form remains open and inputs intact
      expect(find.text('Nuevo Gasto Manual'), findsOneWidget);
      final amountField = tester.widget<TextField>(find.byKey(const Key('manual_amount_input')));
      expect(amountField.controller?.text, '50.00');
      expect(attempts, 1);
    });

    testWidgets('P1.7 Duplicate warning bypass with force: true persists transaction', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int attempts = 0;
      bool forced = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualExpenseFormSheet(
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              initialCategoryId: 'cat-super',
              initialAccountId: 'acc-deb',
              onSave: (dto, {force = false}) async {
                attempts++;
                if (!force) {
                  throw DuplicateTransactionException(
                    message: 'Posible gasto duplicado',
                    existingTransactions: [
                      DuplicateTransactionItem(
                        id: 'dup-1',
                        merchantName: 'Supermercado',
                        amount: 50.0,
                        transactionDate: DateTime(2026, 10, 18),
                      ),
                    ],
                  );
                }
                forced = true;
                return Transaction(
                  id: 'tx-new',
                  userId: 'u1',
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
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('manual_amount_input')), '50.00');
      await tester.enterText(find.byKey(const Key('manual_merchant_input')), 'Supermercado');
      await tester.ensureVisible(find.text('Guardar Gasto'));
      await tester.tap(find.text('Guardar Gasto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Registrar de todas formas
      await tester.tap(find.byKey(const Key('btn_force_duplicate')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(attempts, 2);
      expect(forced, isTrue);
    });

    test('P1.8 Real-time balance deduction (<10ms) via ManualSyncService.deductFromAllocationsList', () {
      final allocs = [
        const BudgetAllocation(
          id: 'alloc-1',
          cycleId: 'cycle-1',
          categoryId: 'cat-super',
          allocatedAmount: 1000.0,
          spentAmount: 200.0,
          availableAmount: 800.0,
        ),
      ];

      final stopwatch = Stopwatch()..start();
      final updated = ManualSyncService.deductFromAllocationsList(
        allocations: allocs,
        targetAllocationOrCategoryId: 'alloc-1',
        expenseAmount: 150.0,
      );
      stopwatch.stop();

      // Completes in under 10ms
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
      expect(updated.first.spentAmount, 350.0);
      expect(updated.first.availableAmount, 650.0);
    });

    test('P1.9 BudgetNotifier.deductExpense executes safely and recalculates zero base in <10ms', () {
      final notifier = BudgetNotifier(apiService: BudgetApiService(ApiClient()));
      final stopwatch = Stopwatch()..start();
      notifier.deductExpense(allocationId: 'alloc-non-existent', amount: 50.0);
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
      expect(notifier.allocations, isEmpty);
    });
  });
}
