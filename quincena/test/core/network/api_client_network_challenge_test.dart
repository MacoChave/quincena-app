import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/network/api_exception.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

/// Mock HTTP client that finalizes requests to populate headers and capture serialized bytes
class ChallengeMockHttpClient extends http.BaseClient {
  ChallengeMockHttpClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request, Uint8List bodyBytes) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stream = request.finalize();
    final bodyBytes = await stream.toBytes();
    return handler(request, bodyBytes);
  }
}

void main() {
  group('Adversarial Challenge 1: Multipart Upload Stress & File Path Resilience', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('quincena_chal_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('streams large simulated file buffer (5 MB) without truncation or payload corruption', () async {
      final largeFile = File('${tempDir.path}/large_receipt_5mb.bin');
      const targetSize = 5 * 1024 * 1024; // 5 MB

      // Generate 5MB of deterministic binary data
      final chunk = Uint8List.fromList(List.generate(65536, (i) => i % 256));
      final sink = largeFile.openWrite();
      for (int i = 0; i < (targetSize ~/ chunk.length); i++) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();

      expect(await largeFile.length(), equals(targetSize));

      int capturedStreamedBytes = 0;
      http.BaseRequest? capturedRequest;

      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        capturedRequest = request;
        capturedStreamedBytes = bodyBytes.length;

        final responsePayload = jsonEncode({
          'scan': {
            'id': 'scan-large-5mb',
            'storage_path': 'user/large_receipt_5mb.bin',
            'ocr_status': 'pending',
          },
          'message': 'Subida de archivo grande completada',
        });

        return http.StreamedResponse(
          Stream.value(utf8.encode(responsePayload)),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      final response = await client.uploadMultipart<Map<String, dynamic>>(
        '/receipt-scans/upload',
        file: largeFile,
        fieldName: 'file',
      );

      expect(response.statusCode, equals(201));
      expect(response.isSuccess, isTrue);
      expect(capturedRequest, isNotNull);
      // Streamed bytes must include the 5MB file plus multipart headers & boundary overhead
      expect(capturedStreamedBytes, greaterThan(targetSize));
      expect(capturedStreamedBytes, lessThan(targetSize + 1024 * 10)); // Overhead under 10KB
    });

    test('handles file path with extreme special characters, unicode, spaces, accents, and emojis', () async {
      // Path containing accents, spaces, hash, parentheses, emojis and ampersand
      final specialFile = File(
        '${tempDir.path}/Factura & Recibo #42 (Quincena Octubre - Café, Té & Maíz) 🧾.pdf',
      );
      await specialFile.writeAsBytes(utf8.encode('SPECIAL_PATH_CONTENT'));

      http.BaseRequest? capturedRequest;
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        capturedRequest = request;
        final responsePayload = jsonEncode({
          'scan': {
            'id': 'scan-special-path',
            'storage_path': 'user/special.pdf',
            'ocr_status': 'pending',
          },
        });

        return http.StreamedResponse(
          Stream.value(utf8.encode(responsePayload)),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      final response = await client.uploadMultipart<Map<String, dynamic>>(
        '/receipt-scans/upload',
        file: specialFile,
      );

      expect(response.statusCode, equals(201));
      expect(capturedRequest, isA<http.MultipartRequest>());
      final multipart = capturedRequest as http.MultipartRequest;
      expect(multipart.files.length, equals(1));
      expect(multipart.files.first.filename, contains('Factura & Recibo #42'));
      expect(multipart.files.first.filename, contains('Café, Té & Maíz'));
    });

    test('handles zero-byte empty file upload gracefully', () async {
      final emptyFile = File('${tempDir.path}/empty_receipt.png');
      await emptyFile.writeAsBytes([]);

      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        expect(bodyBytes.length, greaterThan(0)); // Boundary overhead exists even if file is empty
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'message': 'Recibido vacio'}))),
          200,
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      final response = await client.uploadMultipart(
        '/receipt-scans/upload',
        file: emptyFile,
      );

      expect(response.statusCode, equals(200));
    });

    test('handles excessively long file names (200+ characters) without failure', () async {
      final longFileName = '${'a' * 200}_receipt.jpg';
      final longFile = File('${tempDir.path}/$longFileName');
      await longFile.writeAsBytes(utf8.encode('LONG_FILENAME_CONTENT'));

      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'id': 'ok'}))),
          200,
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      final response = await client.uploadMultipart(
        '/receipt-scans/upload',
        file: longFile,
      );

      expect(response.statusCode, equals(200));
    });
  });

  group('Adversarial Challenge 2: Boundary Delimiter Protection & Malicious Headers', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('quincena_boundary_');
      testFile = File('${tempDir.path}/receipt.jpg');
      await testFile.writeAsBytes(utf8.encode('BOUNDARY_TEST_BYTES'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('malicious Content-Type header cannot strip or replace multipart boundary', () async {
      http.BaseRequest? capturedRequest;

      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        capturedRequest = request;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'ok': true}))),
          200,
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);

      await client.uploadMultipart(
        '/receipt-scans/upload',
        file: testFile,
        headers: {
          'Content-Type': 'application/json',
          'CONTENT-TYPE': 'text/plain',
          'content-type': 'application/octet-stream',
        },
      );

      final contentType = capturedRequest!.headers['content-type'] ?? '';
      expect(contentType, contains('multipart/form-data'));
      expect(contentType, contains('boundary='));
      expect(contentType, isNot(contains('application/json')));
    });

    test('multipart streamed body matches boundary declared in Content-Type header', () async {
      String? declaredBoundary;
      Uint8List? capturedBodyBytes;

      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        final ct = request.headers['content-type'] ?? '';
        final match = RegExp(r'boundary=([^;]+)').firstMatch(ct);
        if (match != null) {
          declaredBoundary = match.group(1);
        }
        capturedBodyBytes = bodyBytes;

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'ok': true}))),
          200,
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      await client.uploadMultipart('/receipt-scans/upload', file: testFile);

      expect(declaredBoundary, isNotNull);
      final bodyString = latin1.decode(capturedBodyBytes!);
      expect(bodyString, contains('--$declaredBoundary'));
      expect(bodyString, contains('--$declaredBoundary--'));
    });

    test('malicious header with whitespace or subtle variations does not corrupt boundary', () async {
      http.BaseRequest? capturedRequest;

      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        capturedRequest = request;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'ok': true}))),
          200,
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      await client.uploadMultipart(
        '/receipt-scans/upload',
        file: testFile,
        headers: {
          ' Content-Type ': 'application/json',
          'content-type ': 'text/plain',
        },
      );

      // The canonical content-type must retain multipart and boundary
      final canonicalContentType = capturedRequest!.headers['content-type'] ?? '';
      expect(canonicalContentType, contains('multipart/form-data'));
      expect(canonicalContentType, contains('boundary='));
    });
  });

  group('Adversarial Challenge 3: Network Failure Modes (500, 403, 404, 502, 504)', () {
    late Directory tempDir;
    late File testFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('quincena_errors_');
      testFile = File('${tempDir.path}/receipt.jpg');
      await testFile.writeAsBytes(utf8.encode('ERROR_TEST_BYTES'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('HTTP 500 with raw HTML body (nginx/gateway crash) is handled without FormatException', () async {
      const htmlBody = '''
        <!DOCTYPE html>
        <html>
          <head><title>500 Internal Server Error</title></head>
          <body>
            <h1>500 Internal Server Error</h1>
            <p>Nginx 1.25.1 gateway connection failed</p>
          </body>
        </html>
      ''';

      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(htmlBody)),
          500,
          headers: {'content-type': 'text/html'},
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);

      // 1. In regular get
      try {
        await client.get('/transactions');
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(500));
        expect(e.isServerError, isTrue);
        expect(e.details, equals(htmlBody));
        expect(ApiException.extractMessage(e), isNotEmpty);
      }

      // 2. In uploadMultipart
      try {
        await client.uploadMultipart('/receipt-scans/upload', file: testFile);
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(500));
        expect(e.isServerError, isTrue);
        expect(e.details, equals(htmlBody));
        expect(ApiException.extractMessage(e), isNotEmpty);
      }
    });

    test('HTTP 500 with structured JSON error payload preserves backend message and error', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 500,
            'message': 'Fallo en la base de datos de transacciones',
            'error': 'Internal Server Error',
          }))),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);

      try {
        await client.get('/transactions');
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(500));
        expect(e.isServerError, isTrue);
        expect(e.message, equals('Fallo en la base de datos de transacciones'));
        expect(e.error, equals('Internal Server Error'));
      }
    });

    test('HTTP 502, 503, 504 are recognized as isServerError', () async {
      for (final code in [502, 503, 504]) {
        final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode('Bad Gateway / Gateway Timeout')),
            code,
          );
        });

        final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
        try {
          await client.get('/transactions');
          fail('Should throw ApiException for $code');
        } on ApiException catch (e) {
          expect(e.statusCode, equals(code));
          expect(e.isServerError, isTrue);
        }
      }
    });

    test('HTTP 403 Forbidden with custom permissions payload preserves message and flag', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 403,
            'message': 'No tienes permisos para modificar este ciclo quincenal.',
            'error': 'Forbidden',
          }))),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);

      try {
        await client.delete('/transactions/tx-123');
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(403));
        expect(e.isForbidden, isTrue);
        expect(e.message, equals('No tienes permisos para modificar este ciclo quincenal.'));
        expect(e.error, equals('Forbidden'));
      }
    });

    test('HTTP 404 Not Found with empty body is handled safely', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value([]),
          404,
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);

      try {
        await client.get('/transactions/not-found-id');
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(404));
        expect(e.isNotFound, isTrue);
        expect(e.message, equals('Ha ocurrido un error en la solicitud.'));
      }
    });

    test('ApiException.extractMessage handles low-level SocketException, HttpException, and FormatException', () {
      final socketEx = const SocketException('Failed host lookup: api.quincena.app');
      final httpEx = const HttpException('Connection closed prematurely');
      final formatEx = const FormatException('Unexpected character at line 1');

      expect(ApiException.extractMessage(socketEx), contains('No se pudo conectar con el servidor'));
      expect(ApiException.extractMessage(httpEx), contains('Error en la conexión con el servidor'));
      expect(ApiException.extractMessage(formatEx), contains('Respuesta inesperada del servidor'));
      expect(ApiException.extractMessage(null), contains('Ha ocurrido un error inesperado.'));
    });
  });

  group('Adversarial Challenge 4: HTTP 409 Conflict with Malformed / Missing Duplicate Details', () {
    late ApiClient client;
    late TransactionApiService service;

    final dummyDto = CreateTransactionDto.manual(
      cycleId: 'cycle-100',
      sourceAccountId: 'acc-1',
      amount: 150.0,
      merchantName: 'Walmart',
      transactionDate: '2026-10-18',
    );

    test('409 Conflict with well-formed duplicate warning payload populates existingTransactions', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 409,
            'message': 'Gasto duplicado detectado (RN-03)',
            'duplicate_warning': true,
            'existing_transactions': [
              {
                'id': 'tx-dup-1',
                'merchant_name': 'Walmart',
                'amount': 150.0,
                'transaction_date': '2026-10-18',
                'created_at': '2026-10-18T10:00:00Z',
              }
            ],
          }))),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      try {
        await service.createTransaction(dummyDto);
        fail('Should throw DuplicateTransactionException');
      } on DuplicateTransactionException catch (e) {
        expect(e.message, equals('Gasto duplicado detectado (RN-03)'));
        expect(e.existingTransactions.length, equals(1));
        expect(e.existingTransactions.first.id, equals('tx-dup-1'));
        expect(e.existingTransactions.first.merchantName, equals('Walmart'));
        expect(e.existingTransactions.first.amount, equals(150.0));
      }
    });

    test('409 Conflict with MISSING existing_transactions key throws DuplicateTransactionException with empty list', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 409,
            'message': 'Gasto posiblemente duplicado',
            'duplicate_warning': true,
            // existing_transactions is omitted
          }))),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      try {
        await service.createTransaction(dummyDto);
        fail('Should throw DuplicateTransactionException');
      } on DuplicateTransactionException catch (e) {
        expect(e.message, equals('Gasto posiblemente duplicado'));
        expect(e.existingTransactions, isEmpty);
      }
    });

    test('409 Conflict with raw non-JSON text payload is handled safely', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('409 Conflict: Concurrent modification in progress')),
          409,
          headers: {'content-type': 'text/plain'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      try {
        await service.createTransaction(dummyDto);
        fail('Should throw DuplicateTransactionException or ApiException');
      } on DuplicateTransactionException catch (e) {
        expect(e.existingTransactions, isEmpty);
      } on ApiException catch (e) {
        expect(e.statusCode, equals(409));
      }
    });

    test('409 Conflict when existing_transactions is malformed (String instead of List)', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 409,
            'message': 'Posible duplicado',
            'duplicate_warning': true,
            'existing_transactions': 'CORRUPTED_STRING_NOT_A_LIST',
          }))),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      // Adversarial check: The service must not crash with an uncaught runtime TypeError.
      // It must throw DuplicateTransactionException or ApiException gracefully.
      expect(
        () async => await service.createTransaction(dummyDto),
        throwsA(anyOf(
          isA<DuplicateTransactionException>(),
          isA<ApiException>(),
        )),
      );
    });

    test('409 Conflict when existing_transactions is malformed (Integer instead of List)', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 409,
            'message': 'Posible duplicado',
            'duplicate_warning': true,
            'existing_transactions': 12345,
          }))),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      expect(
        () async => await service.createTransaction(dummyDto),
        throwsA(anyOf(
          isA<DuplicateTransactionException>(),
          isA<ApiException>(),
        )),
      );
    });

    test('409 Conflict when items inside existing_transactions have malformed types', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 409,
            'message': 'Posible duplicado',
            'duplicate_warning': true,
            'existing_transactions': [
              {
                'id': 99999, // int instead of String
                'merchant_name': 12345, // int instead of String
                'amount': '150.00', // String instead of num
                'transaction_date': 1760000000, // int timestamp instead of String
              }
            ],
          }))),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      // Must not crash with unhandled TypeError
      expect(
        () async => await service.createTransaction(dummyDto),
        throwsA(anyOf(
          isA<DuplicateTransactionException>(),
          isA<ApiException>(),
        )),
      );
    });
  });

  group('Adversarial Challenge 5: Service Resilience Under Unexpected Payloads', () {
    late ApiClient client;
    late TransactionApiService service;

    test('getTransactions returns empty list when server returns unexpected JSON object instead of list', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'unexpected_key': 'unexpected_val'}))),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      final list = await service.getTransactions(cycleId: 'cycle-1');
      expect(list, isEmpty);
    });

    test('confirmReceiptScan propagates 500 error cleanly', () async {
      final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'statusCode': 500,
            'message': 'Error al crear la transacción vinculada',
          }))),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
      service = TransactionApiService(client);

      final dto = ConfirmReceiptScanDto(
        cycleId: 'c-1',
        sourceAccountId: 'a-1',
        merchantName: 'Store',
        amount: 50.0,
      );

      try {
        await service.confirmReceiptScan('scan-1', dto);
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(500));
        expect(e.message, equals('Error al crear la transacción vinculada'));
      }
    });

    test('uploadReceiptScan handles response without scan key or unexpected structure', () async {
      final tempDir = await Directory.systemTemp.createTemp('chal_service_');
      final dummyFile = File('${tempDir.path}/test.jpg');
      await dummyFile.writeAsBytes(utf8.encode('TEST'));

      try {
        final mockClient = ChallengeMockHttpClient((request, bodyBytes) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'status': 'no_scan_key'}))),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);
        service = TransactionApiService(client);

        // Expect either a parsed fallback ReceiptScan or an ApiException, without unhandled crashes
        final scan = await service.uploadReceiptScan(dummyFile);
        expect(scan, isA<ReceiptScan>());
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
