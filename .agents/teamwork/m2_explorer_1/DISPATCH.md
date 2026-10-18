## 2026-10-17T18:33:11Z
You are the OCR Viewfinder & Camera Explorer for Milestone 2 of the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m2_explorer_1
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.
Read previous spec report: E:\Projects\quincena-app\.agents\teamwork\spec_miner_dercas_stitch\handoff.md (specifically Stitch Screen 06dd441359e2446c8c5931868b87b4d7).

Your mission for Milestone 2:
1. Design `quincena/lib/features/ocr/presentation/ocr_scanner_screen.dart` and `quincena/lib/features/ocr/presentation/widgets/ocr_viewfinder.dart`:
   - Match Stitch design *Escanear Comprobante OCR* (`06dd441359e2446c8c5931868b87b4d7`):
     * Top bar with back button, "Cámara Inteligente" pulse pill, torch toggle, and "Manual" shortcut button.
     * Viewfinder overlay with dark translucent mask (`bg-inverse-surface/40` or `rgba(28,36,43,0.6)`), 16px corner cutout, and alignment corner tick guides in `#79ADDC` (3-4px stroke).
     * Animated laser scan bar and live detection pill ("Paiz detectado (98%)" or simulated detection).
     * Bottom capture button or trigger using `image_picker: ^1.1.2` (ImageSource.camera or ImageSource.gallery) to capture real receipt photo/file.
   - When photo/file is selected, initiate upload via `TransactionApiService.uploadReceiptScan(file)` and open `OcrValidationSheet`.
2. Provide concrete implementation code for the worker.
3. Write your complete handoff report to `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_1\handoff.md`.
Follow the Handoff Protocol. Notify the orchestrator via send_message when done.
