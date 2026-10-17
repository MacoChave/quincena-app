# Dispatch: Explorer Mobile

## Objective
Investigate the Flutter mobile application (`e:\Projects\quincena-app\quincena`) to understand its architecture, navigation, state management, design system, and existing integration with backend APIs.

## Scope & Tasks
1. Read `e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md`.
2. Inspect `quincena/lib`:
   - Locate `MainShell` and where the `PlaceholderView` for Presupuestos Quincenales is located.
   - Analyze state management architecture (Provider, Riverpod, Bloc, ChangeNotifier, etc.).
   - Inspect `ApiClient` / HTTP services: how authentication tokens are handled, how requests are made to `quincena-api`.
   - Inspect existing models: Cycle, Category, FinancialAccount, Allocation, etc.
   - Inspect design system: typography (tabular figures), color palette (`#79ADDC` for <70%, `#FFEE93` for 70-90%, `#FFC09F` for >90%/deficit), theme tokens, reusable widgets (cards, buttons, inputs).
3. Check tooling & quality:
   - Check `flutter analyze` and `flutter test` command setup.
   - Identify existing test conventions in `quincena/test`.
4. Document the architecture, files to be created/modified, and concrete design recommendations for RF-03 (Distribution & Base Zero view) and RF-04 (1ra/2da Quincena templates view).
5. Write your detailed findings in `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_mobile\report.md` and complete with `handoff.md`.

## 2026-10-17T03:52:41Z
Received message from b55e68a7-e802-4dba-a48c-1f79ad9d2856:
You are a codebase explorer.
Your working directory is: e:\Projects\quincena-app\.agents\teamwork\explorer_survey_mobile
You MUST first read ORIGINAL_REQUEST.md at: e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md
Also read your instructions in: e:\Projects\quincena-app\.agents\teamwork\explorer_survey_mobile\DISPATCH.md

Your goal is to thoroughly inspect `e:\Projects\quincena-app\quincena` (Flutter app):
1. Main navigation and shell (`MainShell` / navigation bar tabs, find where Presupuestos Quincenales / `PlaceholderView` is located).
2. Existing architecture & patterns: state management (Provider, Riverpod, Bloc, etc.), service layer (`ApiClient`, Supabase client, etc.), models (Cycle, Category, FinancialAccount, Allocation, etc.).
3. Theme and design system tokens: colors (`#79ADDC`, `#FFEE93`, `#FFC09F`), typography (tabular figures), card styles, input styles, buttons.
4. Tooling & current status: run `flutter analyze` and `flutter test` in `quincena/` and document any existing errors, warnings, or test results.
5. Identify the exact files that need to be created or modified for RF-03 (Distribución Quincenal y Presupuestos Base Cero) and RF-04 (Plantillas 1ra y 2da Quincena).

