# Handoff Report: Explorer Survey Mobile

## 1. Observation

1. **Navigation Entrypoint & Placeholder**:
   - `e:\Projects\quincena-app\quincena\lib\main.dart:113`:
     ```dart
     final screens = [
       HomeScreen(
         dashboardApiService: _dashboardApiService,
         onOpenProfile: () => setState(() => _currentIndex = 3),
         onScanReceipt: () { ... },
       ),
       const PlaceholderView(title: 'Presupuestos Quincenales'), // <-- Tab index 1
       const PlaceholderView(title: 'Historial de Transacciones'),
       ProfileScreen( ... ),
     ];
     ```
   - `e:\Projects\quincena-app\quincena\lib\core\components\navigation\app_bottom_nav_bar.dart:42-46`: Tab index 1 corresponds to `label: 'Presupuesto'`, icon `Icons.account_balance_wallet_outlined`.
   - `PlaceholderView` is a static placeholder widget displaying the title centered in a subtle scaffold.

2. **State Management & Services Pattern**:
   - The Flutter project does not use Riverpod, Bloc, or Provider packages. Dependencies in `quincena/pubspec.yaml` (lines 30-39) are exclusively:
     ```yaml
     dependencies:
       flutter:
         sdk: flutter
       cupertino_icons: ^1.0.8
       google_fonts: ^9.0.0
       http: ^1.2.0
     ```
   - Screens use native `StatefulWidget` with `setState`, `FutureBuilder`, and `showModalBottomSheet`.
   - Global session is managed by `AuthSessionManager extends ChangeNotifier` in `lib/features/auth/data/auth_session_manager.dart`.
   - Dedicated API service classes instantiate with `ApiClient` (`DashboardApiService`, `FinancialAccountsApiService`).
   - `ApiClient` in `lib/core/network/api_client.dart` provides typed `get`, `post`, `patch`, `delete` methods with JWT Bearer handling and `ApiException` error parsing.

3. **Existing Models & Feature Packages**:
   - Existing models located at:
     - `lib/features/financial_accounts/models/financial_account.dart` (`FinancialAccount`, `AccountType`)
     - `lib/features/dashboard/data/models/dashboard_data.dart` (`DashboardCycle`, `DashboardSummary`, `DashboardCategory`, `SuggestedPeriod`)
     - `lib/features/auth/data/models/` (`AuthUser`, `AuthTokens`)
     - `lib/features/profile/data/models/` (`UserProfile`)
   - There are currently no models or services for `BudgetAllocation`, `BudgetTemplate`, or `Category` in `quincena/lib/`.

4. **Design System Tokens & Components**:
   - `lib/core/theme/app_colors.dart`:
     - Primary brand & active bar < 70%: `Color(0xFF79ADDC)`
     - Warning threshold 70-90%: `Color(0xFFFFEE93)`
     - Critical / deficit / expense > 90%: `Color(0xFFFFC09F)`
     - Income & balanced indicator: `Color(0xFFADF7B6)`
     - Hero card surface: `Color(0xFFFCF5C7)`
     - Text main: `Color(0xFF1C242B)`
     - Border subtle: `Color(0xFFE2E6EA)`
   - `lib/core/theme/app_typography.dart`: Plus Jakarta Sans with `FontFeature.tabularFigures()` on all monetary styles (`currencyHero`, `currencyHeroMobile`, `currencyMd`, `numericRow`).
   - Reusable components ready in `lib/core/components/`: `AppProgressBar` (with dynamic 70%/90% pastel coloring), `AppAmountInput` (tabular currency input), `AppHeroCard`, `AppCard`, `AppButton`, `AppBadge`, `AppAppBar`.

5. **Tooling & Test Analysis**:
   - Executing `flutter analyze` in `quincena/`:
     ```
     error - The name 'MyApp' isn't a class. Try correcting the name to match an existing class - test\widget_test.dart:16:35 - creation_with_non_type
     1 issue found.
     ```
     `lib/` contains 0 errors and 0 warnings.
   - Executing `flutter test` in `quincena/`:
     Failed at `test/widget_test.dart:16:35: Error: Couldn't find constructor 'MyApp'`.
   - Executing `npm run build` in `quincena-api/`:
     Exited with code 0 (clean TypeScript build).

