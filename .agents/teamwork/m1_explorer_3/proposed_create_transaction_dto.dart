import 'transaction.dart';

/// DTO para la creación de una transacción manual o vinculada a comprobante OCR (POST /transactions)
class CreateTransactionDto {
  const CreateTransactionDto({
    required this.cycleId,
    required this.sourceAccountId,
    required this.amount,
    required this.merchantName,
    required this.transactionDate,
    this.allocationId,
    this.receiptScanId,
    this.transactionType = TransactionType.expense,
    this.entryMethod = EntryMethod.manual,
    this.notes,
  });

  /// ID del ciclo quincenal activo donde se imputa el gasto
  final String cycleId;

  /// ID de la cuenta financiera de origen (banco, billetera o efectivo)
  final String sourceAccountId;

  /// Monto monetario (> 0.00)
  final double amount;

  /// Nombre del comercio o destinatario del gasto
  final String merchantName;

  /// Fecha en formato ISO 'YYYY-MM-DD'
  final String transactionDate;

  /// ID de la partida presupuestaria / bolsa (opcional)
  final String? allocationId;

  /// ID del comprobante OCR origen (opcional)
  final String? receiptScanId;

  /// Tipo de transacción (gasto, ajuste, transferencia)
  final TransactionType transactionType;

  /// Método de ingreso (manual o ocr)
  final EntryMethod entryMethod;

  /// Notas o descripción adicional
  final String? notes;

  /// Constructor de conveniencia para gastos manuales
  factory CreateTransactionDto.manual({
    required String cycleId,
    required String sourceAccountId,
    required double amount,
    required String merchantName,
    required String transactionDate,
    String? allocationId,
    String? notes,
  }) {
    return CreateTransactionDto(
      cycleId: cycleId,
      sourceAccountId: sourceAccountId,
      amount: amount,
      merchantName: merchantName,
      transactionDate: transactionDate,
      allocationId: allocationId,
      entryMethod: EntryMethod.manual,
      transactionType: TransactionType.expense,
      notes: notes,
    );
  }

  /// Constructor de conveniencia para gastos originados por comprobante OCR
  factory CreateTransactionDto.ocr({
    required String cycleId,
    required String sourceAccountId,
    required String receiptScanId,
    required double amount,
    required String merchantName,
    required String transactionDate,
    String? allocationId,
    String? notes,
  }) {
    return CreateTransactionDto(
      cycleId: cycleId,
      sourceAccountId: sourceAccountId,
      receiptScanId: receiptScanId,
      amount: amount,
      merchantName: merchantName,
      transactionDate: transactionDate,
      allocationId: allocationId,
      entryMethod: EntryMethod.ocr,
      transactionType: TransactionType.expense,
      notes: notes,
    );
  }

  factory CreateTransactionDto.fromJson(Map<String, dynamic> json) {
    return CreateTransactionDto(
      cycleId: json['cycle_id'] as String? ?? json['cycleId'] as String? ?? '',
      sourceAccountId: json['source_account_id'] as String? ??
          json['sourceAccountId'] as String? ??
          '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      merchantName: json['merchant_name'] as String? ??
          json['merchantName'] as String? ??
          '',
      transactionDate: json['transaction_date'] as String? ??
          json['transactionDate'] as String? ??
          DateTime.now().toIso8601String().split('T')[0],
      allocationId: json['allocation_id'] as String? ??
          json['allocationId'] as String?,
      receiptScanId: json['receipt_scan_id'] as String? ??
          json['receiptScanId'] as String?,
      transactionType: TransactionType.fromValue(
          json['transaction_type'] as String? ??
              json['transactionType'] as String?),
      entryMethod: EntryMethod.fromValue(json['entry_method'] as String? ??
          json['entryMethod'] as String?),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cycle_id': cycleId,
      'source_account_id': sourceAccountId,
      'amount': amount,
      'merchant_name': merchantName,
      'transaction_date': transactionDate,
      if (allocationId != null && allocationId!.isNotEmpty)
        'allocation_id': allocationId,
      if (receiptScanId != null && receiptScanId!.isNotEmpty)
        'receipt_scan_id': receiptScanId,
      'transaction_type': transactionType.value,
      'entry_method': entryMethod.value,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
