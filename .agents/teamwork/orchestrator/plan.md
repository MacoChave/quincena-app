# Orchestration Plan - RF-03 & RF-04 Implementation

## Objective
Implement end-to-end the screen and functionality for **Distribución Quincenal y Presupuestos Base Cero (RF-03 y RF-04)** in Flutter (`quincena`), integrating with NestJS API (`quincena-api`) and Supabase DB.

## Phases

### Phase 0: Survey & Mapping (Parallel Explorers)
- **Explorer 1 (Backend & DB)**: Inspect `quincena-api` modules for `budget-allocations`, `budget-templates`, `cycles`, `financial-accounts`, DTOs, controllers, services, tests, and Supabase migrations.
- **Explorer 2 (Mobile App Architecture & State)**: Inspect `quincena` (Flutter) app structure: `MainShell`, navigation, state management (Provider/Riverpod/Bloc), existing ApiClient, models, design system colors/typography.
- **Explorer 3 (Spec & Requirements Verification)**: Analyze acceptance criteria for RF-03 and RF-04, check data structures for `budget_allocations` (financial_account_id, amount, category), `budget_templates` (1ra vs 2da quincena), real-time base zero calculation.

### Phase 1: Architecture & Decomposition (PROJECT.md)
- Consolidate explorer findings.
- Define milestones, write ownership, and interface contracts.
- Define test strategy.

### Phase 2: Milestone Iteration Loop
- Milestone 1: Backend API enhancements & DTOs/Tests (if needed).
- Milestone 2: Mobile Models, ApiClient, State Management (Provider/Cubit/Controller) for Allocations & Templates.
- Milestone 3: Mobile UI for RF-03 (Distribución Base Cero, dynamic Por Asignar, grouped by funding account, pastel semaphorization).
- Milestone 4: Mobile UI for RF-04 (Tabs 1ra/2da quincena, apply template, save current cycle as template).
- Milestone 5: Integration into `MainShell` navigation (replacing PlaceholderView).

### Phase 3: Verification, Quality Assurance & Audit
- Flutter analyze (0 errors, 0 severe warnings).
- Unit/widget tests in Flutter for calculations and template handling.
- Backend tests & build (`npm run build`, `npm run test`).
- Reviewers, Challengers, and Forensic Auditor verification.

### Phase 4: Delivery
- Synthesize all results, write completion report to sentinel.
