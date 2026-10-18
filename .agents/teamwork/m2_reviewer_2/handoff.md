# Handoff Report — Milestone 2 Contract & Flow Reviewer

## Verdict: REQUEST_CHANGES

---

## 1. Observation

### Implementation & Flow Inspection
1. **Pre-Confirmation Bottom Sheet & Blind Save Prevention (CA-03.2, CA-05.2)**:
   - File: `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart`
   - Hero Amount Card in `#FCF5C7`: editable amount field (`Key('ocr_amount_input')`, lines 760-775) with tabular digits (`tnum`) via `currencyHeroMobile`.
   - Editable Merchant Row: `TextField` with `Key('ocr_merchant_input')` (lines 826-841).
   - Date Row: `_pickDate` opening calendar picker (lines 878-934).
   - Category Chips: Horizontal slider with auto-suggestion and "+ Nueva" shortcut (lines 938-1047).
   - Funding Account: `Key('ocr_account_dropdown')` (line 1066) opening modal picker `_showAccountPicker` (lines 282-356).
   - Runway Balance Impact Banner: evaluates `currentAvailable - currentAmount` (lines 1129-1216).
   - Prevention of Blind Saves: `_confirmAndDeduct` (lines 409-426) enforces:
     - `amount <= 0.0` -> rejects with `'El monto debe ser mayor a 0.00'`.
     - `merchant.isEmpty` -> rejects with `'El comercio es obligatorio'`.
     - `_selectedAccountId == null || _selectedAccountId!.isEmpty` -> rejects with `'Seleccione una cuenta de débito'`.
     No transaction is ever created or persisted until the user explicitly reviews and taps "Confirmar y Descontar".

2. **Auto-Suggestion Engine (CA-05.2, RN-CAT-01)**:
   - File: `quincena/lib/features/ocr/domain/services/suggestion_engine.dart`
   - Lines 38–58 iterate over past `history` to match merchant names before falling back to keyword heuristics:
     ```dart
     39: for (final tx in history) {
     40:   final txMerchant = tx.merchantName.trim().toLowerCase();
     41:   if ((txMerchant == clean ||
     42:           clean.contains(txMerchant) ||
     43:           txMerchant.contains(clean)) &&
     44:       tx.category != null) {
     ```
   - Vulnerability: When `history` contains any transaction where `merchantName` is empty (`""`) or whitespace (`"   "`), `txMerchant` evaluates to `""`. In Dart, `clean.contains("")` is unconditionally `true` for all non-empty strings. Consequently, any blank-merchant historical transaction matches every incoming receipt, hijacking category and account suggestions away from true merchant keyword heuristics.

3. **OCR Error & Low Confidence Fallback (<70%) (CA-03.4, CA-05.3)**:
   - File: `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart`
   - `_isLowConfidence` getter (lines 164-172): returns `true` if `scan.isFailed`, `confidenceScore == null`, `score < 0.70` (for 0.0-1.0 range), or `score < 70.0` (for 0-100 range).
   - Warning Banner: Lines 628-694 render the amber banner in `#FFEE93` (`AppColors.warningBg`) with warning icon and a dedicated "Manual" action button triggering `_triggerFallbackManual`.
   - In `quincena/lib/features/ocr/presentation/ocr_scanner_screen.dart` (lines 340-362), network or parsing failures during upload catch exceptions, dismiss spinner, and display an error SnackBar with a `Manual` action shortcut.
   - Top utility bar in `OcrViewfinder` (lines 251-280) provides persistent `Key('ocr_manual_button')`.

4. **Confirmation & Transaction Linking (`POST /receipt-scans/:id/confirm`)**:
   - Mobile: `OcrValidationSheet._confirmAndDeduct` (lines 482-494) calls `TransactionApiService.confirmReceiptScan(widget.scan.id, confirmDto)`.
   - Backend Controller: `quincena-api/src/modules/receipt-scans/receipt-scans.controller.ts:82-97` defines `@Post(':id/confirm')`.
   - Backend Service: `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts:137-167` inserts a transaction into `transactions` linked by `receipt_scan_id: scanId`, sets `entry_method: 'ocr'`, and updates `receipt_scans.ocr_status = 'verified'`.

