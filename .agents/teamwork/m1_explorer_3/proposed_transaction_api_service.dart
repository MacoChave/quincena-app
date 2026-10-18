import 'dart:io';
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/network/api_exception.dart';
import '../models/models.dart';

/// Item de transacción conflictiva detectada como duplicado (RN-03)
class DuplicateTransactionItem {
  const DuplicateTransactionItem({
    required this.id,
    required this.merchantName,
    required this.amount,
    this.transactionDate,
    this.createdAt,
  });

  final String id;
  final String merchantName;
  final double amount;
  final DateTime? transactionDate;
  final DateTime? createdAt;

  factory DuplicateTransactionItem.fromJson(Map<String, dynamic> json) {
    return DuplicateTransactionItem(
      id: json['id'] as String? ?? '',
      merchantName: json['merchant_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      transactionDate: json['transaction_date'] != null
          ? DateTime.tryParse(json['transaction_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// Excepción emitida cuando el backend detecta un posible gasto duplicado (HTTP 409 Conflict - RN-03).
///
/// Contiene la lista de transacciones preexistentes dentro de ±24h con mismo monto y comercio.
/// El usuario puede decidir forzar el registro enviando `force: true`.
class DuplicateTransactionException implements Exception {
  const DuplicateTransactionException({
    required this.message,
    this.existingTransactions = const [],
    this.originalException,
  });

  final String message;
  final List<DuplicateTransactionItem> existingTransactions;
  final ApiException? originalException;

  @override
  String toString() => message;
}

/// Servicio API REST para operaciones de transacciones quincenales y comprobantes OCR (RF-03/05, RF-04/06).
class TransactionApiService {
  TransactionApiService(this._client);

  final ApiClient _client;

  /// Obtiene el listado cronológico de transacciones registradas para el ciclo quincenal indicado.
  Future<List<Transaction>> getTransactions({required String cycleId}) async {
    final response = await _client.get('/transactions?cycleId=$cycleId');
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map((item) => Transaction.fromJson(item))
          .toList();
    } else if (response is Map<String, dynamic> &&
        response['transactions'] is List) {
      final list = response['transactions'] as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((item) => Transaction.fromJson(item))
          .toList();
    }
    return [];
  }

  /// Registra una nueva transacción manual u OCR (POST /transactions).
  ///
  /// - Si [force] es false (predeterminado), el backend valida posibles duplicados (RN-03).
  ///   En caso de coincidencia en comercio, monto y fecha ±24h, lanza [DuplicateTransactionException].
  /// - Si [force] es true, envía el parámetro `?force=true` para forzar la inserción sin advertencia.
  Future<Transaction> createTransaction(
    CreateTransactionDto dto, {
    bool force = false,
  }) async {
    final endpoint = force ? '/transactions?force=true' : '/transactions';
    try {
      final response = await _client.post(endpoint, body: dto.toJson());
      if (response is Map<String, dynamic>) {
        return Transaction.fromJson(response);
      }
      throw ApiException(
        statusCode: 500,
        message: 'Respuesta inválida del servidor al crear la transacción.',
      );
    } on ApiException catch (e) {
      if (e.isConflict) {
        // Intercepta 409 Conflict con duplicate_warning (RN-03)
        List<DuplicateTransactionItem> duplicates = [];
        dynamic rawDetails;
        try {
          rawDetails = (e as dynamic).details ?? (e as dynamic).data ?? e.error;
        } catch (_) {
          rawDetails = e.error;
        }

        if (rawDetails is Map<String, dynamic>) {
          final existing =
              rawDetails['existing_transactions'] as List<dynamic>?;
          if (existing != null) {
            duplicates = existing
                .whereType<Map<String, dynamic>>()
                .map((m) => DuplicateTransactionItem.fromJson(m))
                .toList();
          }
        }

        throw DuplicateTransactionException(
          message: e.message,
          existingTransactions: duplicates,
          originalException: e,
        );
      }
      rethrow;
    }
  }

  /// Elimina una transacción por su ID (DELETE /transactions/:id).
  /// El backend recalcula dinámicamente los saldos gastados del ciclo activo.
  Future<void> deleteTransaction(String id) async {
    await _client.delete('/transactions/$id');
  }

  /// Sube un comprobante fotográfico o documento PDF para procesamiento OCR (POST /receipt-scans/upload).
  /// Retorna el registro [ReceiptScan] con estado inicial 'pending'.
  Future<ReceiptScan> uploadReceiptScan(File file) async {
    final dynamic response = await _client.uploadMultipart(
      '/receipt-scans/upload',
      file: file,
      fieldName: 'file',
    );

    // Extrae la carga útil si ApiClient devuelve ApiResponse<T> o Map directo
    dynamic payload;
    if (response is Map<String, dynamic>) {
      payload = response;
    } else {
      try {
        payload = (response as dynamic).data ?? (response as dynamic).rawBody;
      } catch (_) {
        payload = response;
      }
    }

    if (payload is Map<String, dynamic>) {
      if (payload['scan'] is Map<String, dynamic>) {
        return ReceiptScan.fromJson(payload['scan'] as Map<String, dynamic>);
      }
      return ReceiptScan.fromJson(payload);
    }

    if (payload is ReceiptScan) {
      return payload;
    }

    throw ApiException(
      statusCode: 500,
      message: 'Respuesta inesperada del servidor al subir el comprobante.',
    );
  }

  /// Confirma los datos validados del comprobante OCR y crea la transacción correspondiente (CA-03.2).
  Future<Transaction> confirmReceiptScan(
    String scanId,
    ConfirmReceiptScanDto dto,
  ) async {
    final response = await _client.post(
      '/receipt-scans/$scanId/confirm',
      body: dto.toJson(),
    );

    if (response is Map<String, dynamic>) {
      if (response['transaction'] is Map<String, dynamic>) {
        return Transaction.fromJson(
            response['transaction'] as Map<String, dynamic>);
      }
      return Transaction.fromJson(response);
    }

    throw ApiException(
      statusCode: 500,
      message: 'Respuesta inesperada del servidor al confirmar el comprobante.',
    );
  }

  /// Obtiene los detalles y estado actual de extracción de un comprobante OCR (GET /receipt-scans/:id).
  Future<ReceiptScan> getReceiptScan(String scanId) async {
    final response = await _client.get('/receipt-scans/$scanId');
    if (response is Map<String, dynamic>) {
      return ReceiptScan.fromJson(response);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Respuesta inesperada al obtener comprobante.',
    );
  }
}
