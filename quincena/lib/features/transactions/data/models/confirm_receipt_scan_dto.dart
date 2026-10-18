/// DTO para la validación y confirmación de comprobantes OCR (POST /receipt-scans/:id/confirm)
///
/// Permite al usuario validar y corregir los campos detectados automáticamente antes
/// de persistir la transacción y asociar el escaneo verificado (CA-03.2).
class ConfirmReceiptScanDto {
  const ConfirmReceiptScanDto({
    required this.cycleId,
    required this.sourceAccountId,
    this.allocationId,
    this.merchantName,
    this.amount,
    this.transactionDate,
    this.notes,
  });

  /// ID del ciclo quincenal activo donde se imputará el gasto (obligatorio)
  final String cycleId;

  /// ID de la cuenta financiera de origen (banco, billetera o efectivo) (obligatorio)
  final String sourceAccountId;

  /// ID de la partida presupuestaria / bolsa (opcional)
  final String? allocationId;

  /// Nombre del comercio (corregido o verificado por el usuario)
  final String? merchantName;

  /// Monto monetario verificado (> 0.00)
  final double? amount;

  /// Fecha de la operación en formato 'YYYY-MM-DD'
  final String? transactionDate;

  /// Notas o detalles adicionales
  final String? notes;

  factory ConfirmReceiptScanDto.fromJson(Map<String, dynamic> json) {
    return ConfirmReceiptScanDto(
      cycleId: json['cycle_id'] as String? ?? json['cycleId'] as String? ?? '',
      sourceAccountId: json['source_account_id'] as String? ??
          json['sourceAccountId'] as String? ??
          '',
      allocationId: json['allocation_id'] as String? ??
          json['allocationId'] as String?,
      merchantName: json['merchant_name'] as String? ??
          json['merchantName'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      transactionDate: json['transaction_date'] as String? ??
          json['transactionDate'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cycle_id': cycleId,
      'source_account_id': sourceAccountId,
      if (allocationId != null && allocationId!.isNotEmpty)
        'allocation_id': allocationId,
      if (merchantName != null && merchantName!.isNotEmpty)
        'merchant_name': merchantName,
      if (amount != null) 'amount': amount,
      if (transactionDate != null && transactionDate!.isNotEmpty)
        'transaction_date': transactionDate,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
