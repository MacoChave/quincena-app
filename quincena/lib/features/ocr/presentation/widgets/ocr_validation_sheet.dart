import 'package:flutter/material.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/presentation/widgets/icon_helper.dart';
import 'package:quincena/features/categories/data/categories_api_service.dart';
import 'package:quincena/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/confirm_receipt_scan_dto.dart';
import 'package:quincena/features/transactions/data/models/create_transaction_dto.dart';
import 'package:quincena/features/transactions/data/models/receipt_scan.dart';
import 'package:quincena/features/transactions/data/models/transaction.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import '../../domain/services/suggestion_engine.dart';

/// Modal Bottom Sheet de Verificación y Pre-Confirmación OCR (RF-03/RF-05, CA-03.2, CA-05.2)
///
/// Pantalla Stitch: `06dd441359e2446c8c5931868b87b4d7` (*Escanear Comprobante OCR*)
class OcrValidationSheet extends StatefulWidget {
  const OcrValidationSheet({
    super.key,
    required this.scan,
    required this.cycleId,
    this.transactionApiService,
    this.categories = const [],
    this.accounts = const [],
    this.currentAvailableBalance,
    this.cycleEndDate,
    this.daysRemainingInCycle,
    this.onRescan,
    this.onConfirm,
    this.onConfirmed,
    this.onFallbackManual,
    this.onFallbackToManual,
    this.onCreateCategory,
    this.categoriesApiService,
  });

  /// Comprobante escaneado a validar
  final ReceiptScan scan;

  /// ID del ciclo quincenal activo
  final String cycleId;

  /// Servicio API para confirmar el comprobante o registrar la transacción
  final TransactionApiService? transactionApiService;

  /// Categorías disponibles para asignación
  final List<Category> categories;

  /// Cuentas financieras disponibles para fondeo
  final List<FinancialAccount> accounts;

  /// Saldo disponible actual del ciclo (para el cálculo de impacto)
  final double? currentAvailableBalance;

  /// Fecha de fin del ciclo quincenal (para el cálculo de días al corte)
  final DateTime? cycleEndDate;

  /// Días restantes en el ciclo actual
  final int? daysRemainingInCycle;

  /// Callback cuando el usuario elige volver a escanear
  final VoidCallback? onRescan;

  /// Callback opcional directo con ConfirmReceiptScanDto
  final Future<void> Function(ConfirmReceiptScanDto dto)? onConfirm;

  /// Callback emitido cuando la confirmación fue exitosa
  final void Function(Transaction transaction)? onConfirmed;

  /// Callback simple de fallback a manual
  final VoidCallback? onFallbackManual;

  /// Callback detallado de fallback a manual
  final void Function(ReceiptScan? scan, String warningMessage)?
      onFallbackToManual;

  /// Callback para crear nueva categoría
  final Future<Category?> Function()? onCreateCategory;

  /// Servicio opcional para crear categorías contextuales (+ Nueva)
  final CategoriesApiService? categoriesApiService;

  /// Método estático de conveniencia para mostrar el Bottom Sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required ReceiptScan scan,
    required String cycleId,
    TransactionApiService? transactionApiService,
    List<Category> categories = const [],
    List<FinancialAccount> accounts = const [],
    double? currentAvailableBalance,
    DateTime? cycleEndDate,
    int? daysRemainingInCycle,
    VoidCallback? onRescan,
    Future<void> Function(ConfirmReceiptScanDto dto)? onConfirm,
    void Function(Transaction transaction)? onConfirmed,
    VoidCallback? onFallbackManual,
    void Function(ReceiptScan? scan, String warningMessage)? onFallbackToManual,
    Future<Category?> Function()? onCreateCategory,
    CategoriesApiService? categoriesApiService,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OcrValidationSheet(
        scan: scan,
        cycleId: cycleId,
        transactionApiService: transactionApiService,
        categories: categories,
        accounts: accounts,
        currentAvailableBalance: currentAvailableBalance,
        cycleEndDate: cycleEndDate,
        daysRemainingInCycle: daysRemainingInCycle,
        onRescan: onRescan,
        onConfirm: onConfirm,
        onConfirmed: onConfirmed,
        onFallbackManual: onFallbackManual,
        onFallbackToManual: onFallbackToManual,
        onCreateCategory: onCreateCategory,
        categoriesApiService: categoriesApiService,
      ),
    );
  }

  @override
  State<OcrValidationSheet> createState() => _OcrValidationSheetState();
}

