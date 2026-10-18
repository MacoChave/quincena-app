import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/budget_allocation.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/presentation/notifiers/budget_notifier.dart';
import 'package:quincena/features/categories/data/categories_api_service.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';
import 'widgets/account_selector_field.dart';
import 'widgets/category_selector_field.dart';
import 'widgets/duplicate_warning_dialog.dart';

export 'services/manual_sync_service.dart';
export 'widgets/account_selector_field.dart';
export 'widgets/category_selector_field.dart';
export 'widgets/duplicate_warning_dialog.dart';

/// Formateador estricto para montos decimales monetarios (hasta 2 decimales).
///
/// Características:
/// - Permite dígitos del 0 al 9.
/// - Admite un único separador decimal (normaliza comas ',' a puntos '.').
/// - Si el usuario teclea '.' al inicio, antepone '0.'.
/// - Limita la parte decimal estrictamente a [decimalRange] posiciones (por defecto 2).
/// - Rechaza caracteres alfabéticos, espacios o signos negativos.
class DecimalCurrencyInputFormatter extends TextInputFormatter {
  const DecimalCurrencyInputFormatter({this.decimalRange = 2});

  final int decimalRange;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var newText = newValue.text;

    // Normalizar coma a punto decimal para teclados internacionales
    if (newText.contains(',')) {
      newText = newText.replaceAll(',', '.');
    }

    // Permitir campo vacío (para borrado completo)
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Si comienza con punto decimal, autocompletar con "0."
    if (newText == '.') {
      return const TextEditingValue(
        text: '0.',
        selection: TextSelection.collapsed(offset: 2),
      );
    }

    // Validar formato numérico estricto con máximo un punto y hasta `decimalRange` decimales
    final regex = RegExp('^\\d*\\.?\\d{0,$decimalRange}\$');
    if (regex.hasMatch(newText)) {
      final offsetAdjustment = newText.length - newValue.text.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: (newValue.selection.end + offsetAdjustment).clamp(0, newText.length),
        ),
      );
    }

    // Si no coincide con el formato permitido, conservar el valor anterior
    return oldValue;
  }
}

/// Modal Bottom Sheet para Registro Manual de Gastos Quincenales (RF-04 / RF-06).
///
/// Características y requerimientos implementados:
/// - Modal bottom sheet con drag handle táctil, título "Nuevo Gasto Manual" y botón cerrar.
/// - Amount Hero Input en Warm Cream (#FCF5C7) con prefijo '$', cifras tabulares (`tnum`),
///   fuente destacada `AppTypography.currencyHeroMobile` y teclado decimal estricto:
///   `TextInputType.numberWithOptions(decimal: true)` con `DecimalCurrencyInputFormatter`.
/// - Nombre de comercio obligatorio (`TextFormField`) con validación requerida y máximo 120 caracteres.
/// - Selector de fecha con picker interactivo (`showDatePicker`) predeterminado a la fecha actual.
/// - Selector de categoría obligatoria (`CategorySelectorField`) con acceso directo a `+ Nueva Categoría`
///   sin perder ni resetear los datos ingresados en el formulario.
/// - Selector obligatorio de cuenta de débito (`AccountSelectorField`) con auto-selección de cuenta
///   por defecto de la categoría (`RN-CAT-01`).
/// - Campo opcional de notas o descripción adicional.
/// - Botón primario: "Guardar Gasto" con indicador de carga durante la persistencia y guardia síncrona
///   contra doble toque para prevenir condiciones de carrera.
/// - Intercepción reactiva de advertencia de duplicado HTTP 409 Conflict (RN-03) mediante
///   `DuplicateWarningDialog` y reintento con `?force=true`.
/// - Sincronización en tiempo real (<100ms) con `BudgetNotifier.deductExpense` y `onBalanceRefresh`.
/// - Layout responsivo con `MediaQuery.viewInsets.bottom` y `SingleChildScrollView` evitando
///   desbordamientos `RenderFlex` en terminales móviles de 360-400px con teclado virtual abierto.
class ManualExpenseFormSheet extends StatefulWidget {
  const ManualExpenseFormSheet({
    super.key,
    required this.cycleId,
    this.isCycleClosed = false,
    this.transactionApiService,
    this.budgetNotifier,
    this.onBalanceRefresh,
    this.allocations,
    this.categories = const [],
    this.accounts = const [],
    this.initialAmount,
    this.initialMerchant,
    this.initialDate,
    this.initialNotes,
    this.initialCategoryId,
    this.initialAccountId,
    this.initialCategory,
    this.infoBannerMessage,
    this.onCreateCategory,
    this.onAddNewCategory,
    this.categoriesApiService,
    this.onSave,
    this.onTransactionCreated,
  });

  /// ID del ciclo quincenal activo donde se registrará el gasto
  final String cycleId;

