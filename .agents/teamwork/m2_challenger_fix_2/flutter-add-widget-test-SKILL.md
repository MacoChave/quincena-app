# Writing Flutter Widget Tests (Local Skill Copy)

## Core Components
- `WidgetTester`: Primary interface for building and interacting with widgets.
- `Finder`: Locates widgets (e.g. `find.text()`, `find.byType()`, `find.byKey()`).
- `Matcher`: Verifies presence/state (`findsOneWidget`, `findsNothing`, `findsNWidgets(n)`).

## Workflow
1. Define test with `testWidgets(...)`
2. `await tester.pumpWidget(...)` with MaterialApp wrapper.
3. Locate elements with finders.
4. Verify initial state.
5. Simulate interaction (tap, enterText, etc.).
6. Rebuild tree (`tester.pump()` or `tester.pumpAndSettle()`).
7. Verify state with `expect()`.
