import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/transactions/data/models/models.dart';

/// Live Search Input Bar para el Feed de Transacciones (RF-04 / RF-06).
///
/// Especificación de diseño: Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:96-101`.
/// - Altura: 48.0 px (`h-[48px]`).
/// - Radio: 12.0 px (`rounded-xl` / `AppRadius.md`).
/// - Prefijo: Icono de búsqueda (`Icons.search_rounded`, 20px, color `#5C6773` / `textMuted`).
/// - Placeholder: "Buscar por comercio, factura o nota...".
/// - Botón Sufijo: Botón para limpiar texto cuando no esté vacío.
/// - Filtrado del lado del cliente instantáneo (<16ms) sin llamadas de red.
class FeedSearchBar extends StatefulWidget {
  const FeedSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Buscar por comercio, factura o nota...',
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Utilidad de filtrado estático de alto rendimiento (<16ms para >500 registros).
  ///
  /// Evalúa en una sola pasada case-insensitive sobre:
  /// 1. `merchant_name`
  /// 2. `notes`
  /// 3. `tax_id_or_auth_number` (a través de [scanAuthNumbers] o campos en transacción)
  static List<Transaction> filterTransactions({
    required List<Transaction> transactions,
    required String query,
    Map<String, String>? scanAuthNumbers,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return transactions;

    return transactions.where((tx) {
      // 1. Comercio
      if (tx.merchantName.toLowerCase().contains(cleanQuery)) {
        return true;
      }

      // 2. Notas descriptivas
      if (tx.notes != null && tx.notes!.toLowerCase().contains(cleanQuery)) {
        return true;
      }

      // 3. Número de autorización o factura OCR
      if (tx.receiptScanId != null) {
        if (tx.receiptScanId!.toLowerCase().contains(cleanQuery)) {
          return true;
        }
        if (scanAuthNumbers != null) {
          final authNum = scanAuthNumbers[tx.receiptScanId];
          if (authNum != null && authNum.toLowerCase().contains(cleanQuery)) {
            return true;
          }
        }
      }

      return false;
    }).toList();
  }

  @override
  State<FeedSearchBar> createState() => _FeedSearchBarState();
}

class _FeedSearchBarState extends State<FeedSearchBar> {
  late TextEditingController _effectiveController;
  late FocusNode _effectiveFocusNode;
  bool _isLocalController = false;
  bool _isLocalFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _effectiveController = TextEditingController();
      _isLocalController = true;
    } else {
      _effectiveController = widget.controller!;
    }

    if (widget.focusNode == null) {
      _effectiveFocusNode = FocusNode();
      _isLocalFocusNode = true;
    } else {
      _effectiveFocusNode = widget.focusNode!;
    }

    _effectiveController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(FeedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_isLocalController) {
        _effectiveController.removeListener(_onTextChanged);
        _effectiveController.dispose();
        _isLocalController = false;
      }
      _effectiveController = widget.controller ?? TextEditingController();
      _isLocalController = widget.controller == null;
      _effectiveController.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onTextChanged);
    if (_isLocalController) {
      _effectiveController.dispose();
    }
    if (_isLocalFocusNode) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _handleClear() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _effectiveController.text.isNotEmpty;

    return Container(
      height: 48.0,
      decoration: BoxDecoration(
        color: AppColors.surfaceBase,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: _effectiveFocusNode.hasFocus
              ? AppColors.primary
              : AppColors.borderSubtle,
          width: _effectiveFocusNode.hasFocus ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x081C242B),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        key: const Key('feed_search_input'),
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyMd.copyWith(
          color: AppColors.textMain,
          fontSize: 14,
        ),
        textAlignVertical: TextAlignVertical.center,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          hintText: widget.hintText,
          hintStyle: AppTypography.bodyMd.copyWith(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 48,
          ),
          suffixIcon: hasText
              ? Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: IconButton(
                    key: const Key('feed_search_clear_btn'),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                    splashRadius: 18,
                    onPressed: _handleClear,
                    tooltip: 'Limpiar búsqueda',
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 48,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
