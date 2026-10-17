# Dispatch: Mobile Worker (RF-03 & RF-04 Implementation)

## Objective
Implement end-to-end the mobile features for **Distribución Quincenal y Presupuestos Base Cero (RF-03)** and **Plantillas 1ra y 2da Quincena (RF-04)** in `quincena/`, connect them to `quincena-api`, mount `BudgetScreen` in `MainShell`, and ensure clean `flutter analyze` and passing unit/widget tests.

## Mandatory Reading
- `e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md`
- `e:\Projects\quincena-app\PROJECT.md`
- `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_mobile\report.md`
- `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_mobile\handoff.md`
- `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\report.md`
- `e:\Projects\quincena-app\.agents\teamwork\worker_m1_backend\handoff.md`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## File Ownership
You exclusively own and may edit files in:
`e:\Projects\quincena-app\quincena\lib\features\budget\` (new package)
`e:\Projects\quincena-app\quincena\lib\main.dart` (mount BudgetScreen in MainShell index 1)
`e:\Projects\quincena-app\quincena\test\` (fix widget_test.dart, add budget tests)

## Detailed Requirements

### 1. Data Models (`lib/features/budget/data/models/`)
- `category.dart`: `Category` with `id`, `name`, `icon`, `color_hex`.
- `budget_allocation.dart`: `BudgetAllocation` with `id`, `cycle_id`, `category_id`, `destination_account_id`, `allocated_amount`, `spent_amount`, `category` (joined), `destination_account` (joined). Also `AllocationsSummary` (`total_income`, `total_allocated`, `total_spent`, `unallocated`, `is_balanced`).
- `budget_template.dart`: `BudgetTemplate` with `id`, `period` (`QuincenaPeriod.first_half` / `QuincenaPeriod.second_half`), `category_id`, `destination_account_id`, `default_amount`, `category`, `destination_account`.
- `funding_account_summary.dart`: `FundingAccountSummary` representing grouped allocations by destination financial account: account name, type, color, total allocated/to fund, and comparison with current balance.

### 2. Service Layer (`lib/features/budget/data/services/budget_api_service.dart`)
- Method to fetch allocations for cycle: `GET /budget-allocations?cycleId=...`
- Method to create allocation: `POST /budget-allocations` (body includes `cycle_id`, `category_id`, `allocated_amount`, `destination_account_id`)
- Method to update allocation: `PATCH /budget-allocations/:id` (body includes `allocated_amount`, `destination_account_id`)
- Method to delete allocation: `DELETE /budget-allocations/:id`
- Method to fetch templates: `GET /budget-templates?period=first_half|second_half`
- Method to create template item: `POST /budget-templates`
- Method to update template item: `PATCH /budget-templates/:id`
- Method to delete template item: `DELETE /budget-templates/:id`
- Method to apply template: `POST /budget-templates/apply` with `{ cycle_id, overwrite }`
- Method to save cycle as template: `POST /budget-templates/save-from-cycle` with `{ cycle_id }`
- Helper methods to fetch active cycle (or reuse dashboard/cycle service) and financial accounts (`FinancialAccountsApiService` or `/financial-accounts`) and categories (`/categories`).

### 3. UI - RF-03 Distribución Quincenal y Presupuestos Base Cero
- Screen structure with Segmented Control / TabBar:
  * Tab 1: **"Distribución Quincenal"** (RF-03)
  * Tab 2: **"Plantillas Maestras"** (RF-04)
- **Zero-Based Budgeting Header Card (`zero_base_header_card.dart`)**:
  * Real-time "Por Asignar": `total_income - sum(allocated_amounts)`.
  * Dynamic Badge states:
    - Base Cero: `$0.00` -> Fondo `#ADF7B6` (verde pastel), texto `#1C242B` / `#236B31`, icono check.
    - Superávit: `>$0.00` -> Fondo `#79ADDC` o `#FCF5C7`, texto `#1C242B`.
    - Déficit / Sobreasignado: `<$0.00` -> Fondo `#FFC09F` (coral pastel), texto `#1C242B` / `#A33F19`, alerta visual de sobregiro.
  * Formatted with `FontFeature.tabularFigures()`.
- **Funding Account Summary Section (`funding_accounts_summary.dart`)**:
  * Aggregates allocations by destination financial account.
  * Shows card per account: icon, color, account name, Total to fund in this quincena.
  * Displays "Sin cuenta asignada / Efectivo" for allocations with null account.
