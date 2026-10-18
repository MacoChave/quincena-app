## 2026-10-18T05:02:45Z
You are the Manual Expense Form & Decimal Keypad Explorer for Milestone 4 of the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m4_explorer_1
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.
Read spec miner report: E:\Projects\quincena-app\.agents\teamwork\spec_miner_dercas_stitch\handoff.md.

Your mission for Milestone 4:
1. Design `ManualExpenseFormSheet` (`quincena/lib/features/transactions/presentation/manual/manual_expense_form_sheet.dart`):
   - Modal bottom sheet with drag handle, title "Nuevo Gasto Manual", and close/cancel button.
   - Amount hero input with prefix `$`, large font (`AppTypography.currencyHeroMobile`), `FontFeature.tabularFigures()`, and strict decimal keyboard:
     * `keyboardType: const TextInputType.numberWithOptions(decimal: true)`
     * `inputFormatters`: filtering for valid currency format (up to 2 decimals).
   - Merchant name input (`TextFormField`) with validation (non-empty).
   - Date selector row defaulting to current date with calendar picker.
   - Notes optional input.
   - Sticky or accessible submit CTA button: "Registrar Gasto", showing loading state during submission.
2. Ensure responsive layout:
   - Proper padding for on-screen virtual keyboard (`MediaQuery.of(context).viewInsets.bottom`).
   - Scrollable body so no RenderFlex overflows occur on 360-400px mobile viewports when the keyboard is open.
3. Provide complete, fully compilable Dart implementation in:
   - `proposed_manual_expense_form_sheet.dart`
   in your working directory.
4. Write your full handoff report to `E:\Projects\quincena-app\.agents\teamwork\m4_explorer_1\handoff.md`.
Follow the Handoff Protocol. Notify the orchestrator via send_message when done.
