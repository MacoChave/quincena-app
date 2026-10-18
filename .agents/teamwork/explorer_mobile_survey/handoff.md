# Technical Handoff Report: Mobile Architecture Survey (OCR & Transactions)

**Date**: 2026-10-17  
**Agent**: Mobile Architecture Explorer (`explorer_mobile_survey`)  
**Target Milestone**: Captura de Gastos vía OCR (RF-03/RF-05) y Registro Manual con Historial de Transacciones (RF-04/RF-06)  
**Working Directory**: `E:\Projects\quincena-app\.agents\teamwork\explorer_mobile_survey`  

---

## 1. Observation

### 1.1 Architecture and Navigation
- **`lib/main.dart`**:
  - `QuincenaApp` mounts `AuthGate`, which checks `sessionManager.isAuthenticated` (lines 58-74). When authenticated, it instantiates `MainShell` (lines 68-71).
  - `MainShell` manages an `IndexedStack` with 4 screens (lines 104-123):
    - Index 0: `HomeScreen` (lines 105-111).
    - Index 1: `BudgetScreen` (lines 112-115).
    - Index 2: `PlaceholderView(title: 'Historial de Transacciones')` (line 116).
    - Index 3: `ProfileScreen` (lines 117-122).
  - `PlaceholderView` is declared inline in `lib/main.dart` (lines 142-160) as a simple centered `Scaffold`.
  - **Floating Action Button (FAB)**:
    - Anchored in `AppBottomNavBar` (`lib/core/components/navigation/app_bottom_nav_bar.dart` lines 112-122) within a `Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter)` at `top: -20`.
    - Component `AppFab` (`lib/core/components/buttons/app_fab.dart` lines 52-76) is a 56px circular button with background `AppColors.primary` (`#79ADDC`), icon `Icons.qr_code_scanner_rounded`, and shadow `AppShadows.fab`.
    - Current trigger in `lib/main.dart` lines 134-136:
      ```dart
      onFabPressed: () {
        AppToast.showInfo(context, 'Acción: Abrir Escáner OCR de Tickets');
      },
      ```
  - **HomeScreen / Dashboard Direct Access**:
    - `HomeScreen` constructor defines `final VoidCallback? onScanReceipt;` (`lib/features/dashboard/presentation/home_screen.dart` line 24), and `MainShell` passes:
      ```dart
      onScanReceipt: () {
        AppToast.showInfo(context, 'Acción: Escaneo OCR de Comprobantes');
      },
      ```
    - **Defect/Gap**: In `home_screen.dart` (lines 26-382), `widget.onScanReceipt` is **never invoked or referenced** in any widget or button. There is currently no UI element on the Dashboard to launch scanning.