- **Allocations List & Management**:
  * Shows each budget item (category name, icon, color, destination account tag/chip).
  * Progress bar with pastel semaphorization:
    - `<70%`: `#79ADDC`
    - `70%-90%`: `#FFEE93`
    - `>90%`: `#FFC09F`
  * Action button `+ Nueva Partida` opening bottom sheet (`allocation_form_sheet.dart`) to select category, enter amount, select destination account.
  * Edit & Delete actions for each allocation. Real-time recalculation of "Por Asignar" upon any change.

### 4. UI - RF-04 Plantillas 1ra y 2da Quincena
- Segmented tabs `[1ra Quincena]` (`first_half`) and `[2da Quincena]` (`second_half`).
- List of master template items per quincena with category, default amount, destination account.
- Action to create/edit/delete master template items.
- Action button **"Aplicar plantilla predefinida"**:
  * If active cycle has 0 allocations, applies directly.
  * If active cycle has existing allocations, shows confirmation dialog (Sobrescribir / Cancelar) before applying.
  * Preloads all template items into active cycle and refreshes distribution tab.
- Action button **"Guardar ciclo actual como plantilla"**:
  * Takes snapshot of active cycle allocations and saves as the master template for the current quincena.
  * Confirms with dialog and shows success snackbar.
  * Invariant: does not alter closed cycles.

### 5. Navigation Shell Integration
- In `quincena/lib/main.dart` line 113:
  Replace `const PlaceholderView(title: 'Presupuestos Quincenales')` with `BudgetScreen(apiClient: _apiClient, ...)`.
  Ensure `AppBottomNavBar` tab index 1 ('Presupuesto') renders `BudgetScreen`.

### 6. Testing & Quality
- Fix `quincena/test/widget_test.dart` (remove or fix invalid `MyApp` constructor).
- Add unit/widget tests in `quincena/test/features/budget/`:
  * `zero_base_calculation_test.dart`: verify exact formula, positive unallocated, exact $0.00 base zero, negative deficit.
  * `budget_template_test.dart`: verify template serialization, 1ra/2da quincena period enum mapping.
  * `budget_screen_test.dart`: widget test rendering tabs, Por Asignar card, and template switch.
- Run `flutter analyze` and ensure 0 errors and 0 severe warnings.
- Run `flutter test` and ensure all tests pass.

## Deliverables
- Complete code in `quincena/lib/features/budget/` and `quincena/lib/main.dart`
- Clean test suite in `quincena/test/`
- Report in `e:\Projects\quincena-app\.agents\teamwork\worker_mobile\report.md`
- Handoff in `e:\Projects\quincena-app\.agents\teamwork\worker_mobile\handoff.md`


## 2026-10-17T04:17:29Z
You are a Flutter mobile implementation worker.
Your working directory is: e:\Projects\quincena-app\.agents\teamwork\worker_mobile
You MUST read:
1. e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md
2. e:\Projects\quincena-app\PROJECT.md
3. e:\Projects\quincena-app\.agents\teamwork\worker_mobile\DISPATCH.md
4. e:\Projects\quincena-app\.agents\teamwork\explorer_survey_mobile\report.md
5. e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\report.md
6. e:\Projects\quincena-app\.agents\teamwork\worker_m1_backend\handoff.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

File ownership:
You own e:\Projects\quincena-app\quincena\lib\features\budget\, e:\Projects\quincena-app\quincena\lib\main.dart, and e:\Projects\quincena-app\quincena\test\.

Implement all tasks in DISPATCH.md:
1. Models: BudgetAllocation, AllocationsSummary, BudgetTemplate, QuincenaPeriod, Category, FundingAccountSummary.
2. Service: BudgetApiService with full REST integration to quincena-api (including /budget-templates/apply and /budget-templates/save-from-cycle).
3. UI RF-03: BudgetScreen with Zero-Base header card (dynamic Por Asignar with pastel badges: #ADF7B6 for $0.00, #79ADDC for surplus, #FFC09F for deficit, tabular figures), Funding Accounts summary cards, and Allocations list with pastel progress bars (<70% #79ADDC, 70-90% #FFEE93, >90% #FFC09F), creation/editing bottom sheets.
4. UI RF-04: Master templates tab with [1ra Quincena] and [2da Quincena], CRUD, "Aplicar plantilla predefinida" flow with confirmation, "Guardar ciclo actual como plantilla" flow.
5. Navigation: Mount BudgetScreen at tab 1 of MainShell in lib/main.dart replacing PlaceholderView.
6. Tests: Fix test/widget_test.dart and add comprehensive tests for zero-base calculation, templates, and widget rendering.
7. Verification: Run `flutter analyze` (0 errors, 0 warnings) and `flutter test`.

Write your full report to e:\Projects\quincena-app\.agents\teamwork\worker_mobile\report.md and handoff to e:\Projects\quincena-app\.agents\teamwork\worker_mobile\handoff.md.
Send a message to caller when done.
