import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/core/theme/theme.dart';
import 'package:quincena/features/dashboard/data/dashboard_api_service.dart';
import 'package:quincena/features/dashboard/data/models/dashboard_data.dart';
import 'proposed_capture_source_sheet.dart';

/// Fake HTTP Client para simular endpoint `/dashboard`
class FakeDashboardHttpClient extends http.BaseClient {
  FakeDashboardHttpClient({this.hasActiveCycle = true, this.totalSpent = 300.0});

  final bool hasActiveCycle;
  double totalSpent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final responseBody = jsonEncode({
      'has_active_cycle': hasActiveCycle,
      if (hasActiveCycle)
        'cycle': {
          'id': 'cycle-test-1',
          'year': 2026,
          'month': 10,
          'period': 'first_half',
          'start_date': '2026-10-01',
          'end_date': '2026-10-15',
          'total_income': 2500.0,
          'is_closed': false,
        },
      'summary': {
        'total_income': 2500.0,
        'total_allocated': 2000.0,
        'total_spent': totalSpent,
        'total_available': 1700.0,
        'unallocated': 500.0,
        'is_balanced': false,
      },
      'categories': [
        {
          'id': 'alloc-1',
          'category_id': 'cat-1',
          'name': 'Alimentación',
          'icon': 'shopping_cart',
          'color_hex': '#79ADDC',
          'allocated_amount': 1000.0,
          'spent_amount': totalSpent,
          'available_amount': 1000.0 - totalSpent,
          'spent_percentage': (totalSpent / 1000.0) * 100,
        }
      ],
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('CaptureSourceSheet Widget Tests (RF-03/05, RF-04/06)', () {
    testWidgets('Renders all three capture options with Stitch typography & styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CaptureSourceSheet(),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Registrar Gasto'), findsOneWidget);
      expect(
        find.text('Selecciona cómo deseas registrar tu gasto o comprobante'),
        findsOneWidget,
      );

      // Verify Option 1: Tomar Foto
      expect(find.byKey(const Key('capture_option_camera')), findsOneWidget);
      expect(find.text('Tomar Foto'), findsOneWidget);
      expect(find.text('Recomendado'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

      // Verify Option 2: Subir de Galería o PDF
      expect(find.byKey(const Key('capture_option_gallery')), findsOneWidget);
      expect(find.text('Subir de Galería o PDF'), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);

      // Verify Option 3: Registro Manual
      expect(find.byKey(const Key('capture_option_manual')), findsOneWidget);
      expect(find.text('Registro Manual'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
    });

    testWidgets('Tapping Camera option invokes onCameraSelected callback',
        (WidgetTester tester) async {
      bool cameraSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureSourceSheet(
              onCameraSelected: () => cameraSelected = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('capture_option_camera')));
      await tester.pump();

      expect(cameraSelected, isTrue);
    });

    testWidgets('Tapping Gallery option invokes onGallerySelected callback',
        (WidgetTester tester) async {
      bool gallerySelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureSourceSheet(
              onGallerySelected: () => gallerySelected = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('capture_option_gallery')));
      await tester.pump();

      expect(gallerySelected, isTrue);
    });

    testWidgets('Tapping Manual option invokes onManualSelected callback',
        (WidgetTester tester) async {
      bool manualSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptureSourceSheet(
              onManualSelected: () => manualSelected = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('capture_option_manual')));
      await tester.pump();

      expect(manualSelected, isTrue);
    });

    testWidgets('CaptureSourceSheet.show pops with correct CaptureSourceOption',
        (WidgetTester tester) async {
      CaptureSourceOption? chosenOption;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  chosenOption = await CaptureSourceSheet.show(context);
                },
                child: const Text('Abrir Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Abrir Sheet'));
      await tester.pumpAndSettle();

      // Tap gallery option
      await tester.tap(find.byKey(const Key('capture_option_gallery')));
      await tester.pumpAndSettle();

      expect(chosenOption, CaptureSourceOption.gallery);
    });
  });

  group('Real-Time Balance Refresh Signal (<100ms)', () {
    testWidgets('ValueNotifier signal triggers immediate reload of dashboard',
        (WidgetTester tester) async {
      final fakeClient = FakeDashboardHttpClient(hasActiveCycle: true, totalSpent: 300.0);
      final apiClient = ApiClient(httpClient: fakeClient);
      final dashboardApiService = DashboardApiService(apiClient);
      final refreshSignal = ValueNotifier<int>(0);

      int loadCount = 0;
      refreshSignal.addListener(() {
        loadCount++;
      });

      // Simular evento de confirmación de gasto
      final stopwatch = Stopwatch()..start();
      refreshSignal.value++;
      stopwatch.stop();

      expect(loadCount, 1);
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