### 1.2 OCR, Camera & File Selection
- **Dependencies (`quincena/pubspec.yaml` lines 30-39)**:
  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    cupertino_icons: ^1.0.8
    google_fonts: ^9.0.0
    http: ^1.2.0
  ```
  - **Finding**: There is **no camera or image picker dependency** (`image_picker`, `camera`, or `file_picker`).
  - **Finding**: There are no existing camera/viewfinder widgets or file upload implementations in `quincena/lib/`.
- **HTTP Client Capabilities (`quincena/lib/core/network/api_client.dart`)**:
  - `ApiClient` implements `get`, `post`, `patch`, and `delete` using JSON serialization (`jsonEncode` with `application/json`).
  - **Defect/Gap**: `ApiClient` has **no multipart upload method** (e.g., using `http.MultipartRequest`) required to upload receipt files to `/receipt-scans/upload`.
- **Backend Storage Bucket Mismatch**:
  - Migration `supabase/migrations/20261016000002_storage_receipts.sql` (lines 7-9) creates storage bucket `'receipts'`:
    ```sql
    INSERT INTO storage.buckets (id, name, public) VALUES ('receipts', 'receipts', false)
    ```
  - However, `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts` line 10 specifies:
    ```typescript
    const RECEIPT_SCANS_BUCKET = 'receipt-scans';
    ```
  - **Critical Flaw**: Uploads to Supabase Storage via `ReceiptScansService` will fail with bucket not found error unless the bucket name is `'receipts'`.

### 1.3 Data Models & Services
- **Existing Mobile Services**:
  - `ApiClient` (`lib/core/network/api_client.dart`): Base HTTP client with Bearer auth token injection.
  - `BudgetApiService` (`lib/features/budget/data/services/budget_api_service.dart`): Allocations & templates endpoints.
  - `DashboardApiService` (`lib/features/dashboard/data/dashboard_api_service.dart`): Cycle dashboard & init endpoints.
  - `AuthApiService` & `AuthSessionManager`: Auth lifecycle.
  - `CategoriesApiService` & `FinancialAccountsApiService`: Catalog endpoints.
  - **Finding**: There is **no transaction model or service** and **no receipt scan model or service** in `quincena/lib/`.
- **Backend API Endpoints Available (`quincena-api`)**:
  - `GET /v1/transactions?cycleId={id}`: Enriched with `budget_allocations(categories)` and `source_account:financial_accounts`.
  - `POST /v1/transactions?force={true|false}`: Supports duplicate detection (RN-03). Returns HTTP 409 Conflict with `{ message: "...", duplicate_warning: true, existing_transactions: [...] }` if identical amount, merchant, and date within ±24h are found.
  - `PATCH /v1/transactions/:id` and `DELETE /v1/transactions/:id`.
  - `POST /v1/receipt-scans/upload`: Multipart endpoint accepting field `'file'`.
  - `GET /v1/receipt-scans/:id`: Returns scan with extracted data (`extracted_amount`, `extracted_merchant`, `extracted_date`, `tax_id_or_auth_number`).
  - `POST /v1/receipt-scans/:id/confirm`: Accepts `ConfirmReceiptScanDto` (`cycle_id`, `source_account_id`, `allocation_id`, `merchant_name`, `amount`, `transaction_date`, `notes`) and creates the transaction.
- **Supabase & Auth Interaction**:
  - The mobile app interacts **exclusively with the NestJS REST API** (`/v1`).
  - All calls carry the JWT token in `Authorization: Bearer <token>`.
  - The NestJS API validates the token via `SupabaseAuthGuard` and queries PostgreSQL using `@supabase/supabase-js` (`getAuthenticatedClient(token)`).
  - Direct Supabase SDK (`supabase_flutter`) is not used by the Flutter app.

### 1.4 State Management & Real-Time Balance Updating
- **`BudgetNotifier` (`lib/features/budget/presentation/notifiers/budget_notifier.dart`)**:
  - Scoped locally inside `_BudgetScreenState` (`budget_screen.dart` lines 37, 44).
  - Recalculates zero-base metrics (`totalIncome - totalAllocated`, `unallocated`, `totalSpent`, `totalAvailable`) in memory (<16ms).
- **`HomeScreen` (`lib/features/dashboard/presentation/home_screen.dart`)**:
  - Uses `FutureBuilder<DashboardData>` loaded in `initState` (`_dashboardFuture = widget.dashboardApiService.getDashboard()`).
  - Only reloads on pull-to-refresh (`RefreshIndicator`).
  - **Defect/Gap**: There is no reactive notification mechanism between transaction creation and `HomeScreen` or `BudgetNotifier`. When a user saves a transaction in the OCR or manual flow, the Dashboard and Budget screens will display stale balances unless explicitly coordinated or re-fetched.

### 1.5 Test Suite and Static Analysis
- **Static Analysis**:
  - `flutter analyze` executed in `quincena/`: **0 errors, 0 warnings** ("No issues found!").
- **Flutter Test Suite**:
  - `flutter test` executed in `quincena/`: **53 passed, 0 failed** (including adversarial math tests, boundary tests, and widget tests).
- **Backend Verification**:
  - `quincena-api`: `npm test` passed 7/7 suites (45/45 tests); `npm run build` completed cleanly.
  - Note: `transactions` and `receipt-scans` modules in `quincena-api` currently lack `.spec.ts` unit tests.

---

## 2. Logic Chain

```
[Observation: Tab index 2 is PlaceholderView]
  └──> Replacing PlaceholderView in MainShell requires creating a TransactionsScreen at lib/features/transactions/presentation/transactions_screen.dart.

