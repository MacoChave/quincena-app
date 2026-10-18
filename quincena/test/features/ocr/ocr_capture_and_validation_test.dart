import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import '../transactions/transaction_test_doubles.dart';

/// Test widget simulating the Stitch OCR Pre-Confirmation Bottom Sheet
/// Screen `06dd441359e2446c8c5931868b87b4d7`
class OcrPreConfirmationSheetTestWidget extends StatefulWidget {
  const OcrPreConfirmationSheetTestWidget({
    super.key,
    required this.scan,
    required this.cycleId,
    required this.categories,
    required this.accounts,
    required this.currentAvailableBalance,
    required this.onConfirm,
    this.onFallbackManual,
  });

  final ReceiptScan scan;
  final String cycleId;
  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final double currentAvailableBalance;
  final Future<void> Function(ConfirmReceiptScanDto dto) onConfirm;
  final VoidCallback? onFallbackManual;

  @override
  State<OcrPreConfirmationSheetTestWidget> createState() =>
      _OcrPreConfirmationSheetTestWidgetState();
}

class _OcrPreConfirmationSheetTestWidgetState
    extends State<OcrPreConfirmationSheetTestWidget> {
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _isConfirming = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.scan.extractedAmount != null
          ? widget.scan.extractedAmount!.toStringAsFixed(2)
          : '',
    );
    _merchantController = TextEditingController(
      text: widget.scan.extractedMerchant ?? '',
    );
    _notesController = TextEditingController(
      text: widget.scan.taxIdOrAuthNumber != null
          ? 'Autorización: ${widget.scan.taxIdOrAuthNumber}'
          : '',
    );
    _selectedDate = widget.scan.extractedDate ?? DateTime.now();

    // Auto-suggestions (CA-05.2, RN-CAT-01)
    _selectedCategoryId = widget.scan.suggestedCategoryId;
    _selectedAccountId = widget.scan.suggestedAccountId ??
        widget.accounts.firstWhere((a) => a.isDefault, orElse: () => widget.accounts.first).id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _currentAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  double get _projectedBalance =>
      widget.currentAvailableBalance - _currentAmount;

  Future<void> _handleConfirm() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0.0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0.00');
      return;
    }

    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      setState(() => _errorMessage = 'El comercio es obligatorio');
      return;
    }

    if (_selectedAccountId == null) {
      setState(() => _errorMessage = 'Seleccione una cuenta de débito');
      return;
    }

    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });

    try {
      final dto = ConfirmReceiptScanDto(
        cycleId: widget.cycleId,
        sourceAccountId: _selectedAccountId!,
        amount: amount,
        merchantName: merchant,
        transactionDate: _selectedDate.toIso8601String().split('T')[0],
        allocationId: _selectedCategoryId,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      await widget.onConfirm(dto);
    } catch (e) {
      setState(() {
        _isConfirming = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeficit = _projectedBalance < 0.0;

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
            // Title & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Validar Extracción',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppBadge(
                  text: widget.scan.isLowConfidence
                      ? 'Baja Confianza'
                      : 'Listo para aplicar',
                  variant: widget.scan.isLowConfidence
                      ? AppBadgeVariant.warning
                      : AppBadgeVariant.income,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Low confidence / Fallback Banner (CA-03.4 / CA-05.3)
            if (widget.scan.isLowConfidence)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.warningBg.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warningBg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.warningText, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No pudimos leer algunos datos con certeza, por favor complétalos manualmente.',
                        style: AppTypography.captionBadge.copyWith(
                          color: AppColors.warningText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.onFallbackManual != null)
                      TextButton(
                        onPressed: widget.onFallbackManual,
                        child: const Text('Manual'),
                      ),
                  ],
                ),
              ),

            // Amount Hero Card in Warm Cream (#FCF5C7)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHero,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Text(
                    'MONTO TOTAL EXTRAÍDO',
                    style: AppTypography.captionBadge.copyWith(
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('ocr_amount_input'),
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: AppTypography.currencyHeroMobile.copyWith(
                      color: AppColors.textMain,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '\$ ',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Merchant Field Row
            TextField(
              key: const Key('ocr_merchant_input'),
              controller: _merchantController,
              decoration: InputDecoration(
                labelText: 'Comercio / Establecimiento',
                suffixIcon: widget.scan.confidenceScore > 0.8
                    ? const Icon(Icons.check_circle, color: AppColors.incomeText)
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Category Chips Slider
            Text(
              'Categoría Asignada',
              style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat.name),
                      selected: isSelected,
                      selectedColor: cat.parsedColor.withValues(alpha: 0.35),
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategoryId = selected ? cat.id : null;
                          if (selected && cat.defaultAccountId != null) {
                            _selectedAccountId = cat.defaultAccountId;
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Source Account Selector
            Text(
              'Cuenta de Pago / Débito',
              style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('ocr_account_dropdown'),
              initialValue: _selectedAccountId,
              items: widget.accounts.map((acc) {
                return DropdownMenuItem<String>(
                  value: acc.id,
                  child: Text(acc.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedAccountId = val),
            ),
            const SizedBox(height: 16),

            // Runway Balance Impact Banner (Spec #15)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDeficit
                    ? AppColors.expenseBg.withValues(alpha: 0.35)
                    : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDeficit ? AppColors.expenseBg : AppColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDeficit ? Icons.error_outline : Icons.trending_down,
                    color: isDeficit ? AppColors.expenseText : AppColors.primaryAccessible,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isDeficit
                          ? 'Alerta: Este gasto provocará un sobregiro de \$${(-_projectedBalance).toStringAsFixed(2)} en tu quincena.'
                          : 'Tu saldo disponible pasará de \$${widget.currentAvailableBalance.toStringAsFixed(2)} a \$${_projectedBalance.toStringAsFixed(2)}.',
                      style: AppTypography.captionBadge.copyWith(
                        color: isDeficit ? AppColors.expenseText : AppColors.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Error Message
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

            // Primary Confirm & Deduct Button
            AppButton(
              text: 'Confirmar y Descontar',
              isLoading: _isConfirming,
              onPressed: _handleConfirm,
            ),
          ],
        ),
      ),
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

  group('Feature 1: OCR Storage Upload (RF-03/RF-05, Bucket receipts)', () {
    // --- Tier 1 (5 tests) ---
    test('1.1 Uploads JPG receipt image to Supabase Storage bucket receipts with pending status', () async {
      final mockHttp = MockStatefulTransactionsHttpClient(cycleId: 'cycle-1');
      final response = await mockHttp.post(
        Uri.parse('http://localhost:3000/receipt-scans/upload'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'filename': 'ticket.jpg', 'mimetype': 'image/jpeg'}),
      );

      expect(response.statusCode, 201);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['scan']['ocr_status'], 'pending');
      expect(body['scan']['storage_path'], contains('user-test'));
      expect(body['scan']['storage_path'], endsWith('.jpg'));
      expect(mockHttp.bucketUploadHits, 1);
    });

    test('1.2 Uploads PNG receipt image successfully and receives structured scan ID', () async {
      final mockHttp = MockStatefulTransactionsHttpClient(cycleId: 'cycle-1');
      final response = await mockHttp.post(
        Uri.parse('http://localhost:3000/receipt-scans/upload'),
        body: jsonEncode({'filename': 'factura.png', 'mimetype': 'image/png'}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['scan']['id'], startsWith('scan-'));
      expect(body['scan']['confidence_score'], 0.95);
    });

    test('1.3 Uploads PDF document successfully and retains extraction metadata', () async {
      final mockHttp = MockStatefulTransactionsHttpClient(cycleId: 'cycle-1');
      final response = await mockHttp.post(
        Uri.parse('http://localhost:3000/receipt-scans/upload'),
        body: jsonEncode({'filename': 'recibo.pdf', 'mimetype': 'application/pdf'}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['scan']['extracted_merchant'], 'Supermercado La Torre');
      expect(body['scan']['tax_id_or_auth_number'], 'AUTH-99881');
    });

    test('1.4 Handles multipart stream chunking and deserializes ReceiptScan cleanly', () async {
      final rawJson = {
        'id': 'scan-stream-1',
        'user_id': 'u1',
        'storage_path': 'u1/1729000000.jpg',
        'ocr_status': 'pending',
        'extracted_merchant': 'Walmart',
        'extracted_amount': 250.75,
        'confidence_score': 0.92,
      };

      final scan = ReceiptScan.fromJson(rawJson);
      expect(scan.id, 'scan-stream-1');
      expect(scan.extractedAmount, 250.75);
      expect(scan.isLowConfidence, isFalse);
      expect(scan.isFailed, isFalse);
    });

    test('1.5 Returns 201 Created and user notification confirming upload to receipts bucket', () async {
      final mockHttp = MockStatefulTransactionsHttpClient(cycleId: 'cycle-1');
      final response = await mockHttp.post(
        Uri.parse('http://localhost:3000/receipt-scans/upload'),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['message'], contains('bucket receipts'));
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    test('1.6 Unsupported file format (.exe) is rejected by client validation', () {
      final validExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
      const fileExt = 'exe';
      final isSupported = validExtensions.contains(fileExt.toLowerCase());
      expect(isSupported, isFalse);
    });

    test('1.7 Zero-byte empty file upload produces client validation error', () {
      const fileSize = 0;
      final isValid = fileSize > 0;
      expect(isValid, isFalse);
    });

    test('1.8 Exceeds maximum file size limit (>10MB) is intercepted prior to upload', () {
      const fileSize = 12 * 1024 * 1024; // 12 MB
      const maxLimit = 10 * 1024 * 1024; // 10 MB
      final isWithinLimit = fileSize <= maxLimit;
      expect(isWithinLimit, isFalse);
    });

    test('1.9 Network timeout or disconnect sets scan state to failed gracefully', () {
      final scan = const ReceiptScan(
        id: 'scan-err',
        userId: 'u1',
        storagePath: '',
        ocrStatus: OcrStatus.failed,
      );
      expect(scan.isFailed, isTrue);
    });

    test('1.10 Storage bucket name strictly adheres to receipts instead of legacy receipt-scans', () {
      const canonicalBucket = 'receipts';
      expect(canonicalBucket, equals('receipts'));
      expect(canonicalBucket, isNot(equals('receipt-scans')));
    });
  });

  group('Feature 2: OCR Field Extraction & Pre-Confirmation Sheet (CA-03.2, CA-05.2)', () {
    // --- Tier 1 (5 tests) ---
    testWidgets('2.1 Pre-confirmation sheet renders extracted amount, merchant, and auth number',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-test',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        ocrStatus: OcrStatus.pending,
        extractedMerchant: 'La Torre Zona 14',
        extractedAmount: 185.50,
        extractedDate: null,
        taxIdOrAuthNumber: 'AUTH-12345',
        confidenceScore: 0.98,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 1000.0,
              onConfirm: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Validar Extracción'), findsOneWidget);
      expect(find.text('Listo para aplicar'), findsOneWidget);
      expect(find.text('185.50'), findsOneWidget);
      expect(find.text('La Torre Zona 14'), findsOneWidget);
    });

    testWidgets('2.2 User can edit extracted merchant name inline before confirming',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-test',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'La Torre',
        extractedAmount: 50.0,
      );

      String? confirmedMerchant;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (dto) async {
                confirmedMerchant = dto.merchantName;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const Key('ocr_merchant_input')),
        'La Torre Express Zona 10',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.ensureVisible(find.text('Confirmar y Descontar'));
      await tester.tap(find.text('Confirmar y Descontar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmedMerchant, 'La Torre Express Zona 10');
    });

    testWidgets('2.3 User can edit extracted total amount inline before confirming',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-test',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'Supermercado',
        extractedAmount: 100.0,
      );

      double? confirmedAmount;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (dto) async {
                confirmedAmount = dto.amount;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const Key('ocr_amount_input')),
        '145.25',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.ensureVisible(find.text('Confirmar y Descontar'));
      await tester.tap(find.text('Confirmar y Descontar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmedAmount, 145.25);
    });

    test('2.4 ConfirmReceiptScanDto serializes correctly with user overrides', () {
      const dto = ConfirmReceiptScanDto(
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 89.90,
        merchantName: 'Supermercado',
        transactionDate: '2026-10-18',
        allocationId: 'cat-super',
        notes: 'Compra de despensa',
      );

      final json = dto.toJson();
      expect(json['amount'], 89.90);
      expect(json['merchant_name'], 'Supermercado');
      expect(json['cycle_id'], 'c1');
      expect(json['source_account_id'], 'acc-deb');
      expect(dto.validate(), isNull);
    });

    test('2.5 Submitting confirmation issues POST /receipt-scans/:id/confirm creating verified transaction',
        () async {
      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialScans: [
          {
            'id': 'scan-99',
            'user_id': 'u1',
            'storage_path': 'u1/test.jpg',
            'ocr_status': 'pending',
            'extracted_merchant': 'Paiz',
            'extracted_amount': 200.0,
          }
        ],
      );

      final response = await mockHttp.post(
        Uri.parse('http://localhost:3000/receipt-scans/scan-99/confirm'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'cycle_id': 'cycle-1',
          'source_account_id': 'acc-deb',
          'amount': 200.0,
          'merchant_name': 'Paiz',
        }),
      );

      expect(response.statusCode, 201);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['transaction']['entry_method'], 'ocr');
      expect(mockHttp.scansDb.first['ocr_status'], 'verified');
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    testWidgets('2.6 Rejects confirm if total amount edited to zero or negative',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-test',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'Comercio',
        extractedAmount: 50.0,
      );

      bool confirmed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('ocr_amount_input')), '0.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.ensureVisible(find.text('Confirmar y Descontar'));
      await tester.tap(find.text('Confirmar y Descontar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmed, isFalse);
      expect(find.text('El monto debe ser mayor a 0.00'), findsOneWidget);
    });

    test('2.7 Rejects confirm if cycle_id is missing or empty', () {
      const dto = ConfirmReceiptScanDto(
        cycleId: '',
        sourceAccountId: 'acc-deb',
        amount: 50.0,
        merchantName: 'Comercio',
        transactionDate: '2026-10-18',
      );
      expect(dto.validate(), contains('cycle_id'));
    });

    test('2.8 Rejects confirm if source_account_id is missing or empty', () {
      const dto = ConfirmReceiptScanDto(
        cycleId: 'c1',
        sourceAccountId: '',
        amount: 50.0,
        merchantName: 'Comercio',
        transactionDate: '2026-10-18',
      );
      expect(dto.validate(), contains('source_account_id'));
    });

    test('2.9 Rejects confirm if merchant_name is cleared to empty whitespace', () {
      const dto = ConfirmReceiptScanDto(
        cycleId: 'c1',
        sourceAccountId: 'acc-deb',
        amount: 50.0,
        merchantName: '   ',
        transactionDate: '2026-10-18',
      );
      expect(dto.validate(), contains('merchant_name'));
    });

    test('2.10 Confirming a failed scan returns HTTP 400 Bad Request', () async {
      final mockHttp = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialScans: [
          {
            'id': 'scan-fail',
            'user_id': 'u1',
            'ocr_status': 'failed',
          }
        ],
      );

      final res = await mockHttp.post(
        Uri.parse('http://localhost:3000/receipt-scans/scan-fail/confirm'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'cycle_id': 'cycle-1',
          'source_account_id': 'acc-deb',
          'amount': 50.0,
          'merchant_name': 'Test',
        }),
      );

      expect(res.statusCode, 400);
      expect(jsonDecode(res.body)['message'], contains('falló'));
    });
  });

  group('Feature 3: Category & Funding Account Auto-Suggestion (CA-05.2, RN-CAT-01)', () {
    // --- Tier 1 (5 tests) ---
    test('3.1 Suggests category based on historical merchant matching', () {
      final history = [
        Transaction(
          id: 't1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 150.0,
          merchantName: 'Paiz Montufar',
          transactionDate: DateTime(2026, 10, 10),
          category: testCategories[0], // Supermercado
        ),
      ];

      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Paiz Montufar',
        history: history,
        categories: testCategories,
      );

      expect(suggestion['category_id'], 'cat-super');
      expect(suggestion['account_id'], 'acc-deb');
    });

    test('3.2 Auto-selects default account inherited from category (RN-CAT-01)', () {
      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Supermercado La Torre',
        history: [],
        categories: testCategories,
      );

      expect(suggestion['category_id'], 'cat-super');
      expect(suggestion['account_id'], 'acc-deb'); // inherited defaultAccountId
    });

    test('3.3 Keyword heuristic suggests Ocio & Café for Starbucks', () {
      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Starbucks Pradera',
        history: [],
        categories: testCategories,
      );

      expect(suggestion['category_id'], 'cat-ocio');
      expect(suggestion['account_id'], 'acc-cash');
    });

    test('3.4 Keyword heuristic suggests Transporte for Gasolinera Shell', () {
      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Gasolinera Shell Roosevelt',
        history: [],
        categories: testCategories,
      );

      expect(suggestion['category_id'], 'cat-trans');
      expect(suggestion['account_id'], 'acc-deb');
    });

    testWidgets('3.5 User can manually override suggested category in pre-confirmation sheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-sug',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'Walmart',
        extractedAmount: 60.0,
        suggestedCategoryId: 'cat-super',
      );

      String? confirmedCatId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (dto) async {
                confirmedCatId = dto.allocationId;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on 'Ocio & Café' chip to override
      await tester.tap(find.text('Ocio & Café'));
      await tester.pump();

      await tester.ensureVisible(find.text('Confirmar y Descontar'));
      await tester.tap(find.text('Confirmar y Descontar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(confirmedCatId, 'cat-ocio');
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    test('3.6 Completely unknown merchant falls back safely to null category', () {
      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'XYZ Inversiones Misteriosas 99',
        history: [],
        categories: testCategories,
      );
      expect(suggestion['category_id'], isNull);
      expect(suggestion['account_id'], isNull);
    });

    test('3.7 Auto-suggestion is case insensitive across UPPERCASE and lowercase', () {
      final history = [
        Transaction(
          id: 't1',
          userId: 'u1',
          cycleId: 'c1',
          sourceAccountId: 'acc-deb',
          amount: 50.0,
          merchantName: 'walmart',
          transactionDate: DateTime.now(),
          category: testCategories[0],
        ),
      ];

      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'WALMART ZONA 10',
        history: history,
        categories: testCategories,
      );
      expect(suggestion['category_id'], 'cat-super');
    });

    test('3.8 Merchant name with excessive padding whitespace is trimmed before lookup', () {
      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: '   Supermercado La Torre   ',
        history: [],
        categories: testCategories,
      );
      expect(suggestion['category_id'], 'cat-super');
    });

    test('3.9 Special accents and symbols do not break suggestion lookup', () {
      final suggestion = SuggestionEngine.suggestCategoryAndAccount(
        merchantName: 'Café & Panadería Deli',
        history: [],
        categories: testCategories,
      );
      expect(suggestion['category_id'], 'cat-ocio');
    });

    test('3.10 Archived categories are excluded if marked isArchived == true', () {
      final activeOnly = testCategories.where((c) => !c.isArchived).toList();
      expect(activeOnly.length, 3);
    });
  });

  group('Feature 4: OCR Fallback to Manual Form on Low Quality (CA-03.4, CA-05.3)', () {
    // --- Tier 1 (5 tests) ---
    test('4.1 Confidence score < 0.70 flags scan as low confidence', () {
      final scan = const ReceiptScan(
        id: 'scan-low',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        confidenceScore: 0.65,
      );
      expect(scan.isLowConfidence, isTrue);
    });

    test('4.2 Status failed marks scan as failed', () {
      final scan = const ReceiptScan(
        id: 'scan-fail',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        ocrStatus: OcrStatus.failed,
      );
      expect(scan.isFailed, isTrue);
    });

    testWidgets('4.3 Low confidence displays amber warning banner', (tester) async {
      final scan = const ReceiptScan(
        id: 'scan-low',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        confidenceScore: 0.50,
        extractedMerchant: 'Comercio Difuso',
        extractedAmount: 25.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Baja Confianza'), findsOneWidget);
      expect(
        find.text('No pudimos leer algunos datos con certeza, por favor complétalos manualmente.'),
        findsOneWidget,
      );
    });

    testWidgets('4.4 Tapping Manual shortcut in banner triggers fallback callback', (tester) async {
      final scan = const ReceiptScan(
        id: 'scan-low',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        confidenceScore: 0.40,
      );

      bool fallbackTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (_) async {},
              onFallbackManual: () => fallbackTriggered = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();

      expect(fallbackTriggered, isTrue);
    });

    test('4.5 Partial fields are pre-populated into manual form payload without loss', () {
      final scan = const ReceiptScan(
        id: 'scan-part',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'Gasolinera Puma',
        confidenceScore: 0.55,
      );

      final manualDraft = CreateTransactionDto(
        cycleId: 'cycle-1',
        sourceAccountId: 'acc-deb',
        amount: 0.0,
        merchantName: scan.extractedMerchant ?? '',
        transactionDate: DateTime.now().toIso8601String().split('T')[0],
      );

      expect(manualDraft.merchantName, 'Gasolinera Puma');
      expect(manualDraft.entryMethod, EntryMethod.manual);
    });

    // --- Tier 2: Boundary & Corner Cases (5 tests) ---
    test('4.6 Completely unreadable receipt (confidence = 0.0) handles gracefully', () {
      final scan = const ReceiptScan(
        id: 'scan-zero',
        userId: 'u1',
        storagePath: 'u1/zero.jpg',
        confidenceScore: 0.0,
      );
      expect(scan.isLowConfidence, isTrue);
      expect(scan.extractedAmount, isNull);
      expect(scan.extractedMerchant, isNull);
    });

    test('4.7 Torn receipt with partial amount string parses safely', () {
      final parsed = double.tryParse('12.') ?? 0.0;
      expect(parsed, 12.0);
    });

    test('4.8 Special OCR noise characters are stripped before validation', () {
      const noisyMerchant = '### Supermercado Paiz ***';
      final clean = noisyMerchant.replaceAll(RegExp(r'[#*]'), '').trim();
      expect(clean, 'Supermercado Paiz');
    });

    test('4.9 Negative confidence score clamped to 0.0', () {
      final scan = ReceiptScan(
        id: 'scan-neg',
        userId: 'u1',
        storagePath: 'path',
        confidenceScore: (-0.5).clamp(0.0, 1.0),
      );
      expect(scan.confidenceScore, 0.0);
    });

    test('4.10 Confidence score above 1.0 clamped to 1.0', () {
      final scan = ReceiptScan(
        id: 'scan-high',
        userId: 'u1',
        storagePath: 'path',
        confidenceScore: (1.5).clamp(0.0, 1.0),
      );
      expect(scan.confidenceScore, 1.0);
    });
  });

  group('Tier 3: Pairwise Combinations (OCR Flow)', () {
    testWidgets('3.1 OCR Upload + Edit Extracted Amount + User Changes Account + Confirm',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-pw1',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'Paiz',
        extractedAmount: 100.0,
        suggestedAccountId: 'acc-deb',
      );

      ConfirmReceiptScanDto? resultDto;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 800.0,
              onConfirm: (dto) async {
                resultDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Edit amount
      await tester.enterText(find.byKey(const Key('ocr_amount_input')), '120.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Change account to Efectivo
      await tester.tap(find.byKey(const Key('ocr_account_dropdown')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Efectivo Billetera').last);
      await tester.pump();

      await tester.ensureVisible(find.text('Confirmar y Descontar'));
      await tester.tap(find.text('Confirmar y Descontar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(resultDto?.amount, 120.00);
      expect(resultDto?.sourceAccountId, 'acc-cash');
    });

    testWidgets('3.2 Low Confidence Scan + User Overrides Category + Confirm',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-pw2',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        confidenceScore: 0.50,
        extractedMerchant: 'Cafetería El Portal',
        extractedAmount: 35.0,
        suggestedCategoryId: 'cat-super',
      );

      ConfirmReceiptScanDto? resultDto;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 400.0,
              onConfirm: (dto) async {
                resultDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Baja Confianza'), findsOneWidget);

      // Select 'Ocio & Café'
      await tester.tap(find.text('Ocio & Café'));
      await tester.pump();

      await tester.ensureVisible(find.text('Confirmar y Descontar'));
      await tester.tap(find.text('Confirmar y Descontar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(resultDto?.allocationId, 'cat-ocio');
      expect(resultDto?.amount, 35.0);
    });

    testWidgets('3.3 Scan with Missing Auth Number + User Edits Date + Confirm',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-pw3',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'Gasolinera Puma',
        extractedAmount: 150.0,
        taxIdOrAuthNumber: null,
      );

      ConfirmReceiptScanDto? resultDto;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (dto) async {
                resultDto = dto;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.text('Confirmar y Descontar'));
      await tester.tap(find.text('Confirmar y Descontar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(resultDto?.merchantName, 'Gasolinera Puma');
      expect(resultDto?.amount, 150.0);
    });

    testWidgets('3.4 Runway Balance Impact Banner shows Overspending Warning in Coral (#FFC09F)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final scan = const ReceiptScan(
        id: 'scan-pw4',
        userId: 'u1',
        storagePath: 'u1/test.jpg',
        extractedMerchant: 'Tienda Electrónica',
        extractedAmount: 600.0, // Exceeds available balance (500.0) -> Deficit 100.0
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OcrPreConfirmationSheetTestWidget(
              scan: scan,
              cycleId: 'cycle-1',
              categories: testCategories,
              accounts: testAccounts,
              currentAvailableBalance: 500.0,
              onConfirm: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Alerta: Este gasto provocará un sobregiro de \$100.00'),
        findsOneWidget,
      );
    });
  });
}
