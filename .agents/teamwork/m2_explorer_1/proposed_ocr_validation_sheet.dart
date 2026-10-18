import 'package:flutter/material.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/transactions/data/models/models.dart';

/// Hoja modal inferior de Pre-Confirmación y Validación de Extracción OCR (CA-03.2, CA-05.2).
///
/// Implementa fielmente las especificaciones de Stitch Screen `06dd441359e2446c8c5931868b87b4d7`:
/// - Indicador de arrastre (drag handle) y cabecera con badge de estado ("Listo para aplicar" / "Baja Confianza").
/// - Banner de advertencia en caso de baja confianza (<70%) con atajo a formulario manual (CA-03.4, CA-05.3).
/// - Tarjeta Hero de Monto en Warm Cream (#FCF5C7) con cifras tabulares y teclado decimal.
/// - Fila de comercio verificado y selector de fecha.
/// - Carrusel de categorías con auto-sugerencia inteligente y atajo a `+ Nueva Categoría`.
/// - Selector obligatorio de cuenta de débito con herencia de la categoría (`RN-CAT-01`).
/// - Banner de proyección de saldo quincenal con semaforización de sobregiro (coral #FFC09F).
/// - Botón principal "Confirmar y Descontar" y botón secundario "Volver a escanear".
class OcrValidationSheet extends StatefulWidget {
  const OcrValidationSheet({
    super.key,
    required this.scan,
    required this.cycleId,
    required this.categories,
    required this.accounts,
    required this.currentAvailableBalance,
    this.daysRemainingInCycle = 8,
    required this.onConfirm,
    this.onRescan,
    this.onFallbackManual,
    this.onCreateCategory,
  });

  /// Entidad de escaneo OCR con los datos preliminares extraídos.
  final ReceiptScan scan;

  /// ID del ciclo quincenal activo.
  final String cycleId;

  /// Lista de categorías disponibles.
  final List<Category> categories;

  /// Lista de cuentas financieras disponibles.
  final List<FinancialAccount> accounts;

  /// Saldo disponible actual de la quincena.
  final double currentAvailableBalance;

  /// Días restantes para el próximo corte de quincena.
  final int daysRemainingInCycle;

  /// Callback para confirmar y persistir la transacción vinculada al escaneo.
  final Future<void> Function(ConfirmReceiptScanDto dto) onConfirm;

  /// Callback para volver a capturar el comprobante.
  final VoidCallback? onRescan;

  /// Callback para saltar a registro manual en caso de falla o baja confianza.
  final VoidCallback? onFallbackManual;

  /// Callback para abrir modal contextual de creación de categoría.
  final Future<Category?> Function()? onCreateCategory;

  /// Método estático de conveniencia para desplegar la hoja modal
  static Future<T?> show<T>({
    required BuildContext context,
    required ReceiptScan scan,
    required String cycleId,
    required List<Category> categories,
    required List<FinancialAccount> accounts,
    required double currentAvailableBalance,
    int daysRemainingInCycle = 8,
    required Future<void> Function(ConfirmReceiptScanDto dto) onConfirm,
    VoidCallback? onRescan,
    VoidCallback? onFallbackManual,
    Future<Category?> Function()? onCreateCategory,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OcrValidationSheet(
        scan: scan,
        cycleId: cycleId,
        categories: categories,
        accounts: accounts,
        currentAvailableBalance: currentAvailableBalance,
        daysRemainingInCycle: daysRemainingInCycle,
        onConfirm: onConfirm,
        onRescan: onRescan,
        onFallbackManual: onFallbackManual,
        onCreateCategory: onCreateCategory,
      ),
    );
  }

  @override
  State<OcrValidationSheet> createState() => _OcrValidationSheetState();
}

