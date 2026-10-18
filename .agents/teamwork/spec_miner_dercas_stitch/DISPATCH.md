## 2026-10-17T17:33:14Z

You are the DERCAS & Stitch Spec Miner for the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\spec_miner_dercas_stitch
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (specifically the section with timestamp ## 2026-10-17T17:30:29Z).

Your mission:
Probe all specification and design sources in E:\Projects\quincena-app (including docs/, specs/, DERCAS references, Stitch designs, code comments, and ORIGINAL_REQUEST.md):
1. Enumerate all functional requirements, business rules, and acceptance criteria for:
   - RF-03 / RF-05: Captura de Gastos vía OCR y Validación Previa.
     * Trigger: FAB and Dashboard direct access (camera or gallery/PDF selector).
     * Stitch design 'Escanear Comprobante OCR': viewfinder, alignment frame (#79ADDC), dark translucent mask.
     * Extraction fields: total amount, merchant, date, reference/auth number.
     * Modal bottom sheet for pre-confirmation (CA-03.2, CA-05.2): user validates/edits extracted fields.
     * Auto-suggestion of category & default funding account for detected merchant.
     * Fallback to manual form on OCR error or low confidence (CA-03.4, CA-05.3).
     * Receipt file storage in Supabase Storage bucket 'receipts'.
   - RF-04 / RF-06: Historial de Transacciones y Feed Quincenal.
     * Replace PlaceholderView in Historial tab of MainShell with Stitch design 'Historial de Gastos Quincenales'.
     * Chronological list grouped by date for active fortnight.
     * Transaction card: merchant/note, date/time, category icon/color avatar, source financial account, monetary amount formatted with tabular figures (tnum).
     * Quick filter chips by category and financial account.
     * Floating action button / direct action to register manual expense without receipt.
   - RF-04 / RF-06: Entrada Manual de Transacciones y Actualización de Saldos.
     * Modal form for manual expense entry: numeric amount with decimal keyboard (inputmode="decimal"), required category selector (shortcut to + Nueva Categoría), required financial account selector, date/time, merchant/note.
     * Duplicate warning (RN-03): identical amount, merchant, and date within last 24 hours.
     * Real-time budget deduction from category allocation in active cycle and dashboard update (CA-04.2, CA-06.2).
2. Synthesize these into an exhaustive, unambiguous feature checklist with detailed acceptance criteria and edge cases.
3. Write your report to:
   E:\Projects\quincena-app\.agents\teamwork\spec_miner_dercas_stitch\handoff.md
Follow the Handoff Protocol. When finished, notify the orchestrator via send_message.