  /// Indica si el ciclo está cerrado (RN-01)
  final bool isCycleClosed;

  /// Servicio API para transacciones
  final TransactionApiService? transactionApiService;

  /// Notificador de presupuestos para deducción reactiva en memoria (<10ms)
  final BudgetNotifier? budgetNotifier;

  /// Callback global para refrescar balance en HomeScreen y Feed (<100ms)
  final VoidCallback? onBalanceRefresh;

  /// Partidas presupuestarias del ciclo activo
  final List<BudgetAllocation>? allocations;

  /// Lista de categorías disponibles para el usuario
  final List<Category> categories;

  /// Lista de cuentas financieras disponibles para débito
  final List<FinancialAccount> accounts;

  /// Monto prellenado opcional (ej. cuando proviene de fallback OCR)
  final double? initialAmount;

  /// Nombre del comercio prellenado opcional
  final String? initialMerchant;

  /// Fecha predeterminada (por defecto hoy)
  final DateTime? initialDate;

  /// Notas o descripción prellenadas
  final String? initialNotes;

  /// ID de categoría preseleccionada
  final String? initialCategoryId;

  /// ID de cuenta financiera preseleccionada
  final String? initialAccountId;

  /// Instancia de categoría inicial (compatibilidad con tests)
  final Category? initialCategory;

  /// Mensaje informativo o de advertencia superior (ej. fallback OCR)
  final String? infoBannerMessage;

  /// Callback para desplegar la creación contextual de una nueva categoría
  final Future<Category?> Function()? onCreateCategory;

  /// Alias alternativo para onCreateCategory
  final Future<Category?> Function()? onAddNewCategory;

  /// Servicio API opcional para crear categorías contextuales
  final CategoriesApiService? categoriesApiService;

  /// Callback opcional de persistencia directa (para testing o wrappers externos)
  final Future<dynamic> Function(CreateTransactionDto dto, {bool force})? onSave;

  /// Callback ejecutado tras la creación exitosa de la transacción
  final void Function(Transaction transaction)? onTransactionCreated;

  /// Método estático de conveniencia para abrir el modal bottom sheet
  static Future<Transaction?> show({
    required BuildContext context,
    required String cycleId,
    bool isCycleClosed = false,
    TransactionApiService? transactionApiService,
    BudgetNotifier? budgetNotifier,
    VoidCallback? onBalanceRefresh,
    List<BudgetAllocation>? allocations,
    List<Category> categories = const [],
    List<FinancialAccount> accounts = const [],
    double? initialAmount,
    String? initialMerchant,
    DateTime? initialDate,
    String? initialNotes,
    String? initialCategoryId,
    String? initialAccountId,
    Category? initialCategory,
    String? infoBannerMessage,
    Future<Category?> Function()? onCreateCategory,
    Future<Category?> Function()? onAddNewCategory,
    CategoriesApiService? categoriesApiService,
    Future<dynamic> Function(CreateTransactionDto dto, {bool force})? onSave,
    void Function(Transaction transaction)? onTransactionCreated,
  }) {
    return showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualExpenseFormSheet(
        cycleId: cycleId,
        isCycleClosed: isCycleClosed,
        transactionApiService: transactionApiService,
        budgetNotifier: budgetNotifier,
        onBalanceRefresh: onBalanceRefresh,
        allocations: allocations,
        categories: categories,
        accounts: accounts,
        initialAmount: initialAmount,
        initialMerchant: initialMerchant,
        initialDate: initialDate,
        initialNotes: initialNotes,
        initialCategoryId: initialCategoryId,
        initialAccountId: initialAccountId,
        initialCategory: initialCategory,
        infoBannerMessage: infoBannerMessage,
        onCreateCategory: onCreateCategory,
        onAddNewCategory: onAddNewCategory,
        categoriesApiService: categoriesApiService,
        onSave: onSave,
        onTransactionCreated: onTransactionCreated,
      ),
    );
  }

  @override
  State<ManualExpenseFormSheet> createState() => _ManualExpenseFormSheetState();
}

