import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/core/network/api_client.dart';
import 'package:quincena/features/auth/data/auth_session_manager.dart';
import 'package:quincena/main.dart';

void main() {
  testWidgets('QuincenaApp initializes and renders AuthGate smoke test',
      (WidgetTester tester) async {
    final apiClient = ApiClient();
    final sessionManager = AuthSessionManager(apiClient: apiClient);

    await tester.pumpWidget(
      QuincenaApp(
        apiClient: apiClient,
        sessionManager: sessionManager,
      ),
    );

    // Verify MaterialApp renders cleanly
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
