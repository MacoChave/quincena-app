# Project: Quincena - Captura OCR y Transacciones Quincenales (RF-03/05, RF-04/06)

## Architecture
- **Backend**: NestJS REST API (`quincena-api`) using `@supabase/supabase-js`, TypeScript, class-validator DTOs.
  - Storage bucket: `'receipts'` for OCR receipts (Supabase Storage).
  - Modules: `receipt-scans` (`POST /receipt-scans/upload`, `POST /receipt-scans/:id/confirm`), `transactions` (`GET /transactions?cycleId=`, `POST /transactions?force=`, `DELETE /transactions/:id`).
  - Dynamic balance computation: Active cycle allocations and financial account balances are computed on read from `transactions`.
- **Database**: Supabase / PostgreSQL schemas (`receipt_scans`, `transactions`, `budget_allocations`, `financial_accounts`, `categories`, `biweekly_cycles`).
- **Mobile App**: Flutter (`quincena`) under `lib/features/transactions/` and `lib/features/ocr/`:
  - `ApiClient`: extended with multipart upload support (`uploadMultipart`).
  - Clean models: `Transaction`, `ReceiptScan`, `CreateTransactionDto`, `ConfirmReceiptScanDto`.
  - State synchronization: Coordinated notifiers ensuring `<100ms` balance deduction on `HomeScreen` hero cards and active cycle allocations.
  - Design tokens: `AppColors` pastel palette (`#79ADDC`, `#FFEE93`, `#FFC09F`, `#FCF5C7`, `#ADF7B6`), dark text (`#1C242B`), and tabular figures (`tnum`).
- **Navigation Shell**: `MainShell` in `lib/main.dart`:
  - Central FAB `AppFab` triggers receipt capture or manual entry.
  - Tab index 2 embeds `TransactionsFeedScreen` (replacing `PlaceholderView`).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Backend Bucket Name Normalization | Update `RECEIPT_SCANS_BUCKET = 'receipts'` in `receipt-scans.service.ts` and `auth.service.ts` to match DDL migration | M1 | Survey Backend |
| 2 | Mobile Multipart Upload Support | Extend `ApiClient` in `quincena` to support `uploadMultipart` for receipt images/PDFs | M1 | Survey Mobile |
| 3 | Mobile Data Models & DTOs | Implement `Transaction`, `ReceiptScan`, and serialization in `lib/features/transactions/data/models/` | M1 | Survey Spec & Mobile |
| 4 | Mobile Transaction API Service | Implement `TransactionApiService` wrapping `/transactions` and `/receipt-scans` endpoints | M1 | Survey Mobile |
| 5 | Central FAB & Dashboard Trigger | Connect `AppFab` and `HomeScreen(onScanReceipt)` to open capture flow | M2 | ORIGINAL_REQUEST R1, Spec #1, #2 |
| 6 | Capture Source Selector | Options to capture from live camera or select image/PDF from gallery | M2 | ORIGINAL_REQUEST R1, Spec #3 |
| 7 | OCR Scanner Viewfinder (Stitch Screen 06dd441359e2446c8c5931868b87b4d7) | Viewfinder, alignment frame (`#79ADDC`), dark translucent mask, torch toggle, and "Manual" shortcut | M2 | ORIGINAL_REQUEST R1, Spec #4-7 |
| 8 | Pre-Confirmation Bottom Sheet (CA-03.2, CA-05.2) | Slide-up modal displaying extracted total amount, merchant, date, auth number with inline editing | M2 | ORIGINAL_REQUEST R1, Spec #10-12 |
| 9 | Category & Funding Account Auto-Suggestion | Auto-suggest category and default funding account for recognized merchant (CA-05.2) | M2 | ORIGINAL_REQUEST R1, Spec #13, #14 |
| 10 | Quincena Runway Balance Impact Banner | Visual preview: projected balance after expense and days remaining in cycle | M2 | Spec #15 |
| 11 | Fallback to Manual Form on OCR Error (CA-03.4, CA-05.3) | Automatic transition to prefilled manual form if OCR fails or confidence < 70% | M2 | ORIGINAL_REQUEST R1, Spec #16 |
| 12 | Receipt Confirmation Execution | Submits `POST /receipt-scans/:id/confirm` creating transaction linked to receipt scan | M2 | ORIGINAL_REQUEST R1, Spec #17 |
| 13 | History Feed Screen in MainShell (RF-04/06) | Replace `PlaceholderView` at tab index 2 with Stitch-designed `TransactionsFeedScreen` | M3 | ORIGINAL_REQUEST R2, Spec #18 |
| 14 | Quincena Switcher & Progress Header | Period title, navigation controls, and spent vs total ratio | M3 | Spec #19 |
| 15 | Analytics Bento Tile | Bento card in `#FCF5C7` with pace, status badge, progress bar, and daily pace | M3 | Spec #20 |
| 16 | Live Search Input Bar | Real-time search by merchant name, auth/invoice number, or notes | M3 | Spec #21 |
| 17 | Quick Filter Chips Slider | Filter chips for "Todos", Categories, Accounts, and "Con Factura OCR" | M3 | ORIGINAL_REQUEST R2, Spec #22 |
| 18 | Date-Grouped Chronological Feed | Transactions grouped by date (Hoy, Ayer, date headers) with tabular numbers (`tnum`) | M3 | ORIGINAL_REQUEST R2, Spec #23 |
| 19 | Transaction Card Architecture | Category avatar, merchant/note, time, method badge, and tabular currency | M3 | ORIGINAL_REQUEST R2, Spec #24 |
| 20 | Transaction Details & Deletion | Detail bottom sheet and delete action calling `DELETE /transactions/:id` | M3 | Spec #25 |
| 21 | Manual Expense Form Modal (RF-04/06) | Slide-up modal form with amount, category, account, date, and merchant/notes | M4 | ORIGINAL_REQUEST R3, Spec #27 |
| 22 | Decimal Keyboard Activation | Enforce native decimal keypad (`inputmode="decimal"`) with large tabular figures | M4 | ORIGINAL_REQUEST R3, Spec #28 |
| 23 | Contextual + Nueva Categoría | Shortcut inside category selector to create new category without state loss | M4 | ORIGINAL_REQUEST R3, Spec #29 |
| 24 | Required Financial Account Selector | Mandatory account picker auto-selecting category default account (`RN-CAT-01`) | M4 | ORIGINAL_REQUEST R3, Spec #30 |
| 25 | Duplicate Warning Interception (RN-03) | Intercept HTTP 409 Conflict (`duplicate_warning: true`), display alert, and allow `?force=true` bypass | M4 | ORIGINAL_REQUEST R3, Spec #31 |
| 26 | Real-time Category Budget Deduction (CA-04.2, CA-06.2) | Deduct expense immediately from active cycle category allocation in <100ms | M4 | ORIGINAL_REQUEST R3, Spec #32 |
| 27 | Dashboard Live Synchronization | Update `HomeScreen` total spent, available funds, and progress bars reactively | M4 | ORIGINAL_REQUEST R3, Spec #33 |
| 28 | Comprehensive Automated Testing Suite | Unit and widget tests covering OCR validation, manual form, duplicate warning, feed filtering, and balance sync | M5 | Acceptance Criteria, Spec #5-6 |
| 29 | Code Quality & Static Analysis | Maintain `flutter analyze` at 0 errors/warnings; ensure `npm test` and `npm run build` pass cleanly | M5 | Acceptance Criteria |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Backend Bucket Alignment & Mobile Foundation | Fix bucket name to `'receipts'` in NestJS; add `image_picker`; extend `ApiClient.uploadMultipart`; models & `TransactionApiService` | none | DONE |
| M2 | OCR Capture Flow & Pre-Confirmation Sheet (RF-03/05) | FAB & Dashboard triggers, camera/picker selector, viewfinder screen, pre-confirmation bottom sheet, auto-suggestions, manual fallback | M1 | DONE |
| M3 | Transaction History & Fortnightly Feed (RF-04/06) | Replace `PlaceholderView` in `MainShell` tab 2 with `TransactionsFeedScreen`, bento tile, search, filter chips, grouped feed, transaction card | M1 | DONE |
| M4 | Manual Entry Form & Real-time Balance Updating (RF-04/06) | Manual entry modal, decimal keyboard, category shortcut, duplicate warning dialog (RN-03), real-time category balance & Dashboard sync | M1, M3 | DONE |
| M5 | E2E Testing, Adversarial Hardening & Verification | Dual-track test suite (Tiers 1-4), adversarial tests (Tier 5), `flutter analyze`, NestJS test/build, Forensic Audit | M2, M3, M4 | IN_PROGRESS |

