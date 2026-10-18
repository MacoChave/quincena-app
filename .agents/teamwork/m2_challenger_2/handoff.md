# Handoff Report — Milestone 2 Suggestion & Validation Challenger

## Verdict: REQUEST_CHANGES

---

## 1. Observation

- **Test Suite Executed**:
  `quincena/test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart` (19 test cases covering adversarial inputs, runway balance deficit handling, validation error paths, and date edge cases).

- **Execution Command & Result**:
  Command:
  ```pwsh
  cd e:\Projects\quincena-app\quincena
  flutter test test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart
  ```
  Result:
  ```
  00:06 +17 -2: Some tests failed.

  Failing tests:
    E:/Projects/quincena-app/quincena/test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart: Adversarial SuggestionEngine Tests Adversarial History: Empty merchant in transaction history does NOT hijack unrelated scans
    E:/Projects/quincena-app/quincena/test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart: Adversarial SuggestionEngine Tests Adversarial History: Whitespace-only merchant in history does NOT hijack incoming scans
  ```

- **Verbatim Error Logs**:
  1. Test: `Adversarial SuggestionEngine Tests Adversarial History: Empty merchant in transaction history does NOT hijack unrelated scans`:
     ```
     Expected: 'cat-super'
       Actual: 'cat-ocio'
        Which: is different.
               Expected: cat-super
                 Actual: cat-ocio
                             ^
                Differ at offset 4
     Empty merchant in past history must not cause clean.contains("") to match false positives
     ```
  2. Test: `Adversarial SuggestionEngine Tests Adversarial History: Whitespace-only merchant in history does NOT hijack incoming scans`:
     ```
     Expected: 'cat-trans'
       Actual: 'cat-salud'
        Which: is different.
               Expected: cat-trans
                 Actual: cat-salud
                             ^
                Differ at offset 4
     Whitespace-only merchant in past history must not hijack gasolinera to salud
     ```

- **Vulnerable Source Code in Implementation**:
  In `quincena/lib/features/ocr/domain/services/suggestion_engine.dart` (lines 38–58):
  ```dart
  38:    // 1. Coincidencia exacta o parcial en el historial de transacciones del usuario
  39:    for (final tx in history) {
  40:      final txMerchant = tx.merchantName.trim().toLowerCase();
  41:      if ((txMerchant == clean ||
  42:              clean.contains(txMerchant) ||
  43:              txMerchant.contains(clean)) &&
  44:          tx.category != null) {
  45:        final catMatch = activeCategories
  46:            .where((c) => c.id == tx.category!.id)
  47:            .firstOrNull;
  48:        if (catMatch != null) {
  49:          final accountId = tx.sourceAccountId.isNotEmpty
  50:              ? tx.sourceAccountId
  51:              : catMatch.defaultAccountId;
  52:          return {
  53:            'category_id': catMatch.id,
  54:            'account_id': accountId,
  55:          };
  56:        }
  57:      }
  58:    }
  ```

- **Passing Validations Verified (17/19 Passed)**:
  1. *Empty category list*: Handled safely, returns `null` and `{'category_id': null, 'account_id': null}`.
  2. *Empty accounts list*: Handled safely, returns `null`.
  3. *Emojis and Unicode in merchant name*: (`🛒 Supermercado 🥑`, `☕ Café 🥐`, `超市 123`) correctly preserves keywords and avoids regex crashes.
  4. *Conflicting keywords*: Resolved deterministically according to if-else precedence without exceptions.
  5. *Runway Balance Deficit Banner*:
     - When available balance is `0.0`: Displays coral `#FFC09F` (`AppColors.expenseBg`) border/background and overspending alert with exact deficit amount.
     - When available balance is negative (`-40.0`): Displays coral `#FFC09F` banner with projected deficit (`$65.00`).
     - When transaction exceeds balance (`$750.00` vs `$200.00` balance): Displays coral `#FFC09F` banner with `$550.00` sobregiro.
     - Surplus baseline (`$500.00` balance vs `$100.00` expense): Uses primary subtle theme and shows no deficit alert.
     - Exact zero balance (`$50.00` balance vs `$50.00` expense): Accurately treated as balanced ($0.00), not deficit.
     - Dynamic recalculation: Live editing amount text switches the banner in real time between surplus and deficit.
  6. *Validation Sheet Input Rejection*:
     - `$0.00` amount: Blocked with `'El monto debe ser mayor a 0.00'`.
     - Negative amount (`-$45.50`): Blocked with `'El monto debe ser mayor a 0.00'`.
     - Missing / whitespace merchant: Blocked with `'El comercio es obligatorio'`.
     - Missing account selection: Blocked with `'Seleccione una cuenta de débito'`.
  7. *Date Edge Cases*:
     - Leap year `2024-02-29`: Formatted as `'29 Febrero, 2024'` and serialized as `'2024-02-29'`.
     - Leap year `2028-02-29`: Formatted as `'29 Febrero, 2028'` and serialized as `'2028-02-29'`.
     - Boundary date `2025-12-31`: Serialized as `'2025-12-31'`.

