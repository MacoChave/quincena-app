# Milestone 4 Empirical Challenge Report: Manual Form Stress & Layout Resilience

**Agent:** Milestone 4 Manual Form Stress Challenger (`m4_challenger_1`)  
**Workspace:** `E:\Projects\quincena-app`  
**Working Directory:** `E:\Projects\quincena-app\.agents\teamwork\m4_challenger_1`  
**Parent Agent:** `fcccfe2d-36ce-4dac-8218-e4e29818d2eb`  
**Timestamp:** `2026-10-18T05:39:00Z`  
**Verdict:** **REQUEST_CHANGES** (Empirical failures reproduced in Double-Tap Debounce and Tight Viewport Layouts)

---

## 1. Observation

1. **Baseline Suite Execution:**
   - Command: `flutter test test/features/transactions/manual_entry_and_balance_sync_test.dart`
   - Result: 53/53 tests passed (ran in ~9s).
   - Direct Observation: All widget tests in `manual_entry_and_balance_sync_test.dart` explicitly set `tester.view.physicalSize = const Size(1080, 2400);` (lines 1517, 1591, 1635, 1685, 1718, 1792). None of the worker's tests evaluated compact mobile viewports (e.g. 360px, 375px, 400px width).

2. **Empirical Stress Test Harness Creation:**
   - File created: `quincena/test/features/transactions/manual_form_stress_challenge_test.dart`.
   - `flutter analyze test/features/transactions/manual_form_stress_challenge_test.dart` returned `No issues found! (ran in 7.8s)`.

3. **Amount & Input Formatting Stress Observations:**
   - **$0.00:** Entering `0.00` in `manual_amount_input` and tapping "Guardar Gasto" blocked submission and rendered error text: `'El monto debe ser mayor a 0.00'`. (Test 1.6 PASSED)
   - **$0.001:** `DecimalCurrencyInputFormatter.formatEditUpdate` rejected third decimal place input (`0.001`), returning existing `0.00`. (Test 1.1 PASSED)
   - **$99,999,999.99:** Entering `99999999.99` parsed cleanly as double `99999999.99` into `CreateTransactionDto` without precision truncation or scientific notation crash. Entering raw string with `$` and multiple commas (`$99,999,999.99`) was correctly rejected by the formatter. (Tests 1.4, 1.5, 1.7 PASSED)
   - **Commas as decimal separator:** Entering `12,50` was normalized by `DecimalCurrencyInputFormatter` to `12.50`, parsed into `CreateTransactionDto.amount = 12.50`. (Tests 1.2, 1.8 PASSED)
   - **Multiple dots:** Input `12.34.56` was rejected by `DecimalCurrencyInputFormatter`, preserving existing valid value. (Test 1.3 PASSED)

4. **Merchant Name Resilience Observations:**
   - Special regex meta-characters (`r'Costco [Branch #42] (Special Deal!) $5.00 + 10% *promo* ^start? | \ {vip}'`) rendered and saved without escaping errors or crashes. (Test 2.1 PASSED)
   - Unicode emojis (`'🛒 Supermercado Don Pedro 🥑🌮🍻 100% Calidad'`) rendered and saved without error. (Test 2.2 PASSED)
   - Boundary validation: 120 chars accepted; 121 chars rejected with error `'El comercio no puede exceder 120 caracteres'`. (Test 2.3 PASSED)

5. **Anti-Duplicate Double-Tap Debounce / Loading Lock Failure (BUG 1):**
   - Command: `flutter test test/features/transactions/manual_form_stress_challenge_test.dart --name="3.2"`
   - Verbatim Output:
     ```
     00:00 +0: CHALLENGE 3: Rapid Double-Tap on Submit CTA (Debounce & Loading Lock) 3.2 Pre-pump rapid double tap before first frame rebuild
     ══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════════════════
     The following TestFailure was thrown running a test:
     Expected: <1>
       Actual: <2>

     When the exception was thrown, this was the stack:
     #4      main.<anonymous closure>.<anonymous closure> (file:///E:/Projects/quincena-app/quincena/test/features/transactions/manual_form_stress_challenge_test.dart:524:7)
     ```
   - In `manual_expense_form_sheet.dart`:
     * Line 350 (`_submitExpense()`): Does NOT check `if (_isSubmitting) return;` at entry.
     * Line 410 (`_executeCreation()`): Sets `setState(() => _isSubmitting = true)`.
     * Because `setState()` schedules a rebuild for the subsequent frame, two pointer tap events in rapid succession before the first frame rebuilds fire `_submitExpense()` twice, sending two parallel network/creation calls (`onSave` called twice).

