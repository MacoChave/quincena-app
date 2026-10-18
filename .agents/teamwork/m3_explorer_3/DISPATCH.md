## 2026-10-18T03:31:50Z
You are the Transaction Details & MainShell Mount Explorer for Milestone 3 of the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m3_explorer_3
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.
Read spec miner report: E:\Projects\quincena-app\.agents\teamwork\spec_miner_dercas_stitch\handoff.md.

Your mission for Milestone 3:
1. Design `TransactionDetailSheet` (`quincena/lib/features/transactions/presentation/feed/widgets/transaction_detail_sheet.dart`):
   - Modal bottom sheet opened when tapping any `TransactionCard`:
     * Drag handle, title "Detalle de Gasto".
     * Amount hero card with category color accent and tabular figures.
     * Metadata rows: merchant, exact date & time, category badge, funding account badge, entry method badge.
     * Notes and auth number (if present).
     * Receipt viewer: if `entry_method == 'ocr'` and receipt scan exists, show thumbnail or option to view full receipt image / scan metadata.
     * Primary delete action button: confirms with user and calls `TransactionApiService.deleteTransaction(transactionId)`.
     * Upon deletion, pops sheet, displays success snackbar, and signals active cycle / budget balance refresh in <100ms.
2. Design Integration with `MainShell` in `quincena/lib/main.dart`:
   - Replace line 116 `const PlaceholderView(title: 'Historial de Transacciones')` with `TransactionsFeedScreen()`.
   - Provide FAB quick action or speed dial in History feed to add manual expense or scan receipt.
   - Preserve navigation state and handle balance update notifications across tabs.
3. Provide complete, fully compilable Dart implementations in:
   - `proposed_transaction_detail_sheet.dart`
   - `proposed_main_integration.dart` (or diff for `quincena/lib/main.dart`)
   in your working directory.
4. Write your full handoff report to `E:\Projects\quincena-app\.agents\teamwork\m3_explorer_3\handoff.md`.
Follow the Handoff Protocol. Notify the orchestrator via send_message when done.
