# Technical Handoff Report: Mobile ApiClient Multipart & Pubspec Explorer

**Milestone**: Milestone 1 (Backend Bucket Alignment & Mobile Foundation)  
**Agent**: Mobile ApiClient Multipart & Pubspec Explorer (`m1_explorer_2`)  
**Working Directory**: `E:\Projects\quincena-app\.agents\teamwork\m1_explorer_2`  
**Date**: 2026-10-17  

---

## 1. Observation

### 1.1 Dependency Baseline and Pubspec Inspection
- **File**: `quincena/pubspec.yaml` (lines 21-39):
  ```yaml
  environment:
    sdk: ^3.11.0

  dependencies:
    flutter:
      sdk: flutter
    cupertino_icons: ^1.0.8
    google_fonts: ^9.0.0
    http: ^1.2.0
  ```
- **Flutter & Dart SDK Environment**:
  - `flutter --version` output:
    ```
    Flutter 3.47.5 • channel stable • https://github.com/flutter/flutter.git
    Framework • revision 6a19cca564 (2026-09-17)
    Engine • hash ab59836859 (2026-09-16)
    Tools • Dart 3.13.4 • DevTools 2.60.0
    ```
- **Dependency Compatibility Test (`flutter pub add --dry-run image_picker:^1.1.2`)**:
  - Command: `flutter pub add --dry-run image_picker:^1.1.2` executed in `quincena/`.
  - Result: Exit code 0, cleanly resolved:
    ```
    + image_picker 1.1.2
    + image_picker_android 0.8.13+25
    + image_picker_for_web 3.1.1
    + image_picker_ios 0.8.13+12
    + image_picker_linux 0.2.2
    + image_picker_macos 0.2.2+1
    + image_picker_platform_interface 2.11.2
    + image_picker_windows 0.2.2
    + cross_file 0.3.5+5
    + mime 2.1.0
    ```
  - **Zero dependency conflicts** detected with existing packages (`http: ^1.2.0`, `google_fonts: ^9.0.0`, `cupertino_icons: ^1.0.8`).

### 1.2 Existing Network Layer Architecture
- **File**: `quincena/lib/core/network/api_client.dart`:
  - Methods: `get`, `post`, `patch`, `delete` (lines 66-115) all return `Future<dynamic>` after routing through `_handleResponse(response)`.
  - Authentication Token: Stored in `String? _authToken` (line 18), injected via `headers['Authorization'] = 'Bearer $_authToken'` (line 56).
  - Unauthorized Callback: `VoidCallback? onUnauthorized` (line 21), called on HTTP 401 (line 132).
  - Constructor Injection: Accepts optional `http.Client? httpClient` (line 13) and `String? baseUrl` (line 14), enabling mock-based testing without real network I/O.
  - **Gap Identified**: `ApiClient` lacks multipart upload support (`http.MultipartRequest`) required by endpoint `POST /receipt-scans/upload` for uploading image/PDF files.
  - **Gap Identified**: No typed `ApiResponse<T>` wrapper exists in `quincena/lib/core/network/`. Callers currently perform raw dynamic casting.
- **File**: `quincena/lib/core/network/api_exception.dart`:
  - `ApiException` models errors with `statusCode`, `message`, `error` (lines 6-9).
  - **Gap Identified**: `ApiException` does not preserve structured error response details (e.g. `{ duplicate_warning: true, existing_transactions: [...] }` returned by backend on HTTP 409 Conflict).

### 1.3 Backend Endpoint Contract (`quincena-api`)
- **Controller**: `quincena-api/src/modules/receipt-scans/receipt-scans.controller.ts` (lines 56-80):
  - Route: `POST /receipt-scans/upload` (`/v1/receipt-scans/upload`)
  - Request format: `multipart/form-data` with file field name `'file'` (`FileInterceptor('file')`).
  - Auth: Requires Bearer JWT token (`@UseGuards(SupabaseAuthGuard)`).
  - Response: HTTP 201 Created returning:
    ```json
    {
      "scan": {
        "id": "uuid",
        "user_id": "uuid",
        "storage_path": "user_id/1729180000.jpg",
        "ocr_status": "pending",
        "extracted_merchant": null,
        "extracted_amount": null,
        "extracted_date": null,
        "tax_id_or_auth_number": null,
        "confidence_score": null,
        "suggested_account_id": null,
        "created_at": "2026-10-17T..."
      },
      "message": "Comprobante subido exitosamente. El procesamiento OCR está en curso."
    }
    ```

