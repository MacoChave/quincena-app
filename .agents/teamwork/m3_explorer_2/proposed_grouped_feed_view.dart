import 'package:flutter/material.dart';
import 'package:quincena/core/components/app_components.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/transactions/data/models/models.dart';

/// Sección de transacciones agrupadas cronológicamente por día.
class GroupedDateSection {
  const GroupedDateSection({
    required this.date,
    required this.headerTitle,
    required this.dayTotal,
    required this.transactions,
  });

  final DateTime date;
  final String headerTitle;
  final double dayTotal;
  final List<Transaction> transactions;

  /// Agrupa y ordena transacciones de forma cronológica descendente (RF-04 / RF-06).
  ///
  /// - Grupos ordenados por fecha de más reciente a más antigua.
  /// - Dentro de cada día, orden descendente por hora/minuto.
  /// - Formatos de título:
  ///   * "Hoy - [Día] [Mes]"
  ///   * "Ayer - [Día] [Mes]"
  ///   * "[Día] [Mes] [Año]"
  /// - Total acumulado del día exacto sin IEEE-754 drift.
  static List<GroupedDateSection> groupTransactions(
    List<Transaction> list, {
    DateTime? referenceDate,
  }) {
    if (list.isEmpty) return const [];

    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 1. Ordenar transacciones descendente
    final sorted = List<Transaction>.from(list)..sort((a, b) {
      final comp = b.transactionDate.compareTo(a.transactionDate);
      if (comp != 0) return comp;
      final aCreated = a.createdAt ?? a.transactionDate;
      final bCreated = b.createdAt ?? b.transactionDate;
      return bCreated.compareTo(aCreated);
    });

    // 2. Agrupar por clave de fecha (YYYY-MM-DD)
    final Map<String, List<Transaction>> map = {};
    for (final tx in sorted) {
      final d = tx.transactionDate;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(tx);
    }

    const monthNames = [
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

    // 3. Construir secciones
    final List<GroupedDateSection> sections = [];
    for (final entry in map.entries) {
      final txList = entry.value;
      final d = txList.first.transactionDate;
      final dateOnly = DateTime(d.year, d.month, d.day);

      String title;
      if (dateOnly.isAtSameMomentAs(today)) {
        title = 'Hoy - ${d.day} ${monthNames[d.month]}';
      } else if (dateOnly.isAtSameMomentAs(yesterday)) {
        title = 'Ayer - ${d.day} ${monthNames[d.month]}';
      } else {
        title = '${d.day} ${monthNames[d.month]} ${d.year}';
      }

      final total = txList.fold<double>(0.0, (sum, t) => sum + t.amount);

      sections.add(
        GroupedDateSection(
          date: dateOnly,
          headerTitle: title,
          dayTotal: double.parse(total.toStringAsFixed(2)),
          transactions: txList,
        ),
      );
    }

    return sections;
  }
}

/// Encabezado visual para cada bloque de fecha en el feed
class DateSectionHeader extends StatelessWidget {
  const DateSectionHeader({
    super.key,
    required this.title,
    required this.dayTotal,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  final String title;
  final double dayTotal;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.labelMd.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '-\$${dayTotal.toStringAsFixed(2)}',
            style: AppTypography.numericRow.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textMain,
              fontFeatures: const [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estados vacíos estilizados para el Feed de Gastos Quincenales
class EmptyFeedState extends StatelessWidget {
  const EmptyFeedState._({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionText,
    this.onAction,
  });

  /// Estado vacío cuando los filtros o búsqueda devuelven 0 resultados
  factory EmptyFeedState.noFilterResults({
    Key? key,
    required VoidCallback onClearFilters,
  }) {
    return EmptyFeedState._(
      key: key,
      icon: Icons.receipt_long_outlined,
      title: 'No se encontraron gastos para los filtros seleccionados',
      subtitle:
          'Intenta con otros términos o limpia los filtros activos para ver tus registros.',
      actionText: 'Limpiar filtros',
      onAction: onClearFilters,
    );
  }

  /// Estado vacío cuando el ciclo activo no tiene ningún gasto registrado
  factory EmptyFeedState.noTransactionsInCycle({
    Key? key,
    VoidCallback? onScanReceipt,
  }) {
    return EmptyFeedState._(
      key: key,
      icon: Icons.receipt_long_outlined,
      title: 'No hay gastos registrados en esta quincena',
      subtitle:
          'Comienza capturando un comprobante con la cámara o registrando un gasto manual.',
      actionText: onScanReceipt != null ? 'Escanear comprobante' : null,
      onAction: onScanReceipt,
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceHero,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSm.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(
                text: actionText!,
                onPressed: onAction!,
                variant: AppButtonVariant.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
