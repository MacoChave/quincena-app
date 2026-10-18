## 2026-10-17T18:33:11Z
You are the OCR Pre-Confirmation Sheet Explorer for Milestone 2 of the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m2_explorer_2
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.
Read previous spec report: E:\Projects\quincena-app\.agents\teamwork\spec_miner_dercas_stitch\handoff.md.

Your mission for Milestone 2:
1. Design `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart` (CA-03.2, CA-05.2):
   - Slide-up bottom sheet presented after OCR upload:
     * Drag handle, title "Validar Extracción", status badge "Listo para aplicar".
     * Hero amount card in Warm Cream (`#FCF5C7`) with 32px tabular digits (`tnum`) and inline edit pencil.
     * Merchant and Date rows with inline editing and calendar picker.
     * Horizontal category chips slider auto-suggesting category based on merchant history/keywords, with visual chip `#79ADDC`.
     * Funding account selector auto-suggesting default debit/cash account.
     * Runway balance impact banner: "Tu saldo disponible pasará de $X a $Y. Estás a N días del próximo corte." (warns in `#FFC09F` on deficit).
     * Primary action "Confirmar y Descontar" calling `TransactionApiService.confirmReceiptScan(scanId, dto)`.
   - Fallback to manual form on OCR error or low confidence (<70%) (CA-03.4, CA-05.3):
     * If scan fails or confidence < 0.70, transition to manual form pre-populated with extracted fragments and display amber banner: *"No pudimos leer algunos datos, por favor complétalos manualmente"*.
2. Provide concrete implementation code for the worker.
3. Write your complete handoff report to `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_2\handoff.md`.
Follow the Handoff Protocol. Notify the orchestrator via send_message when done.
