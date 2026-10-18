import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/network/api_exception.dart';
import 'package:quincena/core/network/api_response.dart';

/// Mock HTTP Client para simular respuestas de servidor y verificar requests
class MockHttpClient extends http.BaseClient {
  MockHttpClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  group('ApiResponse Tests', () {
    test('instantiates with explicit data and evaluates isSuccess', () {
      const response = ApiResponse<Map<String, dynamic>>(
        statusCode: 201,
        data: {'id': 'scan-123'},
        message: 'Subida exitosa',
      );

      expect(response.statusCode, equals(201));
      expect(response.isSuccess, isTrue);
      expect(response.message, equals('Subida exitosa'));
      expect(response['id'], equals('scan-123'));
    });

    test('operator [] falls back to rawBody if data is not a map', () {
      final response = ApiResponse<int>(
        statusCode: 200,
        data: 42,
        rawBody: {'count': 42},
      );

      expect(response['count'], equals(42));
      expect(response['missing'], isNull);
    });

    test('factory fromResponse decodes JSON and applies fromJson converter', () {
      final httpResponse = http.Response(
        jsonEncode({'scan': {'id': 'abc'}, 'message': 'Procesando'}),
        201,
        headers: {'content-type': 'application/json'},
      );

      final apiResponse = ApiResponse<String>.fromResponse(
        httpResponse,
        fromJson: (json) => json['scan']['id'] as String,
      );

      expect(apiResponse.statusCode, equals(201));
      expect(apiResponse.data, equals('abc'));
      expect(apiResponse.message, equals('Procesando'));
    });
  });

  group('ApiClient.uploadMultipart Tests', () {
    late Directory tempDir;
    late File dummyFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('quincena_test_');
      dummyFile = File('${tempDir.path}/test_receipt.jpg');
      await dummyFile.writeAsBytes(utf8.encode('DUMMY_IMAGE_BYTES'));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('successfully uploads file and sets Authorization header and fields', () async {
      http.BaseRequest? capturedRequest;

      final mockClient = MockHttpClient((request) async {
        capturedRequest = request;
        final responsePayload = jsonEncode({
          'scan': {
            'id': 'scan-uuid-001',
            'storage_path': 'user1/test_receipt.jpg',
            'ocr_status': 'pending',
          },
          'message': 'Comprobante subido exitosamente.',
        });

        return http.StreamedResponse(
          Stream.value(utf8.encode(responsePayload)),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        baseUrl: 'http://api.test/v1',
        httpClient: mockClient,
      );
      client.setAuthToken('mock-jwt-token-xyz');

      final response = await client.uploadMultipart<Map<String, dynamic>>(
        '/receipt-scans/upload',
        file: dummyFile,
        fieldName: 'file',
        fields: {'cycle_id': 'cycle-123'},
      );

      expect(response.statusCode, equals(201));
      expect(response.isSuccess, isTrue);
      expect(response.message, equals('Comprobante subido exitosamente.'));
      expect(response.data['scan']['id'], equals('scan-uuid-001'));
      expect(response['scan']['ocr_status'], equals('pending'));

      // Verificar request capturado
      expect(capturedRequest, isNotNull);
      expect(capturedRequest, isA<http.MultipartRequest>());
      final multipartReq = capturedRequest as http.MultipartRequest;
      expect(multipartReq.url.toString(), equals('http://api.test/v1/receipt-scans/upload'));
      expect(multipartReq.headers['Authorization'], equals('Bearer mock-jwt-token-xyz'));
      expect(multipartReq.headers['Accept'], equals('application/json'));
      expect(multipartReq.headers['content-type'], contains('multipart/form-data'));
      expect(multipartReq.fields['cycle_id'], equals('cycle-123'));
      expect(multipartReq.files.length, equals(1));
      expect(multipartReq.files.first.field, equals('file'));
    });

    test('uses fromJson callback for strongly-typed data deserialization', () async {
      final mockClient = MockHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'scan': {'id': 'scan-typed-999'},
            'message': 'OK',
          }))),
          201,
        );
      });

      final client = ApiClient(
        baseUrl: 'http://api.test/v1',
        httpClient: mockClient,
      );

      final response = await client.uploadMultipart<String>(
        '/receipt-scans/upload',
        file: dummyFile,
        fromJson: (json) => json['scan']['id'] as String,
      );

      expect(response.data, equals('scan-typed-999'));
    });

    test('throws ApiException(400) when target file does not exist', () async {
      final nonExistentFile = File('${tempDir.path}/does_not_exist.jpg');
      final client = ApiClient(baseUrl: 'http://api.test/v1');

      expect(
        () => client.uploadMultipart('/receipt-scans/upload', file: nonExistentFile),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });

    test('invokes onUnauthorized callback and throws ApiException on 401', () async {
      bool unauthorizedCalled = false;

      final mockClient = MockHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'message': 'Token expired'}))),
          401,
        );
      });

      final client = ApiClient(
        baseUrl: 'http://api.test/v1',
        httpClient: mockClient,
      );
      client.onUnauthorized = () {
        unauthorizedCalled = true;
      };

      expect(
        () => client.uploadMultipart('/receipt-scans/upload', file: dummyFile),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Token expired')),
      );

      // El callback debe haberse ejecutado
      expect(unauthorizedCalled, isTrue);
    });

    test('throws ApiException with details on 409 Conflict', () async {
      final mockClient = MockHttpClient((request) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'message': 'Gasto posiblemente duplicado',
            'duplicate_warning': true,
          }))),
          409,
        );
      });

      final client = ApiClient(
        baseUrl: 'http://api.test/v1',
        httpClient: mockClient,
      );

      try {
        await client.uploadMultipart('/receipt-scans/upload', file: dummyFile);
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, equals(409));
        expect(e.isConflict, isTrue);
        expect(e.message, equals('Gasto posiblemente duplicado'));
        expect(e.details, isA<Map<String, dynamic>>());
        expect((e.details as Map)['duplicate_warning'], isTrue);
      }
    });

    test('custom headers are included while preventing Content-Type boundary clobber', () async {
      http.BaseRequest? captured;

      final mockClient = MockHttpClient((request) async {
        captured = request;
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'ok': true}))),
          200,
        );
      });

      final client = ApiClient(baseUrl: 'http://api.test/v1', httpClient: mockClient);

      await client.uploadMultipart(
        '/receipt-scans/upload',
        file: dummyFile,
        headers: {
          'X-Client-Version': '1.0.0',
          'Content-Type': 'application/json', // Intento de sobreescritura malicioso
        },
      );

      expect(captured!.headers['X-Client-Version'], equals('1.0.0'));
      // El content-type debe seguir conteniendo multipart/form-data con boundary
      expect(captured!.headers['content-type'], contains('multipart/form-data'));
      expect(captured!.headers['content-type'], contains('boundary='));
    });
  });
}
