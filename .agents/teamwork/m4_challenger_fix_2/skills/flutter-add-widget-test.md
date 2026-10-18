# Flutter Add Widget Test
Source: C:\Users\totto\.gemini\config\plugins\flutter\skills\flutter-add-widget-test\SKILL.md

## Methodology
- Use `testWidgets` with `WidgetTester` to verify UI rendering, interaction, state transitions, and asynchronous operations.
- Control virtual clock using `tester.pump()` and `tester.pumpAndSettle()`.
- Use explicit finders (`find.byKey`, `find.text`, `find.byType`) and matchers (`findsOneWidget`, `findsNothing`).
- Measure asynchronous latency and reactive UI changes without page reloads.