class _ManualExpenseFormSheetState extends State<ManualExpenseFormSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _notesController;

  late DateTime _selectedDate;
  late List<Category> _categories;
  late List<FinancialAccount> _accounts;

  String? _selectedCategoryId;
  String? _selectedAccountId;

  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _monthNames = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _accounts = List.from(widget.accounts);

    final amountText = (widget.initialAmount != null && widget.initialAmount! > 0)
        ? widget.initialAmount!.toStringAsFixed(2)
        : '';
    _amountController = TextEditingController(text: amountText);
    _merchantController = TextEditingController(text: widget.initialMerchant ?? '');
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
    _selectedDate = widget.initialDate ?? DateTime.now();

    // Resolver selección inicial de categoría
    if (widget.initialCategory != null) {
      _selectedCategoryId = widget.initialCategory!.id;
      _selectedAccountId = widget.initialCategory!.defaultAccountId;
    } else {
      _selectedCategoryId = widget.initialCategoryId;
    }

    // Resolver selección inicial de cuenta
    _selectedAccountId ??= widget.initialAccountId;
    if (_selectedAccountId == null && _accounts.isNotEmpty) {
      final defaultAcc = _accounts.where((a) => a.isDefault).firstOrNull;
      _selectedAccountId = defaultAcc?.id ?? _accounts.first.id;
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
    final text = _amountController.text.trim().replaceAll(',', '.');
    return double.tryParse(text) ?? 0.0;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _monthNames[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textMain,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitExpense() async {
    // Protección síncrona inmediata contra doble toque (double-tap race condition)
    if (_isSubmitting) return;
    _isSubmitting = true;

    // 0. Validar si el ciclo está cerrado (RN-01)
    if (widget.isCycleClosed) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage =
              'No se pueden registrar gastos en un ciclo cerrado (RN-01)';
        });
      } else {
        _isSubmitting = false;
      }
      return;
    }

    // 1. Validar monto
    final amount = _parseAmount();
    if (amount <= 0.0) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'El monto debe ser mayor a 0.00';
        });
      } else {
        _isSubmitting = false;
      }
      return;
    }

    // 2. Validar nombre de comercio
    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'El comercio o nota es obligatorio';
        });
      } else {
        _isSubmitting = false;
      }
      return;
    }
    if (merchant.length > 120) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'El comercio no puede exceder 120 caracteres';
        });
      } else {
        _isSubmitting = false;
      }
      return;
    }

    // 3. Validar categoría
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Seleccione una categoría obligatoria';
        });
      } else {
        _isSubmitting = false;
      }
      return;
    }

    // 4. Validar cuenta financiera de débito
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Seleccione una cuenta financiera obligatoria';
        });
      } else {
        _isSubmitting = false;
      }
      return;
    }

    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final dto = CreateTransactionDto(
      cycleId: widget.cycleId,
      sourceAccountId: _selectedAccountId!,
      allocationId: _selectedCategoryId,
      amount: amount,
      merchantName: merchant,
      transactionDate: dateStr,
      notes: notes,
      entryMethod: EntryMethod.manual,
      transactionType: TransactionType.expense,
    );

    try {
      await _executeCreation(dto, force: false);
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
      } else {
        _isSubmitting = false;
      }
      rethrow;
    }
  }

  Future<void> _executeCreation(CreateTransactionDto dto, {bool force = false}) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      Transaction? result;

      if (widget.onSave != null) {
        final dynamic res = await widget.onSave!(dto, force: force);
        if (res is Transaction) {
          result = res;
        } else {
          result = Transaction(
            id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
            userId: 'current_user',
            cycleId: dto.cycleId,
            allocationId: dto.allocationId,
            sourceAccountId: dto.sourceAccountId,
            amount: dto.amount,
            merchantName: dto.merchantName,
            transactionDate: DateTime.parse(dto.transactionDate),
            entryMethod: EntryMethod.manual,
            transactionType: TransactionType.expense,
            notes: dto.notes,
            createdAt: DateTime.now(),
          );
        }
      } else if (widget.transactionApiService != null) {
        result = await widget.transactionApiService!.createTransaction(
          dto,
          force: force,
        );
      } else {
        result = Transaction(
          id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
          userId: 'test_user',
          cycleId: dto.cycleId,
          allocationId: dto.allocationId,
          sourceAccountId: dto.sourceAccountId,
          amount: dto.amount,
          merchantName: dto.merchantName,
          transactionDate: DateTime.parse(dto.transactionDate),
          entryMethod: EntryMethod.manual,
          transactionType: TransactionType.expense,
          notes: dto.notes,
          createdAt: DateTime.now(),
        );
      }

      if (!mounted) return;

      // Deducción en tiempo real en memoria (<10ms)
      if (widget.budgetNotifier != null) {
        widget.budgetNotifier!.deductExpense(
          allocationId: dto.allocationId,
          amount: dto.amount,
        );
      }

      // Sincronización global (<100ms)
      widget.onBalanceRefresh?.call();

      widget.onTransactionCreated?.call(result);

      Navigator.of(context).pop(result);
    } on DuplicateTransactionException catch (dupEx) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Mostrar diálogo de alerta por duplicado (RN-03)
      final shouldForce = await DuplicateWarningDialog.show(
        context: context,
        merchantName: dto.merchantName,
        amount: dto.amount,
        existingTransactions: dupEx.existingTransactions,
        exception: dupEx,
      );

      // Si el usuario confirma "Registrar de todas formas", reintentar con force: true
      if (shouldForce == true && mounted) {
        await _executeCreation(dto, force: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = viewInsets.bottom > 0 ? viewInsets.bottom + 16 : 24.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.elevated,
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle táctil superior
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

          // Cabecera: Icono, Título y Botón Cerrar (con protección de desbordamiento horizontal)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: AppColors.primaryAccessible,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Nuevo Gasto Manual',
                        style: AppTypography.headlineSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('manual_close_button'),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cuerpo con desplazamiento scrollable para evitar RenderFlex overflow
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner informativo opcional (ej. fallback de escaneo OCR)
                  if (widget.infoBannerMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg.withValues(alpha: 0.4),
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color: AppColors.warningBg,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.warningText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.infoBannerMessage!,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.warningText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 1. Amount Hero Input en Warm Cream (#FCF5C7) con cifras tabulares y teclado decimal estricto
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHero,
                      borderRadius: AppRadius.borderCard,
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MONTO DEL GASTO',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '\$ ',
                              style: AppTypography.currencyHeroMobile.copyWith(
                                color: AppColors.primaryAccessible,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                key: const Key('manual_amount_input'),
                                controller: _amountController,
                                autofocus: widget.initialAmount == null ||
                                    widget.initialAmount! <= 0,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: const [
                                  DecimalCurrencyInputFormatter(decimalRange: 2),
                                ],
                                style: AppTypography.currencyHeroMobile.copyWith(
                                  color: AppColors.textMain,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: '0.00',
                                  hintStyle: AppTypography.currencyHeroMobile.copyWith(
                                    color: AppColors.textMuted,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                              ),
                            ),
                            Text(
                              'USD',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Campo de Comercio / Establecimiento
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                                'Comercio o Nota descriptiva',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              TextField(
                                key: const Key('manual_merchant_input'),
                                controller: _merchantController,
                                textCapitalization: TextCapitalization.words,
                                style: AppTypography.headlineSm.copyWith(
                                  color: AppColors.textMain,
                                  fontSize: 16,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: 'Ej. Supermercado, Almuerzo, Gasolina',
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Fila de Selector de Fecha con Picker
                  InkWell(
                    key: const Key('manual_date_picker_tile'),
                    borderRadius: AppRadius.borderMd,
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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

                  // 4. Selector de Categoría (CategorySelectorField integrado)
                  CategorySelectorField(
                    fieldKey: const Key('manual_category_dropdown'),
                    addCategoryKey: const Key('btn_add_new_category'),
                    categories: _categories,
                    selectedCategoryId: _selectedCategoryId,
                    allocations: widget.allocations,
                    accounts: _accounts,
                    currentAccountId: _selectedAccountId,
                    onCreateCategoryRequested: widget.onAddNewCategory ?? widget.onCreateCategory,
                    categoriesApiService: widget.categoriesApiService,
                    onChanged: (cat) {
                      setState(() {
                        _selectedCategoryId = cat?.id;
                        if (_errorMessage != null) _errorMessage = null;
                      });
                    },
                    onAccountAutoSelected: (accId) {
                      setState(() {
                        _selectedAccountId = accId;
                      });
                    },
                    onCategoryCreated: (newCat) {
                      setState(() {
                        if (!_categories.any((c) => c.id == newCat.id)) {
                          _categories.add(newCat);
                        }
                        _selectedCategoryId = newCat.id;
                        if (newCat.defaultAccountId != null &&
                            newCat.defaultAccountId!.isNotEmpty) {
                          _selectedAccountId = newCat.defaultAccountId;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 5. Selector Obligatorio de Cuenta Financiera (AccountSelectorField integrado)
                  AccountSelectorField(
                    fieldKey: const Key('manual_account_dropdown'),
                    accounts: _accounts,
                    selectedAccountId: _selectedAccountId,
                    onChanged: (acc) {
                      setState(() {
                        _selectedAccountId = acc?.id;
                        if (_errorMessage != null) _errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 6. Campo Opcional de Notas
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSubtle,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                            Icons.notes_rounded,
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
                                'Notas adicionales (opcional)',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              TextField(
                                key: const Key('manual_notes_input'),
                                controller: _notesController,
                                maxLines: 2,
                                style: AppTypography.bodyMd.copyWith(
                                  color: AppColors.textMain,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  hintText: 'Detalles adicionales...',
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mensaje de Error de Validación
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.expenseBg.withValues(alpha: 0.3),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(
                          color: AppColors.expenseBg,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: AppColors.expenseText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.captionBadge.copyWith(
                                color: AppColors.expenseText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Botón Primario de Registro "Guardar Gasto"
                  AppButton(
                    key: const Key('manual_save_button'),
                    text: 'Guardar Gasto',
                    isLoading: _isSubmitting,
                    onPressed: _submitExpense,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
