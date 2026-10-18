## 2026-10-17T18:33:11Z

You are the OCR Navigation & Dashboard Trigger Explorer for Milestone 2 of the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m2_explorer_3
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.
Read spec miner report: E:\Projects\quincena-app\.agents\teamwork\spec_miner_dercas_stitch\handoff.md.

Your mission for Milestone 2:
1. Navigation and Dashboard Triggers:
   - In `quincena/lib/main.dart`:
     * Connect central `AppFab` (`onFabPressed`) to open `CaptureSourceSheet` (modal sheet offering Camera, Gallery, or Manual Entry options).
     * Connect `HomeScreen(onScanReceipt)` to open the OCR capture flow directly.
   - In `quincena/lib/features/dashboard/presentation/home_screen.dart`:
     * Verify where `onScanReceipt` is called or add a prominent Quick Scan action button/banner in the active cycle header or quick actions row.
   - Design `quincena/lib/features/ocr/presentation/widgets/capture_source_sheet.dart`:
     * Action bottom sheet with options: "Tomar Foto" (Camera), "Subir de Galería o PDF" (Gallery/Files), and "Registro Manual" (Direct Manual Form).
   - Real-time balance refresh:
     * When confirmation finishes, trigger refresh on `BudgetNotifier` and active cycle dashboard so available balances update immediately (<100ms).
2. Provide concrete implementation code for the worker.
3. Write your complete handoff report to `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_3\handoff.md`.
Follow the Handoff Protocol. Notify the orchestrator via send_message when done.
