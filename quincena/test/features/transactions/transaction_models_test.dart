import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

/// Fake HTTP Client para simular endpoints de transacciones y OCR
class FakeTransactionHttpClient extends http.BaseClient {
  FakeTransactionHttpClient({this.customHandler});

  final Future<http.Response> Function(http.BaseRequest request)? customHandler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (customHandler != null) {
      final res = await customHandler!(request);
      return http.StreamedResponse(
        Stream.value(res.bodyBytes),
        res.statusCode,
        headers: res.headers,
      );
    }

    final path = request.url.path;
    final query = request.url.query;

    String body = '{}';
    int status = 200;

    if (request.method == 'GET' && path.endsWith('/transactions')) {
      body = jsonEncode([
        {
          'id': 'tx-1',
          'user_id': 'user-123',
          'cycle_id': 'cycle-456',
          'allocation_id': 'alloc-789',
          'receipt_scan_id': null,
          'source_account_id': 'acc-1',
          'amount': 150.75,
          'merchant_name': 'Supermercado La Torre',
          'transaction_date': '2026-10-18',
          'transaction_type': 'expense',
          'entry_method': 'manual',
          'notes': 'Compras de la semana',
          'created_at': '2026-10-18T14:30:00Z',
          'budget_allocations': {
            'id': 'alloc-789',
            'categories': {
              'id': 'cat-1',
              'name': 'Alimentación',
              'icon': 'shopping_cart',
              'color_hex': '#79ADDC',
            },
          },
          'source_account': {
            'id': 'acc-1',
            'name': 'Monetaria BAC',
            'color_hex': '#FFEE93',
          },
        },
      ]);
    } else if (request.method == 'POST' && path.endsWith('/transactions')) {
      if (query.contains('force=true')) {
        body = jsonEncode({
          'id': 'tx-forced-1',
          'user_id': 'user-123',
          'cycle_id': 'cycle-456',
          'source_account_id': 'acc-1',
          'amount': 200.0,
          'merchant_name': 'Gasolinera Shell',
          'transaction_date': '2026-10-18',
          'transaction_type': 'expense',
          'entry_method': 'manual',
        });
      } else {
        // Simular respuesta exitosa normal
        body = jsonEncode({
          'id': 'tx-created-1',
          'user_id': 'user-123',
          'cycle_id': 'cycle-456',
          'source_account_id': 'acc-1',
          'amount': 95.0,
          'merchant_name': 'Farmacia Galeno',
          'transaction_date': '2026-10-18',
          'transaction_type': 'expense',
          'entry_method': 'manual',
        });
      }
    } else if (request.method == 'DELETE' && path.contains('/transactions/')) {
      body = jsonEncode({'message': 'Transacción eliminada exitosamente'});
    } else if (request.method == 'POST' && path.endsWith('/upload')) {
      body = jsonEncode({
        'scan': {
          'id': 'scan-upload-1',
          'user_id': 'user-123',
          'storage_path': 'user-123/receipt.jpg',
          'ocr_status': 'pending',
        },
        'message': 'Comprobante subido exitosamente.',
      });
      status = 201;
    } else if (request.method == 'POST' && path.endsWith('/confirm')) {
      body = jsonEncode({
        'transaction': {
          'id': 'tx-confirmed-1',
          'user_id': 'user-123',
          'cycle_id': 'cycle-456',
          'receipt_scan_id': 'scan-1',
          'source_account_id': 'acc-1',
          'amount': 350.0,
          'merchant_name': 'Pricesmart',
          'transaction_date': '2026-10-18',
          'transaction_type': 'expense',
          'entry_method': 'ocr',
        },
        'scan_id': 'scan-1',
        'message': 'Gasto registrado exitosamente desde comprobante OCR.',
      });
    } else if (request.method == 'GET' && path.contains('/receipt-scans/')) {
      body = jsonEncode({
        'id': 'scan-1',
        'user_id': 'user-123',
        'storage_path': 'user-123/receipt.jpg',
        'ocr_status': 'processed',
        'extracted_merchant': 'Pricesmart',
        'extracted_amount': 350.0,
        'extracted_date': '2026-10-18',
        'confidence_score': 95.0,
      });
    }

    final headers = {'content-type': 'application/json; charset=utf-8'};
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      status,
      headers: headers,
    );
  }
}

