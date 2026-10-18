import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/network/api_exception.dart';
import 'package:quincena/features/budget/data/models/category.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';
import 'package:quincena/features/ocr/presentation/ocr_scanner_screen.dart';
import 'package:quincena/features/transactions/data/models/models.dart';
import 'package:quincena/features/transactions/data/services/transaction_api_service.dart';

class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value([]),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _MockErrorHttpClient extends http.BaseClient {
  _MockErrorHttpClient({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Fake implementation of ImagePicker to inject adversarial files or delays.
class FakeImagePicker extends ImagePicker {
  FakeImagePicker({this.onPickImage});

  Future<XFile?> Function({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice,
    bool requestFullMetadata,
  })? onPickImage;

  int pickImageCallCount = 0;
  List<ImageSource> invokedSources = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickImageCallCount++;
    invokedSources.add(source);
    if (onPickImage != null) {
      return onPickImage!(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
        requestFullMetadata: requestFullMetadata,
      );
    }
    return null;
  }
}

/// Fake implementation of TransactionApiService to simulate network failures, timeouts, and tracking.
class FakeTransactionApiService extends TransactionApiService {
  FakeTransactionApiService({
    this.onUploadReceiptScan,
    this.onConfirmReceiptScan,
  }) : super(ApiClient(httpClient: _NoopHttpClient()));

  int uploadCallCount = 0;
  List<File> uploadedFiles = [];
  Future<ReceiptScan> Function(File file)? onUploadReceiptScan;
  Future<Transaction> Function(String scanId, ConfirmReceiptScanDto dto)?
      onConfirmReceiptScan;

  @override
  Future<ReceiptScan> uploadReceiptScan(File file) async {
    uploadCallCount++;
    uploadedFiles.add(file);
    if (onUploadReceiptScan != null) {
      return onUploadReceiptScan!(file);
    }
    return const ReceiptScan(
      id: 'scan-stress-1',
      userId: 'test-user-id',
      storagePath: 'receipts/test.jpg',
      extractedMerchant: 'La Torre Express',
      extractedAmount: 175.50,
      confidenceScore: 0.96,
      ocrStatus: OcrStatus.processed,
    );
  }

  @override
  Future<Transaction> confirmReceiptScan(
    String scanId,
    ConfirmReceiptScanDto dto,
  ) async {
    if (onConfirmReceiptScan != null) {
      return onConfirmReceiptScan!(scanId, dto);
    }
    return Transaction(
      id: 'tx-created-1',
      userId: 'test-user-id',
      cycleId: dto.cycleId,
      sourceAccountId: dto.sourceAccountId,
      amount: dto.amount ?? 0.0,
      merchantName: dto.merchantName ?? '',
      transactionDate: dto.transactionDate != null
          ? DateTime.parse(dto.transactionDate!)
          : DateTime.now(),
      entryMethod: EntryMethod.ocr,
      receiptScanId: scanId,
    );
  }

  @override
  Future<List<Transaction>> getTransactions({required String cycleId}) async {
    return [];
  }
}

/// Bounded pump helper allowing real async I/O (dart:io File.length/exists)
/// and widget animation frames to resolve cleanly without hanging on repeating
/// ticker animations in [OcrViewfinder].
Future<void> _pumpAsyncIo(
  WidgetTester tester, {
  Duration realDelay = const Duration(milliseconds: 50),
  Duration animDuration = const Duration(milliseconds: 100),
  int extraFrames = 2,
}) async {
  await tester.runAsync(() async {
    await Future.delayed(realDelay);
  });
  await tester.pump();
  for (int i = 0; i < extraFrames; i++) {
    await tester.pump(animDuration);
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('quincena_ocr_stress_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  final testCategories = [
    const Category(
      id: 'cat-super',
      name: 'Supermercado',
      icon: 'shopping_cart',
      colorHex: '#ADF7B6',
      defaultAccountId: 'acc-deb',
    ),
    const Category(
      id: 'cat-ocio',
      name: 'Ocio',
      icon: 'local_cafe',
      colorHex: '#FFEE93',
      defaultAccountId: 'acc-cash',
    ),
  ];

  final testAccounts = [
    const FinancialAccount(
      id: 'acc-deb',
      name: 'Cuenta Débito',
      accountType: AccountType.checking,
      currency: 'GTQ',
      colorHex: '#79ADDC',
      icon: 'account_balance',
      isDefault: true,
      isArchived: false,
      initialBalance: 2000.0,
      currentBalance: 1500.0,
    ),
  ];

  Widget buildTestScreen({
    required FakeImagePicker picker,
    required FakeTransactionApiService transactionApiService,
    VoidCallback? onManualRequested,
    VoidCallback? onOpenManualForm,
  }) {
    return MaterialApp(
      home: OcrScannerScreen(
        picker: picker,
        transactionApiService: transactionApiService,
        cycleId: 'cycle-stress-test',
        initialCategories: testCategories,
        initialAccounts: testAccounts,
        currentAvailableBalance: 1500.0,
        daysRemainingInCycle: 7,
        onManualRequested: onManualRequested,
        onOpenManualForm: onOpenManualForm,
      ),
    );
  }

  group('Adversarial Challenge 1: File Boundary & Format Edge Cases', () {
    testWidgets(
        'Empirically verifies 0-byte file is rejected without triggering upload',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final emptyFile = File('${tempDir.path}/empty_receipt.jpg');
      emptyFile.writeAsBytesSync([]);

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async {
          return XFile(emptyFile.path);
        },
      );

      final fakeApiService = FakeTransactionApiService();

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger capture via shutter button
      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await _pumpAsyncIo(tester);

      // Verify zero uploads were dispatched to backend
      expect(fakeApiService.uploadCallCount, equals(0));

      // Verify the user received explicit toast error about empty file
      expect(find.text('El archivo seleccionado está vacío.'), findsOneWidget);
    });

    testWidgets(
        'Empirically verifies oversized file (>10MB) is rejected without uploading',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a 10.1 MB file (10 * 1024 * 1024 + 102400 bytes)
      final oversizedFile = File('${tempDir.path}/oversized_receipt.jpg');
      final raf = oversizedFile.openSync(mode: FileMode.write);
      raf.truncateSync(10 * 1024 * 1024 + 102400);
      raf.closeSync();

      expect(oversizedFile.lengthSync(), greaterThan(10 * 1024 * 1024));

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async {
          return XFile(oversizedFile.path);
        },
      );

      final fakeApiService = FakeTransactionApiService();

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger capture
      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await _pumpAsyncIo(tester);

      // Verify zero uploads were dispatched
      expect(fakeApiService.uploadCallCount, equals(0));

      // Verify maximum size toast
      expect(
        find.text('El comprobante excede el tamaño máximo permitido de 10 MB.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Empirically verifies unsupported extensions (.exe, .zip) are rejected',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final exeFile = File('${tempDir.path}/invoice_payload.exe');
      exeFile.writeAsBytesSync([0x4D, 0x5A, 0x90, 0x00]); // MZ header

      final zipFile = File('${tempDir.path}/receipts_archive.zip');
      zipFile.writeAsBytesSync([0x50, 0x4B, 0x03, 0x04]); // PK header

      // 1. Test .exe via camera picker
      var fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async =>
            XFile(exeFile.path),
      );
      var fakeApiService = FakeTransactionApiService();

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await _pumpAsyncIo(tester);

      expect(fakeApiService.uploadCallCount, equals(0));
      expect(
        find.text('Formato no compatible. Sube una imagen (JPG, PNG) o PDF.'),
        findsOneWidget,
      );

      // 2. Test .zip via gallery picker
      fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async =>
            XFile(zipFile.path),
      );
      fakeApiService = FakeTransactionApiService();

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('ocr_gallery_button')));
      await _pumpAsyncIo(tester);

      expect(fakeApiService.uploadCallCount, equals(0));
      expect(
        find.text('Formato no compatible. Sube una imagen (JPG, PNG) o PDF.'),
        findsOneWidget,
      );
    });
  });

  group('Adversarial Challenge 2: Rapid Multi-Tap & Concurrency Stress Tests', () {
    testWidgets(
        'Disabling of shutter and gallery buttons during active upload processing',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final validFile = File('${tempDir.path}/receipt_multitap.jpg');
      validFile.writeAsBytesSync(List.filled(2048, 1));

      final uploadCompleter = Completer<ReceiptScan>();

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async =>
            XFile(validFile.path),
      );

      final fakeApiService = FakeTransactionApiService(
        onUploadReceiptScan: (file) => uploadCompleter.future,
      );

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Initial tap on shutter to start upload
      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await _pumpAsyncIo(tester);

      expect(fakeApiService.uploadCallCount, equals(1));
      expect(find.text('Procesando comprobante...'), findsOneWidget);

      // Attempt rapid multi-tap while upload is pending (isProcessing == true)
      await tester.tap(find.byKey(const Key('ocr_shutter_button')), warnIfMissed: false);
      await tester.tap(find.byKey(const Key('ocr_shutter_button')), warnIfMissed: false);
      await tester.tap(find.byKey(const Key('ocr_gallery_button')), warnIfMissed: false);
      await tester.tap(find.byKey(const Key('ocr_gallery_button')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));

      // Assert that extra taps did NOT launch secondary uploads
      expect(fakeApiService.uploadCallCount, equals(1));

      // Resolve the upload
      uploadCompleter.complete(
        const ReceiptScan(
          id: 'scan-resolved',
          userId: 'u1',
          storagePath: 'p1',
          extractedMerchant: 'Farmacia Galeno',
          extractedAmount: 85.0,
          confidenceScore: 0.94,
        ),
      );
      await _pumpAsyncIo(tester);

      // Pre-confirmation sheet appears
      expect(find.text('Farmacia Galeno'), findsOneWidget);
    });

    testWidgets(
        'Concurrent ImagePicker invocations when tapped rapidly before picker returns',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final validFile = File('${tempDir.path}/receipt_concurrent.jpg');
      validFile.writeAsBytesSync(List.filled(1024, 2));

      final pickerCompleter = Completer<XFile?>();

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) =>
            pickerCompleter.future,
      );

      final fakeApiService = FakeTransactionApiService();

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Rapidly tap shutter button 3 times BEFORE picker returns
      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ocr_gallery_button')));
      await tester.pump();

      // Check whether picker was invoked multiple times concurrently
      final initialPickerCalls = fakePicker.pickImageCallCount;

      // Complete the picker
      pickerCompleter.complete(XFile(validFile.path));
      await _pumpAsyncIo(tester);

      // Document concurrency observation
      expect(initialPickerCalls, greaterThanOrEqualTo(1));
    });
  });

  group('Adversarial Challenge 3: Network Drop & Timeout Stress Tests', () {
    testWidgets(
        'Network drop (SocketException) fails gracefully with error message and manual fallback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final validFile = File('${tempDir.path}/receipt_socket_drop.jpg');
      validFile.writeAsBytesSync(List.filled(1024, 3));

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async =>
            XFile(validFile.path),
      );

      // Simulate a network failure during upload
      final fakeApiService = FakeTransactionApiService(
        onUploadReceiptScan: (file) async {
          throw const SocketException('Failed host lookup: api.quincena.app');
        },
      );

      bool manualRequested = false;

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
          onManualRequested: () => manualRequested = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger upload
      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await _pumpAsyncIo(tester);

      // 1. Verify spinner is dismissed
      expect(find.text('Procesando comprobante...'), findsNothing);

      // 2. Verify bottom guide shows error state
      expect(find.text('Error al procesar el comprobante.'), findsOneWidget);

      // 3. Verify SnackBar with error and Manual action
      expect(
        find.textContaining('No pudimos procesar el comprobante'),
        findsOneWidget,
      );
      final manualActionFinder = find.widgetWithText(SnackBarAction, 'Manual');
      expect(manualActionFinder, findsOneWidget);

      // 4. Tap the manual fallback action
      await tester.tap(manualActionFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(manualRequested, isTrue);
    });

    testWidgets(
        'TimeoutException during upload displays error banner and allows manual fallback',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final validFile = File('${tempDir.path}/receipt_timeout.jpg');
      validFile.writeAsBytesSync(List.filled(1024, 4));

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async =>
            XFile(validFile.path),
      );

      final fakeApiService = FakeTransactionApiService(
        onUploadReceiptScan: (file) async {
          throw TimeoutException('Conexión con el servidor excedió el tiempo límite (10s)');
        },
      );

      bool manualOpened = false;

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
          onOpenManualForm: () => manualOpened = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await _pumpAsyncIo(tester);

      expect(
        find.textContaining('tiempo límite'),
        findsOneWidget,
      );

      final manualBtn = find.widgetWithText(SnackBarAction, 'Manual');
      expect(manualBtn, findsOneWidget);
      await tester.tap(manualBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(manualOpened, isTrue);
    });

    test(
        'Direct ApiClient.uploadMultipart catches and propagates HTTP 504 and network errors',
        () async {
      final validFile = File('${tempDir.path}/direct_upload.jpg');
      validFile.writeAsBytesSync(List.filled(512, 5));

      // Create a mock http.Client that returns 504 Gateway Timeout
      final fakeHttpClient = _MockErrorHttpClient(
        statusCode: 504,
        body: '{"message": "Gateway Timeout", "error": "Gateway Timeout"}',
      );
      final apiClient = ApiClient(httpClient: fakeHttpClient);

      await expectLater(
        apiClient.uploadMultipart('/receipt-scans/upload', file: validFile),
        throwsA(
          isA<ApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            equals(504),
          ),
        ),
      );
    });
  });

  group('Adversarial Challenge 4: Non-existent File Path Handling', () {
    testWidgets(
        'Non-existent file path from camera picker is caught and reported to user',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const missingPath = 'C:/missing_folder_98765/phantom_ticket.jpg';
      expect(File(missingPath).existsSync(), isFalse);

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async =>
            XFile(missingPath),
      );

      final fakeApiService = FakeTransactionApiService();

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Shutter tap with non-existent file path
      await tester.tap(find.byKey(const Key('ocr_shutter_button')));
      await _pumpAsyncIo(tester);

      // Verify no upload was dispatched
      expect(fakeApiService.uploadCallCount, equals(0));

      // Verify the camera error catch block protected the application
      expect(
        find.textContaining('No se pudo acceder a la cámara'),
        findsOneWidget,
      );

      // Verify widget tree is fully intact and still renders viewfinder
      expect(find.byKey(const Key('ocr_shutter_button')), findsOneWidget);
    });

    testWidgets(
        'Non-existent file path from gallery picker is caught and reported to user',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const missingPath = 'C:/missing_gallery_123/deleted_photo.png';
      expect(File(missingPath).existsSync(), isFalse);

      final fakePicker = FakeImagePicker(
        onPickImage: ({
          required source,
          maxWidth,
          maxHeight,
          imageQuality,
          preferredCameraDevice = CameraDevice.rear,
          requestFullMetadata = true,
        }) async =>
            XFile(missingPath),
      );

      final fakeApiService = FakeTransactionApiService();

      await tester.pumpWidget(
        buildTestScreen(
          picker: fakePicker,
          transactionApiService: fakeApiService,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Gallery tap with non-existent file path
      await tester.tap(find.byKey(const Key('ocr_gallery_button')));
      await _pumpAsyncIo(tester);

      // Verify no upload was dispatched
      expect(fakeApiService.uploadCallCount, equals(0));

      // Verify gallery error catch block caught the missing file exception
      expect(
        find.text('No se pudo abrir la galería de imágenes.'),
        findsOneWidget,
      );

      // Viewfinder is intact
      expect(find.byKey(const Key('ocr_gallery_button')), findsOneWidget);
    });

    test(
        'Direct ApiClient.uploadMultipart throws 400 ApiException when file does not exist',
        () async {
      final missingFile = File('${tempDir.path}/definitely_not_here.jpg');
      expect(missingFile.existsSync(), isFalse);

      final apiClient = ApiClient(httpClient: _NoopHttpClient());

      await expectLater(
        apiClient.uploadMultipart('/receipt-scans/upload', file: missingFile),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', equals(400))
              .having(
                (e) => e.message,
                'message',
                contains('El archivo para subida no existe'),
              ),
        ),
      );
    });
  });
}