5. **Balance Refresh Signal (<100ms)**:
   - File: `quincena/lib/main.dart` (lines 102, 120-123) coordinates `ValueNotifier<int> _dashboardRefreshSignal` with `_budgetNotifier.refreshAllocations()`.
   - File: `quincena/lib/features/dashboard/presentation/home_screen.dart` (lines 40, 58-65) listens to `refreshListenable` and executes `_loadDashboard()` synchronously in memory in `<1ms`, fulfilling the `<100ms` requirement.
   - Verified via unit test: `production_ocr_flow_test.dart:495-510` confirms stopwatch elapsed time is `< 100ms`.

### Independent Build and Test Execution Results
1. `flutter analyze` in `quincena/`:
   ```
   Analyzing quincena...
   No issues found! (ran in 3.7s)
   ```
   Exit code: 0.

2. `flutter test test/features/ocr/production_ocr_flow_test.dart`:
   ```
   00:04 +12: All tests passed!
   ```
   Exit code: 0. (12 passed, 0 failed).

3. `flutter test test/features/ocr/ocr_capture_and_validation_test.dart`:
   ```
   00:05 +44: All tests passed!
   ```
   Exit code: 0. (44 passed, 0 failed).

4. `npm test` in `quincena-api/`:
   ```
   PASS src/modules/budget-allocations/budget-allocations.service.spec.ts
   PASS src/modules/categories/categories.service.spec.ts
   PASS src/modules/receipt-scans/receipt-scans.service.spec.ts
   PASS src/modules/budget-allocations/dto/budget-allocation-dto.spec.ts
   PASS src/modules/budget-templates/dto/budget-template-dto.spec.ts
   PASS src/app.controller.spec.ts
   PASS src/modules/budget-templates/budget-templates.service.spec.ts
   PASS src/modules/budget-templates/budget-templates.controller.spec.ts

   Test Suites: 8 passed, 8 total
   Tests:       46 passed, 46 total
   ```
   Exit code: 0.

5. `npm run build` in `quincena-api/`:
   ```
   > quincena-api@0.0.1 build
   > nest build
   ```
   Exit code: 0.

6. Adversarial Test Execution: `flutter test test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart`:
   ```
   00:03 +17 -2: Some tests failed.

   Failing tests:
     E:/Projects/quincena-app/quincena/test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart: Adversarial SuggestionEngine Tests Adversarial History: Empty merchant in transaction history does NOT hijack unrelated scans
     E:/Projects/quincena-app/quincena/test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart: Adversarial SuggestionEngine Tests Adversarial History: Whitespace-only merchant in history does NOT hijack incoming scans
   ```
   Exit code: 1.

### Integrity Audit
- No hardcoded test responses or facade bypasses detected in `SuggestionEngine`, `OcrValidationSheet`, or `OcrScannerScreen`.
- Implementation provides genuine domain inference and complete widget trees.

---

## 2. Logic Chain

1. **Step 1 (Observation 1)**: All requirements for CA-03.2 and CA-05.2 are implemented in `OcrValidationSheet`. Amounts, merchants, categories, and accounts must be validated prior to submission; zero or blank entries are rejected with user-visible errors, preventing blind saves.
2. **Step 2 (Observation 2 & Independent Result 6)**: In Dart, evaluating `clean.contains("")` on any non-empty string returns `true`. When a transaction in `history` has an empty or whitespace merchant name, line 40 trims it to `""`, causing line 42 (`clean.contains(txMerchant)`) to evaluate to `true` for any incoming scan. This falsely matches the empty transaction and hijacks auto-suggestion, failing the acceptance criterion for accurate suggestion based on merchant history (CA-05.2).
3. **Step 3 (Observation 3)**: Low-confidence detection (<70% or failed) accurately triggers the amber warning banner and seamlessly routes to manual entry via multiple dedicated callbacks and buttons (`CA-03.4, CA-05.3`).
4. **Step 4 (Observation 4 & Independent Result 4-5)**: "Confirmar y Descontar" correctly posts to `/receipt-scans/:id/confirm`, which updates the scan status to `verified` and creates a transaction referencing `receipt_scan_id`.
5. **Step 5 (Observation 5)**: In-memory signal dispatch executes instantaneously (<1ms), triggering synchronous dashboard updates well below the 100ms threshold.
6. **Step 6 (Independent Results 1-6)**: While standard unit tests and backend builds pass cleanly, the adversarial test suite reveals a deterministic logic failure in `SuggestionEngine` that must be resolved before Milestone 2 can be approved.