6. **Database Schema & Backend API**:
   - `supabase/migrations/20261016000001_initial_schema.sql`:
     - `budget_allocations` (lines 108-118) has columns: `id`, `cycle_id`, `category_id`, `destination_account_id` (FK to `financial_accounts`), `allocated_amount`, with unique constraint `(cycle_id, category_id)`.
     - `budget_templates` (lines 92-103) has columns: `id`, `user_id`, `period` (`first_half` | `second_half`), `category_id`, `destination_account_id`, `default_amount`, with unique constraint `(user_id, period, category_id)`.
   - Backend controllers in `quincena-api/`:
     - `budget-allocations.controller.ts`: supports `GET /budget-allocations?cycleId=...` (returns enriched allocations + summary with `unallocated`), `POST /budget-allocations`, `PATCH /budget-allocations/:id`, `DELETE /budget-allocations/:id`.
     - `budget-templates.controller.ts`: supports `GET /budget-templates?period=...`, `POST /budget-templates`, `PATCH /budget-templates/:id`, `DELETE /budget-templates/:id`.

---

## 2. Logic Chain

1. From **Observation 1**, `PlaceholderView(title: 'Presupuestos Quincenales')` at index 1 of `MainShell` in `lib/main.dart` is the precise point where the new budget screen (`BudgetScreen`) must be integrated.
2. From **Observation 2**, the application enforces vanilla Flutter state architecture with service-layer decoupling. Therefore, the implementation of RF-03 and RF-04 should follow the exact pattern established by `FinancialAccountsScreen` and `HomeScreen`: a dedicated service (`BudgetApiService`) consuming `ApiClient`, coupled with stateful screen and modular bottom sheets (`showModalBottomSheet`) for form inputs.
3. From **Observation 4**, all design tokens and UI widgets needed for RF-03 (Hero Card with "Por Asignar", progress bars with dynamic color coding at 70% and 90%, tabular number inputs) are already present and tested in `core/theme/` and `core/components/`. No additional UI primitives need to be designed from scratch.
4. From **Observation 5**, the only linter and test failure is an obsolete boilerplate test in `test/widget_test.dart`. Fixing this and adding targeted tests for Zero-Base calculations and template application will achieve 100% clean test and analysis status.
5. From **Observation 6**, both `budget_allocations` and `budget_templates` already have `destination_account_id` in Postgres DDL and NestJS DTOs. For RF-04 operations ("Aplicar plantilla predefinida" and "Guardar ciclo actual como plantilla"), adding two endpoints to `quincena-api` (`POST /budget-templates/apply` and `POST /budget-templates/save-from-cycle`) will provide atomic, transactional server-side execution, which the Flutter `BudgetApiService` can consume seamlessly.

---

## 3. Caveats

- In `budget-templates.service.ts` line 27 of `quincena-api`, the query `select('*, categories(id, name, icon, color_hex)')` does not join `destination_account:financial_accounts(id, name, color_hex)`. Adding this join ensures the frontend receives the destination account metadata directly in template lists without client-side manual joins.
- No offline caching layer was requested in the prompt; data fetching directly against `ApiClient` conforms to the existing pattern of the app.

---

## 4. Conclusion

The `quincena` Flutter codebase is well-structured, modular, and ready for the implementation of RF-03 and RF-04. The plan is clear:
1. Create `quincena/lib/features/budget/`:
   - Models: `budget_allocation.dart` (`BudgetAllocation`, `AllocationsSummary`, `FundingAccountSummary`), `budget_template.dart` (`BudgetTemplate`, `QuincenaPeriod`), `category.dart` (`Category`).
   - Service: `budget_api_service.dart`.
   - UI: `budget_screen.dart`, `zero_base_header_card.dart`, `funding_accounts_summary.dart`, `allocation_item_tile.dart`, `allocation_form_sheet.dart`, `templates_tab_view.dart`, `template_form_sheet.dart`.
2. Update `quincena/lib/main.dart` line 113 to mount `BudgetScreen`.
3. Fix `test/widget_test.dart` and add `zero_base_calculation_test.dart` and `budget_screen_test.dart`.
4. Add the two atomic helper endpoints in `quincena-api/src/modules/budget-templates/` (`apply` and `save-from-cycle`).

All details have been documented in `report.md`.

---

## 5. Verification Method

1. **Flutter Analysis**:
   ```bash
   cd e:\Projects\quincena-app\quincena
   flutter analyze
   ```
   *Expected*: Once `widget_test.dart` is corrected, 0 issues found.
2. **Flutter Test Suite**:
   ```bash
   cd e:\Projects\quincena-app\quincena
   flutter test
   ```
   *Expected*: All tests pass.
3. **Backend Compilation**:
   ```bash
   cd e:\Projects\quincena-app\quincena-api
   npm run build
   ```
   *Expected*: Build succeeds with code 0.
4. **Visual Inspection**:
   Inspect `quincena/lib/main.dart:113` to confirm `PlaceholderView` replacement, and check that `BudgetScreen` renders tabs for `Distribución Quincenal` and `Plantillas Quincenales (1ra y 2da Quincena)`.