6. **Tight Mobile Viewport Layout Failures / RenderFlex Overflows (BUG 2):**
   - Command: `flutter test test/features/transactions/manual_form_stress_challenge_test.dart --name="4."`
   - Verbatim Failures across all 3 requested viewports:
     * **Compact 360x640 (keyboard 280px):**
       ```
       A RenderFlex overflowed by 83 pixels on the right.
       The relevant error-causing widget was:
         Row:file:///E:/Projects/quincena-app/quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart:543:11

       A RenderFlex overflowed by 67 pixels on the right.
       The relevant error-causing widget was:
         Row:file:///E:/Projects/quincena-app/quincena/lib/features/transactions/presentation/manual/widgets/category_selector_field.dart:276:9

       A RenderFlex overflowed by 11 pixels on the right.
       The relevant error-causing widget was:
         Row:file:///E:/Projects/quincena-app/quincena/lib/features/transactions/presentation/manual/widgets/account_selector_field.dart:151:9
       ```
     * **Standard 375x812 (keyboard 320px):**
       ```
       A RenderFlex overflowed by 68 pixels on the right.
       The relevant error-causing widget was:
         Row:file:///E:/Projects/quincena-app/quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart:543:11

       A RenderFlex overflowed by 52 pixels on the right.
       The relevant error-causing widget was:
         Row:file:///E:/Projects/quincena-app/quincena/lib/features/transactions/presentation/manual/widgets/category_selector_field.dart:276:9
       ```
     * **Tall 400x800 (keyboard 300px):**
       ```
       A RenderFlex overflowed by 43 pixels on the right.
       The relevant error-causing widget was:
         Row:file:///E:/Projects/quincena-app/quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart:543:11

       A RenderFlex overflowed by 27 pixels on the right.
       The relevant error-causing widget was:
         Row:file:///E:/Projects/quincena-app/quincena/lib/features/transactions/presentation/manual/widgets/category_selector_field.dart:276:9
       ```

---

## 2. Logic Chain

1. **Amount & Formatting Integrity (Verified Robust):**
   - `DecimalCurrencyInputFormatter` was empirically proven to reject 3+ decimals, sanitize commas to dots, reject multiple dots, and allow large numeric strings up to 8 integer digits and 2 decimals. The form correctly parses `$12,50` into `12.50` and rejects `$0.00`.

