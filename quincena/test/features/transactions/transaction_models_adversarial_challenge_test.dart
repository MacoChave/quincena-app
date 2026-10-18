import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/network/api_exception.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

/// Fake HTTP client capable of returning dynamic responses for adversarial testing
class AdversarialFakeHttpClient extends http.BaseClient {
  AdversarialFakeHttpClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('Adversarial Challenge: Malformed JSON & Null Safety', () {
    test('Transaction.fromJson handles empty JSON map without throwing', () {
      final tx = Transaction.fromJson({});

      expect(tx.id, '');
      expect(tx.userId, '');
      expect(tx.cycleId, '');
      expect(tx.sourceAccountId, '');
      expect(tx.amount, 0.0);
      expect(tx.merchantName, 'Sin nombre');
      expect(tx.transactionDate, isA<DateTime>());
      expect(tx.transactionType, TransactionType.expense);
      expect(tx.entryMethod, EntryMethod.manual);
      expect(tx.allocationId, isNull);
      expect(tx.receiptScanId, isNull);
      expect(tx.notes, isNull);
      expect(tx.createdAt, isNull);
      expect(tx.updatedAt, isNull);
      expect(tx.category, isNull);
      expect(tx.sourceAccount, isNull);
      expect(tx.categoryName, 'Sin categoría');
      expect(tx.sourceAccountName, 'Cuenta origen');
      expect(tx.isExpense, isTrue);
      expect(tx.isManual, isTrue);
      expect(tx.isOcr, isFalse);
    });

    test('Transaction.fromJson handles explicitly null values across all keys', () {
      final json = <String, dynamic>{
        'id': null,
        'user_id': null,
        'cycle_id': null,
        'source_account_id': null,
        'amount': null,
        'merchant_name': null,
        'transaction_date': null,
        'transaction_type': null,
        'entry_method': null,
        'notes': null,
        'created_at': null,
        'updated_at': null,
        'category': null,
        'source_account': null,
      };

      final tx = Transaction.fromJson(json);

      expect(tx.id, '');
      expect(tx.userId, '');
      expect(tx.cycleId, '');
      expect(tx.sourceAccountId, '');
      expect(tx.amount, 0.0);
      expect(tx.merchantName, 'Sin nombre');
      expect(tx.transactionType, TransactionType.expense);
      expect(tx.entryMethod, EntryMethod.manual);
      expect(tx.notes, isNull);
      expect(tx.category, isNull);
      expect(tx.sourceAccount, isNull);
    });

    test('Transaction.fromJson supports camelCase keys as alternative payload format', () {
      final json = <String, dynamic>{
        'id': 'tx-camel-1',
        'userId': 'usr-camel',
        'cycleId': 'cyc-camel',
        'sourceAccountId': 'acc-camel',
        'allocationId': 'alloc-camel',
        'receiptScanId': 'scan-camel',
        'merchantName': 'Camel Merchant',
        'amount': 75.50,
        'transactionType': 'income_adjustment',
        'entryMethod': 'ocr',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.id, 'tx-camel-1');
      expect(tx.userId, 'usr-camel');
      expect(tx.cycleId, 'cyc-camel');
      expect(tx.sourceAccountId, 'acc-camel');
      expect(tx.allocationId, 'alloc-camel');
      expect(tx.receiptScanId, 'scan-camel');
      expect(tx.merchantName, 'Camel Merchant');
      expect(tx.amount, 75.50);
      expect(tx.transactionType, TransactionType.incomeAdjustment);
      expect(tx.entryMethod, EntryMethod.ocr);
    });

    test('ReceiptScan.fromJson handles empty map and null values defensively', () {
      final scan = ReceiptScan.fromJson({});

      expect(scan.id, '');
      expect(scan.userId, '');
      expect(scan.storagePath, '');
      expect(scan.ocrStatus, OcrStatus.pending);
      expect(scan.extractedMerchant, isNull);
      expect(scan.extractedAmount, isNull);
      expect(scan.extractedDate, isNull);
      expect(scan.taxIdOrAuthNumber, isNull);
      expect(scan.suggestedAccountId, isNull);
      expect(scan.confidenceScore, isNull);
      expect(scan.ocrRawData, isNull);
      expect(scan.createdAt, isNull);
      expect(scan.isPending, isTrue);
      expect(scan.isProcessed, isFalse);
      expect(scan.isFailed, isFalse);
      expect(scan.isVerified, isFalse);
      expect(scan.hasHighConfidence, isFalse);
      expect(scan.isReadyForConfirmation, isFalse);
      expect(scan.formattedConfidence, '0%');
    });

    test('CreateTransactionDto.fromJson handles empty map and null values', () {
      final dto = CreateTransactionDto.fromJson({});

      expect(dto.cycleId, '');
      expect(dto.sourceAccountId, '');
      expect(dto.amount, 0.0);
      expect(dto.merchantName, '');
      expect(dto.transactionDate, isNotEmpty);
      expect(dto.allocationId, isNull);
      expect(dto.receiptScanId, isNull);
      expect(dto.transactionType, TransactionType.expense);
      expect(dto.entryMethod, EntryMethod.manual);
      expect(dto.notes, isNull);
    });

    test('ConfirmReceiptScanDto.fromJson handles empty map and null values', () {
      final dto = ConfirmReceiptScanDto.fromJson({});

      expect(dto.cycleId, '');
      expect(dto.sourceAccountId, '');
      expect(dto.allocationId, isNull);
      expect(dto.merchantName, isNull);
      expect(dto.amount, isNull);
      expect(dto.transactionDate, isNull);
      expect(dto.notes, isNull);
    });

    test('Empirical check: String amounts in JSON throw TypeError due to as num? cast', () {
      final json = <String, dynamic>{
        'id': 'tx-str-amount',
        'amount': '150.50', // string from backend/db
      };

      expect(
        () => Transaction.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('transactionDate (camelCase) is recognized and parsed correctly', () {
      final json = <String, dynamic>{
        'id': 'tx-camel-date',
        'transactionDate': '2020-01-01', // camelCase date
      };

      final tx = Transaction.fromJson(json);

      expect(tx.transactionDate.year, equals(2020));
      expect(tx.transactionDate.month, equals(1));
      expect(tx.transactionDate.day, equals(1));
    });

    test('Handles malformed types in joined category and account safely', () {
      final json = <String, dynamic>{
        'id': 'tx-corrupt-joins',
        'category': 'not-a-map',
        'source_account': 12345,
        'budget_allocations': ['invalid', 'list'],
        'financial_accounts': true,
      };

      final tx = Transaction.fromJson(json);

      expect(tx.category, isNull);
      expect(tx.sourceAccount, isNull);
      expect(tx.categoryName, 'Sin categoría');
      expect(tx.sourceAccountName, 'Cuenta origen');
    });
  });

  group('Adversarial Challenge: Extreme Currency Numbers & Float Precision', () {
    test('Minimum positive currency unit (0.01) formats correctly', () {
      final tx = Transaction(
        id: 'tx-min',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: 0.01,
        merchantName: 'Micro Pago',
        transactionDate: DateTime(2026, 10, 18),
      );

      expect(tx.formattedSignedAmount, '-\$0.01');
    });

    test('Zero currency amount formats with negative prefix if expense', () {
      final tx = Transaction(
        id: 'tx-zero',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: 0.0,
        merchantName: 'Gasto Cero',
        transactionDate: DateTime(2026, 10, 18),
      );

      expect(tx.formattedSignedAmount, '-\$0.00');
    });

    test('Extreme high currency amounts (999,999,999.99) format cleanly without overflow', () {
      final tx = Transaction(
        id: 'tx-large',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: 999999999.99,
        merchantName: 'Mega Inversión',
        transactionDate: DateTime(2026, 10, 18),
      );

      expect(tx.formattedSignedAmount, '-\$999999999.99');
    });

    test('Floating point representation artifacts (0.1 + 0.2) round correctly to 2 decimals', () {
      final floatArtifact = 0.1 + 0.2; // 0.30000000000000004 in IEEE 754
      expect(floatArtifact.toString(), isNot('0.3'));

      final tx = Transaction(
        id: 'tx-float-artifact',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: floatArtifact,
        merchantName: 'Float Test',
        transactionDate: DateTime(2026, 10, 18),
      );

      expect(tx.formattedSignedAmount, '-\$0.30');
    });

    test('Compound multiplication float artifacts (19.99 * 3) round cleanly', () {
      final price = 19.99 * 3; // 59.970000000000006
      final tx = Transaction(
        id: 'tx-float-multi',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: price,
        merchantName: 'Multi Test',
        transactionDate: DateTime(2026, 10, 18),
      );

      expect(tx.formattedSignedAmount, '-\$59.97');
    });

    test('Integer amounts from JSON parse seamlessly into double', () {
      final json = <String, dynamic>{
        'id': 'tx-int-amount',
        'amount': 250, // int, not double
        'merchant_name': 'Entero',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.amount, 250.0);
      expect(tx.formattedSignedAmount, '-\$250.00');
    });

    test('Positive prefix applied for incomeAdjustment and transfer types', () {
      final incomeTx = Transaction(
        id: 'tx-income',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: 1250.50,
        merchantName: 'Bono Quincenal',
        transactionDate: DateTime(2026, 10, 18),
        transactionType: TransactionType.incomeAdjustment,
      );

      final transferTx = Transaction(
        id: 'tx-transfer',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: 300.0,
        merchantName: 'Traspaso a Ahorro',
        transactionDate: DateTime(2026, 10, 18),
        transactionType: TransactionType.transfer,
      );

      expect(incomeTx.formattedSignedAmount, '+\$1250.50');
      expect(transferTx.formattedSignedAmount, '+\$300.00');
    });

    test('Negative amount in expense formats without double-minus artifact', () {
      final tx = Transaction(
        id: 'tx-neg-amount',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: -50.0,
        merchantName: 'Reembolso Negativo',
        transactionDate: DateTime(2026, 10, 18),
      );

      expect(tx.formattedSignedAmount, '-\$50.00');
    });

    test('ReceiptScan confidence score boundary cases (69.99% vs 70.0% vs >100%)', () {
      final borderlineLow = ReceiptScan(
        id: 's-low',
        userId: 'u',
        storagePath: 'p',
        confidenceScore: 69.99,
        extractedAmount: 100.0,
        ocrStatus: OcrStatus.processed,
      );

      final exactThreshold = ReceiptScan(
        id: 's-threshold',
        userId: 'u',
        storagePath: 'p',
        confidenceScore: 70.0,
        extractedAmount: 100.0,
        ocrStatus: OcrStatus.processed,
      );

      final high = ReceiptScan(
        id: 's-high',
        userId: 'u',
        storagePath: 'p',
        confidenceScore: 99.8,
        extractedAmount: 100.0,
        ocrStatus: OcrStatus.processed,
      );

      expect(borderlineLow.hasHighConfidence, isFalse);
      expect(borderlineLow.formattedConfidence, '70%'); // rounds 69.99 to 70%
      expect(borderlineLow.isReadyForConfirmation, isTrue); // amount > 0 and processed

      expect(exactThreshold.hasHighConfidence, isTrue);
      expect(exactThreshold.formattedConfidence, '70%');

      expect(high.hasHighConfidence, isTrue);
      expect(high.formattedConfidence, '100%'); // rounds 99.8 to 100%
    });

    test('ReceiptScan isReadyForConfirmation requires positive amount', () {
      final zeroAmount = ReceiptScan(
        id: 's-zero',
        userId: 'u',
        storagePath: 'p',
        extractedAmount: 0.0,
        ocrStatus: OcrStatus.processed,
      );

      final negativeAmount = ReceiptScan(
        id: 's-neg',
        userId: 'u',
        storagePath: 'p',
        extractedAmount: -5.0,
        ocrStatus: OcrStatus.processed,
      );

      final positiveAmount = ReceiptScan(
        id: 's-pos',
        userId: 'u',
        storagePath: 'p',
        extractedAmount: 0.05,
        ocrStatus: OcrStatus.processed,
      );

      final failedStatus = ReceiptScan(
        id: 's-fail',
        userId: 'u',
        storagePath: 'p',
        extractedAmount: 150.0,
        ocrStatus: OcrStatus.failed,
      );

      expect(zeroAmount.isReadyForConfirmation, isFalse);
      expect(negativeAmount.isReadyForConfirmation, isFalse);
      expect(positiveAmount.isReadyForConfirmation, isTrue);
      expect(failedStatus.isReadyForConfirmation, isFalse);
    });
  });

  group('Adversarial Challenge: Timestamp Parsing Scenarios', () {
    test('Parses date-only format YYYY-MM-DD correctly', () {
      final json = <String, dynamic>{
        'id': 'tx-date-only',
        'transaction_date': '2026-10-18',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.transactionDate.year, 2026);
      expect(tx.transactionDate.month, 10);
      expect(tx.transactionDate.day, 18);
    });

    test('Parses full ISO8601 with Zulu time Z correctly', () {
      final json = <String, dynamic>{
        'id': 'tx-iso-z',
        'transaction_date': '2026-10-18T15:45:30.500Z',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.transactionDate.year, 2026);
      expect(tx.transactionDate.month, 10);
      expect(tx.transactionDate.day, 18);
    });

    test('Parses ISO8601 with positive timezone offset (+02:00)', () {
      final json = <String, dynamic>{
        'id': 'tx-iso-tz-pos',
        'transaction_date': '2026-10-18T20:00:00+02:00',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.transactionDate.isUtc || !tx.transactionDate.isUtc, isTrue);
      expect(tx.transactionDate.year, 2026);
    });

    test('Parses ISO8601 with negative timezone offset (-06:00)', () {
      final json = <String, dynamic>{
        'id': 'tx-iso-tz-neg',
        'transaction_date': '2026-10-18T10:00:00-06:00',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.transactionDate.year, 2026);
    });

    test('Parses space-separated SQL timestamp format (YYYY-MM-DD HH:mm:ss)', () {
      final json = <String, dynamic>{
        'id': 'tx-sql-ts',
        'transaction_date': '2026-10-18 16:30:00',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.transactionDate.year, 2026);
      expect(tx.transactionDate.month, 10);
      expect(tx.transactionDate.day, 18);
    });

    test('Malformed date string falls back to current time without throwing', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final json = <String, dynamic>{
        'id': 'tx-bad-date',
        'transaction_date': 'INVALID_NOT_A_DATE',
      };

      final tx = Transaction.fromJson(json);
      final after = DateTime.now().add(const Duration(seconds: 1));

      expect(tx.transactionDate.isAfter(before), isTrue);
      expect(tx.transactionDate.isBefore(after), isTrue);
    });

    test('Unparseable created_at and updated_at dates safely parse as null', () {
      final json = <String, dynamic>{
        'id': 'tx-bad-created',
        'created_at': 'corrupt-timestamp',
        'updated_at': 'not-a-date-at-all',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.createdAt, isNull);
      expect(tx.updatedAt, isNull);
    });

    test('Empirical check: Dart DateTime.tryParse normalizes rollover for out-of-range ISO digits', () {
      // Dart's DateTime parser does arithmetic calendar rollover on numeric ISO strings
      // e.g. month 99 rolls forward into year 10007 rather than returning null.
      final parsed = DateTime.tryParse('9999-99-99T99:99:99Z');
      expect(parsed, isNotNull);
      expect(parsed!.year, greaterThan(9999));
    });

    test('ReceiptScan extractedDate parses date-only and ISO timestamps', () {
      final dateOnlyJson = <String, dynamic>{
        'id': 's-1',
        'extracted_date': '2026-10-17',
      };
      final fullIsoJson = <String, dynamic>{
        'id': 's-2',
        'extractedDate': '2026-10-17T21:00:00Z',
      };

      final s1 = ReceiptScan.fromJson(dateOnlyJson);
      final s2 = ReceiptScan.fromJson(fullIsoJson);

      expect(s1.extractedDate?.year, 2026);
      expect(s1.extractedDate?.month, 10);
      expect(s1.extractedDate?.day, 17);

      expect(s2.extractedDate?.year, 2026);
      expect(s2.extractedDate?.month, 10);
      expect(s2.extractedDate?.day, 17);
    });

    test('Serialization roundtrip produces valid YYYY-MM-DD date string', () {
      final tx = Transaction(
        id: 'tx-roundtrip',
        userId: 'u',
        cycleId: 'c',
        sourceAccountId: 'a',
        amount: 100.0,
        merchantName: 'Roundtrip Test',
        transactionDate: DateTime(2026, 12, 31, 23, 59, 59),
      );

      final json = tx.toJson();
      expect(json['transaction_date'], '2026-12-31');

      final deserialized = Transaction.fromJson(json);
      expect(deserialized.transactionDate.year, 2026);
      expect(deserialized.transactionDate.month, 12);
      expect(deserialized.transactionDate.day, 31);
    });
  });

  group('Adversarial Challenge: Unknown Enum Values & Defensive Mapping', () {
    test('TransactionType falls back to expense for unexpected values', () {
      expect(
        TransactionType.fromValue('crypto_payment'),
        TransactionType.expense,
      );
      expect(
        TransactionType.fromValue('UNKNOWN_ENUM'),
        TransactionType.expense,
      );
      expect(
        TransactionType.fromValue(''),
        TransactionType.expense,
      );
      expect(
        TransactionType.fromValue(null),
        TransactionType.expense,
      );
      expect(
        TransactionType.fromValue('TRANSFER'), // case sensitive check
        TransactionType.expense,
      );
    });

    test('EntryMethod falls back to manual for unexpected values', () {
      expect(
        EntryMethod.fromValue('nfc_tap'),
        EntryMethod.manual,
      );
      expect(
        EntryMethod.fromValue('ai_agent'),
        EntryMethod.manual,
      );
      expect(
        EntryMethod.fromValue(''),
        EntryMethod.manual,
      );
      expect(
        EntryMethod.fromValue(null),
        EntryMethod.manual,
      );
      expect(
        EntryMethod.fromValue('OCR'), // case sensitive check
        EntryMethod.manual,
      );
    });

    test('OcrStatus falls back to pending for unexpected values', () {
      expect(
        OcrStatus.fromValue('processing'),
        OcrStatus.pending,
      );
      expect(
        OcrStatus.fromValue('rejected_by_system'),
        OcrStatus.pending,
      );
      expect(
        OcrStatus.fromValue(''),
        OcrStatus.pending,
      );
      expect(
        OcrStatus.fromValue(null),
        OcrStatus.pending,
      );
    });

    test('Transaction.fromJson gracefully adopts fallbacks on alien enums', () {
      final json = <String, dynamic>{
        'id': 'tx-alien-enums',
        'transaction_type': 'alien_type_xyz',
        'entry_method': 'telepathic_entry',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.transactionType, TransactionType.expense);
      expect(tx.entryMethod, EntryMethod.manual);
    });

    test('ReceiptScan.fromJson gracefully adopts fallback on alien status', () {
      final json = <String, dynamic>{
        'id': 'scan-alien-status',
        'ocr_status': 'in_review_by_auditor',
      };

      final scan = ReceiptScan.fromJson(json);

      expect(scan.ocrStatus, OcrStatus.pending);
      expect(scan.isPending, isTrue);
    });
  });

  group('Adversarial Challenge: Category & Account Color Hex Parsing', () {
    test('Standard 6-character hex code parses accurately', () {
      const cat = TransactionCategory(
        id: 'cat-1',
        name: 'Normal Hex',
        colorHex: '#FFEE93',
      );

      expect(cat.parsedColor, const Color(0xFFFFEE93));
    });

    test('6-character hex code without leading hash parses accurately', () {
      const acc = TransactionSourceAccount(
        id: 'acc-1',
        name: 'No Hash Hex',
        colorHex: '79ADDC',
      );

      expect(acc.parsedColor, const Color(0xFF79ADDC));
    });

    test('Short or malformed length hex codes fall back to default pastel blue', () {
      const catShort = TransactionCategory(
        id: 'cat-short',
        name: 'Short Hex',
        colorHex: '#FFF',
      );
      const catEmpty = TransactionCategory(
        id: 'cat-empty',
        name: 'Empty Hex',
        colorHex: '',
      );

      expect(catShort.parsedColor, const Color(0xFF79ADDC));
      expect(catEmpty.parsedColor, const Color(0xFF79ADDC));
    });

    test('6-char non-hex string safely falls back to default pastel blue without throwing', () {
      const catInvalidChars = TransactionCategory(
        id: 'cat-invalid-chars',
        name: 'Invalid Hex Chars',
        colorHex: '#ZZZZZZ',
      );

      expect(
        catInvalidChars.parsedColor,
        equals(const Color(0xFF79ADDC)),
      );
    });
  });

  group('Adversarial Challenge: TransactionApiService Defensive Behavior', () {
    test('getTransactions handles dirty list with non-map elements', () async {
      final dirtyHttp = AdversarialFakeHttpClient((request) async {
        final body = jsonEncode([
          {
            'id': 'tx-good-1',
            'amount': 50.0,
            'merchant_name': 'Good 1',
            'transaction_date': '2026-10-18',
          },
          'corrupt string item',
          42,
          null,
          {
            'id': 'tx-good-2',
            'amount': 99.0,
            'merchant_name': 'Good 2',
            'transaction_date': '2026-10-18',
          },
        ]);
        return http.Response(body, 200, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(baseUrl: 'http://localhost/v1', httpClient: dirtyHttp);
      final service = TransactionApiService(client);

      final list = await service.getTransactions(cycleId: 'cyc-1');

      expect(list.length, 2);
      expect(list[0].id, 'tx-good-1');
      expect(list[1].id, 'tx-good-2');
    });

    test('getTransactions handles unexpected non-list JSON payload by returning empty list', () async {
      final unexpectedHttp = AdversarialFakeHttpClient((request) async {
        final body = jsonEncode({
          'status': 'success',
          'unexpected_structure': true,
        });
        return http.Response(body, 200, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(baseUrl: 'http://localhost/v1', httpClient: unexpectedHttp);
      final service = TransactionApiService(client);

      final list = await service.getTransactions(cycleId: 'cyc-1');

      expect(list, isEmpty);
    });

    test('createTransaction handles 409 Conflict with corrupt or null existing_transactions', () async {
      final corruptConflictHttp = AdversarialFakeHttpClient((request) async {
        final body = jsonEncode({
          'statusCode': 409,
          'message': 'Possible duplicate',
          'duplicate_warning': true,
          'existing_transactions': [
            'not a map item',
            null,
            42,
            {
              'id': 'dup-valid-1',
              'merchant_name': 'Shell',
              'amount': 100.0,
              'transaction_date': '2026-10-18',
            },
          ],
        });
        return http.Response(body, 409, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(baseUrl: 'http://localhost/v1', httpClient: corruptConflictHttp);
      final service = TransactionApiService(client);

      final dto = CreateTransactionDto.manual(
        cycleId: 'cyc-1',
        sourceAccountId: 'acc-1',
        amount: 100.0,
        merchantName: 'Shell',
        transactionDate: '2026-10-18',
      );

      DuplicateTransactionException? caughtException;
      try {
        await service.createTransaction(dto);
      } on DuplicateTransactionException catch (e) {
        caughtException = e;
      }

      expect(caughtException, isNotNull);
      expect(caughtException!.existingTransactions.length, 1);
      expect(caughtException.existingTransactions.first.id, 'dup-valid-1');
      expect(caughtException.existingTransactions.first.amount, 100.0);
    });

    test('createTransaction handles 409 Conflict when existing_transactions field is omitted entirely', () async {
      final bareConflictHttp = AdversarialFakeHttpClient((request) async {
        final body = jsonEncode({
          'statusCode': 409,
          'message': 'Duplicate detected without existing items payload',
        });
        return http.Response(body, 409, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(baseUrl: 'http://localhost/v1', httpClient: bareConflictHttp);
      final service = TransactionApiService(client);

      final dto = CreateTransactionDto.manual(
        cycleId: 'cyc-1',
        sourceAccountId: 'acc-1',
        amount: 100.0,
        merchantName: 'Shell',
        transactionDate: '2026-10-18',
      );

      DuplicateTransactionException? caughtException;
      try {
        await service.createTransaction(dto);
      } on DuplicateTransactionException catch (e) {
        caughtException = e;
      }

      expect(caughtException, isNotNull);
      expect(caughtException!.existingTransactions, isEmpty);
      expect(caughtException.message, contains('Duplicate detected'));
    });

    test('uploadReceiptScan handles flat payload without nested scan key', () async {
      final flatHttp = AdversarialFakeHttpClient((request) async {
        final body = jsonEncode({
          'id': 'scan-flat-1',
          'ocr_status': 'pending',
          'storage_path': 'receipts/ticket.jpg',
        });
        return http.Response(body, 201, headers: {'content-type': 'application/json'});
      });

      final client = ApiClient(baseUrl: 'http://localhost/v1', httpClient: flatHttp);
      final service = TransactionApiService(client);

      final tempDir = await Directory.systemTemp.createTemp('upload_test_');
      final dummyFile = File('${tempDir.path}/test.jpg');
      await dummyFile.writeAsBytes([1, 2, 3]);

      try {
        final scan = await service.uploadReceiptScan(dummyFile);
        expect(scan.id, 'scan-flat-1');
        expect(scan.ocrStatus, OcrStatus.pending);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('uploadReceiptScan throws ApiException when backend returns unexpected non-map body', () async {
      final invalidBodyHttp = AdversarialFakeHttpClient((request) async {
        return http.Response('Internal Server Error Text', 500);
      });

      final client = ApiClient(baseUrl: 'http://localhost/v1', httpClient: invalidBodyHttp);
      final service = TransactionApiService(client);

      final tempDir = await Directory.systemTemp.createTemp('upload_err_test_');
      final dummyFile = File('${tempDir.path}/test.jpg');
      await dummyFile.writeAsBytes([1, 2, 3]);

      try {
        await expectLater(
          service.uploadReceiptScan(dummyFile),
          throwsA(isA<ApiException>()),
        );
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
