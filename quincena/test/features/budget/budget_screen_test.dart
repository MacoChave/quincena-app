import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/features/budget/data/models/models.dart';
import 'package:quincena/features/budget/presentation/budget_screen.dart';
import 'package:quincena/features/budget/presentation/widgets/funding_accounts_summary.dart';
import 'package:quincena/features/budget/presentation/widgets/zero_base_header_card.dart';
import 'package:quincena/features/dashboard/data/models/dashboard_data.dart';
import 'package:quincena/features/financial_accounts/models/financial_account.dart';

/// Fake HTTP client para simular respuestas REST de quincena-api en widget tests
class FakeBudgetHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final query = request.url.query;

    String responseBody = '{}';
    int statusCode = 200;

    if (path.contains('/biweekly-cycles/current')) {
      responseBody = jsonEncode({
        'id': 'cycle-test-1',
        'year': 2026,
        'month': 10,
        'period': 'first_half',
        'start_date': '2026-10-01',
        'end_date': '2026-10-15',
        'total_income': 3000.0,
        'is_closed': false,
      });
    } else if (path.contains('/categories')) {
      responseBody = jsonEncode([
        {
          'id': 'cat-1',
          'name': 'Alimentación',
          'icon': 'restaurant',
          'color_hex': '#79ADDC',
        },
        {
          'id': 'cat-2',
          'name': 'Vivienda',
          'icon': 'home',
          'color_hex': '#ADF7B6',
        },
      ]);
    } else if (path.contains('/financial-accounts')) {
      responseBody = jsonEncode([
        {
          'id': 'acc-1',
          'name': 'Banco Principal',
          'account_type': 'checking',
          'currency': 'GTQ',
          'color_hex': '#79ADDC',
          'icon': 'account_balance',
          'is_default': true,
          'is_archived': false,
          'initial_balance': 2000.0,
          'current_balance': 2000.0,
        },
      ]);
    } else if (path.contains('/budget-allocations')) {
      responseBody = jsonEncode({
        'allocations': [
          {
            'id': 'alloc-1',
            'cycle_id': 'cycle-test-1',
            'category_id': 'cat-1',
            'destination_account_id': 'acc-1',
            'allocated_amount': 1000.0,
            'spent_amount': 300.0,
            'categories': {
              'id': 'cat-1',
              'name': 'Alimentación',
              'icon': 'restaurant',
              'color_hex': '#79ADDC',
            },
            'destination_account': {
              'id': 'acc-1',
              'name': 'Banco Principal',
              'color_hex': '#79ADDC',
              'icon': 'account_balance',
            },
          },
        ],
        'summary': {
          'total_income': 3000.0,
          'total_allocated': 1000.0,
          'unallocated': 2000.0,
          'total_spent': 300.0,
          'total_available': 700.0,
          'is_balanced': false,
          'is_closed': false,
        },
      });
    } else if (path.contains('/budget-templates')) {
      if (query.contains('second_half')) {
        responseBody = jsonEncode([
          {
            'id': 'tmpl-2',
            'period': 'second_half',
            'category_id': 'cat-2',
            'default_amount': 1500.0,
            'categories': {
              'id': 'cat-2',
              'name': 'Vivienda',
              'icon': 'home',
              'color_hex': '#ADF7B6',
            },
          },
        ]);
      } else {
        responseBody = jsonEncode([
          {
            'id': 'tmpl-1',
            'period': 'first_half',
            'category_id': 'cat-1',
            'default_amount': 1000.0,
            'categories': {
              'id': 'cat-1',
              'name': 'Alimentación',
              'icon': 'restaurant',
              'color_hex': '#79ADDC',
            },
          },
        ]);
      }
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(responseBody)),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('ZeroBaseHeaderCard Widget Tests (RF-03)', () {
    testWidgets('Renders Base Cero \$0.00 with green badge when balanced',
        (WidgetTester tester) async {
      const summary = AllocationsSummary(
        totalIncome: 2500.0,
        totalAllocated: 2500.0,
        unallocated: 0.0,
        isBalanced: true,
      );

      final cycle = DashboardCycle(
        id: 'c1',
        year: 2026,
        month: 10,
        period: 'first_half',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 15),
        totalIncome: 2500.0,
        isClosed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZeroBaseHeaderCard(
              summary: summary,
              cycle: cycle,
            ),
          ),
        ),
      );

      expect(find.text('POR ASIGNAR (BASE CERO)'), findsOneWidget);
      expect(find.text('Base Cero: \$0.00'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.textContaining('¡Presupuesto Base Cero logrado!'), findsOneWidget);
    });

    testWidgets('Renders Deficit in coral badge when over-allocated',
        (WidgetTester tester) async {
      const summary = AllocationsSummary(
        totalIncome: 2000.0,
        totalAllocated: 2350.0,
        unallocated: -350.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZeroBaseHeaderCard(
              summary: summary,
            ),
          ),
        ),
      );

      expect(find.text('Déficit: -\$350.00'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('Has asignado más de tu ingreso quincenal'), findsOneWidget);
    });
  });

  group('FundingAccountsSummarySection Widget Tests', () {
    testWidgets('Renders funding accounts with covered status',
        (WidgetTester tester) async {
      const acc = FinancialAccount(
        id: 'acc1',
        name: 'Cuenta Principal',
        accountType: AccountType.checking,
        currency: 'GTQ',
        colorHex: '#79ADDC',
        icon: 'account_balance',
        isDefault: true,
        isArchived: false,
        initialBalance: 1000.0,
        currentBalance: 1200.0,
      );

      final summary = FundingAccountSummary(
        account: acc,
        totalAllocated: 800.0,
        allocations: const [
          BudgetAllocation(
            id: 'b1',
            cycleId: 'c1',
            categoryId: 'cat1',
            allocatedAmount: 800.0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FundingAccountsSummarySection(
              summaries: [summary],
            ),
          ),
        ),
      );

      expect(find.text('Cuentas de Fondeo de la Quincena'), findsOneWidget);
      expect(find.text('Cuenta Principal'), findsOneWidget);
      expect(find.text('Cubierto'), findsOneWidget);
    });
  });

  group('BudgetScreen Integration Widget Tests', () {
    testWidgets('Renders tabs and allows switching between distribution and templates',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeClient = FakeBudgetHttpClient();
      final apiClient = ApiClient(httpClient: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: BudgetScreen(apiClient: apiClient),
        ),
      );

      // Permite resolver los Futures iniciales
      await tester.pumpAndSettle();

      // Verifica encabezados y pestañas
      expect(find.text('Presupuestos Quincenales'), findsOneWidget);
      expect(find.text('Distribución Quincenal'), findsOneWidget);
      expect(find.text('Plantillas Maestras'), findsOneWidget);

      // Verifica tarjeta Hero en pestaña 0
      expect(find.text('POR ASIGNAR (BASE CERO)'), findsOneWidget);
      expect(find.text('Alimentación'), findsOneWidget);

      // Tap en la pestaña 1 [Plantillas Maestras]
      await tester.tap(find.text('Plantillas Maestras'));
      await tester.pumpAndSettle();

      // Verifica controles de plantillas
      expect(find.text('1ra Quincena'), findsOneWidget);
      expect(find.text('2da Quincena'), findsOneWidget);
      expect(find.text('TOTAL BASE PLANTILLA'), findsOneWidget);
      expect(find.text('Aplicar al ciclo'), findsOneWidget);
      expect(find.text('Guardar ciclo'), findsOneWidget);

      // Tap en [2da Quincena]
      await tester.tap(find.text('2da Quincena'));
      await tester.pumpAndSettle();

      expect(find.text('Vivienda'), findsOneWidget);
    });
  });
}
