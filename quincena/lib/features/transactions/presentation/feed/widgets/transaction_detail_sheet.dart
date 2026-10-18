import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/presentation/widgets/icon_helper.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

/// Modal Bottom Sheet con los detalles completos de una transacción (RF-04 / RF-06).
///
/// Implementa las directrices de diseño de Stitch:
/// - Tirador de arrastre superior (drag handle) y título "Detalle de Gasto".
/// - Tarjeta Hero de monto en Warm Cream (#FCF5C7) con acento de color de categoría y números tabulares (`tnum`).
/// - Filas de metadatos estructuradas: Comercio, Fecha/Hora, Categoría, Cuenta de fondeo y Método de captura.
/// - Bloque de notas y folio fiscal / autorización cuando están presentes.
/// - Visor de comprobante OCR con miniatura y modal interactivo para visualización completa.
/// - Botón primario de eliminación sticky en el pie del modal con confirmación preventiva,
///   llamada a `DELETE /transactions/:id`, toast de confirmación y disparo de sincronización de saldos en <100ms.
class TransactionDetailSheet extends StatefulWidget {
  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.transactionApiService,
    this.receiptScan,
    this.onTransactionDeleted,
  });

  /// Transacción a inspeccionar
  final Transaction transaction;

  /// Servicio de API para operaciones de eliminación o consulta de comprobante
  final TransactionApiService transactionApiService;

  /// Registro de comprobante OCR previamente resuelto (opcional)
  final ReceiptScan? receiptScan;

  /// Callback emitido cuando la transacción es eliminada exitosamente
  final VoidCallback? onTransactionDeleted;

  /// Muestra el modal bottom sheet de detalles y retorna `true` si la transacción fue eliminada.
  static Future<bool?> show({
    required BuildContext context,
    required Transaction transaction,
    required TransactionApiService transactionApiService,
    ReceiptScan? receiptScan,
    VoidCallback? onTransactionDeleted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionDetailSheet(
        transaction: transaction,
        transactionApiService: transactionApiService,
        receiptScan: receiptScan,
        onTransactionDeleted: onTransactionDeleted,
      ),
    );
  }

  @override
  State<TransactionDetailSheet> createState() => _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<TransactionDetailSheet> {
  ReceiptScan? _receiptScan;
  bool _isLoadingReceipt = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _receiptScan = widget.receiptScan;
    if (_receiptScan == null &&
        widget.transaction.isOcr &&
        widget.transaction.receiptScanId != null &&
        widget.transaction.receiptScanId!.isNotEmpty) {
      _loadReceiptScan();
    }
  }

  Future<void> _loadReceiptScan() async {
    setState(() => _isLoadingReceipt = true);
    try {
      final scan = await widget.transactionApiService
          .getReceiptScan(widget.transaction.receiptScanId!);
      if (mounted) {
        setState(() => _receiptScan = scan);
      }
    } catch (_) {
      // Falla silenciosa de carga de comprobante; no bloquea los detalles de la transacción
    } finally {
      if (mounted) {
        setState(() => _isLoadingReceipt = false);
      }
    }
  }

  String _formatDateTime(DateTime date) {
    const months = [
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
    final monthName = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} de $monthName de ${date.year}, $hour:$minute hrs';
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceBase,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderCard),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.expenseBg.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.expenseText,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¿Eliminar gasto?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta acción no se puede deshacer.',
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'El monto de ${widget.transaction.formattedSignedAmount} en "${widget.transaction.merchantName}" será reintegrado inmediatamente al saldo disponible de tu ciclo activo y a la categoría "${widget.transaction.categoryName}".',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancelar',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textMain,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.borderMd,
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Eliminar Gasto',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await widget.transactionApiService
          .deleteTransaction(widget.transaction.id);

      if (!mounted) return;

      // Cerrar el modal bottom sheet reportando eliminación exitosa
      Navigator.of(context).pop(true);

      // Mostrar notificación de éxito
      AppToast.showSuccess(
        context,
        'Gasto eliminado y saldo reintegrado exitosamente',
      );

      // Notificar al padre para sincronizar balances en <100ms
      widget.onTransactionDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      AppToast.showError(context, e);
    }
  }

  void _showFullReceiptViewer(BuildContext context, ReceiptScan scan) {
    showDialog<void>(
      context: context,
      builder: (viewerContext) => Dialog(
        backgroundColor: AppColors.surfaceBase,
        insetPadding: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderCard,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySubtle,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.primaryAccessible,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Comprobante OCR',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(viewerContext).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Contenedor visual del comprobante escaneado
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.card,
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        size: 34,
                        color: AppColors.primaryAccessible,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scan.storagePath.split('/').last,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Almacenado de forma segura en Supabase Storage (receipts)',
                      style: AppTypography.captionBadge.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tabla de datos extraídos por el motor OCR
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: AppRadius.borderMd,
                ),
                child: Column(
                  children: [
                    _buildScanMetaRow(
                      'Comercio Detectado',
                      scan.extractedMerchant ?? widget.transaction.merchantName,
                    ),
                    const Divider(height: 14, color: AppColors.borderSubtle),
                    _buildScanMetaRow(
                      'Monto Extraído',
                      scan.extractedAmount != null
                          ? '\$${scan.extractedAmount!.toStringAsFixed(2)}'
                          : widget.transaction.formattedSignedAmount,
                    ),
                    const Divider(height: 14, color: AppColors.borderSubtle),
                    _buildScanMetaRow(
                      'Nivel de Confianza',
                      scan.formattedConfidence,
                      highlightColor: scan.hasHighConfidence
                          ? AppColors.incomeText
                          : AppColors.warningText,
                    ),
                    if (scan.taxIdOrAuthNumber != null &&
                        scan.taxIdOrAuthNumber!.isNotEmpty) ...[
                      const Divider(height: 14, color: AppColors.borderSubtle),
                      _buildScanMetaRow(
                        'No. Autorización / Factura',
                        scan.taxIdOrAuthNumber!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              AppButton(
                text: 'Cerrar Visor',
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(viewerContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanMetaRow(String label, String value, {Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.captionBadge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTypography.labelSm.copyWith(
            color: highlightColor ?? AppColors.textMain,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final catColor = tx.categoryColor;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Barra superior con Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // 2. Encabezado con título y botón de cierre
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Detalle de Gasto',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (tx.isOcr)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySubtle,
                              borderRadius: AppRadius.borderPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.document_scanner_rounded,
                                  size: 13,
                                  color: AppColors.primaryAccessible,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'OCR',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.primaryAccessible,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.borderSubtle),

              // 3. Contenido Scrolleable (Hero, Metadata, Notas y Comprobante)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Amount Hero Card ---
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHero,
                          borderRadius: AppRadius.borderHero,
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                          boxShadow: AppShadows.hero,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: catColor.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          resolveCategoryIcon(tx.categoryIcon),
                                          size: 20,
                                          color: catColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          tx.categoryName,
                                          style: AppTypography.labelMd.copyWith(
                                            color: AppColors.textMain,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                AppBadge.expense(
                                  text: 'Gasto Quincenal',
                                  prefixIcon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 13,
                                    color: AppColors.expenseText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                tx.formattedSignedAmount,
                                style: AppTypography.currencyHeroMobile.copyWith(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Descontado del presupuesto quincenal activo',
                              style: AppTypography.captionBadge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Metadata Card ---
                      Text(
                        'INFORMACIÓN GENERAL',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBase,
                          borderRadius: AppRadius.borderCard,
                          border: Border.all(color: AppColors.borderSubtle),
                          boxShadow: AppShadows.card,
                        ),
                        child: Column(
                          children: [
                            // 1. Comercio
                            _buildInfoRow(
                              icon: Icons.storefront_rounded,
                              label: 'Establecimiento / Comercio',
                              content: Text(
                                tx.merchantName,
                                style: AppTypography.labelLg.copyWith(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Divider(
                              height: 18,
                              color: AppColors.borderSubtle,
                            ),

                            // 2. Fecha y Hora exacta
                            _buildInfoRow(
                              icon: Icons.event_outlined,
                              label: 'Fecha y Hora de la Operación',
                              content: Text(
                                _formatDateTime(tx.transactionDate),
                                style: AppTypography.numericRow.copyWith(
                                  color: AppColors.textMain,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Divider(
                              height: 18,
                              color: AppColors.borderSubtle,
                            ),

                            // 3. Categoría de gasto
                            _buildInfoRow(
                              icon: Icons.category_outlined,
                              label: 'Bolsa Asignada',
                              content: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: catColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      tx.categoryName,
                                      style: AppTypography.bodyMd.copyWith(
                                        color: AppColors.textMain,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 18,
                              color: AppColors.borderSubtle,
                            ),

                            // 4. Cuenta de fondeo
                            _buildInfoRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Cuenta de Débito / Fondeo',
                              content: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tx.sourceAccountColor
                                          .withValues(alpha: 0.15),
                                      borderRadius: AppRadius.borderPill,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.credit_card_rounded,
                                          size: 14,
                                          color: tx.sourceAccountColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            tx.sourceAccountName,
                                            style: AppTypography.labelSm.copyWith(
                                              color: AppColors.textMain,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 18,
                              color: AppColors.borderSubtle,
                            ),

                            // 5. Método de entrada
                            _buildInfoRow(
                              icon: tx.isOcr
                                  ? Icons.document_scanner_rounded
                                  : Icons.edit_note_rounded,
                              label: 'Método de Registro',
                              content: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: tx.isOcr
                                      ? AppColors.primarySubtle
                                      : AppColors.surfaceSubtle,
                                  borderRadius: AppRadius.borderPill,
                                ),
                                child: Text(
                                  tx.isOcr
                                      ? 'Comprobante OCR Escaneado'
                                      : 'Registro Manual',
                                  style: AppTypography.labelSm.copyWith(
                                    color: tx.isOcr
                                        ? AppColors.primaryAccessible
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // --- Notas (si existen) ---
                      if (tx.notes != null && tx.notes!.trim().isNotEmpty) ...[
                        Text(
                          'NOTAS Y OBSERVACIONES',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.sticky_note_2_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tx.notes!,
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.textMain,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // --- Folio / Autorización (si existe en scan o notas) ---
                      if (_receiptScan?.taxIdOrAuthNumber != null &&
                          _receiptScan!.taxIdOrAuthNumber!.isNotEmpty) ...[
                        Text(
                          'FOLIO FISCAL / AUTORIZACIÓN',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBase,
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.verified_outlined,
                                color: AppColors.primaryAccessible,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _receiptScan!.taxIdOrAuthNumber!,
                                  style: AppTypography.numericRow.copyWith(
                                    color: AppColors.textMain,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                tooltip: 'Copiar folio',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: _receiptScan!.taxIdOrAuthNumber!,
                                    ),
                                  );
                                  AppToast.showSuccess(
                                    context,
                                    'Folio copiado al portapapeles',
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // --- Visor de Comprobante OCR (si aplica) ---
                      if (tx.isOcr) ...[
                        Text(
                          'COMPROBANTE VINCULADO',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_isLoadingReceipt)
                          Container(
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppRadius.borderMd,
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryAccessible,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Cargando datos del comprobante...',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        else if (_receiptScan != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppRadius.borderMd,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: AppShadows.card,
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: AppColors.primaryAccessible,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Ticket OCR Verificado',
                                            style: AppTypography.labelMd.copyWith(
                                              color: AppColors.textMain,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Confianza: ${_receiptScan!.formattedConfidence}',
                                            style: AppTypography.captionBadge
                                                .copyWith(
                                              color:
                                                  _receiptScan!.hasHighConfidence
                                                      ? AppColors.incomeText
                                                      : AppColors.warningText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _showFullReceiptViewer(
                                        context,
                                        _receiptScan!,
                                      ),
                                      icon: const Icon(
                                        Icons.zoom_in_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Ver'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            AppColors.primaryAccessible,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSubtle,
                              borderRadius: AppRadius.borderMd,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Comprobante procesado (ID: ${tx.receiptScanId ?? "N/A"})',
                                    style: AppTypography.captionBadge.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),

              // 4. Barra de Acción Destructiva Fija (Sticky Bottom Action Bar)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceBase,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isDeleting ? null : _confirmAndDelete,
                    borderRadius: AppRadius.borderMd,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.expenseBg.withValues(alpha: 0.25),
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(
                          color: AppColors.expenseBg.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _isDeleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.expenseText,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.expenseText,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Eliminar Gasto',
                                  style: AppTypography.labelLg.copyWith(
                                    color: AppColors.expenseText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primaryAccessible),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.captionBadge.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
