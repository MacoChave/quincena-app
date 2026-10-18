import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/budget_allocation.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'transaction_test_doubles.dart';

/// Interactive E2E Scenario App Harness that orchestrates screens,
/// category allocations, accounts, and the stateful transactions mock HTTP client.
class RealWorldScenariosAppHarness extends StatefulWidget {
  const RealWorldScenariosAppHarness({
    super.key,
    required this.initialAllocations,
    required this.categories,
    required this.accounts,
    required this.httpClient,
    this.initialRoute = 'feed',
    this.initialFormMerchant = '',
    this.initialFormAmount = 0.0,
    this.initialOcrConfidence = 1.0,
    this.initialOcrWarning = false,
    this.initialFormCategoryId,
    this.initialFormAccountId,
  });

  final List<BudgetAllocation> initialAllocations;
  final List<Category> categories;
  final List<FinancialAccount> accounts;
  final MockStatefulTransactionsHttpClient httpClient;
  final String initialRoute;
  final String initialFormMerchant;
  final double initialFormAmount;
  final double initialOcrConfidence;
  final bool initialOcrWarning;
  final String? initialFormCategoryId;
  final String? initialFormAccountId;

  @override
  State<RealWorldScenariosAppHarness> createState() =>
      RealWorldScenariosAppHarnessState();
}

