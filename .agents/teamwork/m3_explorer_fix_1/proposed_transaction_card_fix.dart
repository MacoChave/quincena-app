import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/budget/presentation/widgets/icon_helper.dart';
import 'package:quincena/features/transactions/data/models/models.dart';

/// Tarjeta de Transacción para el Feed Quincenal (RF-04 / RF-06).
///
/// Especificación de diseño: Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:140-161`.
/// - Avatar 44x44px con radio de 12px, color distintivo de categoría e ícono representativo.
/// - Nombre del comercio truncado con puntos suspensivos (`TextOverflow.ellipsis`).
/// - Fila de metadatos responsiva: Hora formateada ("14:32 hrs"), punto separador condicional
///   y píldora de método/cuenta protegida en `Flexible` con elipsis interno:
///   * OCR: "OCR Escaneado" con ícono `document_scanner` en `#79ADDC`.
///   * Manual: Etiqueta de cuenta de débito/origen ("Tarjeta Débito", "Efectivo", etc.).
/// - Columna derecha: Cifra monetaria con números tabulares (`tnum` / `FontFeature.tabularFigures()`)
///   y etiqueta de categoría o cuenta de fondeo, con `ConstrainedBox` para no canibalizar la columna central.
/// - Botón opcional de eliminación con hit-target compacto accesible (32x32px).
/// - Micro-interacción táctil accesible con sutil reducción de escala al presionar (`active:scale-[0.985]`).
class TransactionCard extends StatefulWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
    this.margin = const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final EdgeInsetsGeometry margin;

  @override
  State<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<TransactionCard> {
  bool _isPressed = false;

  String _formatTimestamp(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute hrs';
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final catColor = tx.category?.parsedColor ?? AppColors.primary;
    final formattedAmount = tx.formattedSignedAmount;

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: AppColors.surfaceBase,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: AppColors.borderSubtle.withValues(alpha: 0.8),
            width: 1.0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A1C242B),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16.0),
            onHighlightChanged: (highlighted) {
              setState(() => _isPressed = highlighted);
            },
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  // 1. Avatar de Categoría (44x44px, radio 12px)
                  Container(
                    width: 44.0,
                    height: 44.0,
                    constraints: const BoxConstraints(
                      maxWidth: 44.0,
                      maxHeight: 44.0,
                    ),
                    decoration: BoxDecoration(
                      color: catColor,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      resolveCategoryIcon(tx.category?.icon),
                      size: 22.0,
                      color: AppColors.textMain, // Nunca blanco sobre pastel
                    ),
                  ),
                  const SizedBox(width: 12.0),

                  // 2. Columna Central: Comercio y Metadatos Responsivos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.merchantName,
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3.0),
                        // Fila de metadatos responsiva: timestamp flexible + dot condicional + pill flexible
                        Row(
                          children: [
                            // Hora de transacción (Flexible para adaptarse bajo presión flex extrema)
                            Flexible(
                              child: Text(
                                _formatTimestamp(tx.transactionDate),
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (tx.isOcr || tx.sourceAccount != null) ...[
                              const SizedBox(width: 4.0),
                              // Punto separador sutil (solo si hay método o cuenta que separar)
                              Container(
                                width: 3.0,
                                height: 3.0,
                                decoration: const BoxDecoration(
                                  color: AppColors.borderHairline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4.0),

                              // Píldora de método / cuenta responsiva
                              Flexible(
                                child: tx.isOcr
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.25),
                                          borderRadius:
                                              BorderRadius.circular(6.0),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.document_scanner_rounded,
                                              size: 11.0,
                                              color:
                                                  AppColors.primaryAccessible,
                                            ),
                                            const SizedBox(width: 3.5),
                                            Flexible(
                                              child: Text(
                                                'OCR Escaneado',
                                                style: AppTypography
                                                    .captionBadge
                                                    .copyWith(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors
                                                      .primaryAccessible,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : (tx.sourceAccount != null
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6.0,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceSubtle,
                                              borderRadius:
                                                  BorderRadius.circular(6.0),
                                            ),
                                            child: Text(
                                              tx.sourceAccountName,
                                              style: AppTypography.captionBadge
                                                  .copyWith(
                                                fontSize: 11.0,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )
                                        : const SizedBox.shrink()),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8.0),

                  // 3. Columna Derecha: Monto Tabular y Categoría
                  // Protegida con ConstrainedBox para garantizar ancho disponible en la columna central
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formattedAmount,
                          style: AppTypography.numericRow.copyWith(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w700,
                            color: tx.isExpense
                                ? AppColors.textMain
                                : AppColors.incomeText,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          tx.categoryName,
                          style: AppTypography.bodySm.copyWith(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 4. Acción opcional de eliminación
                  if (widget.onDelete != null) ...[
                    const SizedBox(width: 2.0),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppColors.textMuted,
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Eliminar gasto',
                      onPressed: widget.onDelete,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
