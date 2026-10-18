import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/features/budget/data/models/models.dart';
import 'package:quincena/features/budget/presentation/widgets/template_item_form_sheet.dart';
import 'package:quincena/features/categories/data/categories_api_service.dart';
import 'package:quincena/features/categories/presentation/categories_screen.dart';
import 'package:quincena/features/categories/presentation/widgets/category_form_sheet.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';

/// Fake HTTP Client para simular /categories y /financial-accounts
class FakeCategoriesHttpClient extends http.BaseClient {
  List<Map<String, dynamic>> categoriesDb = [
    {
      'id': 'cat-1',
      'name': 'Supermercado',
      'icon': 'shopping_cart',
      'color_hex': '#ADF7B6',
      'default_account_id': 'acc-1',
      'is_archived': false,
      'default_account': {
        'id': 'acc-1',
        'name': 'Monetaria BAC',
        'account_type': 'checking',
        'currency': 'GTQ',
        'color_hex': '#79ADDC',
        'icon': 'account_balance',
      },
    },
    {
      'id': 'cat-2',
      'name': 'Renta y Hogar',
      'icon': 'home',
      'color_hex': '#79ADDC',
      'default_account_id': 'acc-1',
      'is_archived': false,
      'default_account': {
        'id': 'acc-1',
        'name': 'Monetaria BAC',
        'account_type': 'checking',
        'currency': 'GTQ',
        'color_hex': '#79ADDC',
        'icon': 'account_balance',
      },
    },
    {
      'id': 'cat-3',
      'name': 'Ahorro Fondo Emergencia',
      'icon': 'savings',
      'color_hex': '#FCF5C7',
      'default_account_id': 'acc-2',
      'is_archived': false,
      'default_account': {
        'id': 'acc-2',
        'name': 'Billetera Efectivo',
        'account_type': 'cash',
        'currency': 'GTQ',
        'color_hex': '#ADF7B6',
        'icon': 'payments',
      },
    },
  ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final method = request.method;

    if (path.endsWith('/categories') && method == 'GET') {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(categoriesDb))),
        200,
      );
    } else if (path.endsWith('/financial-accounts') && method == 'GET') {
      return http.StreamedResponse(
        Stream.value(
          utf8.encode(
            jsonEncode([
              {
                'id': 'acc-1',
                'name': 'Monetaria BAC',
                'account_type': 'checking',
                'currency': 'GTQ',
                'color_hex': '#79ADDC',
                'icon': 'account_balance',
                'is_default': true,
                'is_archived': false,
                'initial_balance': 2500.0,
                'current_balance': 2500.0,
              },
              {
                'id': 'acc-2',
                'name': 'Billetera Efectivo',
                'account_type': 'cash',
                'currency': 'GTQ',
                'color_hex': '#ADF7B6',
                'icon': 'payments',
                'is_default': false,
                'is_archived': false,
                'initial_balance': 300.0,
                'current_balance': 300.0,
              },
            ]),
          ),
        ),
        200,
      );
    } else if (path.endsWith('/categories') && method == 'POST') {
      final byteStream = request.finalize();
      final bodyStr = await byteStream.bytesToString();
      final body = jsonDecode(bodyStr) as Map<String, dynamic>;
      final newCat = {
        'id': 'cat-new-123',
        'name': body['name'],
        'icon': body['icon'] ?? 'category',
        'color_hex': body['color_hex'] ?? '#79ADDC',
        'default_account_id': body['default_account_id'],
        'is_archived': false,
      };
      categoriesDb.add(newCat);
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(newCat))),
        201,
      );
    } else if (path.contains('/categories/') && method == 'DELETE') {
      final id = path.split('/').last;
      categoriesDb.removeWhere((c) => c['id'] == id);
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'success': true}))),
        200,
      );
    }

    return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200);
  }
}

