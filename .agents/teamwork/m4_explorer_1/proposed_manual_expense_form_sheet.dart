import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/budget/presentation/widgets/icon_helper.dart';
import 'package:quincena/features/categories/data/categories_api_service.dart';
import 'package:quincena/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

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

/// Diálogo de advertencia por posible gasto duplicado dentro de las últimas 24 horas (RN-03).
///
/// Se presenta cuando el backend retorna HTTP 409 Conflict (`duplicate_warning: true`).
/// Permite al usuario revisar la coincidencia y decidir si cancela o fuerza el registro (`?force=true`).
class DuplicateWarningDialog extends StatelessWidget {
  const DuplicateWarningDialog({
    super.key,
    required this.merchantName,
    required this.amount,
    this.existingTransactions = const [],
    this.message,
    this.onConfirmForce,
    this.onCancel,
  });

  final String merchantName;
  final double amount;
  final List<DuplicateTransactionItem> existingTransactions;
  final String? message;
  final VoidCallback? onConfirmForce;
  final VoidCallback? onCancel;

  /// Método estático de conveniencia para mostrar el diálogo modal
  static Future<bool?> show({
    required BuildContext context,
    required String merchantName,
    required double amount,
    List<DuplicateTransactionItem> existingTransactions = const [],
    String? message,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DuplicateWarningDialog(
        merchantName: merchantName,
        amount: amount,
        existingTransactions: existingTransactions,
        message: message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = '\$${amount.toStringAsFixed(2)}';
    final existing = existingTransactions.firstOrNull;

    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.borderHero,
      ),
      backgroundColor: AppColors.surfaceBase,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icono de advertencia circular
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.warningBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warningText,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Título
            Center(
              child: Text(
                'Posible Gasto Duplicado',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Badge de Regla de Negocio
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningBg.withValues(alpha: 0.5),
                  borderRadius: AppRadius.borderPill,
                ),
                child: Text(
                  'Regla RN-03 (±24 Horas)',
                  style: AppTypography.captionBadge.copyWith(
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Mensaje descriptivo
            Text(
              message ??
                  'Ya existe un gasto similar registrado recientemente con el mismo comercio y monto.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),

            // Tarjeta con detalle de la coincidencia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          merchantName,
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedAmount,
                        style: AppTypography.currencyMd.copyWith(
                          color: AppColors.expenseText,
                        ),
                      ),
                    ],
                  ),
                  if (existing?.transactionDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Fecha detectada: ${existing!.transactionDate!.toIso8601String().split('T')[0]}',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Acciones: Forzar o Cancelar
            AppButton(
              key: const Key('duplicate_force_button'),
              text: 'Registrar de todas formas',
              prefixIcon: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () {
                if (onConfirmForce != null) {
                  onConfirmForce!();
                } else {
                  Navigator.of(context).pop(true);
                }
              },
            ),
            const SizedBox(height: 8),
            AppButton.secondary(
              key: const Key('duplicate_cancel_button'),
              text: 'Cancelar',
              onPressed: () {
                if (onCancel != null) {
                  onCancel!();
                } else {
                  Navigator.of(context).pop(false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet para Registro Manual de Gastos Quincenales (RF-04 / RF-06).
///
/// Características y requerimientos implementados:
/// - Modal bottom sheet con drag handle táctil, título "Nuevo Gasto Manual" y botón cerrar.
/// - Amount Hero Input en Warm Cream (#FCF5C7) con prefijo '$', cifras tabulares (`tnum`),
///   fuente destacada `AppTypography.currencyHeroMobile` y teclado decimal estricto:
///   `TextInputType.numberWithOptions(decimal: true)` con `DecimalCurrencyInputFormatter`.
/// - Nombre de comercio obligatorio (`TextFormField`) con validación de campo requerido.
/// - Selector de fecha con picker interactivo (`showDatePicker`) predeterminado a la fecha actual.
/// - Selector de categoría obligatoria con slider horizontal y acceso directo a `+ Nueva Categoría`
///   (`CategoryFormSheet`) sin perder el estado de los datos ingresados.
/// - Selector obligatorio de cuenta de débito/fondeo con auto-selección de cuenta por defecto
///   de la categoría (`RN-CAT-01`).
/// - Campo opcional de notas o descripción adicional.
/// - Botón sticky o accesible de acción primaria: "Registrar Gasto" con spinner de carga durante el submit.
/// - Intercepción reactiva de advertencia de duplicado HTTP 409 Conflict (RN-03) mediante
///   `DuplicateWarningDialog` y reintento con `?force=true`.
/// - Layout responsivo con `MediaQuery.viewInsets.bottom` y `SingleChildScrollView` evitando
///   desbordamientos `RenderFlex` en terminales móviles de 360-400px con teclado virtual abierto.
class ManualExpenseFormSheet extends StatefulWidget {
  const ManualExpenseFormSheet({
    super.key,
    required this.cycleId,
    this.transactionApiService,
    this.categories = const [],
    this.accounts = const [],
    this.initialAmount,
    this.initialMerchant,
    this.initialDate,
    this.initialNotes,
    this.initialCategoryId,
    this.initialAccountId,
    this.infoBannerMessage,
    this.onCreateCategory,
    this.categoriesApiService,
    this.onSave,
    this.onTransactionCreated,
  });

  /// ID del ciclo quincenal activo donde se registrará el gasto
  final String cycleId;

  /// Servicio API para transacciones
  final TransactionApiService? transactionApiService;

  /// Lista de categorías disponibles para el usuario
  final List<Category> categories;

  /// Lista de cuentas financieras disponibles para débito
  final List<FinancialAccount> accounts;

  /// Monto prellenado opcional (ej. cuando se proviene de un fallback OCR)
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

  /// Mensaje informativo o de advertencia superior (ej. fallback de lectura OCR baja)
  final String? infoBannerMessage;

  /// Callback para desplegar la creación contextual de una nueva categoría
  final Future<Category?> Function()? onCreateCategory;

  /// Servicio API opcional para crear categorías contextuales
  final CategoriesApiService? categoriesApiService;

  /// Callback opcional de persistencia directa (para testing o wrappers externos)
  final Future<Transaction?> Function(CreateTransactionDto dto, {bool force})? onSave;

  /// Callback ejecutado tras la creación exitosa de la transacción
  final void Function(Transaction transaction)? onTransactionCreated;

  /// Método estático de conveniencia para abrir el modal bottom sheet
  static Future<Transaction?> show({
    required BuildContext context,
    required String cycleId,
    TransactionApiService? transactionApiService,
    List<Category> categories = const [],
    List<FinancialAccount> accounts = const [],
    double? initialAmount,
    String? initialMerchant,
    DateTime? initialDate,
    String? initialNotes,
    String? initialCategoryId,
    String? initialAccountId,
    String? infoBannerMessage,
    Future<Category?> Function()? onCreateCategory,
    CategoriesApiService? categoriesApiService,
    Future<Transaction?> Function(CreateTransactionDto dto, {bool force})? onSave,
    void Function(Transaction transaction)? onTransactionCreated,
  }) {
    return showModalBottomSheet<Transaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ManualExpenseFormSheet(
        cycleId: cycleId,
        transactionApiService: transactionApiService,
        categories: categories,
        accounts: accounts,
        initialAmount: initialAmount,
        initialMerchant: initialMerchant,
        initialDate: initialDate,
        initialNotes: initialNotes,
        initialCategoryId: initialCategoryId,
        initialAccountId: initialAccountId,
        infoBannerMessage: infoBannerMessage,
        onCreateCategory: onCreateCategory,
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
  final _formKey = GlobalKey<FormState>();

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
    'Diciembre',
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
    _selectedCategoryId = widget.initialCategoryId;
    if (_selectedCategoryId == null && _categories.isNotEmpty) {
      _selectedCategoryId = _categories.first.id;
    }

    // Resolver selección inicial de cuenta de débito
    _selectedAccountId = widget.initialAccountId;
    if (_selectedAccountId == null) {
      // Regla RN-CAT-01: Heredar cuenta default de la categoría seleccionada
      if (_selectedCategoryId != null) {
        final matchingCategory = _categories.firstWhere(
          (c) => c.id == _selectedCategoryId,
          orElse: () => _categories.first,
        );
        if (matchingCategory.defaultAccountId != null &&
            matchingCategory.defaultAccountId!.isNotEmpty) {
          _selectedAccountId = matchingCategory.defaultAccountId;
        }
      }

      // Si no hay cuenta en la categoría, usar cuenta por defecto o la primera cuenta disponible
      if (_selectedAccountId == null && _accounts.isNotEmpty) {
        final defaultAccount = _accounts.firstWhere(
          (a) => a.isDefault,
          orElse: () => _accounts.first,
        );
        _selectedAccountId = defaultAccount.id;
      }
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    if (isToday) {
      return 'Hoy, ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
    } else if (isYesterday) {
      return 'Ayer, ${date.day} ${_monthNames[date.month - 1]} ${date.year}';
    }
    return '${date.day} ${_monthNames[date.month - 1]} ${date.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
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

    // Despliegue de CategoryFormSheet contextual estándar
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
          if (widget.categoriesApiService != null) {
            return await widget.categoriesApiService!.createCategory(
              name: name,
              icon: icon,
              colorHex: colorHex,
              defaultAccountId: defaultAccountId,
            );
          }
          return Category(
            id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
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

  void _showAccountPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceBase,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                'Seleccionar cuenta de débito',
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
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  Future<void> _submitExpense() async {
    // 1. Validar monto
    final amount = _parseAmount();
    if (amount <= 0.0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0.00');
      return;
    }

    // 2. Validar nombre de comercio
    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      setState(() => _errorMessage = 'El nombre del comercio es requerido');
      return;
    }

    // 3. Validar categoría
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione una categoría para el gasto');
      return;
    }

    // 4. Validar cuenta financiera de fondeo
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione una cuenta de débito');
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

    await _executeCreation(dto, force: false);
  }

  Future<void> _executeCreation(CreateTransactionDto dto, {bool force = false}) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      Transaction? result;

      if (widget.onSave != null) {
        result = await widget.onSave!(dto, force: force);
      } else if (widget.transactionApiService != null) {
        result = await widget.transactionApiService!.createTransaction(
          dto,
          force: force,
        );
      } else {
        // Fallback para entornos de prueba sin servicios inyectados
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

      if (result != null) {
        widget.onTransactionCreated?.call(result);
      }

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
        message: dupEx.message,
      );

      // Si el usuario confirma "Registrar de todas formas", reintentar con ?force=true
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

    // Obtener la cuenta actualmente seleccionada
    final selectedAccount = _accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => FinancialAccount(
        id: '',
        name: 'Seleccionar cuenta de débito',
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

          // Cabecera: Icono, Título y Botón Cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                  Text(
                    'Nuevo Gasto Manual',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
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
            child: Form(
              key: _formKey,
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
                                child: TextFormField(
                                  key: const Key('manual_amount_input'),
                                  controller: _amountController,
                                  autofocus: widget.initialAmount == null ||
                                      widget.initialAmount! <= 0,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
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

                    // 2. Campo de Comercio / Establecimiento (TextFormField con validación requerida)
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
                                  'Comercio / Establecimiento',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                TextFormField(
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
                                    hintText: 'Ej. Supermercado, Gasolinera...',
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

                    // 4. Selector de Categoría & Acceso Directo contextual "+ Nueva"
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
                        GestureDetector(
                          key: const Key('manual_add_category_button'),
                          onTap: _openCreateCategory,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add,
                                size: 16,
                                color: AppColors.primaryAccessible,
                              ),
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
                                key: Key('category_chip_${cat.id}'),
                                borderRadius: AppRadius.borderPill,
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId =
                                        isSelected ? null : cat.id;
                                    // Regla RN-CAT-01: Auto-seleccionar cuenta predeterminada de categoría
                                    if (!isSelected &&
                                        cat.defaultAccountId != null &&
                                        cat.defaultAccountId!.isNotEmpty) {
                                      _selectedAccountId = cat.defaultAccountId;
                                    }
                                    if (_errorMessage != null) {
                                      _errorMessage = null;
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

                    // 5. Selector Obligatorio de Cuenta Financiera de Débito
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
                      key: const Key('manual_account_selector_tile'),
                      borderRadius: AppRadius.borderMd,
                      onTap: _showAccountPicker,
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
                                  'Notas o descripción (opcional)',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                TextFormField(
                                  key: const Key('manual_notes_input'),
                                  controller: _notesController,
                                  maxLines: 2,
                                  style: AppTypography.bodyLg.copyWith(
                                    color: AppColors.textMain,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: 'Detalles del gasto, factura o referencia...',
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mensaje de Error en línea
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.expenseBg.withValues(alpha: 0.3),
                          borderRadius: AppRadius.borderSm,
                          border: Border.all(color: AppColors.expenseBg),
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
                    ],

                    const SizedBox(height: 20),

                    // Botón CTA Primario: "Registrar Gasto"
                    AppButton(
                      key: const Key('manual_submit_button'),
                      text: 'Registrar Gasto',
                      isLoading: _isSubmitting,
                      prefixIcon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _isSubmitting ? null : _submitExpense,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