---

## 3. Caveats

1. **Date Picker `firstDate` Boundary**: In `ocr_validation_sheet.dart:260`, `firstDate: DateTime(2020)` causes a Flutter runtime assertion failure (`!initialDate.isBefore(firstDate)`) if an extracted receipt has a date prior to 2020.
2. **Viewfinder Canvas Corner Arc**: In `ocr_viewfinder.dart:680`, the bottom-right corner arc specifies `clockwise: true` instead of `clockwise: false`. This creates a slight inward concave curve rather than a convex rounded corner.
3. **Adversarial Test Suite Animation Timers**: In `ocr_capture_stress_challenge_test.dart`, calling `tester.pumpAndSettle()` against `OcrScannerScreen` timed out because `OcrViewfinder` contains infinite repeating animations (`_pulseController.repeat()` and `_laserController.repeat()`). Widget tests targeting `OcrScannerScreen` must use bounded pumps (`await tester.pump(const Duration(milliseconds: 100))`) rather than `pumpAndSettle()`.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES.**

Milestone 2 implementation is well-structured, follows Design System guidelines, prevents blind saves, links confirmed transactions to receipt scans, and dispatches instant balance refreshes. However, the auto-suggestion engine contains a reproducible bug where empty or whitespace merchant names in transaction history hijack all incoming scan suggestions.

### Required Changes for Worker:

#### [Major] Fix 1: Guard against empty or short merchant names in `SuggestionEngine`
- **Location**: `quincena/lib/features/ocr/domain/services/suggestion_engine.dart:39-44`
- **Problem**: `clean.contains("")` is always `true`. If `txMerchant` is empty, it matches any incoming merchant. Short strings (< 3 chars) also cause false substring positives.
- **Required Fix**:
  ```dart
  for (final tx in history) {
    final txMerchant = tx.merchantName.trim().toLowerCase();
    if (txMerchant.isNotEmpty &&
        (txMerchant == clean ||
         (txMerchant.length >= 3 && clean.contains(txMerchant)) ||
         (clean.length >= 3 && txMerchant.contains(clean))) &&
        tx.category != null) {
  ```

#### [Minor] Fix 2: Clamp `firstDate` in `_pickDate`
- **Location**: `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart:260`
- **Required Fix**:
  ```dart
  firstDate: _selectedDate.isBefore(DateTime(2020)) ? _selectedDate : DateTime(2020),
  ```

#### [Minor] Fix 3: Correct bottom-right arc direction in `_ViewfinderOverlayPainter`
- **Location**: `quincena/lib/features/ocr/presentation/widgets/ocr_viewfinder.dart:680`
- **Required Fix**: Change `clockwise: true` to `clockwise: false`.

---

## 5. Verification Method

To verify resolution of these findings:

1. **Verify SuggestionEngine fix**:
   ```pwsh
   cd e:\Projects\quincena-app\quincena
   flutter test test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart
   ```
   Must pass all 19 tests with 0 failures (previously failed 2 tests).

2. **Verify production OCR flow tests**:
   ```pwsh
   flutter test test/features/ocr/production_ocr_flow_test.dart
   flutter test test/features/ocr/ocr_capture_and_validation_test.dart
   ```
   Must pass all 56 tests (12 + 44).

3. **Verify static analysis**:
   ```pwsh
   flutter analyze
   ```
   Must output `No issues found!`.

4. **Verify backend integrity**:
   ```pwsh
   cd e:\Projects\quincena-app\quincena-api
   npm test
   npm run build
   ```
   Must pass all 46 tests across 8 suites and compile cleanly.