---

## 2. Logic Chain

1. **Bug Root Cause**: In Dart, evaluating `clean.contains("")` on any non-empty string always returns `true` (e.g. `"supermercado la torre".contains("") == true`).
2. **Failure Mode**: When a user's transaction history contains any record where `merchantName` is empty (`""`) or only whitespace (`"   "`), line 40 trims it to `""`.
3. **Hijacking Effect**: In lines 41–44, `clean.contains(txMerchant)` evaluates to `true`. Because history is evaluated in step 1 prior to keyword heuristics in step 2, `SuggestionEngine.suggestCategoryAndAccount` immediately matches that empty transaction's category.
4. **Impact**: Every subsequent receipt scanned by the user is hijacked by the first empty-merchant transaction in history, completely bypassing accurate keyword matching (e.g., a receipt from "Supermercado La Torre" is incorrectly categorized as "Ocio" or "Salud").
5. **Secondary Risk**: Bidirectional unconstrained substring matching (`clean.contains(txMerchant) || txMerchant.contains(clean)`) without checking minimum string length (e.g. `txMerchant.length >= 3`) creates false positives for common short substrings (e.g., merchant "La" or "De" matching all incoming merchants containing those syllables).

---

## 3. Caveats

- **Date Picker Bounds Constraint**: In `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart`, `_pickDate()` uses `firstDate: DateTime(2020)`. If an OCR ticket has an extracted date prior to 2020 (e.g. historical tax receipt from 2019), tapping the date picker will trigger Flutter's assertion `!initialDate.isBefore(firstDate)`. To make this resilient, `firstDate` should be clamped: `firstDate: _selectedDate.isBefore(DateTime(2020)) ? _selectedDate : DateTime(2020)`.
- Existing test suites (`production_ocr_flow_test.dart` and `ocr_capture_and_validation_test.dart`) passed because their mock transaction histories only contained well-formed non-empty merchant strings.
- Backend suite (`npm test` and `npm run build` in `quincena-api/`) remains 100% green with 46/46 tests passing.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES.**

The implementation of Milestone 2 is solid across UI, deficit calculation, validation rules, and date serialization. However, `SuggestionEngine.suggestCategoryAndAccount` contains a reproducible logic bug where empty or whitespace merchant names in transaction history hijack all future receipt suggestions due to `clean.contains("") == true`.

### Required Worker Fix:
In `quincena/lib/features/ocr/domain/services/suggestion_engine.dart` lines 39–44, guard against empty/short merchant strings before evaluating substring matches:

```dart
for (final tx in history) {
  final txMerchant = tx.merchantName.trim().toLowerCase();
  if (txMerchant.isNotEmpty &&
      (txMerchant == clean ||
       (txMerchant.length >= 3 && clean.contains(txMerchant)) ||
       (clean.length >= 3 && txMerchant.contains(clean))) &&
      tx.category != null) {
```

---

## 5. Verification Method

To independently reproduce this failure and verify the subsequent fix:

1. Run the empirical adversarial challenge test suite:
   ```pwsh
   cd e:\Projects\quincena-app\quincena
   flutter test test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart
   ```
   **Expected before fix**: 2 tests fail with:
   - `Adversarial SuggestionEngine Tests Adversarial History: Empty merchant in transaction history does NOT hijack unrelated scans`
   - `Adversarial SuggestionEngine Tests Adversarial History: Whitespace-only merchant in history does NOT hijack incoming scans`

2. After applying the guard in `suggestion_engine.dart`, re-run:
   ```pwsh
   flutter test test/features/ocr/ocr_validation_sheet_adversarial_challenge_test.dart
   ```
   **Expected after fix**: 19/19 tests pass (100% green).

3. Verify existing test suites continue to pass:
   ```pwsh
   flutter test test/features/ocr/production_ocr_flow_test.dart
   flutter test test/features/ocr/ocr_capture_and_validation_test.dart
   flutter analyze
   ```