class _OcrValidationSheetState extends State<OcrValidationSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _notesController;

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

    // Auto-sugerencias (CA-05.2, RN-CAT-01)
    _selectedCategoryId = widget.scan.suggestedAccountId != null
        ? widget.categories
            .where((c) => c.defaultAccountId == widget.scan.suggestedAccountId)
            .firstOrNull
            ?.id
        : null;

    // Si el scan ya trae cuenta sugerida, la usamos; si no, la cuenta por defecto o primera disponible
    if (widget.scan.suggestedAccountId != null &&
        widget.accounts.any((a) => a.id == widget.scan.suggestedAccountId)) {
      _selectedAccountId = widget.scan.suggestedAccountId;
    } else if (widget.accounts.isNotEmpty) {
      _selectedAccountId = widget.accounts
          .firstWhere((a) => a.isDefault, orElse: () => widget.accounts.first)
          .id;
    }
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

  bool get _isLowConfidence =>
      !widget.scan.hasHighConfidence || widget.scan.isFailed;

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

    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
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
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      await widget.onConfirm(dto);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.textMain,
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

  @override
  Widget build(BuildContext context) {
    final isDeficit = _projectedBalance < 0.0;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: 24 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicador de arrastre superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabecera: Título y Badge de Estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.incomeBg,
                      ),
                      child: const Icon(
                        Icons.document_scanner_outlined,
                        size: 18,
                        color: AppColors.incomeText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Validar Extracción',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                AppBadge(
                  text: _isLowConfidence ? 'Baja Confianza' : 'Listo para aplicar',
                  variant: _isLowConfidence
                      ? AppBadgeVariant.warning
                      : AppBadgeVariant.income,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Banner de baja confianza (CA-03.4 / CA-05.3)
            if (_isLowConfidence) _buildLowConfidenceBanner(),

            // Tarjeta Hero de Monto en Warm Cream (#FCF5C7)
            _buildAmountHeroCard(),

            const SizedBox(height: 14),

            // Campo de Comercio emisor
            _buildMerchantInput(),

            const SizedBox(height: 12),

            // Fila de Fecha con selector interactivo
            _buildDateSelectorRow(),

            const SizedBox(height: 16),

            // Carrusel de selección de Categorías
            _buildCategorySection(),

            const SizedBox(height: 16),

            // Selector obligatorio de Cuenta Financiera de Débito
            _buildAccountSelectorSection(),

            const SizedBox(height: 16),

            // Banner de impacto quincenal en balance (Runway)
            _buildRunwayImpactBanner(isDeficit),

            // Mensaje de error de validación
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  _errorMessage!,
                  style: AppTypography.captionBadge.copyWith(
                    color: AppColors.expenseText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Botones de acción
            AppButton(
              text: 'Confirmar y Descontar',
              isLoading: _isConfirming,
              prefixIcon: const Icon(Icons.check_circle_rounded, size: 20),
              onPressed: _handleConfirm,
            ),

            const SizedBox(height: 8),

            AppButton.secondary(
              text: 'Volver a escanear',
              prefixIcon: const Icon(Icons.photo_camera_outlined, size: 18),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRescan?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Banner de advertencia de baja legibilidad con fallback a registro manual
  Widget _buildLowConfidenceBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.warningBg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningBg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warningText,
            size: 20,
          ),
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
              onPressed: () {
                Navigator.of(context).pop();
                widget.onFallbackManual?.call();
              },
              child: const Text('Manual'),
            ),
        ],
      ),
    );
  }

  /// Tarjeta Hero de Monto en Warm Cream (#FCF5C7) con cifras tabulares y prefijo
  Widget _buildAmountHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const SizedBox(height: 4),
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
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  /// Input de comercio emisor con badge de verificación
  Widget _buildMerchantInput() {
    final isVerified = (widget.scan.confidenceScore ?? 0.0) >= 0.8;

    return TextField(
      key: const Key('ocr_merchant_input'),
      controller: _merchantController,
      style: AppTypography.bodyLg.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
      ),
      decoration: InputDecoration(
        labelText: 'Comercio / Establecimiento',
        labelStyle: AppTypography.bodyMd,
        prefixIcon: const Icon(Icons.storefront_rounded, color: AppColors.primary),
        suffixIcon: isVerified
            ? Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.incomeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: AppColors.incomeText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verificado',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.incomeText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  /// Fila de fecha interactiva con selector de calendario
  Widget _buildDateSelectorRow() {
    final formattedDate =
        '${_selectedDate.day} ${_monthName(_selectedDate.month)}, ${_selectedDate.year}';

    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha del gasto',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Sección de selección de categorías con atajo contextual `+ Nueva Categoría`
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categoría Asignada',
              style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
            ),
            if (widget.onCreateCategory != null)
              InkWell(
                onTap: () async {
                  final newCat = await widget.onCreateCategory?.call();
                  if (newCat != null && mounted) {
                    setState(() {
                      _selectedCategoryId = newCat.id;
                      if (newCat.defaultAccountId != null) {
                        _selectedAccountId = newCat.defaultAccountId;
                      }
                    });
                  }
                },
                child: Text(
                  '+ Nueva Categoría',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primaryAccessible,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
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
                  checkmarkColor: AppColors.textMain,
                  labelStyle: AppTypography.labelMd.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textMain,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategoryId = selected ? cat.id : null;
                      // Herencia de cuenta predeterminada de la categoría (RN-CAT-01)
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
      ],
    );
  }

  /// Selector de cuenta bancaria o efectivo de origen
  Widget _buildAccountSelectorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cuenta de Pago / Débito',
          style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('ocr_account_dropdown'),
          initialValue: _selectedAccountId,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.credit_card_rounded, color: AppColors.primary),
          ),
          items: widget.accounts.map((acc) {
            return DropdownMenuItem<String>(
              value: acc.id,
              child: Text(
                acc.name,
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedAccountId = val),
        ),
      ],
    );
  }

  /// Banner de proyección del saldo en la quincena (Runway Impact)
  Widget _buildRunwayImpactBanner(bool isDeficit) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isDeficit ? Icons.error_outline_rounded : Icons.insights_rounded,
            color: isDeficit ? AppColors.expenseText : AppColors.primaryAccessible,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impacto en tu quincena',
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDeficit ? AppColors.expenseText : AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDeficit
                      ? 'Alerta: Este gasto provocará un sobregiro de \$${(-_projectedBalance).toStringAsFixed(2)} en tu quincena.'
                      : 'Tu saldo disponible pasará de \$${widget.currentAvailableBalance.toStringAsFixed(2)} a \$${_projectedBalance.toStringAsFixed(2)}. Estás a ${widget.daysRemainingInCycle} días del próximo corte.',
                  style: AppTypography.captionBadge.copyWith(
                    color: isDeficit ? AppColors.expenseText : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _monthName(int month) {
    const months = [
      '',
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
    return month >= 1 && month <= 12 ? months[month] : '';
  }
}