## Interface Contracts

### 1. `quincena-api` ↔ `quincena` (REST Endpoints)
- `POST /receipt-scans/upload`: Multipart `file` (image/pdf); returns `{ scan: ReceiptScan, message: string }`.
- `POST /receipt-scans/:id/confirm`: Body `ConfirmReceiptScanDto` (`cycle_id`, `source_account_id`, `amount`, `merchant_name`, `transaction_date`, `allocation_id?`, `notes?`); returns `{ transaction, scan_id, message }`.
- `GET /transactions?cycleId={id}`: Returns list of transactions with joined `budget_allocations(categories)` and `source_account`.
- `POST /transactions?force={true|false}`: Body `CreateTransactionDto`; returns HTTP 201 or HTTP 409 Conflict with `{ duplicate_warning: true, existing_transactions: [...] }`.
- `DELETE /transactions/:id`: Deletes transaction; active cycle recalculates spent balances dynamically.

## Code Layout

### Backend (`quincena-api`)
- `src/modules/receipt-scans/`: `receipt-scans.service.ts` (update bucket name to `'receipts'`), `receipt-scans.controller.ts`, DTOs
- `src/modules/transactions/`: `transactions.service.ts`, `transactions.controller.ts`, DTOs
- `src/modules/auth/`: `auth.service.ts` (update bucket name to `'receipts'`)

### Mobile (`quincena`)
- `lib/core/network/api_client.dart`: Extended with `uploadMultipart`
- `lib/features/transactions/`:
  - `data/models/`: `transaction.dart`, `receipt_scan.dart`, `create_transaction_dto.dart`, `confirm_receipt_scan_dto.dart`
  - `data/services/`: `transaction_api_service.dart`
  - `presentation/notifiers/`: `transactions_notifier.dart`
  - `presentation/feed/`: `transactions_feed_screen.dart`, `widgets/transaction_card.dart`, `widgets/feed_analytics_bento.dart`, `widgets/filter_chips_bar.dart`, `widgets/transaction_detail_sheet.dart`
  - `presentation/manual/`: `manual_expense_form_sheet.dart`, `widgets/duplicate_warning_dialog.dart`
- `lib/features/ocr/`:
  - `presentation/`: `ocr_scanner_screen.dart`, `widgets/ocr_viewfinder.dart`, `widgets/ocr_validation_sheet.dart`, `widgets/capture_source_sheet.dart`
- `lib/features/dashboard/presentation/home_screen.dart`: Connected `onScanReceipt` action
- `lib/main.dart`: Mounted `TransactionsFeedScreen` at tab index 2; connected central `AppFab` to OCR / manual triggers
- `test/features/transactions/`: Unit & widget tests
- `test/features/ocr/`: Unit & widget tests