[Observation: AppFab and HomeScreen.onScanReceipt are stubbed with AppToast]
  └──> Activating OCR requires wiring onFabPressed and adding a visible OCR quick action button/card on HomeScreen that opens the scan flow.

[Observation: pubspec.yaml lacks camera/image picking; ApiClient lacks multipart upload]
  └──> OCR flow requires:
       1. Adding `image_picker: ^1.1.2` to pubspec.yaml.
       2. Extending ApiClient with `uploadMultipart()` for POST /receipt-scans/upload.
       3. Creating ReceiptScanViewfinder with dark translucent mask and #79ADDC alignment frame.

[Observation: Backend bucket name is 'receipt-scans' in code vs 'receipts' in SQL migration]
  └──> Uploading to Supabase Storage will throw 400 Bad Request / Bucket not found unless `RECEIPT_SCANS_BUCKET` in `receipt-scans.service.ts` is corrected to `'receipts'`.

[Observation: Backend POST /transactions returns 409 Conflict with duplicate_warning on duplicate]
  └──> The Flutter manual entry modal must catch ApiException(409) and prompt the user with a confirmation dialog:
       "Posible gasto duplicado... ¿Deseas continuar?" -> if yes, call POST /transactions?force=true.

[Observation: HomeScreen and BudgetNotifier do not share state or listen to transaction creations]
  └──> Real-time balance update (CA-04.2 / CA-06.2) requires:
       1. When a transaction is saved, trigger a refresh on Dashboard and BudgetNotifier.
       2. In MainShell, propagate a `TransactionsNotifier` or pass a refresh callback `onTransactionRecorded` to reload both views.
