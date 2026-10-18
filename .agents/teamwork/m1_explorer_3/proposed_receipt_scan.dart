/// Estado del escaneo y procesamiento OCR
enum OcrStatus {
  pending(
    value: 'pending',
    label: 'Pendiente',
  ),
  processed(
    value: 'processed',
    label: 'Procesado',
  ),
  failed(
    value: 'failed',
    label: 'Fallido',
  ),
  verified(
    value: 'verified',
    label: 'Verificado',
  );

  const OcrStatus({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  static OcrStatus fromValue(String? val) {
    return OcrStatus.values.firstWhere(
      (e) => e.value == val,
      orElse: () => OcrStatus.pending,
    );
  }
}

/// Modelo de entidad para Comprobantes procesados vía OCR (RF-03 / RF-05)
class ReceiptScan {
  const ReceiptScan({
    required this.id,
    required this.userId,
    required this.storagePath,
    this.ocrStatus = OcrStatus.pending,
    this.extractedMerchant,
    this.extractedAmount,
    this.extractedDate,
    this.taxIdOrAuthNumber,
    this.suggestedAccountId,
    this.confidenceScore,
    this.ocrRawData,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String storagePath;
  final OcrStatus ocrStatus;
  final String? extractedMerchant;
  final double? extractedAmount;
  final DateTime? extractedDate;
  final String? taxIdOrAuthNumber;
  final String? suggestedAccountId;
  final double? confidenceScore;
  final Map<String, dynamic>? ocrRawData;
  final DateTime? createdAt;

  // --- Getters de conveniencia UI ---

  bool get isPending => ocrStatus == OcrStatus.pending;
  bool get isProcessed => ocrStatus == OcrStatus.processed;
  bool get isFailed => ocrStatus == OcrStatus.failed;
  bool get isVerified => ocrStatus == OcrStatus.verified;

  /// Retorna si el reconocimiento tuvo una confianza aceptable (>= 70%)
  bool get hasHighConfidence => (confidenceScore ?? 0.0) >= 70.0;

  /// Retorna si el comprobante está listo para pre-validación / confirmación
  bool get isReadyForConfirmation =>
      (ocrStatus == OcrStatus.processed || ocrStatus == OcrStatus.pending) &&
      (extractedAmount != null && extractedAmount! > 0);

  /// Porcentaje de confianza legible para UI (e.g. "98%")
  String get formattedConfidence =>
      '${(confidenceScore ?? 0.0).toStringAsFixed(0)}%';

  factory ReceiptScan.fromJson(Map<String, dynamic> json) {
    return ReceiptScan(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      storagePath: json['storage_path'] as String? ??
          json['storagePath'] as String? ??
          '',
      ocrStatus: OcrStatus.fromValue(
          json['ocr_status'] as String? ?? json['ocrStatus'] as String?),
      extractedMerchant: json['extracted_merchant'] as String? ??
          json['extractedMerchant'] as String?,
      extractedAmount: (json['extracted_amount'] as num?)?.toDouble() ??
          (json['extractedAmount'] as num?)?.toDouble(),
      extractedDate: json['extracted_date'] != null
          ? DateTime.tryParse(json['extracted_date'] as String)
          : (json['extractedDate'] != null
              ? DateTime.tryParse(json['extractedDate'] as String)
              : null),
      taxIdOrAuthNumber: json['tax_id_or_auth_number'] as String? ??
          json['taxIdOrAuthNumber'] as String?,
      suggestedAccountId: json['suggested_account_id'] as String? ??
          json['suggestedAccountId'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ??
          (json['confidenceScore'] as num?)?.toDouble(),
      ocrRawData: json['ocr_raw_data'] is Map<String, dynamic>
          ? json['ocr_raw_data'] as Map<String, dynamic>
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'storage_path': storagePath,
      'ocr_status': ocrStatus.value,
      if (extractedMerchant != null) 'extracted_merchant': extractedMerchant,
      if (extractedAmount != null) 'extracted_amount': extractedAmount,
      if (extractedDate != null)
        'extracted_date': extractedDate!.toIso8601String().split('T')[0],
      if (taxIdOrAuthNumber != null)
        'tax_id_or_auth_number': taxIdOrAuthNumber,
      if (suggestedAccountId != null)
        'suggested_account_id': suggestedAccountId,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      if (ocrRawData != null) 'ocr_raw_data': ocrRawData,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ReceiptScan copyWith({
    String? id,
    String? userId,
    String? storagePath,
    OcrStatus? ocrStatus,
    String? extractedMerchant,
    double? extractedAmount,
    DateTime? extractedDate,
    String? taxIdOrAuthNumber,
    String? suggestedAccountId,
    double? confidenceScore,
    Map<String, dynamic>? ocrRawData,
    DateTime? createdAt,
  }) {
    return ReceiptScan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storagePath: storagePath ?? this.storagePath,
      ocrStatus: ocrStatus ?? this.ocrStatus,
      extractedMerchant: extractedMerchant ?? this.extractedMerchant,
      extractedAmount: extractedAmount ?? this.extractedAmount,
      extractedDate: extractedDate ?? this.extractedDate,
      taxIdOrAuthNumber: taxIdOrAuthNumber ?? this.taxIdOrAuthNumber,
      suggestedAccountId: suggestedAccountId ?? this.suggestedAccountId,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      ocrRawData: ocrRawData ?? this.ocrRawData,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
