## 2026-10-18T05:11:04Z
You are the Milestone 4 Implementation Worker for the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m4_worker
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your mission for Milestone 4 (Manual Entry Form & Real-time Balance Updating RF-04/06):
Implement and integrate production components for manual transaction entry, duplicate prevention (RN-03), and real-time balance synchronization (<100ms):

Write Ownership:
You exclusively own:
- `quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart`
- `quincena/lib/features/transactions/presentation/manual/widgets/duplicate_warning_dialog.dart`
- `quincena/lib/features/transactions/presentation/manual/widgets/category_selector_field.dart`
- `quincena/lib/features/transactions/presentation/manual/widgets/account_selector_field.dart`
- `quincena/lib/features/transactions/presentation/manual/services/manual_sync_service.dart`
- `quincena/lib/features/budget/presentation/notifiers/budget_notifier.dart` (adding `deductExpense` method)
- `quincena/lib/features/transactions/presentation/feed/transactions_feed_screen.dart` (wiring `_effectiveManualExpense()` to open `ManualExpenseFormSheet`)
- `quincena/lib/main.dart` (wiring manual expense trigger or balance refresh if needed)
- `quincena/test/features/transactions/manual_entry_and_balance_sync_test.dart`

Input artifacts to copy and integrate from the 3 M4 Explorers:
1. From `E:\Projects\quincena-app\.agents\teamwork\m4_explorer_1\`:
   - `proposed_manual_expense_form_sheet.dart` -> `quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart`
     (Uses `DecimalCurrencyInputFormatter`, hero input in Warm Cream `#FCF5C7`, tabular figures, merchant validation, date picker, responsive layout for 360-400px mobile viewports).
2. From `E:\Projects\quincena-app\.agents\teamwork\m4_explorer_2\`:
   - `proposed_category_selector_field.dart` -> `quincena/lib/features/transactions/presentation/manual/widgets/category_selector_field.dart`
     (Category selector with pastel color badges, `resolveCategoryIcon`, active cycle budget indicators, shortcut to `+ Nueva Categoría` preserving form state, and `RN-CAT-01` default account callback).
   - `proposed_account_selector_field.dart` -> `quincena/lib/features/transactions/presentation/manual/widgets/account_selector_field.dart`
     (Account selector with icon, name, account type, balance in tabular figures, and `RN-CAT-01` reactive pre-selection).
3. From `E:\Projects\quincena-app\.agents\teamwork\m4_explorer_3\`:
   - `proposed_duplicate_warning_dialog.dart` -> `quincena/lib/features/transactions/presentation/manual/widgets/duplicate_warning_dialog.dart`
     (Warning dialog for HTTP 409 Conflict with `{ duplicate_warning: true }`, cancel button keeping form open, and force button bypassing check with `?force=true`).
   - `proposed_manual_sync_service.dart` -> `quincena/lib/features/transactions/presentation/manual/services/manual_sync_service.dart`
     (Submission coordinator, duplicate interception, <10ms in-memory deduction, and <100ms `_handleBalanceRefresh()` propagation).
   - In `quincena/lib/features/budget/presentation/notifiers/budget_notifier.dart`: add `deductExpense({required String? allocationId, required double amount})` per `m4_explorer_3/handoff.md § 4`.

Ensure clean integration:
- Make sure `ManualExpenseFormSheet` embeds `CategorySelectorField` and `AccountSelectorField` cleanly.
- In `quincena/lib/features/transactions/presentation/feed/transactions_feed_screen.dart`, update `_effectiveManualExpense()` to open `ManualExpenseFormSheet`.
- Write comprehensive tests in `quincena/test/features/transactions/manual_entry_and_balance_sync_test.dart` covering:
  1. Manual expense form rendering (amount, decimal keyboard, category, account, date, notes).
  2. Input formatting with `DecimalCurrencyInputFormatter` (decimals, commas normalized to dots, max 2 decimals).
  3. Form validation (positive amount > 0, merchant non-empty, category and account selected).
  4. Contextual `+ Nueva Categoría` opening without losing entered form data.
  5. `RN-CAT-01` category default account auto-selection.
  6. Duplicate warning interception (HTTP 409 Conflict) and cancellation keeping form open.
  7. Duplicate warning bypass with `force: true` persisting transaction.
  8. Real-time balance deduction in `<100ms` and `HomeScreen` synchronization.

Verification:
1. In `quincena/`:
   - Run `flutter analyze` (must be 0 errors, 0 warnings).
   - Run `flutter test test/features/transactions/manual_entry_and_balance_sync_test.dart` (all tests must pass cleanly).
   - Run full `flutter test` across all mobile tests (must pass 100%).
2. In `quincena-api/`:
   - Run `npm test` and `npm run build` (must pass cleanly).

Write your complete handoff report to:
`E:\Projects\quincena-app\.agents\teamwork\m4_worker\handoff.md`
Follow the Handoff Protocol. Notify the orchestrator via send_message when done.