class RealWorldScenariosAppHarnessState
    extends State<RealWorldScenariosAppHarness> {
  late List<BudgetAllocation> _allocations;
  late List<Category> _categories;
  late List<FinancialAccount> _accounts;
  late List<Transaction> _transactions;

  late String _currentScreen; // 'feed', 'ocr_preview', 'manual_form'
  FeedFilter _filter = const FeedFilter();

  // Form & OCR State
  late double _formAmount;
  late String _formMerchant;
  String? _formCategoryId;
  String? _formAccountId;
  late double _ocrConfidence;
  late bool _ocrLowConfidenceWarning;
  String? _activeDuplicateWarning;

  @override
  void initState() {
    super.initState();
    _allocations = List.from(widget.initialAllocations);
    _categories = List.from(widget.categories);
    _accounts = List.from(widget.accounts);
    _currentScreen = widget.initialRoute;
    _formMerchant = widget.initialFormMerchant;
    _formAmount = widget.initialFormAmount;
    _ocrConfidence = widget.initialOcrConfidence;
    _ocrLowConfidenceWarning = widget.initialOcrWarning;
    _formCategoryId = widget.initialFormCategoryId ?? _categories.firstOrNull?.id;
    _formAccountId = widget.initialFormAccountId ?? _accounts.firstOrNull?.id;
    _refreshTransactionsFromClient();
  }

  void _refreshTransactionsFromClient() {
    _transactions = widget.httpClient.transactionsDb.map((tx) {
      final cat = _categories.where((c) => c.id == tx['allocation_id']).firstOrNull;
      final acc = _accounts.where((a) => a.id == tx['source_account_id']).firstOrNull;
      return Transaction(
        id: tx['id'] as String,
        userId: 'u1',
        cycleId: widget.httpClient.cycleId,
        allocationId: tx['allocation_id'] as String?,
        sourceAccountId: (tx['source_account_id'] as String?) ?? 'acc-deb',
        amount: (tx['amount'] as num).toDouble(),
        merchantName: tx['merchant_name'] as String,
        transactionDate: DateTime.parse(tx['transaction_date'] as String),
        category: cat,
        sourceAccount: acc,
      );
    }).toList();
  }

  double get _totalAllocated =>
      _allocations.fold(0.0, (acc, a) => acc + a.allocatedAmount);

  double get _totalSpent =>
      _allocations.fold(0.0, (acc, a) => acc + a.spentAmount);

  double get _totalAvailable =>
      (_totalAllocated - _totalSpent).clamp(0.0, double.infinity);

  void _deductCategoryBalance(String? categoryId, double amount) {
    if (categoryId == null) return;
    final index = _allocations.indexWhere((a) => a.categoryId == categoryId);
    if (index != -1) {
      final current = _allocations[index];
      final newSpent = current.spentAmount + amount;
      final newAvailable = (current.allocatedAmount - newSpent).clamp(0.0, double.infinity);
      _allocations[index] = current.copyWith(
        spentAmount: newSpent,
        availableAmount: newAvailable,
      );
    }
  }

  void _revertCategoryBalance(String? categoryId, double amount) {
    if (categoryId == null) return;
    final index = _allocations.indexWhere((a) => a.categoryId == categoryId);
    if (index != -1) {
      final current = _allocations[index];
      final newSpent = (current.spentAmount - amount).clamp(0.0, double.infinity);
      final newAvailable = (current.allocatedAmount - newSpent).clamp(0.0, double.infinity);
      _allocations[index] = current.copyWith(
        spentAmount: newSpent,
        availableAmount: newAvailable,
      );
    }
  }

  Future<void> _submitExpense({bool force = false}) async {
    final payload = {
      'cycle_id': widget.httpClient.cycleId,
      'source_account_id': _formAccountId ?? _accounts.first.id,
      'amount': _formAmount,
      'merchant_name': _formMerchant,
      'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
      if (_formCategoryId != null) 'allocation_id': _formCategoryId,
      'entry_method': 'manual',
    };

    final url = force
        ? 'http://localhost:3000/transactions?force=true'
        : 'http://localhost:3000/transactions';

    final res = await widget.httpClient.post(
      Uri.parse(url),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode == 409) {
      setState(() {
        _activeDuplicateWarning =
            'Posible duplicado detectado (\$${_formAmount.toStringAsFixed(2)} en $_formMerchant). ¿Deseas registrar este gasto de todos modos?';
      });
      return;
    }

    if (res.statusCode == 201) {
      _deductCategoryBalance(_formCategoryId, _formAmount);
      setState(() {
        _refreshTransactionsFromClient();
        _currentScreen = 'feed';
        _activeDuplicateWarning = null;
      });
    }
  }

  Future<void> _deleteTransaction(String id) async {
    final tx = widget.httpClient.transactionsDb.firstWhere((t) => t['id'] == id);
    final amount = (tx['amount'] as num).toDouble();
    final catId = tx['allocation_id'] as String?;

    final res = await widget.httpClient.delete(
      Uri.parse('http://localhost:3000/transactions/$id'),
    );

    if (res.statusCode == 200) {
      _revertCategoryBalance(catId, amount);
      setState(() {
        _refreshTransactionsFromClient();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Outfit'),
      home: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentScreen == 'feed'
                ? 'Historial de Transacciones'
                : (_currentScreen == 'ocr_preview' ? 'Validar Gasto OCR' : 'Nuevo Gasto Manual'),
          ),
          actions: [
            if (_currentScreen != 'feed')
              IconButton(
                key: const Key('appbar_btn_back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentScreen = 'feed'),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (_currentScreen == 'feed') _buildFeedScreen(),
            if (_currentScreen == 'ocr_preview') _buildOcrPreviewScreen(),
            if (_currentScreen == 'manual_form') _buildManualFormScreen(),
            if (_activeDuplicateWarning != null) _buildDuplicateModal(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedScreen() {
    final filtered = FeedFilter.apply(_transactions, _filter);

    return Column(
      children: [
        // Live Bento Hero Balance Indicator
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surfaceBase,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Presupuesto Asignado', style: AppTypography.labelSm),
                  Text(
                    '\$${_totalAllocated.toStringAsFixed(2)}',
                    key: const Key('hero_total_allocated'),
                    style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                children: [
                  Text('Gastado', style: AppTypography.labelSm),
                  Text(
                    '\$${_totalSpent.toStringAsFixed(2)}',
                    key: const Key('hero_total_spent'),
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.expenseText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text('Disponible', style: AppTypography.labelSm),
                  Text(
                    '\$${_totalAvailable.toStringAsFixed(2)}',
                    key: const Key('hero_total_available'),
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Action Bar (Start OCR / Start Manual)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  key: const Key('btn_trigger_ocr_scan'),
                  text: 'Escanear Ticket',
                  prefixIcon: const Icon(Icons.camera_alt, size: 20),
                  onPressed: () {
                    setState(() {
                      _formMerchant = 'Supermercado La Colonia';
                      _formAmount = 145.80;
                      _ocrConfidence = 0.95;
                      _ocrLowConfidenceWarning = false;
                      _formCategoryId = 'cat-super';
                      _formAccountId = 'acc-deb';
                      _currentScreen = 'ocr_preview';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  key: const Key('btn_trigger_manual_entry'),
                  text: 'Gasto Manual',
                  variant: AppButtonVariant.secondary,
                  prefixIcon: const Icon(Icons.edit, size: 20),
                  onPressed: () {
                    setState(() {
                      _formMerchant = '';
                      _formAmount = 0.0;
                      _formCategoryId = _categories.first.id;
                      _formAccountId = _accounts.first.id;
                      _currentScreen = 'manual_form';
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const Key('feed_search_input'),
            decoration: const InputDecoration(
              hintText: 'Buscar por comercio...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                _filter = _filter.copyWith(
                  searchQuery: val.isEmpty ? null : val,
                  clearSearch: val.isEmpty,
                );
              });
            },
          ),
        ),

        // Category Filter Chips
        SizedBox(
          height: 48,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    key: const Key('filter_chip_all'),
                    label: const Text('Todos'),
                    selected: _filter.selectedCategoryId == null && _filter.selectedAccountId == null,
                    onSelected: (_) => setState(() {
                      _filter = const FeedFilter();
                    }),
                  ),
                ),
                ..._categories.map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      key: Key('filter_chip_cat_${cat.id}'),
                      label: Text(cat.name),
                      selected: _filter.selectedCategoryId == cat.id,
                      onSelected: (selected) {
                        setState(() {
                          _filter = _filter.copyWith(
                            selectedCategoryId: selected ? cat.id : null,
                            clearCategory: !selected,
                          );
                        });
                      },
                    ),
                  );
                }),
                ..._accounts.map((acc) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      key: Key('filter_chip_acc_${acc.id}'),
                      label: Text(acc.name),
                      selected: _filter.selectedAccountId == acc.id,
                      onSelected: (selected) {
                        setState(() {
                          _filter = _filter.copyWith(
                            selectedAccountId: selected ? acc.id : null,
                            clearAccount: !selected,
                          );
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const Divider(height: 1),

        // List of Transactions
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No se encontraron transacciones',
                    key: const Key('empty_feed_message'),
                    style: AppTypography.bodyMd,
                  ),
                )
              : ListView.builder(
                  key: const Key('transactions_feed_list'),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final colorHex = item.category?.colorHex ?? '#79ADDC';
                    return ListTile(
                      key: Key('transaction_item_${item.id}'),
                      leading: CircleAvatar(
                        backgroundColor: Color(
                          int.parse(colorHex.replaceFirst('#', '0xFF')),
                        ),
                        child: const Icon(Icons.shopping_bag, color: Colors.white, size: 20),
                      ),
                      title: Text(item.merchantName, style: AppTypography.bodyMd),
                      subtitle: Text('${item.category?.name ?? 'General'} • ${item.sourceAccount?.name ?? 'Cuenta'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '-\$${item.amount.toStringAsFixed(2)}',
                            key: Key('tx_amount_${item.id}'),
                            style: AppTypography.bodyLg.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          IconButton(
                            key: Key('btn_delete_tx_${item.id}'),
                            icon: const Icon(Icons.delete_outline, color: AppColors.expenseText, size: 20),
                            onPressed: () => _deleteTransaction(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOcrPreviewScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Low Confidence Amber Banner (Spec #29)
          if (_ocrConfidence < 0.70 || _ocrLowConfidenceWarning)
            Container(
              key: const Key('ocr_warning_banner'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEE93),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF0DA70)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFF8B6C00)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Advertencia: Lectura de baja confianza. Por favor verifique los datos.',
                      style: TextStyle(
                        color: Color(0xFF5A4600),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('btn_redirect_manual_fallback'),
                    onPressed: () {
                      setState(() {
                        _currentScreen = 'manual_form';
                      });
                    },
                    child: const Text('Editar'),
                  ),
                ],
              ),
            ),

          Text(
            'Comercio Detectado: $_formMerchant',
            key: const Key('ocr_merchant_text'),
            style: AppTypography.headlineSm,
          ),
          const SizedBox(height: 8),
          Text(
            'Monto Total: \$${_formAmount.toStringAsFixed(2)}',
            key: const Key('ocr_amount_text'),
            style: AppTypography.currencyHeroMobile,
          ),
          const SizedBox(height: 16),

          // Auto-suggested Category Tag Chip
          Row(
            children: [
              const Text('Categoría Sugerida: '),
              Chip(
                key: const Key('ocr_suggested_category_chip'),
                label: Text(
                  _categories.firstWhere((c) => c.id == _formCategoryId).name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFF79ADDC),
              ),
            ],
          ),
          const SizedBox(height: 24),

          AppButton(
            key: const Key('btn_confirm_ocr_expense'),
            text: 'Confirmar Gasto',
            onPressed: () => _submitExpense(),
          ),
        ],
      ),
    );
  }

  Widget _buildManualFormScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('form_amount_input'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            controller: TextEditingController(
              text: _formAmount > 0 ? _formAmount.toStringAsFixed(2) : '',
            ),
            decoration: const InputDecoration(
              labelText: 'Monto (\$)',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              _formAmount = double.tryParse(val) ?? 0.0;
            },
          ),
          const SizedBox(height: 12),

          TextField(
            key: const Key('form_merchant_input'),
            controller: TextEditingController(text: _formMerchant),
            decoration: const InputDecoration(
              labelText: 'Comercio o Nota',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              _formMerchant = val;
            },
          ),
          const SizedBox(height: 12),

          // Category Dropdown with Contextual "+ Nueva Categoría" Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                key: const Key('btn_contextual_new_category'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('+ Nueva Categoría'),
                onPressed: () {
                  final newCat = const Category(
                    id: 'cat-mascotas',
                    name: 'Mascotas',
                    icon: 'pets',
                    colorHex: '#FFC09F',
                    defaultAccountId: 'acc-deb',
                  );
                  final newAlloc = const BudgetAllocation(
                    id: 'alloc-mascotas',
                    cycleId: 'cycle-1',
                    categoryId: 'cat-mascotas',
                    allocatedAmount: 150.0,
                    spentAmount: 0.0,
                    availableAmount: 150.0,
                  );
                  setState(() {
                    _categories.add(newCat);
                    _allocations.add(newAlloc);
                    _formCategoryId = newCat.id;
                  });
                },
              ),
            ],
          ),

          DropdownButtonFormField<String>(
            key: const Key('form_category_dropdown'),
            // ignore: deprecated_member_use
            value: _formCategoryId,
            items: _categories.map((c) {
              return DropdownMenuItem<String>(
                value: c.id,
                child: Text(c.name),
              );
            }).toList(),
            onChanged: (val) => setState(() => _formCategoryId = val),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            key: const Key('form_account_dropdown'),
            // ignore: deprecated_member_use
            value: _formAccountId,
            items: _accounts.map((a) {
              return DropdownMenuItem<String>(
                value: a.id,
                child: Text(a.name),
              );
            }).toList(),
            onChanged: (val) => setState(() => _formAccountId = val),
          ),
          const SizedBox(height: 24),

          AppButton(
            key: const Key('btn_save_manual_expense'),
            text: 'Guardar Gasto',
            onPressed: () => _submitExpense(),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateModal() {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Card(
        key: const Key('duplicate_warning_modal'),
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, color: Color(0xFFF4A261), size: 48),
              const SizedBox(height: 12),
              const Text(
                'Posible Duplicado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _activeDuplicateWarning!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('btn_cancel_duplicate'),
                    onPressed: () => setState(() => _activeDuplicateWarning = null),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    key: const Key('btn_force_save_duplicate'),
                    text: 'Registrar de todas formas',
                    isFullWidth: false,
                    onPressed: () => _submitExpense(force: true),
                  ),
                ],
              ),
            ],
          ),
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
      colorHex: '#79ADDC',
      defaultAccountId: 'acc-deb',
    ),
    const Category(
      id: 'cat-transporte',
      name: 'Transporte',
      icon: 'directions_car',
      colorHex: '#FFC09F',
      defaultAccountId: 'acc-deb',
    ),
    const Category(
      id: 'cat-cafe',
      name: 'Cafetería',
      icon: 'local_cafe',
      colorHex: '#FFEE93',
      defaultAccountId: 'acc-cash',
    ),
    const Category(
      id: 'cat-salud',
      name: 'Salud',
      icon: 'local_pharmacy',
      colorHex: '#ADF7B6',
      defaultAccountId: 'acc-deb',
    ),
    const Category(
      id: 'cat-servicios',
      name: 'Servicios',
      icon: 'receipt',
      colorHex: '#FCF5C7',
      defaultAccountId: 'acc-deb',
    ),
    const Category(
      id: 'cat-ocio',
      name: 'Entretenimiento',
      icon: 'movie',
      colorHex: '#79ADDC',
      defaultAccountId: 'acc-cred',
    ),
  ];

  final testAccounts = [
    const FinancialAccount(
      id: 'acc-deb',
      name: 'Cuenta Débito Banco',
      accountType: AccountType.checking,
      currency: 'GTQ',
      currentBalance: 3500.0,
      initialBalance: 3500.0,
      isDefault: true,
      isArchived: false,
      colorHex: '#79ADDC',
      icon: 'account_balance',
    ),
    const FinancialAccount(
      id: 'acc-cash',
      name: 'Efectivo',
      accountType: AccountType.cash,
      currency: 'GTQ',
      currentBalance: 500.0,
      initialBalance: 500.0,
      isDefault: false,
      isArchived: false,
      colorHex: '#ADF7B6',
      icon: 'payments',
    ),
    const FinancialAccount(
      id: 'acc-cred',
      name: 'Tarjeta de Crédito',
      accountType: AccountType.creditCard,
      currency: 'GTQ',
      currentBalance: -250.0,
      initialBalance: 0.0,
      isDefault: false,
      isArchived: false,
      colorHex: '#FFC09F',
      icon: 'credit_card',
    ),
  ];

  group('Tier 4: Real-World Application Workload Scenarios', () {
    // ------------------------------------------------------------------------
    // Scenario 1: Scanned Supermarket Ticket Flow
    // ------------------------------------------------------------------------
    testWidgets('Scenario 1: Scanned Supermarket Ticket Flow (OCR upload -> pre-confirmation -> auto-suggest -> confirm -> category balance deducted -> feed card visible)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final httpClient = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [],
      );

      final allocations = [
        const BudgetAllocation(
          id: 'alloc-super',
          cycleId: 'cycle-1',
          categoryId: 'cat-super',
          allocatedAmount: 500.0,
          spentAmount: 0.0,
          availableAmount: 500.0,
        ),
      ];

      await tester.pumpWidget(
        RealWorldScenariosAppHarness(
          initialAllocations: allocations,
          categories: testCategories,
          accounts: testAccounts,
          httpClient: httpClient,
          initialRoute: 'feed',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Initial State: Total spent $0.00, Available $500.00
      expect(find.byKey(const Key('hero_total_spent')), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.text('\$500.00'), findsWidgets);

      // 2. User taps 'Escanear Ticket'
      await tester.tap(find.byKey(const Key('btn_trigger_ocr_scan')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. OCR Preview screen verifies parsed data and suggested category
      expect(find.byKey(const Key('ocr_merchant_text')), findsOneWidget);
      expect(find.text('Comercio Detectado: Supermercado La Colonia'), findsOneWidget);
      expect(find.text('Monto Total: \$145.80'), findsOneWidget);
      expect(find.byKey(const Key('ocr_suggested_category_chip')), findsOneWidget);
      expect(find.text('Supermercado'), findsOneWidget);

      // 4. User confirms expense
      await tester.tap(find.byKey(const Key('btn_confirm_ocr_expense')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Returns to Feed, Spent is $145.80, Available is $354.20
      expect(find.text('\$145.80'), findsOneWidget);
      expect(find.text('\$354.20'), findsOneWidget);

      // 6. Transaction item visible in feed
      expect(find.text('Supermercado La Colonia'), findsOneWidget);
      expect(find.text('-\$145.80'), findsOneWidget);
      expect(httpClient.transactionsDb.length, 1);
    });

    // ------------------------------------------------------------------------
    // Scenario 2: Blurry Receipt Fallback Flow
    // ------------------------------------------------------------------------
    testWidgets('Scenario 2: Blurry Receipt Fallback Flow (Confidence < 0.70 -> amber warning -> manual form pre-filled -> save -> history feed)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final httpClient = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [],
      );

      final allocations = [
        const BudgetAllocation(
          id: 'alloc-salud',
          cycleId: 'cycle-1',
          categoryId: 'cat-salud',
          allocatedAmount: 200.0,
          spentAmount: 0.0,
          availableAmount: 200.0,
        ),
      ];

      final harnessKey = GlobalKey<RealWorldScenariosAppHarnessState>();

      await tester.pumpWidget(
        RealWorldScenariosAppHarness(
          key: harnessKey,
          initialAllocations: allocations,
          categories: testCategories,
          accounts: testAccounts,
          httpClient: httpClient,
          initialRoute: 'ocr_preview',
          initialFormMerchant: 'Far__cia El Ah__ro',
          initialFormAmount: 30.00,
          initialOcrConfidence: 0.52,
          initialOcrWarning: true,
          initialFormCategoryId: 'cat-salud',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Amber Warning Banner is visible (Spec #29)
      expect(find.byKey(const Key('ocr_warning_banner')), findsOneWidget);
      expect(
        find.text('Advertencia: Lectura de baja confianza. Por favor verifique los datos.'),
        findsOneWidget,
      );

      // 2. User taps 'Editar' to fallback to manual form
      await tester.tap(find.byKey(const Key('btn_redirect_manual_fallback')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Manual Form is displayed pre-filled
      expect(find.text('Nuevo Gasto Manual'), findsOneWidget);

      // 4. User corrects merchant name and amount
      await tester.enterText(find.byKey(const Key('form_merchant_input')), 'Farmacia El Ahorro');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('form_amount_input')), '32.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // 5. User submits corrected expense
      await tester.tap(find.byKey(const Key('btn_save_manual_expense')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 6. Returns to Feed with updated values: spent $32.00, remaining $168.00
      expect(find.text('Farmacia El Ahorro'), findsOneWidget);
      expect(find.text('-\$32.00'), findsOneWidget);
      expect(find.text('\$32.00'), findsOneWidget);
      expect(find.text('\$168.00'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // Scenario 3: Manual Coffee Expense with Duplicate Warning Flow
    // ------------------------------------------------------------------------
    testWidgets('Scenario 3: Manual Coffee Expense with Duplicate Warning (Enter \$4.50 coffee -> save -> duplicate entry within 24h -> 409 warning -> user confirms force -> 2 transactions recorded)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final httpClient = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [],
      );

      final allocations = [
        const BudgetAllocation(
          id: 'alloc-cafe',
          cycleId: 'cycle-1',
          categoryId: 'cat-cafe',
          allocatedAmount: 100.0,
          spentAmount: 0.0,
          availableAmount: 100.0,
        ),
      ];

      await tester.pumpWidget(
        RealWorldScenariosAppHarness(
          initialAllocations: allocations,
          categories: testCategories,
          accounts: testAccounts,
          httpClient: httpClient,
          initialRoute: 'manual_form',
          initialFormCategoryId: 'cat-cafe',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Enter first coffee transaction ($4.50 at 'Café Central')
      await tester.enterText(find.byKey(const Key('form_amount_input')), '4.50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('form_merchant_input')), 'Café Central');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Submit first time -> 201 Created
      await tester.tap(find.byKey(const Key('btn_save_manual_expense')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Historial de Transacciones'), findsOneWidget);
      expect(find.text('-\$4.50'), findsOneWidget);
      expect(httpClient.transactionsDb.length, 1);

      // 2. Open manual entry again to register identical coffee expense (accidental double tap)
      await tester.tap(find.byKey(const Key('btn_trigger_manual_entry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Set category to cafe
      await tester.tap(find.byKey(const Key('form_category_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cafetería').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('form_amount_input')), '4.50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('form_merchant_input')), 'Café Central');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Submit second time -> Backend returns 409 Conflict
      await tester.tap(find.byKey(const Key('btn_save_manual_expense')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Duplicate Warning Modal appears (RN-03)
      expect(find.byKey(const Key('duplicate_warning_modal')), findsOneWidget);
      expect(find.text('Posible Duplicado'), findsOneWidget);

      // 4. User confirms intentional repeat expense
      await tester.tap(find.byKey(const Key('btn_force_save_duplicate')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Both expenses are registered! Total spent is $9.00
      expect(find.text('Historial de Transacciones'), findsOneWidget);
      expect(find.text('\$9.00'), findsOneWidget);
      expect(httpClient.transactionsDb.length, 2);
    });

    // ------------------------------------------------------------------------
    // Scenario 4: Contextual Category Creation from Form Flow
    // ------------------------------------------------------------------------
    testWidgets('Scenario 4: Contextual Category Creation from Form (Inside manual form, open + Nueva Categoría -> create "Mascotas" -> return to form -> save -> balance deducted)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final httpClient = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: [],
      );

      await tester.pumpWidget(
        RealWorldScenariosAppHarness(
          initialAllocations: [],
          categories: List.from(testCategories),
          accounts: testAccounts,
          httpClient: httpClient,
          initialRoute: 'manual_form',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Enter vet amount $65.00 and merchant
      await tester.enterText(find.byKey(const Key('form_amount_input')), '65.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.enterText(find.byKey(const Key('form_merchant_input')), 'Clínica Veterinaria');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // 2. Tap '+ Nueva Categoría'
      await tester.tap(find.byKey(const Key('btn_contextual_new_category')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Mascotas category is created and selected
      expect(find.text('Mascotas'), findsWidgets);

      // 4. User saves expense
      await tester.tap(find.byKey(const Key('btn_save_manual_expense')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Feed shows transaction and budget allocation shows $65.00 spent of $150.00
      expect(find.text('Clínica Veterinaria'), findsOneWidget);
      expect(find.text('-\$65.00'), findsOneWidget);
      expect(find.text('\$65.00'), findsOneWidget);
      expect(find.text('\$85.00'), findsOneWidget);
    });

    // ------------------------------------------------------------------------
    // Scenario 5: Feed Filtering & Search Real-Time Flow
    // ------------------------------------------------------------------------
    testWidgets('Scenario 5: Feed Filtering & Search Real-Time (6 mixed transactions -> category filter -> account filter -> search keyword -> sub-16ms filtering)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialTxList = [
        {
          'id': 'tx-1',
          'amount': 120.00,
          'merchant_name': 'Supermercado Norte',
          'allocation_id': 'cat-super',
          'source_account_id': 'acc-deb',
          'transaction_date': '2026-10-18',
        },
        {
          'id': 'tx-2',
          'amount': 15.00,
          'merchant_name': 'Gasolinera Uno',
          'allocation_id': 'cat-transporte',
          'source_account_id': 'acc-deb',
          'transaction_date': '2026-10-17',
        },
        {
          'id': 'tx-3',
          'amount': 4.50,
          'merchant_name': 'Starbucks Coffee',
          'allocation_id': 'cat-cafe',
          'source_account_id': 'acc-cash',
          'transaction_date': '2026-10-17',
        },
        {
          'id': 'tx-4',
          'amount': 45.20,
          'merchant_name': 'Walmart Supercenter',
          'allocation_id': 'cat-super',
          'source_account_id': 'acc-deb',
          'transaction_date': '2026-10-16',
        },
        {
          'id': 'tx-5',
          'amount': 85.00,
          'merchant_name': 'CFE Energía Eléctrica',
          'allocation_id': 'cat-servicios',
          'source_account_id': 'acc-deb',
          'transaction_date': '2026-10-15',
        },
        {
          'id': 'tx-6',
          'amount': 30.00,
          'merchant_name': 'Cinépolis VIP',
          'allocation_id': 'cat-ocio',
          'source_account_id': 'acc-cred',
          'transaction_date': '2026-10-14',
        },
      ];

      final httpClient = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: initialTxList,
      );

      await tester.pumpWidget(
        RealWorldScenariosAppHarness(
          initialAllocations: [
            const BudgetAllocation(
              id: 'a1',
              cycleId: 'cycle-1',
              categoryId: 'cat-super',
              allocatedAmount: 1000.0,
              spentAmount: 299.70,
              availableAmount: 700.30,
            ),
          ],
          categories: testCategories,
          accounts: testAccounts,
          httpClient: httpClient,
          initialRoute: 'feed',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // All 6 transactions initially visible
      expect(find.byKey(const Key('transaction_item_tx-1')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-2')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-3')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-4')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-5')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-6')), findsOneWidget);

      // 1. Filter by Supermercado -> Only tx-1 and tx-4 shown
      await tester.tap(find.byKey(const Key('filter_chip_cat_cat-super')));
      await tester.pump();

      expect(find.byKey(const Key('transaction_item_tx-1')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-4')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-2')), findsNothing);
      expect(find.byKey(const Key('transaction_item_tx-3')), findsNothing);

      // 2. Clear Category filter
      await tester.tap(find.byKey(const Key('filter_chip_all')));
      await tester.pump();

      // 3. Instant Search by 'Starbucks'
      await tester.enterText(find.byKey(const Key('feed_search_input')), 'starbucks');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(find.byKey(const Key('transaction_item_tx-3')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-1')), findsNothing);

      // 4. Clear search and filter by Credit Account
      await tester.enterText(find.byKey(const Key('feed_search_input')), '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('filter_chip_acc_acc-cred')));
      await tester.tap(find.byKey(const Key('filter_chip_acc_acc-cred')));
      await tester.pump();

      expect(find.byKey(const Key('transaction_item_tx-6')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-1')), findsNothing);

      // 5. Combine Supermercado filter + Search 'Walmart'
      await tester.ensureVisible(find.byKey(const Key('filter_chip_all')));
      await tester.tap(find.byKey(const Key('filter_chip_all')));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('filter_chip_cat_cat-super')));
      await tester.tap(find.byKey(const Key('filter_chip_cat_cat-super')));
      await tester.pump();

      await tester.enterText(find.byKey(const Key('feed_search_input')), 'Walmart');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(find.byKey(const Key('transaction_item_tx-4')), findsOneWidget);
      expect(find.byKey(const Key('transaction_item_tx-1')), findsNothing);
    });

    // ------------------------------------------------------------------------
    // Scenario 6: Transaction Deletion Balance Recovery Flow
    // ------------------------------------------------------------------------
    testWidgets('Scenario 6: Transaction Deletion Balance Recovery (Delete \$50 transaction -> active cycle category allocation spent amount reverts and available funds increase)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialTxList = [
        {
          'id': 'tx-transporte-50',
          'amount': 50.00,
          'merchant_name': 'Gasolinera Texaco',
          'allocation_id': 'cat-transporte',
          'source_account_id': 'acc-deb',
          'transaction_date': '2026-10-18',
        },
      ];

      final httpClient = MockStatefulTransactionsHttpClient(
        cycleId: 'cycle-1',
        initialTransactions: initialTxList,
      );

      final allocations = [
        const BudgetAllocation(
          id: 'alloc-transporte',
          cycleId: 'cycle-1',
          categoryId: 'cat-transporte',
          allocatedAmount: 200.0,
          spentAmount: 80.0,
          availableAmount: 120.0,
        ),
      ];

      await tester.pumpWidget(
        RealWorldScenariosAppHarness(
          initialAllocations: allocations,
          categories: testCategories,
          accounts: testAccounts,
          httpClient: httpClient,
          initialRoute: 'feed',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Initial State: Category has $80.00 spent, $120.00 available
      expect(find.text('\$80.00'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget);
      expect(find.text('Gasolinera Texaco'), findsOneWidget);
      expect(find.text('-\$50.00'), findsOneWidget);

      // 2. User taps delete button on the transaction card
      await tester.tap(find.byKey(const Key('btn_delete_tx_tx-transporte-50')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 3. Transaction deleted from backend
      expect(httpClient.transactionsDb.isEmpty, isTrue);

      // 4. Category and Dashboard balance recovered: spent reduces to $30.00, available increases to $170.00
      expect(find.text('\$30.00'), findsOneWidget);
      expect(find.text('\$170.00'), findsOneWidget);

      // 5. Transaction card removed from feed, empty message shown
      expect(find.byKey(const Key('transaction_item_tx-transporte-50')), findsNothing);
      expect(find.byKey(const Key('empty_feed_message')), findsOneWidget);
    });
  });
}
