# Project: Quincena - RF-03 y RF-04 (Distribución Quincenal y Presupuestos Base Cero)

## Architecture
- **Backend**: NestJS REST API (`quincena-api`) using `@supabase/supabase-js`, TypeScript, class-validator DTOs with `whitelist: true, forbidNonWhitelisted: true`.
- **Database**: Supabase / PostgreSQL schemas (`budget_allocations`, `budget_templates`, `biweekly_cycles`, `financial_accounts`, `categories`).
- **Mobile App**: Flutter (`quincena`) with clean feature structure under `lib/features/budget/`, consuming `ApiClient` (`http`), standard `StatefulWidget` / `ChangeNotifier` reactive state, design system tokens in `AppColors` and `AppTypography`.
- **Navigation Shell**: `MainShell` in `lib/main.dart` displaying `BudgetScreen` at tab index 1 (`AppBottomNavBar`).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Backend DTOs & Validation | Support `destination_account_id` and alias `financial_account_id` in allocation and template DTOs | M1 | Survey Backend |
| 2 | Backend Template Account Join | Enrich `GET /budget-templates` to join `destination_account:financial_accounts(id, name, color_hex)` | M1 | Survey Backend |
| 3 | Backend Apply Template Endpoint | Atomic endpoint `POST /budget-templates/apply` to preload template items into active cycle | M1 | Survey Backend |
| 4 | Backend Save Cycle as Template Endpoint | Atomic endpoint `POST /budget-templates/save-from-cycle` to update master template from cycle allocations | M1 | Survey Backend |
| 5 | Mobile Data Models | Define `BudgetAllocation`, `BudgetTemplate`, `Category`, `FundingAccountSummary`, `ZeroBaseSummary` | M2 | Survey Mobile |
| 6 | Mobile Budget API Service | Implement `BudgetApiService` with methods for cycle allocations, templates, apply, and save-from-cycle | M2 | Survey Mobile |
| 7 | Real-time Zero-Base Calculation | Dynamic "Por Asignar" calculation (`total_income - sum(allocations)`) with <16ms reactive updates | M3 | ORIGINAL_REQUEST R1 |
| 8 | Pastel Semaphorization Badges | Zero-base badge (`#ADF7B6` for $0.00, `#79ADDC` for surplus, `#FFC09F` for deficit) and progress bars (<70% `#79ADDC`, 70-90% `#FFEE93`, >90% `#FFC09F`) with WCAG AA `#1C242B` text | M3 | ORIGINAL_REQUEST R1, Spec Survey |
| 9 | Funding Account Summary | Group allocations by funding financial account (`destination_account_id`), showing required funding vs balance | M3 | ORIGINAL_REQUEST R1 |
| 10 | Allocation CRUD UI | Interactive list with ability to create, edit, rebalance, and delete allocations with destination accounts | M3 | ORIGINAL_REQUEST R1 |
| 11 | Master Templates 1ra/2da Quincena Tabs | Segmented tab views `[1ra Quincena]` (`first_half`) and `[2da Quincena]` (`second_half`) | M4 | ORIGINAL_REQUEST R2 |
| 12 | Apply Template Flow | Flow to apply master template to active cycle with confirmation modal when allocations exist | M4 | ORIGINAL_REQUEST R2 |
| 13 | Save Current Cycle as Template Flow | Flow to snapshot current cycle allocations to master template without modifying closed cycles | M4 | ORIGINAL_REQUEST R2 |
| 14 | MainShell Navigation Integration | Replace `PlaceholderView` at tab index 1 in `quincena/lib/main.dart` with `BudgetScreen` | M4 | ORIGINAL_REQUEST R3 |
| 15 | Unit & Widget Tests | Unit tests verifying Zero-base math, deficit handling, template data, and widget smoke tests | M5 | Acceptance Criteria |
| 16 | Static Analysis & Verification | Zero errors/warnings in `flutter analyze`, clean `npm run build` and `npm run test` in `quincena-api` | M5 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Backend API Enhancements | DTOs, join enrichment, atomic apply & save endpoints, node_modules test fix in `quincena-api` | none | DONE |
| M2 | Mobile Data & Service Layer | Models (`budget_allocation.dart`, `budget_template.dart`, `category.dart`) & `BudgetApiService` | M1 | DONE |
| M3 | Mobile RF-03 UI (Base Cero & Fondeo) | `ZeroBaseHeaderCard`, `FundingAccountsSummary`, `AllocationItemTile`, `AllocationFormSheet` | M2 | DONE |
| M4 | Mobile RF-04 UI & MainShell Navigation | `TemplatesTabView`, `TemplateFormSheet`, apply/save actions, mount in `MainShell` | M3 | DONE |
| M5 | Test Suite, Verification & Audit | Flutter tests, fix `widget_test.dart`, `flutter analyze`, backend tests, adversarial & forensic audit | M4 | DONE |

## Interface Contracts

### 1. `quincena-api` ↔ `quincena` (REST Endpoints)
- `GET /budget-allocations?cycleId={id}`: Enriched allocations + summary with `unallocated` and `is_balanced`.
- `POST /budget-allocations`: Creates allocation; accepts `destination_account_id` and `financial_account_id`.
- `PATCH /budget-allocations/:id`: Updates allocation.
- `DELETE /budget-allocations/:id`: Removes allocation.
- `GET /budget-templates?period={first_half|second_half}`: Enriched with `destination_account:financial_accounts(id, name, color_hex, icon)`.
- `POST /budget-templates`: Creates master template item.
- `PATCH /budget-templates/:id`: Updates template item.
- `DELETE /budget-templates/:id`: Deletes template item.
- `POST /budget-templates/apply`: Atomic copy into active cycle.
- `POST /budget-templates/save-from-cycle`: Atomic snapshot into master template.

## Code Layout

### Backend (`quincena-api`)
- `src/modules/budget-allocations/`: DTOs, service, controller, unit tests
- `src/modules/budget-templates/`: DTOs, service, controller, unit tests

### Mobile (`quincena`)
- `lib/features/budget/`:
  - `data/models/`: `budget_allocation.dart`, `budget_template.dart`, `category.dart`, `funding_account_summary.dart`, `models.dart`
  - `data/services/`: `budget_api_service.dart`
  - `presentation/notifiers/`: `budget_notifier.dart`
  - `presentation/budget_screen.dart`: Main budget screen with segmented tabs
  - `presentation/widgets/`: `zero_base_header_card.dart`, `funding_accounts_summary.dart`, `allocation_item_tile.dart`, `allocation_form_sheet.dart`, `templates_tab_view.dart`, `template_form_sheet.dart`
- `lib/main.dart`: mounted `BudgetScreen` at index 1 of `MainShell`
- `test/features/budget/`:
  - `zero_base_calculation_test.dart` (baseline unit tests)
  - `budget_template_test.dart` (template model tests)
  - `budget_screen_test.dart` (widget tests)
  - `zero_base_adversarial_test.dart` (25 stress & boundary tests)
  - `templates_and_workflow_invariants_challenge_test.dart` (7 invariant tests)
