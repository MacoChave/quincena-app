## 2026-10-17T17:31:45Z
You are the Project Orchestrator for the Quincena project.

Working Directory: E:\Projects\quincena-app\.agents\teamwork\orchestrator_ocr_tx
Project Root / Workspace: E:\Projects\quincena-app
Original Request: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (see header ## 2026-10-17T17:30:29Z)

Your mission:
Implement end-to-end:
1. **Captura de Gastos vía OCR (RF-03 / RF-05)**:
   - Floating Action Button (FAB) and Dashboard direct access opening capture flow (camera or gallery/PDF selector).
   - Screen matching Stitch design *Escanear Comprobante OCR* with viewfinder, alignment frame (#79ADDC), and dark translucent mask.
   - Endpoint integration (`/receipt-scans`) for automated data extraction (total amount, merchant, date, reference/auth number).
   - Modal bottom sheet for pre-confirmation where user validates or edits extracted fields before saving (CA-03.2, CA-05.2).
   - Auto-suggestion of category and default funding account for detected merchant.
   - Automatic fallback to manual form on OCR error or low confidence (CA-03.4, CA-05.3).
   - Comprobantes uploaded and linked in Supabase Storage (bucket `receipts`).

2. **Historial de Transacciones y Feed Quincenal (RF-04 / RF-06)**:
   - Replace `PlaceholderView` in the *Historial* tab of `MainShell` with Stitch-designed *Historial de Gastos Quincenales*.
   - Chronological list of expenses grouped by date for the active fortnight.
   - Transaction card: merchant name/note, date/time, category icon/color avatar, source financial account, monetary amount formatted with tabular figures (`tnum`).
   - Quick filter chips by category and financial account.
   - Action to launch manual expense entry without photo.

3. **Entrada Manual de Transacciones y Actualización de Saldos (RF-04 / RF-06)**:
   - Modal form for manual expense entry: numeric amount with decimal keyboard, required category selector (with shortcut to + Nueva Categoría), required financial account selector, date/time, merchant/note.
   - Preventive duplicate warning if an expense with identical amount, merchant, and date within the last 24 hours is detected (RN-03).
   - Immediate budget balance deduction from category allocation in active cycle and real-time dashboard update (CA-04.2, CA-06.2).

4. **Full-stack Integration, Persistence & Test Coverage**:
   - Flutter (`quincena`) connected with `quincena-api` modules `transactions` and `receipt-scans`.
   - Unit and widget tests in Flutter for manual entry, OCR validation, deduplication warning, and history feed filtering.
   - Maintain `flutter analyze` at 0 errors and 0 warnings.
   - Ensure NestJS test suite (`npm run test`) and build (`npm run build`) pass cleanly.

Coordinate subagents (explorers, workers, reviewers, challengers) following Teamwork protocols. Maintain plan.md and progress.md in your working directory.
When you finish and all tests pass and acceptance criteria are met, report victory to the Sentinel.