---

## 2. Logic Chain

```
[Observation: pubspec.yaml lacks image_picker; dry-run confirms image_picker: ^1.1.2 resolves with 0 conflicts]
  └──> Place `image_picker: ^1.1.2` under `dependencies:` immediately after `http: ^1.2.0`.

[Observation: POST /receipt-scans/upload requires multipart/form-data with field 'file' and Bearer token]
  └──> Design ApiClient.uploadMultipart<T>() using package:http `MultipartRequest('POST', uri)`:
       1. Check file existence on disk; if missing, fail fast with ApiException(400).
       2. Set Authorization: Bearer $_authToken (when authenticated).
       3. Set Accept: application/json.
       4. Merge optional extra headers, defensively preventing manual Content-Type overwrite
          to avoid destroying the auto-generated multipart boundary delimiter.
       5. Add optional form fields via request.fields.addAll(fields).
       6. Attach file via http.MultipartFile.fromPath(fieldName, file.path).
       7. Send request via injected _httpClient.send(request).
       8. Convert StreamedResponse to Response via http.Response.fromStream(streamed).

[Observation: Dispatch requires proper response decoding and conversion into ApiResponse<T>]
  └──> Create a dedicated `ApiResponse<T>` class in `quincena/lib/core/network/api_response.dart`:
       1. Encapsulate `statusCode`, `data` (type T), `message`, `rawBody`, and `headers`.
       2. Implement `operator [](String key)` for index access to maps (e.g. response['scan']).
       3. Support optional `fromJson: (dynamic json) => T` callback for strongly-typed models.
       4. Re-export `api_response.dart` from `api_client.dart` so all consumers get it automatically.

[Observation: 401 triggers onUnauthorized; 409 Conflict carries duplicate_warning payload]
  └──> Route response through `_handleMultipartResponse`:
       1. If statusCode == 401: invoke `onUnauthorized?.call()`.
       2. If statusCode >= 400: throw ApiException(statusCode, message, error, details: body).
       3. Add optional `final dynamic details;` to `ApiException` to expose payload on conflicts.
       4. If 200 <= statusCode < 300: deserialize and return `ApiResponse<T>`.
```

---

## 3. Caveats

1. **Native Permissions for `image_picker` on Mobile Devices**:
   - `image_picker: ^1.1.2` functions out-of-the-box for simulator and desktop test execution. When deploying to real physical Android/iOS devices, native permissions (`CAMERA`, `READ_MEDIA_IMAGES` in AndroidManifest.xml; `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` in Info.plist) must be configured in milestone deployment.
2. **Multipart Content-Type Header Guard**:
   - `http.MultipartRequest` dynamically computes its own `Content-Type` header (e.g., `multipart/form-data; boundary=dart-http-...`). If a caller inadvertently passes `'Content-Type': 'application/json'` in `headers`, the upload will be corrupted. Our implementation explicitly ignores `Content-Type` from the `headers` map to guarantee boundary integrity.
3. **File Path on Real Disk vs In-Memory**:
   - `http.MultipartFile.fromPath` requires a filesystem path. In unit tests, temporary files created with `Directory.systemTemp.createTemp` must be used.

---

## 4. Conclusion & Concrete Code Implementation

### 4.1 Modifications to `quincena/pubspec.yaml`
Add `image_picker: ^1.1.2` under `dependencies:`:
```yaml
dependencies:
  flutter:
    sdk: flutter

  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  google_fonts: ^9.0.0
  http: ^1.2.0
  image_picker: ^1.1.2
```

---

