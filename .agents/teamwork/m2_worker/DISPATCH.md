## 2026-10-17T18:43:35Z
You are the Milestone 2 Implementation Worker for the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m2_worker
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your mission for Milestone 2 (OCR Capture Flow & Pre-Confirmation Sheet):
Implement the production files for OCR capture and pre-confirmation matching Stitch Screen 06dd441359e2446c8c5931868b87b4d7:

1. Copy and adapt the proposed files from M2 Explorers:
   - From `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_1\`:
     * `proposed_suggestion_engine.dart` -> `quincena/lib/features/ocr/domain/services/suggestion_engine.dart`
     * `proposed_ocr_viewfinder.dart` -> `quincena/lib/features/ocr/presentation/widgets/ocr_viewfinder.dart` (viewfinder, dark translucent mask, corner alignment ticks `#79ADDC`, torch toggle, manual shortcut)
     * `proposed_capture_source_sheet.dart` -> `quincena/lib/features/ocr/presentation/widgets/capture_source_sheet.dart`
     * `proposed_ocr_scanner_screen.dart` -> `quincena/lib/features/ocr/presentation/ocr_scanner_screen.dart`
   - From `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_2\`:
     * `proposed_ocr_validation_sheet.dart` -> `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart` (Hero Amount Card in `#FCF5C7`, merchant and date rows with calendar picker, category chips slider with `#79ADDC`, funding account selector with RN-CAT-01 default account auto-suggestion, runway balance impact banner, fallback to manual form on <70% confidence)

2. Connect Navigation Triggers (from `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_3\handoff.md`):
   - In `quincena/lib/features/dashboard/presentation/home_screen.dart`:
     * Add the Quick Scan Action Banner in the active cycle view wired to `widget.onScanReceipt`.
   - In `quincena/lib/main.dart`:
     * Wire central `AppFab` (`onFabPressed`) to show `CaptureSourceSheet`.
     * Wire `HomeScreen(onScanReceipt:)` to launch `OcrScannerScreen`.
     * Ensure real-time balance refresh signal `<100ms`.

3. Verification:
   - Run `flutter analyze` in `quincena/` (must be 0 errors, 0 warnings).
   - Run `flutter test test/features/ocr/ocr_capture_and_validation_test.dart`.
   - Run `flutter test` across all tests in `quincena/`.
   - Run `npm test` and `npm run build` in `quincena-api/`.

4. Document all changes and verification results in:
   `E:\Projects\quincena-app\.agents\teamwork\m2_worker\handoff.md`.
Follow the Handoff Protocol. Notify the orchestrator via send_message when done.