```

---

## 3. Caveats

1. **Physical Camera vs Simulator/Emulators**:
   Running a raw `camera` package in Flutter on desktop Windows or certain emulators can cause native driver crashes or missing permissions. Using `image_picker` (which delegates to native camera and gallery intents or desktop file dialogs) provides reliable cross-platform execution while adhering to the Stitch viewfinder design for preview and alignment.
2. **OCR Worker / Background Processing**:
   In `quincena-api`, `uploadAndCreateScan` stores the file in Supabase Storage and returns `ocr_status: 'pending'`. A mock or live extraction step must be supported in the app so that if the backend returns pending or immediate extracted fields, the UI handles both seamlessly, including fallback to manual entry when confidence is low or fields are null.
3. **Backend Bucket Fix**:
   This survey is read-only for source code. The correction of `RECEIPT_SCANS_BUCKET` in `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts` (line 10: `'receipt-scans'` -> `'receipts'`) should be coordinated with the backend developer agent.

---

## 4. Conclusion & Architecture Blueprint

### 4.1 Target File Structure to Implement
```
quincena/
├── pubspec.yaml (add image_picker: ^1.1.2)
├── lib/
│   ├── core/
│   │   └── network/
│   │       └── api_client.dart (add uploadMultipart method)
│   ├── features/
│   │   ├── transactions/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   ├── transaction.dart
│   │   │   │   │   ├── create_transaction_dto.dart
│   │   │   │   │   └── transaction_filter.dart
│   │   │   │   └── services/
│   │   │   │       └── transactions_api_service.dart
│   │   │   ├── presentation/
│   │   │   │   ├── notifiers/
│   │   │   │   │   └── transactions_notifier.dart
│   │   │   │   ├── transactions_screen.dart (Replaces PlaceholderView)
│   │   │   │   └── widgets/
│   │   │   │       ├── transaction_tile.dart (Card with category avatar, account, tnum amount)
│   │   │   │       ├── transaction_filters_bar.dart (Category & account filter chips)
│   │   │   │       ├── manual_transaction_sheet.dart (Modal with AppAmountInput, date, merchant, duplicate dialog)
│   │   │   │       └── duplicate_warning_dialog.dart (RN-03 alert)
│   │   │   └── transactions.dart (barrel)
│   │   ├── receipt_scans/
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   │   ├── receipt_scan.dart
│   │   │   │   │   └── confirm_receipt_scan_dto.dart
│   │   │   │   └── services/
│   │   │   │       └── receipt_scans_api_service.dart
│   │   │   ├── presentation/
│   │   │   │   ├── receipt_scan_viewfinder_screen.dart (Stitch design: #79ADDC frame, dark mask)
│   │   │   │   └── widgets/
│   │   │   │       └── ocr_verification_sheet.dart (Pre-validation bottom sheet)
│   │   │   └── receipt_scans.dart (barrel)
│   │   └── dashboard/
│   │       └── presentation/
│   │           └── home_screen.dart (Add visible OCR scan card / button calling widget.onScanReceipt)
│   └── main.dart (Mount TransactionsScreen at index 2, wire FAB and HomeScreen to ReceiptScanViewfinderScreen)
└── test/
    └── features/
        ├── transactions/
        │   ├── transaction_model_test.dart
        │   ├── transactions_screen_test.dart
        │   └── manual_transaction_sheet_test.dart
        └── receipt_scans/
            ├── receipt_scan_model_test.dart
            └── receipt_scan_viewfinder_test.dart
```

### 4.2 Detailed Component Specifications (Stitch Compliance)
1. **ReceiptScanViewfinderScreen (`Escanear Comprobante OCR`)**:
   - Background: Dark translucent overlay (`Color(0x99000000)`).
   - Cutout / Viewfinder: Centered transparent aperture (e.g. 280x380 dp).
   - Alignment Frame: Border in `AppColors.primary` (`#79ADDC`, width 2.5px), with corner brackets or rounded rectangle (`AppRadius.borderLg`).
   - Instruction header: "Coloca tu ticket dentro del recuadro" (`AppTypography.headlineSm` in `#FFFFFF`).
   - Capture controls: Floating capture button, gallery button (`Icons.photo_library_outlined`), and manual entry fallback button (`Icons.edit_note_rounded`).
2. **OCR Pre-Verification Modal (`CA-03.2`, `CA-05.2`)**:
   - Displays extracted fields:
     - Amount: editable using `AppAmountInput`.
     - Merchant: editable using `AppTextField`.
     - Date: editable via `DatePicker`.
     - Reference / Authorization number (if extracted).
     - Category: auto-suggested or selectable from categories list.
     - Destination Account: auto-suggested or selectable.
   - Fallback button: "Ingresar manualmente" if image is unreadable or fails confidence check.
3. **TransactionsScreen (`Historial de Gastos Quincenales`)**:
   - Groups transactions by chronological date headers (`Hoy`, `Ayer`, `15 de Octubre 2026`).
   - Fast filter chips at top: "Todas", specific categories, and specific accounts.
   - Transaction card:
     - Category Avatar: rounded rectangle with pastel background (`cat.colorHex` with 15% opacity), category icon (`resolveCategoryIcon`).
     - Details: Merchant name (`AppTypography.labelLg`), account badge (`AppTypography.captionBadge`).
     - Trailing: Monetary amount formatted in tabular figures (`AppTypography.numericRow` or `currencyMd`, red/coral `#FFC09F` / `#A33F19`).
4. **Manual Transaction Sheet & Deduplication (`RN-03`)**:
   - `AppAmountInput` with `keyboardType: TextInputType.numberWithOptions(decimal: true)` (`inputmode="decimal"`).
   - Category selector with `+ Nueva Categoría` chip opening `CategoryFormSheet`.
   - Account selector.
   - Date picker (default: `DateTime.now()`).
   - Merchant / note field.
   - Conflict handling: If API returns 409, display alert dialog prompting user to force or cancel.

---

## 5. Verification Method

To independently verify the baseline and future changes:

1. **Static Analysis**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter analyze
   ```
   *Expected*: `No issues found!` (0 errors, 0 warnings).

2. **Flutter Test Suite**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter test
   ```
   *Expected*: 53+ tests passing.

3. **Backend API Suite**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena-api
   npm test
   npm run build
   ```
   *Expected*: 45+ tests passing, zero TypeScript build errors.

4. **Invalidation Conditions**:
   - Failure of `flutter analyze` due to missing imports or lint warnings.
   - `RECEIPT_SCANS_BUCKET` in `quincena-api` left as `'receipt-scans'` causing Supabase Storage 400 errors during image uploads.
   - Regressions in existing 53 Flutter unit/widget tests.