### 4.2 New File: `quincena/lib/core/network/api_response.dart`
Create file `quincena/lib/core/network/api_response.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Representa una respuesta exitosa tipada de la API REST de Quincena.
///
/// Encapsula el código de estado HTTP, la carga útil deserializada [data],
/// el mensaje informativo opcional [message] y el cuerpo crudo decodificado [rawBody].
class ApiResponse<T> {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.message,
    this.rawBody,
    this.headers,
  });

  /// Código de estado HTTP retornado por el servidor (p. ej. 200, 201).
  final int statusCode;

  /// Carga útil procesada o transformada a través de un deserializador genérico [T].
  final T data;

  /// Mensaje descriptivo proporcionado por el backend en el payload JSON.
  final String? message;

  /// Contenido decodificado original (Map, List, o String) para acceso directo flexible.
  final dynamic rawBody;

  /// Encabezados de la respuesta HTTP recibida.
  final Map<String, String>? headers;

  /// Indica si la petición fue exitosa (códigos 2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Acceso indexado dinámico para facilitar consumo cuando [data] o [rawBody] es un mapa.
  ///
  /// Permite sintaxis como `response['scan']` o `response['message']` sin necesidad de casts manuales.
  dynamic operator [](String key) {
    if (data is Map<String, dynamic>) {
      return (data as Map<String, dynamic>)[key];
    }
    if (rawBody is Map<String, dynamic>) {
      return (rawBody as Map<String, dynamic>)[key];
    }
    return null;
  }

  /// Constructor factory para instanciar a partir de una [http.Response].
  factory ApiResponse.fromResponse(
    http.Response response, {
    T Function(dynamic json)? fromJson,
  }) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    String? message;
    if (decoded is Map<String, dynamic>) {
      final msg = decoded['message'];
      if (msg is List) {
        message = msg.join(', ');
      } else if (msg is String) {
        message = msg;
      }
    }

    final T data = fromJson != null
        ? fromJson(decoded)
        : (decoded is T ? decoded : decoded as T);

    return ApiResponse<T>(
      statusCode: response.statusCode,
      data: data,
      message: message,
      rawBody: decoded,
      headers: response.headers,
    );
  }

  @override
  String toString() =>
      'ApiResponse<$T>(statusCode: $statusCode, message: $message, data: $data)';
}
```

---

### 4.3 Update to `quincena/lib/core/network/api_exception.dart`
Add optional `final dynamic details;` to preserve structured error bodies:
```dart
class ApiException implements Exception {
  ApiException({
    required this.statusCode,
    required this.message,
    this.error,
    this.details,
  });

  final int statusCode;
  final String message;
  final String? error;

  /// Datos estructurados retornados por el servidor (p. ej. duplicate_warning, existing_transactions)
  final dynamic details;
```

---