class _OcrValidationSheetState extends State<OcrValidationSheet> {
  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;

  late List<Category> _categories;
  late List<FinancialAccount> _accounts;

  String? _selectedCategoryId;
  String? _selectedAccountId;

  bool _isEditingAmount = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
  ];

  /// Determina si el escaneo presenta baja confianza (< 70%) o falló (CA-03.4, CA-05.3)
  bool get _isLowConfidence {
    if (widget.scan.isFailed) return true;
    final score = widget.scan.confidenceScore;
    if (score == null) return true;
    if (score <= 1.0) {
      return score < 0.70;
    }
    return score < 70.0;
  }

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _accounts = List.from(widget.accounts);

    final rawAmount = widget.scan.extractedAmount;
    final amountText = (rawAmount != null && rawAmount > 0)
        ? rawAmount.toStringAsFixed(2)
        : '';
    _amountController = TextEditingController(text: amountText);

    _merchantController = TextEditingController(
      text: widget.scan.extractedMerchant ?? '',
    );

    final defaultNote = widget.scan.taxIdOrAuthNumber != null &&
            widget.scan.taxIdOrAuthNumber!.isNotEmpty
        ? 'Ref/NIT: ${widget.scan.taxIdOrAuthNumber}'
        : '';
    _notesController = TextEditingController(text: defaultNote);

    _selectedDate = widget.scan.extractedDate ?? DateTime.now();

    // Auto-sugerencia de Categoría (CA-05.2)
    _selectedCategoryId = SuggestionEngine.suggestCategory(
      merchantName: widget.scan.extractedMerchant,
      categories: _categories,
    );

    // Auto-sugerencia de Cuenta Financiera (CA-05.2, RN-CAT-01)
    _selectedAccountId = SuggestionEngine.suggestAccount(
      scan: widget.scan,
      categoryId: _selectedCategoryId,
      categories: _categories,
      accounts: _accounts,
    );

    // Si la lectura de monto fue nula o fallida, inicia en modo de edición
    if (rawAmount == null || rawAmount <= 0 || _isLowConfidence) {
      _isEditingAmount = true;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _parseAmount() {
    final clean = _amountController.text.trim().replaceAll(',', '');
    return double.tryParse(clean) ?? 0.0;
  }

  String _formatCurrency(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '\$$intPart.${parts[1]}';
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthNames[date.month - 1]}, ${date.year}';
  }

  int _calculateDaysToCutoff() {
    if (widget.daysRemainingInCycle != null) {
      return widget.daysRemainingInCycle!;
    }
    if (widget.cycleEndDate != null) {
      final diff = widget.cycleEndDate!.difference(DateTime.now()).inDays + 1;
      return diff > 0 ? diff : 0;
    }
    return 8;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _selectedDate.isBefore(DateTime(2020))
          ? _selectedDate
          : DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryAccessible,
              onPrimary: Colors.white,
              surface: AppColors.surfaceBase,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAccountPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Seleccionar cuenta de fondeo',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 12),
              ..._accounts.map((acc) {
                final isSelected = acc.id == _selectedAccountId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: acc.parsedColor.withValues(alpha: 0.2),
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: Icon(acc.displayIcon, color: acc.parsedColor),
                  ),
                  title: Text(
                    acc.name,
                    style: AppTypography.labelLg.copyWith(
                      color: AppColors.textMain,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    '${acc.accountType.label} • Saldo: ${acc.currency} ${acc.currentBalance.toStringAsFixed(2)}',
                    style: AppTypography.bodySm,
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedAccountId = acc.id);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateCategory() async {
    if (widget.onCreateCategory != null) {
      final newCat = await widget.onCreateCategory!();
      if (newCat != null && mounted) {
        setState(() {
          _categories.add(newCat);
          _selectedCategoryId = newCat.id;
          if (newCat.defaultAccountId != null &&
              newCat.defaultAccountId!.isNotEmpty) {
            _selectedAccountId = newCat.defaultAccountId;
          }
        });
      }
      return;
    }

    if (widget.categoriesApiService == null) return;
    final newCat = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CategoryFormSheet(
        accounts: _accounts,
        onSave: ({
          required name,
          required icon,
          required colorHex,
          defaultAccountId,
        }) async {
          return await widget.categoriesApiService!.createCategory(
            name: name,
            icon: icon,
            colorHex: colorHex,
            defaultAccountId: defaultAccountId,
          );
        },
      ),
    );

    if (newCat != null && mounted) {
      setState(() {
        _categories.add(newCat);
        _selectedCategoryId = newCat.id;
        if (newCat.defaultAccountId != null &&
            newCat.defaultAccountId!.isNotEmpty) {
          _selectedAccountId = newCat.defaultAccountId;
        }
      });
    }
  }

  Future<void> _confirmAndDeduct() async {
    final amount = _parseAmount();
    if (amount <= 0.0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0.00');
      return;
    }

    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      setState(() => _errorMessage = 'El comercio es obligatorio');
      return;
    }

    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione una cuenta de débito');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      final confirmDto = ConfirmReceiptScanDto(
        cycleId: widget.cycleId,
        sourceAccountId: _selectedAccountId!,
        allocationId: _selectedCategoryId,
        merchantName: merchant,
        amount: amount,
        transactionDate: dateStr,
        notes: notes,
      );

      // Si se proporcionó un callback onConfirm personalizado, invocarlo prioritariamente
      if (widget.onConfirm != null) {
        await widget.onConfirm!(confirmDto);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      // Si disponemos de transactionApiService:
      if (widget.transactionApiService != null) {
        // Si el escaneo falló en backend o no tiene ID persistido, recurre a createTransaction (CA-03.4)
        if (widget.scan.id.isEmpty || widget.scan.isFailed) {
          final createDto = CreateTransactionDto(
            cycleId: widget.cycleId,
            sourceAccountId: _selectedAccountId!,
            allocationId: _selectedCategoryId,
            amount: amount,
            merchantName: merchant,
            transactionDate: dateStr,
            notes: notes,
            receiptScanId: widget.scan.id.isNotEmpty ? widget.scan.id : null,
            entryMethod: EntryMethod.manual,
          );

          final transaction =
              await widget.transactionApiService!.createTransaction(createDto);
          if (mounted) {
            widget.onConfirmed?.call(transaction);
            Navigator.of(context).pop(transaction);
          }
          return;
        }

        // Flujo canónico OCR: POST /receipt-scans/:id/confirm
        final transaction =
            await widget.transactionApiService!.confirmReceiptScan(
          widget.scan.id,
          confirmDto,
        );

        if (mounted) {
          widget.onConfirmed?.call(transaction);
          Navigator.of(context).pop(transaction);
        }
        return;
      }

      // Fallback genérico para tests de widget
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _triggerFallbackManual() {
    if (widget.onFallbackManual != null) {
      widget.onFallbackManual!();
      return;
    }
    if (widget.onFallbackToManual != null) {
      widget.onFallbackToManual!(
        widget.scan,
        'No pudimos leer algunos datos con certeza, por favor complétalos manualmente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final currentAvailable = widget.currentAvailableBalance ?? 0.0;
    final currentAmount = _parseAmount();
    final projectedAvailable = currentAvailable - currentAmount;
    final isDeficit = projectedAvailable < 0.0;
    final daysToCutoff = _calculateDaysToCutoff();

    // Cuenta actualmente seleccionada
    final selectedAccount = _accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => FinancialAccount(
        id: '',
        name: 'Seleccionar cuenta',
        accountType: AccountType.checking,
        currency: 'USD',
        colorHex: '#79ADDC',
        icon: 'credit_card',
        isDefault: false,
        isArchived: false,
        initialBalance: 0,
        currentBalance: 0,
      ),
    );

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: viewInsets.bottom > 0 ? viewInsets.bottom + 16 : 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Scrollable sheet content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header & Status Pill (Stitch lines 66-76)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppColors.incomeBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.document_scanner_outlined,
                              size: 18,
                              color: AppColors.textMain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Validar Extracción',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                        ],
                      ),
                      AppBadge(
                        text: _isLowConfidence
                            ? 'Baja Confianza'
                            : 'Listo para aplicar',
                        variant: _isLowConfidence
                            ? AppBadgeVariant.warning
                            : AppBadgeVariant.income,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Low-confidence or OCR error fallback banner (CA-03.4, CA-05.3)
                  if (_isLowConfidence) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg.withValues(alpha: 0.35),
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color: AppColors.warningText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.warningText,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No pudimos leer algunos datos con certeza, por favor complétalos manualmente.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.warningText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if ((widget.scan.confidenceScore ?? 0.0) > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Nivel de confianza: ${widget.scan.formattedConfidence}',
                                      style: AppTypography.captionBadge.copyWith(
                                        color: AppColors.warningText
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.onFallbackManual != null ||
                              widget.onFallbackToManual != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _triggerFallbackManual,
                              child: Text(
                                'Manual',
                                style: AppTypography.captionBadge.copyWith(
                                  color: AppColors.warningText,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Hero Amount Card in Warm Cream (#FCF5C7) (Stitch lines 78-89)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHero,
                      borderRadius: AppRadius.borderCard,
                      border: Border.all(color: AppColors.borderHairline),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MONTO RECONOCIDO',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setState(
                                    () => _isEditingAmount = !_isEditingAmount),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBase
                                        .withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: AppShadows.card,
                                  ),
                                  child: Icon(
                                    _isEditingAmount
                                        ? Icons.check_rounded
                                        : Icons.edit_outlined,
                                    size: 16,
                                    color: AppColors.textMain,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$ ',
                              style: AppTypography.currencyHeroMobile.copyWith(
                                color: AppColors.primaryAccessible,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                key: const Key('ocr_amount_input'),
                                controller: _amountController,
                                keyboardType: const TextInputType
                                    .numberWithOptions(decimal: true),
                                style: AppTypography.currencyHeroMobile.copyWith(
                                  color: AppColors.textMain,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: '0.00',
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Text(
                              'USD',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Merchant Row (Stitch lines 93-107)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBase,
                            borderRadius: AppRadius.borderSm,
                            boxShadow: AppShadows.card,
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: AppColors.primaryAccessible,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Comercio emisor',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              TextField(
                                key: const Key('ocr_merchant_input'),
                                controller: _merchantController,
                                style: AppTypography.headlineSm.copyWith(
                                  color: AppColors.textMain,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: 'Comercio / Establecimiento',
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                        if (!_isLowConfidence &&
                            _merchantController.text.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.incomeBg.withValues(alpha: 0.5),
                              borderRadius: AppRadius.borderPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 15,
                                  color: AppColors.incomeText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Verificado',
                                  style: AppTypography.captionBadge.copyWith(
                                    color: AppColors.incomeText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Date Row (Stitch lines 108-122)
                  InkWell(
                    borderRadius: AppRadius.borderMd,
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBase,
                              borderRadius: AppRadius.borderSm,
                              boxShadow: AppShadows.card,
                            ),
                            child: const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.primaryAccessible,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fecha del gasto',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: AppTypography.headlineSm.copyWith(
                                    color: AppColors.textMain,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.expand_more,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Chips Slider (Stitch lines 123-141)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ASIGNAR A CATEGORÍA',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.onCreateCategory != null ||
                          widget.categoriesApiService != null)
                        GestureDetector(
                          onTap: _openCreateCategory,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add,
                                  size: 16, color: AppColors.primaryAccessible),
                              const SizedBox(width: 2),
                              Text(
                                'Nueva',
                                style: AppTypography.captionBadge.copyWith(
                                  color: AppColors.primaryAccessible,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ..._categories.map((cat) {
                          final isSelected = _selectedCategoryId == cat.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              borderRadius: AppRadius.borderPill,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = isSelected ? null : cat.id;
                                  // Hereda cuenta predeterminada de categoría (RN-CAT-01)
                                  if (!isSelected &&
                                      cat.defaultAccountId != null &&
                                      cat.defaultAccountId!.isNotEmpty) {
                                    _selectedAccountId = cat.defaultAccountId;
                                  }
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.surfaceSubtle,
                                  borderRadius: AppRadius.borderPill,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.borderSubtle,
                                  ),
                                  boxShadow:
                                      isSelected ? AppShadows.card : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected) ...[
                                      const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: AppColors.textMain,
                                      ),
                                      const SizedBox(width: 6),
                                    ] else ...[
                                      Icon(
                                        resolveCategoryIcon(cat.icon),
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      cat.name,
                                      style: AppTypography.labelMd.copyWith(
                                        color: AppColors.textMain,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Funding Account Selector (Stitch lines 142-155)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CUENTA DE DÉBITO',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    key: const Key('ocr_account_dropdown'),
                    borderRadius: AppRadius.borderMd,
                    onTap: _showAccountPicker,
                    child: Container(
                      key: const Key('ocr_account_selector_tile'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBase,
                              borderRadius: AppRadius.borderSm,
                              boxShadow: AppShadows.card,
                            ),
                            child: Icon(
                              selectedAccount.displayIcon,
                              color: AppColors.primaryAccessible,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Método de débito',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedAccount.name,
                                  style: AppTypography.labelLg.copyWith(
                                    color: AppColors.textMain,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.unfold_more,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Runway Balance Impact Banner (Spec #15, Stitch lines 156-165)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDeficit
                          ? AppColors.expenseBg.withValues(alpha: 0.35)
                          : AppColors.primarySubtle,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: isDeficit
                            ? AppColors.expenseBg
                            : AppColors.primary.withValues(alpha: 0.2),
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isDeficit
                                ? AppColors.expenseText
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDeficit
                                ? Icons.error_outline_rounded
                                : Icons.insights_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDeficit
                                    ? 'Alerta: Este gasto provocará un sobregiro presupuestario'
                                    : 'Impacto en tu quincena',
                                style: AppTypography.bodySm.copyWith(
                                  color: isDeficit
                                      ? AppColors.expenseText
                                      : AppColors.textMain,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(
                                  style: AppTypography.bodySm.copyWith(
                                    color: isDeficit
                                        ? AppColors.expenseText
                                        : AppColors.textSecondary,
                                  ),
                                  children: [
                                    if (isDeficit) ...[
                                      TextSpan(
                                        text:
                                            'Alerta: Este gasto provocará un sobregiro de \$${(-projectedAvailable).toStringAsFixed(2)} en tu quincena. Estás a $daysToCutoff días del próximo corte.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.expenseText,
                                        ),
                                      ),
                                    ] else ...[
                                      TextSpan(
                                        text:
                                            'Tu saldo disponible pasará de ${_formatCurrency(currentAvailable)} a ${_formatCurrency(projectedAvailable)}. Estás a $daysToCutoff días del próximo corte.',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textMain,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error notification if present
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: AppTypography.captionBadge.copyWith(
                        color: AppColors.expenseText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Actions: Primary "Confirmar y Descontar" and Secondary "Volver a escanear"
                  AppButton(
                    key: const Key('ocr_confirm_button'),
                    text: 'Confirmar y Descontar',
                    isLoading: _isSubmitting,
                    prefixIcon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _isSubmitting ? null : _confirmAndDeduct,
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'Volver a escanear',
                    variant: AppButtonVariant.ghost,
                    prefixIcon: const Icon(
                      Icons.photo_camera_outlined,
                      size: 18,
                      color: AppColors.textMain,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onRescan?.call();
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
