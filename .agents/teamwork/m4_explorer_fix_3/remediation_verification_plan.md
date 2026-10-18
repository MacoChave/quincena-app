# Remediation, Verification & Deployment Plan: Milestone 4 (Iteration 2)

**Document ID:** `m4_remediation_verification_plan`  
**Author:** Stress Test Harness & Verification Explorer (`m4_explorer_fix_3`)  
**Workspace:** `E:\Projects\quincena-app`  
**Timestamp:** `2026-10-18T06:05:00Z`  
**Target Milestone:** Milestone 4: Manual Entry Form & Real-time Balance Updating (RF-04/06)  

---

## 1. Executive Summary

During Milestone 4 Iteration 2 challenge testing, two comprehensive adversarial test suites were evaluated:
1. `quincena/test/features/transactions/manual_form_stress_challenge_test.dart` (15 tests by Challenger 1):
   - Evaluates extreme amount formatting, regex/emoji merchant sanitization, rapid double-tap debouncing, and tight viewport rendering (360px–400px with virtual keyboard 280px–320px).
   - **Current status:** 11 passed, 4 failed.
   - **Defects identified:**
     - Test 3.2 fails: Pre-pump rapid double-tap on "Guardar Gasto" triggers two concurrent creation calls because `_submitExpense()` lacks an immediate synchronous execution lock.
     - Tests 4.1, 4.2, and 4.3 fail: Unconstrained horizontal `Row` widgets in `manual_expense_form_sheet.dart` and `category_selector_field.dart` cause `RenderFlex` overflows of 43px to 83px on viewports under 400px width.
2. `quincena/test/features/transactions/duplicate_and_balance_sync_adversarial_challenge_test.dart` (15 tests by Challenger 2):
   - Evaluates RN-03 duplicate detection boundary conditions (±24 hours, epsilon, case/trim normalization), modal bypass flows (`?force=true`), in-memory deduction latency (<10ms), and Dashboard UI update latency (<100ms).
   - **Current status:** 15 passed, 0 failed (100% pass rate both standalone and combined).
   - **Auditor Caveat Assessment:** Auditor flagged Test 3.3 for potential currency format mismatches (`$500.00`). Our empirical trace confirmed that `HomeScreen` formats the badge as `'Gastado: ' + _formatCurrency(500.0)` which yields `'Gastado: $500.00'`. Challenger 2 already asserted `find.text('Gastado: \$500.00')`. Both standalone and combined suite runs succeed deterministically; **no harmonization or test double modifications are required**.

This plan provides exact code modifications and a step-by-step verification pipeline to achieve 100% passing test suites across all 217 transaction tests with zero regressions.

---

## 2. Root Cause Analysis

### 2.1 Defect 1: CTA Double-Tap Race Condition (Test 3.2)
- **File:** `quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart`
- **Location:** Line 350 (`_submitExpense()`) & Line 410 (`_executeCreation()`).
- **Mechanism:**
  1. In Flutter, calling `setState(() => _isSubmitting = true)` marks the `StatefulWidget` dirty but does not immediately rebuild the widget tree; rebuild occurs on the subsequent frame pipeline pass (or during `tester.pump()`).
  2. When two tap gestures are registered in rapid succession before the first frame rebuilds (e.g., test 3.2 doing `await tester.tap(...); await tester.tap(...); await tester.pump();`), the button widget's `onPressed` callback is still active.
  3. `_submitExpense()` executes synchronously through validations and invokes `_executeCreation(dto, force: false)`. Inside `_executeCreation()`, execution pauses at the asynchronous `await widget.onSave(...)`.
  4. The second tap immediately enters `_submitExpense()`. Because `_submitExpense()` did not check `if (_isSubmitting) return;`, it constructs a second DTO and calls `_executeCreation()` again, invoking `widget.onSave` a second time (`Actual: <2>`, `Expected: <1>`).