### 4.4 Update to `quincena/lib/core/network/api_client.dart`
Add `export 'api_response.dart';` and the `uploadMultipart<T>` method:
```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

export 'api_exception.dart';
export 'api_response.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  final http.Client _httpClient;
  String _baseUrl;
  String? _authToken;

  VoidCallback? onUnauthorized;

  // ... [mantiene propiedades y métodos existentes get, post, patch, delete] ...

  /// Sube un archivo con campos opcionales mediante petición HTTP multipart/form-data (POST).
  ///
  /// - [path]: Ruta del endpoint relativo (p. ej. `/receipt-scans/upload`).
  /// - [file]: Archivo [File] a transferir en la petición.
  /// - [fieldName]: Nombre del campo de archivo esperado por el backend (por defecto `'file'`).
  /// - [fields]: Pares clave-valor de campos de texto adicionales en el multipart.
  /// - [headers]: Encabezados HTTP complementarios (se preserva automáticamente el boundary multipart).
  /// - [fromJson]: Función transformadora opcional para deserializar el resultado tipado [T].
  ///
  /// Inyecta automáticamente el token JWT en el encabezado `Authorization: Bearer <token>` si está autenticado.
  /// Lanza [ApiException] en códigos HTTP fuera de 2xx o si el archivo no existe.
  Future<ApiResponse<T>> uploadMultipart<T>(
    String path, {
    required File file,
    String fieldName = 'file',
    Map<String, String>? fields,
    Map<String, String>? headers,
    T Function(dynamic json)? fromJson,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    // 1. Inyectar cabecera de autenticación y aceptación
    if (_authToken != null && _authToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    request.headers['Accept'] = 'application/json';

    // 2. Inyectar headers personalizados omitiendo Content-Type para preservar el boundary generado
    if (headers != null) {
      headers.forEach((key, value) {
        if (key.toLowerCase() != 'content-type') {
          request.headers[key] = value;
        }
      });
    }

    // 3. Inyectar campos de formulario adicionales
    if (fields != null && fields.isNotEmpty) {
      request.fields.addAll(fields);
    }

    // 4. Validar existencia del archivo
    if (!await file.exists()) {
      throw ApiException(
        statusCode: 400,
        message: 'El archivo para subida no existe en la ruta: ${file.path}',
      );
    }

    // 5. Adjuntar archivo multipart
    final multipartFile = await http.MultipartFile.fromPath(
      fieldName,
      file.path,
    );
    request.files.add(multipartFile);

    // 6. Transmitir y procesar respuesta
    final streamedResponse = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    return _handleMultipartResponse<T>(response, fromJson: fromJson);
  }

  ApiResponse<T> _handleMultipartResponse<T>(
    http.Response response, {
    T Function(dynamic json)? fromJson,
  }) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      String? message;
      if (body is Map<String, dynamic>) {
        final msg = body['message'];
        if (msg is List) {
          message = msg.join(', ');
        } else if (msg is String) {
          message = msg;
        }
      }

      final T data = fromJson != null
          ? fromJson(body)
          : (body is T ? body : body as T);

      return ApiResponse<T>(
        statusCode: response.statusCode,
        data: data,
        message: message,
        rawBody: body,
        headers: response.headers,
      );
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    String message = 'Ha ocurrido un error en la solicitud de subida.';
    String? error;

    if (body is Map<String, dynamic>) {
      final msg = body['message'];
      if (msg is List) {
        message = msg.join(', ');
      } else if (msg is String) {
        message = msg;
      }
      error = body['error'] as String?;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      error: error,
      details: body,
    );
  }

  dynamic _handleResponse(http.Response response) {
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }

    String message = 'Ha ocurrido un error en la solicitud.';
    String? error;

    if (body is Map<String, dynamic>) {
      final msg = body['message'];
      if (msg is List) {
        message = msg.join(', ');
      } else if (msg is String) {
        message = msg;
      }
      error = body['error'] as String?;
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      error: error,
      details: body,
    );
  }

  void dispose() {
    _httpClient.close();
  }
}
```

---

### 4.5 New Unit Test Suite: `quincena/test/core/network/api_client_multipart_test.dart`
Create unit test suite covering `ApiResponse` and `ApiClient.uploadMultipart`:
```dart
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
          'Content-Type': 'application/json',
        },
      );

      expect(captured!.headers['X-Client-Version'], equals('1.0.0'));
      expect(captured!.headers['content-type'], contains('multipart/form-data'));
      expect(captured!.headers['content-type'], contains('boundary='));
    });
  });
}
```

---

## 5. Verification Method

Once the worker implements the proposed files, execute the following commands to independently verify:

1. **Install Dependencies**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter pub get
   ```
   *Expected Result*: Resolves `image_picker 1.1.2` and related plugins cleanly without conflicts.

2. **Static Analysis**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter analyze
   ```
   *Expected Result*: `No issues found!` (0 errors, 0 warnings).

3. **Execute Test Suite**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter test test/core/network/api_client_multipart_test.dart
   ```
   *Expected Result*: All 8 multipart & ApiResponse tests pass.

4. **Execute Full Project Regression Test Suite**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter test
   ```
   *Expected Result*: 61+ passed (53 baseline tests + 8 new multipart tests), 0 failures.

5. **Invalidation Conditions**:
   - `flutter analyze` reports type mismatch, missing exports, or lint violations.
   - `ApiClient.uploadMultipart` fails to inject Bearer token or alters `Content-Type` stripping multipart boundary.
   - Any regression in existing 53 Flutter unit/widget tests.