void main() {
  late ApiClient apiClient;
  late FakeCategoriesHttpClient fakeHttp;

  setUp(() {
    fakeHttp = FakeCategoriesHttpClient();
    apiClient = ApiClient(
      baseUrl: 'http://localhost:3000',
      httpClient: fakeHttp,
    );
    apiClient.setAuthToken('mock-token');
  });

  group('CategoriesApiService Unit Tests (RF-CAT-01)', () {
    test('getCategories retorna lista de categorías', () async {
      final service = CategoriesApiService(apiClient);
      final categories = await service.getCategories();
      expect(categories.length, 3);
      expect(categories.first.name, 'Supermercado');
      expect(categories.first.defaultAccount?.name, 'Monetaria BAC');
    });

    test('createCategory crea exitosamente', () async {
      final service = CategoriesApiService(apiClient);
      final created = await service.createCategory(
        name: 'Gimnasio & Bienestar',
        icon: 'fitness_center',
        colorHex: '#ADF7B6',
        defaultAccountId: 'acc-1',
      );
      expect(created.name, 'Gimnasio & Bienestar');
      expect(created.icon, 'fitness_center');
      expect(created.colorHex, '#ADF7B6');
    });
  });

  group('Screen C1: CategoriesScreen Widget Tests', () {
    testWidgets('Renderiza lista de categorías, buscador y filtros', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(apiClient: apiClient),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar títulos y buscador
      expect(find.text('Mantenimiento de Categorías'), findsOneWidget);
      expect(find.text('Categorías'), findsOneWidget);
      expect(find.text('3 activas'), findsOneWidget);
      expect(find.text('Supermercado'), findsOneWidget);
      expect(find.text('Renta y Hogar'), findsOneWidget);
      expect(find.text('Ahorro Fondo Emergencia'), findsOneWidget);

      // Probar filtro rápido por categoría
      await tester.tap(find.text('Fijas'));
      await tester.pumpAndSettle();
      expect(find.text('Renta y Hogar'), findsOneWidget);
      expect(find.text('Supermercado'), findsNothing);

      // Volver a Todas
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('Supermercado'), findsOneWidget);

      // Probar buscador
      await tester.enterText(find.byType(TextField).first, 'Ahorro');
      await tester.pumpAndSettle();
      expect(find.text('Ahorro Fondo Emergencia'), findsOneWidget);
      expect(find.text('Supermercado'), findsNothing);
    });
  });

  group('Screen C2: CategoryFormSheet Widget Tests', () {
    testWidgets('Live preview se actualiza al escribir y valida campos obligatorios', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool onSaveCalled = false;
      final accounts = [
        const FinancialAccount(
          id: 'acc-1',
          name: 'Monetaria BAC',
          accountType: AccountType.checking,
          currency: 'GTQ',
          colorHex: '#79ADDC',
          icon: 'account_balance',
          isDefault: true,
          isArchived: false,
          initialBalance: 2000,
          currentBalance: 2000,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryFormSheet(
              accounts: accounts,
              onSave: ({
                required String name,
                required String icon,
                required String colorHex,
                String? defaultAccountId,
              }) async {
                onSaveCalled = true;
                return Category(
                  id: 'cat-test',
                  name: name,
                  icon: icon,
                  colorHex: colorHex,
                  defaultAccountId: defaultAccountId,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nueva Categoría'), findsOneWidget);
      expect(find.text('VISTA PREVIA INSTANTÁNEA'), findsOneWidget);

      // Ingresar nombre
      final nameField = find.widgetWithText(TextField, 'Ej. Supermercado, Gimnasio, Renta');
      await tester.enterText(nameField, 'Transporte Urbano');
      await tester.pumpAndSettle();

      expect(find.text('Transporte Urbano'), findsNWidgets(2)); // Input + Preview

      // Seleccionar icono
      await tester.tap(find.byIcon(Icons.directions_car_rounded));
      await tester.pumpAndSettle();

      // Guardar
      await tester.ensureVisible(find.text('Crear Categoría'));
      await tester.tap(find.text('Crear Categoría'));
      await tester.pumpAndSettle();

      expect(onSaveCalled, isTrue);
    });
  });

  group('Screen C3: TemplateItemFormSheet Widget Tests (RF-PLANT-02)', () {
    final categories = [
      const Category(
        id: 'cat-1',
        name: 'Supermercado',
        icon: 'shopping_cart',
        colorHex: '#ADF7B6',
        defaultAccountId: 'acc-1',
      ),
      const Category(
        id: 'cat-2',
        name: 'Transporte',
        icon: 'directions_car',
        colorHex: '#FFC09F',
      ),
    ];

    final accounts = [
      const FinancialAccount(
        id: 'acc-1',
        name: 'Monetaria BAC',
        accountType: AccountType.checking,
        currency: 'GTQ',
        colorHex: '#79ADDC',
        icon: 'account_balance',
        isDefault: true,
        isArchived: false,
        initialBalance: 2000,
        currentBalance: 2000,
      ),
    ];

    testWidgets('Previene duplicidad de categoría en la misma plantilla (CA-P2.2)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final List<BudgetTemplate> existingTemplates = [
        BudgetTemplate(
          id: 't-1',
          period: QuincenaPeriod.firstHalf,
          categoryId: 'cat-1',
          defaultAmount: 400.0,
          category: categories[0],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TemplateItemFormSheet(
              period: QuincenaPeriod.firstHalf,
              existingTemplates: existingTemplates,
              categories: categories,
              accounts: accounts,
              estimatedIncome: 3000.0,
              onSave: ({
                required QuincenaPeriod period,
                required String categoryId,
                required double defaultAmount,
                String? destinationAccountId,
              }) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Por defecto selecciona la disponible (cat-2: Transporte)
      expect(find.text('Transporte'), findsOneWidget);

      // Abrir menú de categoría y seleccionar Supermercado (que ya existe)
      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Supermercado').last);
      await tester.pumpAndSettle();

      // Debe mostrar advertencia de duplicidad (CA-P2.2)
      expect(find.textContaining('Esta categoría ya está agregada'), findsOneWidget);
    });

    testWidgets('Chips de incremento rápido ajustan el monto base', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TemplateItemFormSheet(
              period: QuincenaPeriod.firstHalf,
              existingTemplates: const [],
              categories: categories,
              accounts: accounts,
              estimatedIncome: 3000.0,
              onSave: ({
                required QuincenaPeriod period,
                required String categoryId,
                required double defaultAmount,
                String? destinationAccountId,
              }) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Click en +$100
      await tester.tap(find.text('+\$100'));
      await tester.pumpAndSettle();

      expect(find.text('100.00'), findsOneWidget);

      // Click en +$50 -> 150.00
      await tester.tap(find.text('+\$50'));
      await tester.pumpAndSettle();

      expect(find.text('150.00'), findsOneWidget);
    });
  });
}