void main() {
  group('Transaction Data Model Tests (RF-04 / RF-06)', () {
    test('Deserializes full Transaction JSON with joined category and account', () {
      final json = {
        'id': 'tx-100',
        'user_id': 'u-1',
        'cycle_id': 'c-1',
        'allocation_id': 'a-1',
        'receipt_scan_id': 'rs-1',
        'source_account_id': 'sa-1',
        'amount': 249.99,
        'merchant_name': 'Walmart Bosques',
        'transaction_date': '2026-10-17',
        'transaction_type': 'expense',
        'entry_method': 'ocr',
        'notes': 'Despensa quincenal',
        'created_at': '2026-10-17T18:00:00Z',
        'updated_at': '2026-10-17T18:05:00Z',
        'budget_allocations': {
          'id': 'a-1',
          'categories': {
            'id': 'cat-1',
            'name': 'Supermercado',
            'icon': 'shopping_basket',
            'color_hex': '#FFEE93',
          },
        },
        'source_account': {
          'id': 'sa-1',
          'name': 'BAC Débito',
          'color_hex': '#79ADDC',
        },
      };

      final tx = Transaction.fromJson(json);

      expect(tx.id, 'tx-100');
      expect(tx.userId, 'u-1');
      expect(tx.cycleId, 'c-1');
      expect(tx.allocationId, 'a-1');
      expect(tx.receiptScanId, 'rs-1');
      expect(tx.sourceAccountId, 'sa-1');
      expect(tx.amount, 249.99);
      expect(tx.merchantName, 'Walmart Bosques');
      expect(tx.transactionDate.year, 2026);
      expect(tx.transactionDate.month, 10);
      expect(tx.transactionDate.day, 17);
      expect(tx.transactionType, TransactionType.expense);
      expect(tx.entryMethod, EntryMethod.ocr);
      expect(tx.notes, 'Despensa quincenal');
      expect(tx.isOcr, isTrue);
      expect(tx.isManual, isFalse);
      expect(tx.isExpense, isTrue);

      // Category and account convenience getters
      expect(tx.categoryName, 'Supermercado');
      expect(tx.categoryIcon, 'shopping_basket');
      expect(tx.categoryColorHex, '#FFEE93');
      expect(tx.sourceAccountName, 'BAC Débito');
      expect(tx.sourceAccountColorHex, '#79ADDC');
      expect(tx.formattedSignedAmount, '-\$249.99');
    });

    test('Handles null and missing optional fields with sensible defaults', () {
      final json = {
        'id': 'tx-minimal',
        'user_id': 'u-1',
        'cycle_id': 'c-1',
        'source_account_id': 'sa-1',
        'amount': 50.0,
        'merchant_name': 'Café Barista',
        'transaction_date': '2026-10-17',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.allocationId, isNull);
      expect(tx.receiptScanId, isNull);
      expect(tx.notes, isNull);
      expect(tx.category, isNull);
      expect(tx.sourceAccount, isNull);
      expect(tx.categoryName, 'Sin categoría');
      expect(tx.sourceAccountName, 'Cuenta origen');
      expect(tx.transactionType, TransactionType.expense);
      expect(tx.entryMethod, EntryMethod.manual);
      expect(tx.isManual, isTrue);
    });

    test('Serializes to JSON with snake_case keys for API compatibility', () {
      final tx = Transaction(
        id: 'tx-json',
        userId: 'u-1',
        cycleId: 'c-1',
        sourceAccountId: 'sa-1',
        amount: 80.5,
        merchantName: 'Uber',
        transactionDate: DateTime(2026, 10, 16),
        entryMethod: EntryMethod.manual,
        transactionType: TransactionType.expense,
        notes: 'Viaje a oficina',
      );

      final serialized = tx.toJson();

      expect(serialized['id'], 'tx-json');
      expect(serialized['cycle_id'], 'c-1');
      expect(serialized['source_account_id'], 'sa-1');
      expect(serialized['amount'], 80.5);
      expect(serialized['merchant_name'], 'Uber');
      expect(serialized['transaction_date'], '2026-10-16');
      expect(serialized['transaction_type'], 'expense');
      expect(serialized['entry_method'], 'manual');
      expect(serialized['notes'], 'Viaje a oficina');
    });

    test('copyWith produces updated instance preserving immutable fields', () {
      final tx = Transaction(
        id: 'tx-orig',
        userId: 'u-1',
        cycleId: 'c-1',
        sourceAccountId: 'sa-1',
        amount: 100.0,
        merchantName: 'Puma Gas',
        transactionDate: DateTime(2026, 10, 15),
      );

      final updated = tx.copyWith(
        amount: 120.0,
        merchantName: 'Shell Gas',
        notes: 'Actualizado',
      );

      expect(updated.id, 'tx-orig');
      expect(updated.amount, 120.0);
      expect(updated.merchantName, 'Shell Gas');
      expect(updated.notes, 'Actualizado');
      expect(updated.sourceAccountId, 'sa-1');
    });
  });

  group('ReceiptScan Data Model Tests (RF-03 / RF-05)', () {
    test('Deserializes high-confidence ReceiptScan JSON accurately', () {
      final json = {
        'id': 'scan-100',
        'user_id': 'u-1',
        'storage_path': 'u-1/receipts/12345.jpg',
        'ocr_status': 'processed',
        'extracted_merchant': 'Paiz Roosevelt',
        'extracted_amount': 430.75,
        'extracted_date': '2026-10-17',
        'tax_id_or_auth_number': 'AUTH-998877',
        'suggested_account_id': 'sa-1',
        'confidence_score': 98.0,
        'created_at': '2026-10-17T12:00:00Z',
      };

      final scan = ReceiptScan.fromJson(json);

      expect(scan.id, 'scan-100');
      expect(scan.ocrStatus, OcrStatus.processed);
      expect(scan.extractedMerchant, 'Paiz Roosevelt');
      expect(scan.extractedAmount, 430.75);
      expect(scan.taxIdOrAuthNumber, 'AUTH-998877');
      expect(scan.confidenceScore, 98.0);
      expect(scan.hasHighConfidence, isTrue);
      expect(scan.isReadyForConfirmation, isTrue);
      expect(scan.formattedConfidence, '98%');
    });

    test('Handles low confidence and failed status correctly', () {
      final json = {
        'id': 'scan-fail',
        'user_id': 'u-1',
        'storage_path': 'u-1/blurry.jpg',
        'ocr_status': 'failed',
        'confidence_score': 35.0,
      };

      final scan = ReceiptScan.fromJson(json);

      expect(scan.ocrStatus, OcrStatus.failed);
      expect(scan.isFailed, isTrue);
      expect(scan.hasHighConfidence, isFalse);
      expect(scan.isReadyForConfirmation, isFalse);
    });

    test('Serializes ReceiptScan to JSON with proper enum mapping', () {
      final scan = ReceiptScan(
        id: 'scan-verify',
        userId: 'u-1',
        storagePath: 'u-1/ticket.png',
        ocrStatus: OcrStatus.verified,
        extractedMerchant: 'La Torre',
        extractedAmount: 110.0,
      );

      final json = scan.toJson();

      expect(json['id'], 'scan-verify');
      expect(json['ocr_status'], 'verified');
      expect(json['extracted_merchant'], 'La Torre');
      expect(json['extracted_amount'], 110.0);
    });
  });

  group('DTO Serialization Tests', () {
    test('CreateTransactionDto formats fields for POST /transactions', () {
      final dto = CreateTransactionDto.manual(
        cycleId: 'cycle-1',
        sourceAccountId: 'acc-1',
        amount: 88.5,
        merchantName: 'San Martín',
        transactionDate: '2026-10-18',
        allocationId: 'alloc-1',
        notes: 'Desayuno de trabajo',
      );

      final json = dto.toJson();

      expect(json['cycle_id'], 'cycle-1');
      expect(json['source_account_id'], 'acc-1');
      expect(json['amount'], 88.5);
      expect(json['merchant_name'], 'San Martín');
      expect(json['transaction_date'], '2026-10-18');
      expect(json['allocation_id'], 'alloc-1');
      expect(json['entry_method'], 'manual');
      expect(json['transaction_type'], 'expense');
      expect(json['notes'], 'Desayuno de trabajo');
    });

    test('ConfirmReceiptScanDto formats fields for POST /receipt-scans/:id/confirm', () {
      final dto = ConfirmReceiptScanDto(
        cycleId: 'cycle-1',
        sourceAccountId: 'acc-1',
        allocationId: 'alloc-1',
        merchantName: 'Walmart Editado',
        amount: 299.0,
        transactionDate: '2026-10-18',
        notes: 'Verificado por usuario',
      );

      final json = dto.toJson();

      expect(json['cycle_id'], 'cycle-1');
      expect(json['source_account_id'], 'acc-1');
      expect(json['merchant_name'], 'Walmart Editado');
      expect(json['amount'], 299.0);
      expect(json['transaction_date'], '2026-10-18');
      expect(json['notes'], 'Verificado por usuario');
    });
  });

  group('TransactionApiService Tests with Mocked HTTP Client', () {
    late ApiClient apiClient;
    late TransactionApiService service;

    setUp(() {
      final fakeHttp = FakeTransactionHttpClient();
      apiClient = ApiClient(
        baseUrl: 'http://localhost:3000/v1',
        httpClient: fakeHttp,
      );
      service = TransactionApiService(apiClient);
    });

    test('getTransactions fetches and parses transaction list', () async {
      final list = await service.getTransactions(cycleId: 'cycle-456');

      expect(list, isNotEmpty);
      expect(list.first.merchantName, 'Supermercado La Torre');
      expect(list.first.amount, 150.75);
      expect(list.first.categoryName, 'Alimentación');
      expect(list.first.sourceAccountName, 'Monetaria BAC');
    });

    test('createTransaction creates manual transaction successfully', () async {
      final dto = CreateTransactionDto.manual(
        cycleId: 'cycle-456',
        sourceAccountId: 'acc-1',
        amount: 95.0,
        merchantName: 'Farmacia Galeno',
        transactionDate: '2026-10-18',
      );

      final tx = await service.createTransaction(dto);

      expect(tx.id, 'tx-created-1');
      expect(tx.amount, 95.0);
      expect(tx.merchantName, 'Farmacia Galeno');
    });

    test('createTransaction with force=true appends query parameter', () async {
      final dto = CreateTransactionDto.manual(
        cycleId: 'cycle-456',
        sourceAccountId: 'acc-1',
        amount: 200.0,
        merchantName: 'Gasolinera Shell',
        transactionDate: '2026-10-18',
      );

      final tx = await service.createTransaction(dto, force: true);

      expect(tx.id, 'tx-forced-1');
      expect(tx.amount, 200.0);
    });

    test('createTransaction intercepts 409 Conflict and throws DuplicateTransactionException (RN-03)', () async {
      final conflictHttp = FakeTransactionHttpClient(
        customHandler: (request) async {
          final errorBody = jsonEncode({
            'statusCode': 409,
            'message':
                'Parece que este gasto ya fue registrado. ¿Deseas continuar de todas formas? (RN-03)',
            'duplicate_warning': true,
            'existing_transactions': [
              {
                'id': 'dup-1',
                'merchant_name': 'Walmart',
                'amount': 150.0,
                'transaction_date': '2026-10-18',
                'created_at': '2026-10-18T10:00:00Z',
              }
            ],
          });
          return http.Response(
            errorBody,
            409,
            headers: {'content-type': 'application/json'},
          );
        },
      );

      final conflictApiClient = ApiClient(
        baseUrl: 'http://localhost:3000/v1',
        httpClient: conflictHttp,
      );
      final conflictService = TransactionApiService(conflictApiClient);

      final dto = CreateTransactionDto.manual(
        cycleId: 'cycle-456',
        sourceAccountId: 'acc-1',
        amount: 150.0,
        merchantName: 'Walmart',
        transactionDate: '2026-10-18',
      );

      expect(
        () async => await conflictService.createTransaction(dto),
        throwsA(isA<DuplicateTransactionException>()),
      );
    });

    test('deleteTransaction calls DELETE endpoint without error', () async {
      await expectLater(
        service.deleteTransaction('tx-delete-1'),
        completes,
      );
    });

    test('confirmReceiptScan submits verification and returns confirmed transaction', () async {
      final dto = ConfirmReceiptScanDto(
        cycleId: 'cycle-456',
        sourceAccountId: 'acc-1',
        merchantName: 'Pricesmart',
        amount: 350.0,
      );

      final tx = await service.confirmReceiptScan('scan-1', dto);

      expect(tx.id, 'tx-confirmed-1');
      expect(tx.merchantName, 'Pricesmart');
      expect(tx.amount, 350.0);
      expect(tx.entryMethod, EntryMethod.ocr);
    });

    test('getReceiptScan retrieves extracted scan record', () async {
      final scan = await service.getReceiptScan('scan-1');

      expect(scan.id, 'scan-1');
      expect(scan.ocrStatus, OcrStatus.processed);
      expect(scan.extractedMerchant, 'Pricesmart');
      expect(scan.extractedAmount, 350.0);
      expect(scan.hasHighConfidence, isTrue);
    });

    test('uploadReceiptScan uploads file and returns pending scan record', () async {
      final tempDir = await Directory.systemTemp.createTemp('quincena_service_test_');
      final dummyFile = File('${tempDir.path}/recibo.jpg');
      await dummyFile.writeAsBytes(utf8.encode('TEST_BYTES'));

      try {
        final scan = await service.uploadReceiptScan(dummyFile);
        expect(scan.id, 'scan-upload-1');
        expect(scan.ocrStatus, OcrStatus.pending);
        expect(scan.storagePath, 'user-123/receipt.jpg');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