### 2.2 Defect 2: Horizontal RenderFlex Overflows on Narrow Viewports (Tests 4.1, 4.2, 4.3)
- **Primary Overflow 1:** `quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart:543:11`
  - In the modal header:
    ```dart
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 34, height: 34, ...), // Circle icon
            const SizedBox(width: 10),
            Text('Nuevo Gasto Manual', style: AppTypography.headlineSm ...),
          ],
        ),
        IconButton(key: Key('manual_close_button'), ...),
      ],
    )
    ```
  - Available width on 360px viewport: $360\text{px} - 40\text{px (sheet horizontal padding)} = 320\text{px}$.
  - The inner `Row` and `Text` are unconstrained. Total required width: $34 + 10 + 235 (\text{headlineSm}) + 48 (\text{IconButton}) = 327\text{px} + \text{margins}$, causing an 83px overflow on 360px width, 68px on 375px, and 43px on 400px.
- **Primary Overflow 2:** `quincena/lib/features/transactions/presentation/manual/widgets/category_selector_field.dart:276:9`
  - In the field header:
    ```dart
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(widget.label), Text(' *')],
        ),
        TextButton.icon(label: Text('+ Nueva Categoría'), ...),
      ],
    )
    ```
  - Label text and the contextual `+ Nueva Categoría` button sit side-by-side unconstrained, overflowing by 67px on 360px width, 52px on 375px, and 27px on 400px.
- **Safeguard 3:** `quincena/lib/features/transactions/presentation/manual/widgets/account_selector_field.dart:151:9`
  - Header label `Cuenta de Pago / Débito *` lacks `Flexible` with `TextOverflow.ellipsis`.

### 2.3 Evaluation of Auditor Caveat #2 (Test 3.3 in Duplicate Challenge)
- **Auditor Note:** Noted possible assertion mismatch where `HomeScreen` currency string format was asserted (`$500.00`).
- **Empirical Findings:**
  1. In `HomeScreenState._formatCurrency(double amount)` (`quincena/lib/features/dashboard/presentation/home_screen.dart`, lines 92–97):
     ```dart
     String _formatCurrency(double amount) {
       return '\$${amount.toStringAsFixed(2).replaceAllMapped(
             RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
             (Match m) => '${m[1]},',
           )}';
     }
     ```
     This custom implementation is 100% deterministic, platform-independent, and formats numbers strictly as `$` + comma thousands + dot decimals.
  2. In `AppHeroCard` (`quincena/lib/core/components/cards/app_hero_card.dart`, lines 118–121):
     ```dart
     AppBadge.expense(
       text: 'Gastado: $expenseAmount',
       prefixIcon: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.expenseText),
     )
     ```
     The expense pill is prefixed with literal string `'Gastado: '`.
  3. In `duplicate_and_balance_sync_adversarial_challenge_test.dart`:
     - Line 652: `expect(find.text('\$1,500.00'), findsOneWidget);`
     - Line 653: `expect(find.text('Gastado: \$500.00'), findsOneWidget);`
     - Line 670: `expect(find.text('\$1,350.00'), findsOneWidget);`
     - Line 671: `expect(find.text('Gastado: \$650.00'), findsOneWidget);`
  4. Both standalone run (`flutter test ... duplicate_and_balance_sync_adversarial_challenge_test.dart`) and full transaction suite run (`flutter test test/features/transactions/`) pass 15/15 with 0 failures and 12.3 ms latency.
  5. **Verdict:** Test 3.3 is robust and requires no code changes.

---

## 3. Remediation Specifications

### 3.1 Remediation Item 1: Synchronous Submission Lock (`manual_expense_form_sheet.dart`)

**Target File:** `quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart`  
**Target Range:** Lines 350–408

#### Code Modification:
Add an entry guard `if (_isSubmitting) return;` at line 351, execute synchronous field validations, and set `_isSubmitting = true;` immediately prior to calling `_executeCreation`:

```dart
<<<< CURRENT CODE (Lines 350-408):
  Future<void> _submitExpense() async {
    // 0. Validar si el ciclo está cerrado (RN-01)
    if (widget.isCycleClosed) {
      setState(() => _errorMessage =
          'No se pueden registrar gastos en un ciclo cerrado (RN-01)');
      return;
    }

    // 1. Validar monto
    final amount = _parseAmount();
    if (amount <= 0.0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0.00');
      return;
    }

    // 2. Validar nombre de comercio
    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      setState(() => _errorMessage = 'El comercio o nota es obligatorio');
      return;
    }
    if (merchant.length > 120) {
      setState(() =>
          _errorMessage = 'El comercio no puede exceder 120 caracteres');
      return;
    }

    // 3. Validar categoría
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione una categoría obligatoria');
      return;
    }

    // 4. Validar cuenta financiera de débito
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione una cuenta financiera obligatoria');
      return;
    }

    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final dto = CreateTransactionDto(
      cycleId: widget.cycleId,
      sourceAccountId: _selectedAccountId!,
      allocationId: _selectedCategoryId,
      amount: amount,
      merchantName: merchant,
      transactionDate: dateStr,
      notes: notes,
      entryMethod: EntryMethod.manual,
      transactionType: TransactionType.expense,
    );

    await _executeCreation(dto, force: false);
  }
====
>>>> PROPOSED CODE:
  Future<void> _submitExpense() async {
    // Bloqueo síncrono inmediato contra doble-tap / rapid firing
    if (_isSubmitting) return;

    // 0. Validar si el ciclo está cerrado (RN-01)
    if (widget.isCycleClosed) {
      setState(() => _errorMessage =
          'No se pueden registrar gastos en un ciclo cerrado (RN-01)');
      return;
    }

    // 1. Validar monto
    final amount = _parseAmount();
    if (amount <= 0.0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0.00');
      return;
    }

    // 2. Validar nombre de comercio
    final merchant = _merchantController.text.trim();
    if (merchant.isEmpty) {
      setState(() => _errorMessage = 'El comercio o nota es obligatorio');
      return;
    }
    if (merchant.length > 120) {
      setState(() =>
          _errorMessage = 'El comercio no puede exceder 120 caracteres');
      return;
    }

    // 3. Validar categoría
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione una categoría obligatoria');
      return;
    }

    // 4. Validar cuenta financiera de débito
    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      setState(() => _errorMessage = 'Seleccione una cuenta financiera obligatoria');
      return;
    }

    // Bloqueo síncrono de estado antes de cualquier llamada asíncrona
    _isSubmitting = true;

    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    final dto = CreateTransactionDto(
      cycleId: widget.cycleId,
      sourceAccountId: _selectedAccountId!,
      allocationId: _selectedCategoryId,
      amount: amount,
      merchantName: merchant,
      transactionDate: dateStr,
      notes: notes,
      entryMethod: EntryMethod.manual,
      transactionType: TransactionType.expense,
    );

    await _executeCreation(dto, force: false);
  }
<<<<
```

---

### 3.2 Remediation Item 2: Header Layout Elasticity (`manual_expense_form_sheet.dart`)

**Target File:** `quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart`  
**Target Range:** Lines 542–579

#### Code Modification:
Wrap the inner title `Row` in `Expanded`, wrap the `Text` in `Expanded` with `overflow: TextOverflow.ellipsis` and `maxLines: 1`, and add `const SizedBox(width: 8)` between title and close button:

```dart
<<<< CURRENT CODE (Lines 542-579):
          // Cabecera: Icono, Título y Botón Cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: AppColors.primaryAccessible,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Nuevo Gasto Manual',
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const Key('manual_close_button'),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
====
>>>> PROPOSED CODE:
          // Cabecera: Icono, Título y Botón Cerrar con protección contra desbordamiento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySubtle,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: AppColors.primaryAccessible,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Nuevo Gasto Manual',
                        style: AppTypography.headlineSm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('manual_close_button'),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
<<<<
```

---

### 3.3 Remediation Item 3: Category Selector Header Resilience (`category_selector_field.dart`)

**Target File:** `quincena/lib/features/transactions/presentation/manual/widgets/category_selector_field.dart`  
**Target Range:** Lines 275–330

#### Code Modification:
Wrap the label row in `Expanded`, wrap `Text(widget.label)` in `Flexible` with `overflow: TextOverflow.ellipsis`, and insert a spacing separator before the contextual button:

```dart
<<<< CURRENT CODE (Lines 275-305):
        // Fila de Cabecera: Etiqueta y Botón Contextual "+ Nueva Categoría"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                if (widget.isRequired)
                  Text(
                    ' *',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.expenseText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            if (widget.showAddButtonInHeader)
              TextButton.icon(
                key: widget.addCategoryKey,
                onPressed: widget.enabled ? _openCreateCategory : null,
====
>>>> PROPOSED CODE:
        // Fila de Cabecera: Etiqueta y Botón Contextual "+ Nueva Categoría" (Resiliente a pantallas estrechas)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.label,
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isRequired)
                    Text(
                      ' *',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.expenseText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.showAddButtonInHeader) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                key: widget.addCategoryKey,
                onPressed: widget.enabled ? _openCreateCategory : null,
<<<<
```

---

### 3.4 Remediation Item 4: Account Selector Header Safeguard (`account_selector_field.dart`)

**Target File:** `quincena/lib/features/transactions/presentation/manual/widgets/account_selector_field.dart`  
**Target Range:** Lines 150–171

#### Code Modification:
Wrap `Text(widget.label)` in `Flexible` with `overflow: TextOverflow.ellipsis` and `maxLines: 1`:

```dart
<<<< CURRENT CODE (Lines 150-171):
        // Fila de Cabecera / Etiqueta
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            if (widget.isRequired)
              Text(
                ' *',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.expenseText,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
====
>>>> PROPOSED CODE:
        // Fila de Cabecera / Etiqueta con protección contra desbordamiento
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.label,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.isRequired)
              Text(
                ' *',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.expenseText,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
<<<<
```

---

## 4. Verification and Validation Protocol

The implementer (`m4_worker`) and subsequent verification agents must follow this sequential test progression:

### Step 1: Unit & Targeted Stress Verification
Execute the manual form stress challenge suite to verify that tests 3.2, 4.1, 4.2, and 4.3 transition to green:
```powershell
cd E:\Projects\quincena-app\quincena
flutter test test/features/transactions/manual_form_stress_challenge_test.dart
```
**Expected Outcome:** `00:05 +15: All tests passed!` (15/15 tests passing, zero RenderFlex errors).

### Step 2: Adversarial Duplicate & Balance Sync Verification
Execute the duplicate and balance sync challenge suite to confirm sustained 100% pass:
```powershell
flutter test test/features/transactions/duplicate_and_balance_sync_adversarial_challenge_test.dart
```
**Expected Outcome:** `00:03 +15: All tests passed!` (15/15 tests passing, latency strictly <10ms and <100ms).

### Step 3: Full Feature Transaction Suite Convergence
Execute all 10 transaction test suites together:
```powershell
flutter test test/features/transactions/
```
**Expected Outcome:** `00:25 +217: All tests passed!` (217/217 passing tests, 0 failures).

### Step 4: Flutter Static Analysis Gate
Verify strict linter compliance:
```powershell
flutter analyze
```
**Expected Outcome:** `No issues found! (ran in <10s)` (0 errors, 0 warnings).

### Step 5: Backend Test & Build Integration Gate
Ensure that mobile changes preserve full compatibility with NestJS API contracts:
```powershell
cd E:\Projects\quincena-app\quincena-api
npm test
npm run build
```
**Expected Outcome:** `8 test suites passed, 46 tests passed`, clean `nest build` with exit code 0.

---

## 5. Deployment & Rollout Checklist

- [ ] `manual_expense_form_sheet.dart` includes `if (_isSubmitting) return;` at entry of `_submitExpense()` and sets `_isSubmitting = true;` synchronously before async invocation.
- [ ] `manual_expense_form_sheet.dart` header wraps title row in `Expanded` and text in `Expanded(child: Text(..., overflow: TextOverflow.ellipsis))`.
- [ ] `category_selector_field.dart` wraps label in `Expanded` / `Flexible` with `overflow: TextOverflow.ellipsis`.
- [ ] `account_selector_field.dart` wraps label in `Flexible` with `overflow: TextOverflow.ellipsis`.
- [ ] All 15 tests in `manual_form_stress_challenge_test.dart` pass.
- [ ] All 15 tests in `duplicate_and_balance_sync_adversarial_challenge_test.dart` pass.
- [ ] All 217 tests across `quincena/test/features/transactions/` pass simultaneously.
- [ ] `flutter analyze` returns 0 issues.
- [ ] `npm test` and `npm run build` in `quincena-api` return exit code 0.
