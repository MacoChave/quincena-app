import 'package:flutter/material.dart';
import 'package:quincena/core/theme/theme.dart';

/// Estado de ritmo de gasto quincenal para el status pill del Bento Tile.
enum ExpensePaceStatus {
  /// En meta: <70% del presupuesto y consumo proporcional a los días transcurridos.
  onTrack,

  /// Alerta: 70% - 90% del presupuesto consumido o gasto acelerado respecto a días transcurridos.
  warning,

  /// Sobrepasado: >90% del presupuesto consumido o saldo disponible negativo (déficit).
  overspent;

  String get label {
    switch (this) {
      case ExpensePaceStatus.onTrack:
        return 'En meta';
      case ExpensePaceStatus.warning:
        return 'Alerta';
      case ExpensePaceStatus.overspent:
        return 'Sobrepasado';
    }
  }

  Color get dotColor {
    switch (this) {
      case ExpensePaceStatus.onTrack:
        return const Color(0xFF256B38); // Forest Green de Stitch
      case ExpensePaceStatus.warning:
        return AppColors.warningText; // #856404
      case ExpensePaceStatus.overspent:
        return AppColors.expenseText; // #A33F19
    }
  }
}

/// Widget de Tarjeta Bento para Analíticas Quincenales (`FeedAnalyticsBento`).
///
/// Implementa fielmente el diseño Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:50-94`:
/// - Fondo Warm Cream (#FCF5C7) con sombra suave `AppShadows.hero` (0 8px 24px rgba(252,245,199,0.45)).
/// - Fila de título: "RITMO DE GASTO QUINCENAL" (protegida con `Expanded` y elipsis) + píldora translúcida con dot semafórico ("En meta", "Alerta", "Sobrepasado").
/// - Hero monetario: Cifra tabular bold (32px) con total ejecutado y desglose de días transcurridos.
/// - Barra de progreso de 8px con animación y semaforización pastel (#79ADDC <70%, #FFEE93 70-90%, #FFC09F >90%).
/// - Fila de submétricas en 2 columnas: "Promedio" ($X.XX / día) y "Capturas" (N comprobantes OCR).
class FeedAnalyticsBento extends StatelessWidget {
  const FeedAnalyticsBento({
    super.key,
    required this.totalSpent,
    required this.totalBudgeted,
    this.daysElapsed = 1,
    this.totalDays = 15,
    this.ocrReceiptsCount = 0,
    this.availableBalance,
    this.onTapInsights,
  });

  /// Total de dinero gastado en el ciclo activo
  final double totalSpent;

  /// Presupuesto total asignado o ingreso neto de la quincena
  final double totalBudgeted;

  /// Días transcurridos desde el inicio del ciclo quincenal (base 1)
  final int daysElapsed;

  /// Total de días del ciclo quincenal (típicamente 15 o 16 días)
  final int totalDays;

  /// Cantidad de transacciones registradas mediante escaneo OCR
  final int ocrReceiptsCount;

  /// Saldo disponible actual (opcional para detectar déficit < 0)
  final double? availableBalance;

  /// Callback opcional al presionar el botón de insights
  final VoidCallback? onTapInsights;

  /// Calcula el ritmo del gasto según consumo y días transcurridos
  ExpensePaceStatus get paceStatus {
    if (availableBalance != null && availableBalance! < 0) {
      return ExpensePaceStatus.overspent;
    }
    if (totalBudgeted <= 0) {
      return totalSpent > 0
          ? ExpensePaceStatus.overspent
          : ExpensePaceStatus.onTrack;
    }

    final ratio = totalSpent / totalBudgeted;
    if (ratio >= 0.90) {
      return ExpensePaceStatus.overspent;
    }
    if (ratio >= 0.70) {
      return ExpensePaceStatus.warning;
    }

    // Regla proporcional de ritmo de días transcurridos
    if (totalDays > 0 && daysElapsed > 0) {
      final expectedPace = daysElapsed / totalDays;
      if (ratio > (expectedPace + 0.15) && ratio > 0.50) {
        return ExpensePaceStatus.warning;
      }
    }

    return ExpensePaceStatus.onTrack;
  }

  /// Calcula el ratio de progreso acotado de 0.0 a 1.0
  double get progressRatio {
    if (totalBudgeted <= 0) {
      return totalSpent > 0 ? 1.0 : 0.0;
    }
    return (totalSpent / totalBudgeted).clamp(0.0, 1.0);
  }

  /// Resuelve el color de la barra según el semáforo Stitch
  Color get progressColor {
    final ratio = totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0.0;
    if (ratio < 0.70) return AppColors.primary; // #79ADDC
    if (ratio < 0.90) return AppColors.warningBg; // #FFEE93
    return AppColors.expenseBg; // #FFC09F
  }

  /// Promedio de gasto diario
  double get dailyAverage {
    final effectiveDays = daysElapsed <= 0 ? 1 : daysElapsed;
    return totalSpent / effectiveDays;
  }

  String _formatCurrency(double amount) {
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final formatted = absAmount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return isNegative ? '-\$$formatted' : '\$$formatted';
  }

  @override
  Widget build(BuildContext context) {
    final status = paceStatus;
    final effectiveDays = daysElapsed <= 0 ? 1 : daysElapsed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHero, // #FCF5C7
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x141C242B), // sutil borde 8%
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x73FCF5C7), // ~45% rgba(252,245,199,0.45)
            offset: Offset(0, 8),
            blurRadius: 24,
          ),
          BoxShadow(
            color: Color(0x0A1C242B),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Fila de Encabezado: Título + Status Pill (Protegida con Expanded + elipsis)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'RITMO DE GASTO QUINCENAL',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Píldora de Estado (Stitch: bg-surface-base/80 shadow-sm backdrop-blur-sm)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase.withValues(alpha: 0.85),
                  borderRadius: AppRadius.borderPill,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x081C242B),
                      offset: Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: status.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status.label,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Fila Hero: Cifra Principal Tabular + Botón Insights
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatCurrency(totalSpent),
                        style: AppTypography.currencyHeroMobile,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total ejecutado en $effectiveDays ${effectiveDays == 1 ? 'día' : 'días'} de ciclo',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Ícono de insights redondeado (Stitch: w-12 h-12 bg-surface-base/60)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTapInsights,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBase.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x081C242B),
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.insights_rounded,
                        size: 24,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Barra de progreso animada de 8px
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.textMain.withValues(alpha: 0.10),
              borderRadius: AppRadius.borderPill,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth * progressRatio;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    width: barWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: progressColor,
                      borderRadius: AppRadius.borderPill,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 4. Sub-métricas Row (2 Columnas: Promedio & Capturas)
          Row(
            children: [
              // Columna 1: Promedio diario
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7EFF8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          size: 18,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Promedio',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${_formatCurrency(dailyAverage)} / día',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.textMain,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Columna 2: Capturas OCR
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBase.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFAAF4B3).withValues(alpha: 0.50),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.document_scanner_outlined,
                          size: 18,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Capturas',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$ocrReceiptsCount comprobantes',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.textMain,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