2. **Merchant Name Resilience (Verified Robust):**
   - Inputs containing regular expression meta-characters (`.*+?^${}()|[]\`) and emojis (`🛒🌮🍻`) were accepted and serialized into DTOs without escaping errors, and length validation correctly enforces the 120-character ceiling.

3. **Double-Tap Race Condition Analysis (Bug Confirmed):**
   - Observation 5 demonstrated that `onSave` was invoked twice (`Actual: <2>`) during rapid taps.
   - Tracing `manual_expense_form_sheet.dart:350-415`: `_submitExpense()` is asynchronous. When called, it validates fields, constructs the DTO, and calls `_executeCreation(dto, force: false)`.
   - In `_executeCreation()`, `_isSubmitting = true` is set via `setState()`. Because Flutter batches rebuilds, the `AppButton` widget remains enabled (`isLoading == false`) until the frame pipeline renders.
   - Without an immediate synchronous guard `if (_isSubmitting) return;` at the very first line of `_submitExpense()` and before entering `_executeCreation()`, an uncoordinated second tap bypasses the button lock and dispatches duplicate HTTP requests.

4. **Viewport RenderFlex Overflow Analysis (Bug Confirmed):**
   - Observation 6 demonstrated `RenderFlex` overflows on 360px, 375px, and 400px viewports.
   - At `manual_expense_form_sheet.dart:543:11`:
     ```dart
     Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Row(
           children: [
             Container(...),
             const SizedBox(width: 10),
             Text('Nuevo Gasto Manual', style: AppTypography.headlineSm ...),
           ],
         ),
         IconButton(key: Key('manual_close_button'), ...),
       ],
     )
     ```
     Neither the outer nor inner Row wraps the title text in `Expanded` or `Flexible`. On 360px width with 40px sheet padding, the available width is 320px, whereas the icon + headline text + close button require >400px, causing an 83px overflow.
   - At `category_selector_field.dart:276:9`:
     ```dart
     Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Row(children: [Text(widget.label), Text(' *')]),
         TextButton.icon(label: Text('+ Nueva Categoría'), ...),
       ],
     )
     ```
     The label row and action button sit unconstrained side-by-side without `Expanded` or `Flexible`, overflowing by 67px on 360px screens and 27px on 400px screens.
   - At `account_selector_field.dart:151:9`:
     ```dart
     Row(children: [Text(widget.label), Text(' *')])
     ```
     With default label `'Cuenta de Pago / Débito *'`, the unconstrained text in `AppTypography.labelMd` overflows 320px by 11px.

---

## 3. Caveats

- No caveats. All 4 requested dimensions (amounts, merchants, double-tap debounce, and viewport keyboard layouts) were directly exercised against production Flutter widgets using an automated test harness.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES**

The manual expense form is functionally solid in terms of data parsing, category auto-selection, and duplicate warning dialog flow, but has two critical defects that fail the acceptance criteria:

1. **Pre-pump Double-Tap Race Condition:**
   - Rapid double-tapping on "Guardar Gasto" triggers two concurrent creation requests because `_submitExpense()` lacks a synchronous guard:
     ```dart
     if (_isSubmitting) return;
     _isSubmitting = true;
     ```
2. **Horizontal RenderFlex Overflows on Standard Mobile Screens (360px - 400px):**
   - `manual_expense_form_sheet.dart:543`: Outer header row must wrap title column/row with `Expanded(child: ...)` and add `overflow: TextOverflow.ellipsis` to `Text('Nuevo Gasto Manual')`.
   - `category_selector_field.dart:276`: Must wrap the left label row in `Expanded` with ellipsis so it gracefully shares space with `+ Nueva Categoría`.
   - `account_selector_field.dart:151`: Must wrap label in `Expanded` or `Flexible` with `overflow: TextOverflow.ellipsis`.

---

## 5. Verification Method

To independently reproduce the failures:

1. **Execute the Empirical Stress Test Suite:**
   ```powershell
   cd E:\Projects\quincena-app\quincena
   flutter test test/features/transactions/manual_form_stress_challenge_test.dart
   ```
   *Expected Failure Output:*
   - Test `3.2 Pre-pump rapid double tap before first frame rebuild` fails with `Expected: <1>, Actual: <2>`.
   - Test `4. Viewport Compact 360x640 with keyboard` fails with `A RenderFlex overflowed by 83 pixels on the right` and `A RenderFlex overflowed by 67 pixels on the right`.
   - Test `4. Viewport Standard 375x812 with keyboard` fails with `A RenderFlex overflowed by 68 pixels on the right` and `52 pixels on the right`.
   - Test `4. Viewport Tall 400x800 with keyboard` fails with `A RenderFlex overflowed by 43 pixels on the right` and `27 pixels on the right`.

2. **Verify Static Analysis:**
   ```powershell
   cd E:\Projects\quincena-app\quincena
   flutter analyze test/features/transactions/manual_form_stress_challenge_test.dart
   ```
   *Expected Output:* `No issues found!`.

3. **Resolution Invalidation Conditions:**
   - Adding `if (_isSubmitting) return;` at line 351 of `manual_expense_form_sheet.dart`.
   - Wrapping header rows in `Expanded` with `TextOverflow.ellipsis` across `manual_expense_form_sheet.dart:543`, `category_selector_field.dart:276`, and `account_selector_field.dart:151`.
   - Once resolved, running `flutter test test/features/transactions/manual_form_stress_challenge_test.dart` will achieve 100% pass across all 15 tests.
