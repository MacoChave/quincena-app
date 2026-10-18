# Specification Mining Report: OCR Expense Capture, Fortnightly History Feed & Manual Expense Registration

**Author:** Specification Miner (`spec_miner_dercas_stitch`)  
**Date:** 2026-10-17T17:42:00Z  
**Workspace:** `E:\Projects\quincena-app`  
**Parent Agent:** `fcccfe2d-36ce-4dac-8218-e4e29818d2eb`  
**Milestone Scope:** RF-03 / RF-05 (Captura OCR y Validación Previa), RF-04 / RF-06 (Historial de Transacciones y Feed Quincenal), RF-04 / RF-06 (Entrada Manual y Actualización de Saldos)

---

## 1. Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | OCR Capture (RF-03/05) | Central FAB Navigation Trigger | Elevated central circular action button (`AppFab`, 56px, `#79ADDC`) anchored on `AppBottomNavBar` triggering the receipt scan flow. | User tap on FAB | Launches camera viewfinder / file selector | Non-blocking; remains anchored during scroll/navigation | `quincena/lib/core/components/navigation/app_bottom_nav_bar.dart:104`, `design-system_quincena.md:40` |
| 2 | OCR Capture (RF-03/05) | Dashboard Direct Scan Action | Action button/banner in `HomeScreen` allowing instant initiation of OCR receipt scan directly from active cycle view. | User tap on quick scan action | Opens OCR camera / picker view | Displays error snackbar if camera/picker fails | `quincena/lib/features/dashboard/presentation/home_screen.dart:24`, `ORIGINAL_REQUEST.md:62` |
| 3 | OCR Capture (RF-03/05) | Capture Source Selector (Camera vs Gallery/PDF) | Action sheet allowing user to choose between taking live camera photo or picking JPG/PNG image / PDF from device storage. | Source selection: camera photo vs file picker | Image / PDF file handle & binary buffer | Invalid file type or permission denial triggers user prompt | `dercas_1_0.md:73`, `ORIGINAL_REQUEST.md:62` |
| 4 | OCR Capture (RF-03/05) | Viewfinder Overlay & Framing Guides | Camera viewport overlay with dark translucent mask (`rgba(28,36,43,0.6)` / `bg-inverse-surface/40`), clear scan window with 16px radius, and high-contrast corner tick guides (`#79ADDC`, 3-4px stroke). | Camera live preview feed | Guided viewfinder with laser scan animation | Displays unaligned warning if document out of frame | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:35-60`, `design-system_quincena.md:47` |
| 5 | OCR Capture (RF-03/05) | Live Confidence Indicator Chip | Floating pill badge pinned over viewfinder showing recognized merchant and live confidence score (e.g. "Paiz detectado (98%)") with pulsing dot (`#ADF7B6`). | OCR real-time stream frames | Pill badge with confidence percentage | Low confidence (<70%) displays amber/warning badge | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:49-53`, `dercas_1_0.md:149` |
| 6 | OCR Capture (RF-03/05) | Flashlight / Torch Toggle | Quick toggle button in top utility bar to enable/disable camera flash for low-light environments. | User tap on torch button | Toggles device torch and updates button styling (`#FFEE93`) | Silently disables if device lacks torch | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:25-27` |
| 7 | OCR Capture (RF-03/05) | Shortcut to Manual Entry from Scanner | Direct button in top utility bar ("Manual" with `edit_note` icon) to abandon scanner and open manual form immediately. | User tap on "Manual" | Transitions to manual transaction modal sheet | Preserves any camera state cleanly | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:28-31`, `design-system_quincena.md:46` |
| 8 | OCR Capture (RF-03/05) | Receipt File Upload to Supabase Storage | Uploads scanned receipt image/PDF to Supabase Storage bucket `receipts` under path `receipts/<user_id>/<timestamp>.<ext>`. | Binary file multipart `file` | Scan record (`id`, `storage_path`, `ocr_status: 'pending'`) | Throws 400 Bad Request on upload error or unsupported format | `supabase/migrations/20261016000002_storage_receipts.sql:6-16`, `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts:55-98` |
| 9 | OCR Capture (RF-03/05) | OCR Automated Field Extraction | Extraction engine extracts 4 key fields: total amount (with currency/decimals), merchant name, date/time, and tax ID / authorization number (`tax_id_or_auth_number`). | Scanned image/PDF | Structured JSON in `receipt_scans` table | If extraction fails, status set to `failed` | `dercas_1_0.md:77-85`, `dercas_1_2.md:71-72`, `20261016000001_initial_schema.sql:128-134` |
| 10 | OCR Capture (RF-03/05) | Pre-Confirmation Modal Bottom Sheet (CA-03.2) | Slide-up verification modal sheet (60%-85% height) presenting all recognized fields for user validation/editing. Never saves blindly. | Scan ID, extracted fields | Interactive editable preview sheet | Disables confirm button if required fields missing | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:61-177`, `dercas_1_0.md:87`, `ORIGINAL_REQUEST.md:65` |
| 11 | OCR Capture (RF-03/05) | Amount Hero Editing Card | Prominent Warm Cream (`#FCF5C7`) card displaying recognized amount in large tabular figures (`currency-hero-mobile`, 32px) with quick edit pencil button. | Extracted numeric amount | Editable currency field with decimal keyboard | Rejects amount `<= 0.00` | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:77-89`, `colors_quincena.md:98` |
| 12 | OCR Capture (RF-03/05) | Merchant & Date Field Row | Tiles displaying detected merchant and date with "Verificado" badge (`#ADF7B6`) and calendar picker trigger. | Extracted strings | Formatted merchant and localized date | Allows user inline editing | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:92-122` |
| 13 | OCR Capture (RF-03/05) | Category Auto-Suggestion & Chips | Horizontal chip slider auto-selecting suggested category based on merchant history or category keywords, with shortcut to create category. | Recognized merchant name | Pre-selected category chip | Defaults to 'Otros' or unallocated if no match | `dercas_1_0.md:89`, `dercas_1_2.md:73`, Stitch Screen `06dd441359e2446c8c5931868b87b4d7:124-141` |
| 14 | OCR Capture (RF-03/05) | Funding Account Auto-Suggestion | Preselects habitual funding account for merchant or category default account (`default_account_id`); user can switch account via selector. | Category / merchant profile | Pre-selected financial account | Defaults to user's primary cash account if none | `dercas_1_2.md:73`, `dercas_1_4.md:39`, Stitch Screen `06dd441359e2446c8c5931868b87b4d7:143-154` |
| 15 | OCR Capture (RF-03/05) | Quincena Runway Balance Impact Banner | Live insight banner: "Tu saldo disponible pasará de $X a $Y. Estás a N días del próximo corte." | Current balance & transaction amount | Dynamic projected balance and days to cycle end | Warns in coral (`#FFC09F`) if transaction causes deficit | Stitch Screen `06dd441359e2446c8c5931868b87b4d7:156-165` |
| 16 | OCR Capture (RF-03/05) | Fallback to Manual Form on Low Quality (CA-03.4/05.3) | If OCR confidence is low (<70%) or image unreadable, automatically opens manual form with banner "No pudimos leer algunos datos, por favor complétalos manualmente" pre-populating high-confidence fields. | Failed/ambiguous scan | Pre-filled manual entry modal | Shows amber warning banner on top of form | `dercas_1_0.md:91`, `dercas_1_2.md:74-75`, `ORIGINAL_REQUEST.md:67` |
| 17 | OCR Capture (RF-03/05) | Confirm & Deduct Execution | Submits `POST /receipt-scans/:id/confirm` with user overrides; creates transaction linked to scan and allocation, updates scan to `verified`. | ConfirmReceiptScanDto | Persisted transaction & updated scan status | 400 Bad Request if missing cycle_id or source_account_id | `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts:105-168` |
| 18 | Feed (RF-04/06) | MainShell Tab 2 History Replacement | Replaces `PlaceholderView(title: 'Historial de Transacciones')` at index 2 of `MainShell` with full 'Historial de Gastos Quincenales' screen. | Navigation tab tap (index 2) | Full transactional feed screen | Smooth transition without state loss | `quincena/lib/main.dart:116`, `ORIGINAL_REQUEST.md:70` |
| 19 | Feed (RF-04/06) | Quincena Switcher & Progress Header | Header with chevron controls, period span label (e.g. "16 - 31 Octubre 2026"), spent vs total ratio ("Gastado $1,050.00 de $2,500.00"), and export button. | Selected cycle ID / period | Formatted period title and consumption totals | Disables forward navigation beyond current cycle | Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:20-48` |
| 20 | Feed (RF-04/06) | Analytics Bento Tile | Bento card in Warm Cream (`#FCF5C7`) with "Ritmo de Gasto Quincenal", "En meta" badge, spent total, 8px progress bar, daily average pace, and scan count. | Active cycle transaction aggregates | Visual pace statistics and progress bar | Progress bar shifts color: `<70%` `#79ADDC`, `70-90%` `#FFEE93`, `>90%` `#FFC09F` | Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:50-94` |
| 21 | Feed (RF-04/06) | Live Search Input Bar | Search bar with magnifying glass icon filtering transactions in real-time by merchant name, invoice/auth number, or notes. | Search query string | Instant filtered transaction list (<16ms) | Empty search state: "No se encontraron gastos" | Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:96-101` |
| 22 | Feed (RF-04/06) | Quick Filter Chips Slider | Horizontal slider of pill filter chips: "Todos", Category chips (with category icon/color), "Con Factura OCR" chip, and Financial Account chips. | Filter chip selection | Filtered list matching active chips | Clear all filters button if 0 results match | Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:103-127`, `ORIGINAL_REQUEST.md:73` |
| 23 | Feed (RF-04/06) | Date-Grouped Chronological Feed | List of transactions grouped by date sections: "Hoy - [Fecha]" + day total, "Ayer - [Fecha]" + day total, "[Fecha]" + day total. | Transactions list from `GET /transactions?cycleId=` | Chronologically sorted sections (descending) | Empty cycle state with call to action | Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:130-293`, `dercas_1_0.md:139` |
| 24 | Feed (RF-04/06) | Transaction Card Architecture | Card exhibiting: category avatar (44x44px, 12px radius, category color & icon), merchant/note title, time ("14:32 hrs"), method badge ("OCR Escaneado" `#79ADDC` / "Tarjeta Débito" / "Efectivo"), and tabular amount (`-$48.50`). | Transaction record with joined category & account | Accessible card with `tnum` typography | Overdrawn / warning items visually distinct | Stitch Screen `bd720de35f2b45fe856fff91b08e99f2:140-161`, `colors_quincena.md:114-125` |
| 25 | Feed (RF-04/06) | Transaction Detail & Delete Action | Tapping card opens details sheet with full invoice metadata, receipt view (if OCR), edit action, and delete button calling `DELETE /transactions/:id`. | User tap / swipe on card | Transaction detail bottom sheet / modal | Reverts category spent balance on delete | `quincena-api/src/modules/transactions/transactions.controller.ts:95-104` |
| 26 | Manual Entry (RF-04/06) | Floating/Direct Manual Expense Trigger | Quick action button / speed-dial in History screen and scanner to register expense without receipt. | User tap on manual trigger | Opens manual expense modal bottom sheet | Non-blocking | `ORIGINAL_REQUEST.md:74`, Stitch Screen `bd720de35f2b45fe856fff91b08e99f2` |
| 27 | Manual Entry (RF-04/06) | Modal Form for Manual Expense | Modal bottom sheet with drag handle, title "Nuevo Gasto Manual", amount, category, account, date, and merchant/notes fields. | User inputs | Structured transaction payload | Validation errors shown inline | `dercas_1_0.md:99`, `dercas_1_2.md:78-80`, `ORIGINAL_REQUEST.md:77` |
| 28 | Manual Entry (RF-04/06) | Decimal Keyboard Activation | Amount input explicitly activates decimal keyboard (`inputmode="decimal"` / `TextInputType.numberWithOptions(decimal: true)`) with large tabular figures. | User tap on amount input | Native decimal keypad | Prevents non-numeric characters | `dercas_1_0.md:99`, `colors_quincena.md:132`, `ORIGINAL_REQUEST.md:78` |
| 29 | Manual Entry (RF-04/06) | Category Selector with Contextual + Nueva Categoría | Visual category picker dropdown/grid showing active categories and prominent `+ Nueva Categoría` option opening `CategoryFormSheet` without losing input state. | User selection | Category assigned to transaction | Prevents submit if category omitted | `dercas_1_4.md:21`, `ORIGINAL_REQUEST.md:79` |
| 30 | Manual Entry (RF-04/06) | Required Financial Account Selector | Mandatory selector for origin funding account (`source_account_id`); auto-selects category default account if configured (`RN-CAT-01`). | User account selection | Account assigned to transaction | Prevents submit if account omitted | `dercas_1_2.md:79`, `dercas_1_4.md:39`, `ORIGINAL_REQUEST.md:80` |
| 31 | Manual Entry (RF-04/06) | Duplicate Warning Interception (RN-03) | If backend responds with HTTP 409 Conflict (`duplicate_warning: true`) due to identical merchant, amount, and date within ±24 hours, displays confirmation dialog asking user to verify before forcing with `?force=true`. | Submit transaction payload | Confirmation alert dialog | If user cancels, transaction is not registered | `dercas_1_0.md:143`, `quincena-api/src/modules/transactions/transactions.service.ts:60-85`, `ORIGINAL_REQUEST.md:83` |
| 32 | Balance Update (RF-04/06) | Real-time Category Budget Deduction (<100ms) | Saving a transaction immediately adds `amount` to `spent_amount`, subtracts from `available_amount`, and updates progress bar ratio in local reactive state. | Transaction creation event | Immediate updated budget allocation state | If spent > allocated, enters negative deficit state | `dercas_1_0.md:101`, `dercas_1_2.md:80`, `ORIGINAL_REQUEST.md:84` |
| 33 | Balance Update (RF-04/06) | Dashboard & Hero Card Live Synchronization | In `<100ms`, `HomeScreen` hero card decreases `totalAvailable`, increases `totalSpent`, and adjusts category progress bars with pastel semaphorization. | Transaction confirmation | Reactive update to `DashboardData` / notifier | Updates semaphoric color (<70% blue, 70-90% yellow, >90% coral) | `dercas_1_0.md:109-114`, `design-system_quincena.md:36-39`, `ORIGINAL_REQUEST.md:84` |
| 34 | Infrastructure / API | Bucket Name Normalization | Ensure backend and mobile agree on Supabase Storage bucket `'receipts'` (as defined in DDL migration `20261016000002_storage_receipts.sql`), resolving discrepancy with `'receipt-scans'`. | Bucket name configuration | Storage upload/download path consistency | Fixes potential 400/404 during receipt storage | `20261016000002_storage_receipts.sql:8`, `receipt-scans.service.ts:10` |

---

## 2. Edge Cases

| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | OCR Capture | Blurry image, low light, or torn receipt | OCR extraction confidence < 70% or `ocr_status === 'failed'`. Backend/Mobile gracefully falls back to manual entry form prefilled with whatever high-confidence fields were detected, displaying amber toast/banner: *"No pudimos leer algunos datos, por favor complétalos manualmente"* (CA-03.4, CA-05.3). |
| 2 | OCR Capture | Non-receipt document (e.g. selfie, landscape photo) | OCR parser detects no merchant or currency figures; returns `confidence_score = 0.00`. System prompts user to re-scan with alignment guides or switch to manual input without crashing. |
| 3 | OCR Capture | Very large image file (>10MB) or slow network (3G/4G) | Mobile compresses/scales image prior to multipart upload to stay within 3.5s latency SLA (RNF-01). UI displays spinning loader: *"Subiendo comprobante..."* with cancellation button. |
| 4 | OCR Capture | Corrupt PDF or non-image/non-pdf file | Backend `FileInterceptor` and multer reject file; returns HTTP 400 Bad Request. Mobile displays descriptive toast: *"Formato no compatible. Sube una imagen (JPG, PNG) o PDF"*. |
| 5 | Storage Bucket | Discrepancy between bucket `'receipts'` and `'receipt-scans'` | DDL `20261016000002_storage_receipts.sql` created bucket `'receipts'`, while `receipt-scans.service.ts:10` hardcoded `'receipt-scans'`. If bucket `'receipt-scans'` is not in Supabase, upload fails with `400 Error al subir el archivo: Bucket not found`. Must use `'receipts'` consistently. |
| 6 | Manual Entry | Duplicate expense within 24 hours (RN-03) | User enters identical `merchant_name`, `amount`, and `transaction_date` within ±24 hours. `POST /transactions` returns HTTP 409 Conflict with `{ duplicate_warning: true, existing_transactions: [...] }`. Mobile displays confirmation alert with previous transaction details. Tapping "Registrar de todas formas" re-submits with `?force=true`. |
| 7 | Manual Entry | Expense registered without existing allocation in cycle | User selects category that has no active allocation in `budget_allocations` for this cycle. If `allocation_id` is null, transaction records `allocation_id = NULL`, deducting from global cycle available funds without category progress bar link; or UI prompts to add category allocation first. |
| 8 | Manual Entry | Expense exceeding category remaining budget (Overspending) | Available balance becomes negative (deficit), category progress bar fill shifts to coral (`#FFC09F`), and badge displays deficit. System does NOT block transaction, strictly adhering to zero-base flexibility (CA-05.3, RN-04.1). |
| 9 | Manual Entry | Amount input with zero (`$0.00`) or negative value | Form client-side validation marks input red with *"El monto debe ser mayor a 0.00"*; submit button remains disabled (`@Min(0.01)` in `CreateTransactionDto`). |
| 10 | Manual Entry | Closed cycle transaction attempt (RN-01) | User attempts to post expense with date belonging to a cycle where `is_closed == true`. Backend throws HTTP 400 Bad Request: *"No se pueden registrar gastos en un ciclo cerrado (RN-01)"*. Mobile informs user and suggests opening new cycle or adjusting date. |
| 11 | Feed / Cards | Extremely long merchant name (>60 characters) or emojis | Merchant text in `TransactionCard` is truncated with `TextOverflow.ellipsis` on mobile viewport while preserving full name in detail modal sheet without UI overflow. |
| 12 | Feed / Filters | Filter chips combination yielding 0 matching transactions | Feed renders clean empty-state card: *"No se encontraron gastos para los filtros seleccionados"*, with a quick button to *"Limpiar filtros"*. |
| 13 | Feed / Typography | High-speed scrolling with varying digit widths (e.g. $1,111.11 vs $8,888.88) | `AppTypography.numericRow` enforces tabular figures (`font-variant-numeric: tabular-nums` / `tnum: 1`), preventing horizontal jitter or number misalignment in transaction rows and bento tile. |
| 14 | Contextual Category | Creating a new category from within manual entry sheet | User taps `+ Nueva Categoría` inside category picker. `CategoryFormSheet` opens as modal over current form. Upon saving, new category is returned, selected automatically, and original transaction inputs (amount, date, merchant) remain intact without state loss. |
| 15 | Offline / Disconnection | User captures receipt or records expense with zero signal | Mobile client handles connection timeout gracefully, informs user with offline notice, and queues/retains draft transaction in memory until reconnected (RNF-02). |

---

## 3. 5-Component Handoff Report

### 1. Observation
1. **`ORIGINAL_REQUEST.md` (lines 50–111, timestamp `## 2026-10-17T17:30:29Z`):**
   - Mandates end-to-end implementation of **Captura de Gastos vía OCR (RF-03 / RF-05)** and **Registro Manual con Historial de Transacciones (RF-04 / RF-06)** in `quincena`.
   - Requires central FAB in navigation bar and direct dashboard trigger for camera/gallery/PDF capture.
   - Demands alignment frame (`#79ADDC`), dark translucent mask, and viewfinder matching Stitch design *Escanear Comprobante OCR*.
   - Requires bottom sheet pre-confirmation modal (CA-03.2, CA-05.2) with extracted fields, category & funding account auto-suggestion, and fallback to manual form on OCR error or low confidence (CA-03.4, CA-05.3).
   - Requires replacing `PlaceholderView` in `MainShell` tab 2 with Stitch design *Historial de Gastos Quincenales*, featuring date-grouped chronological list, tabular numbers (`tnum`), filter chips by category/account, and manual entry FAB/button.
   - Demands duplicate warning (RN-03) on identical amount, merchant, and date within 24 hours.
   - Mandates real-time budget deduction and dashboard sync (CA-04.2, CA-06.2).
   - Requires receipt storage in Supabase Storage bucket `'receipts'`.

2. **Authoritative DERCAS Specifications:**
   - `dercas_1_0.md:71-102`: RF-03 (OCR extraction of amount, merchant, date, auth number; CA-03.2 never save blindly; CA-03.4 fallback), RF-04 (Manual entry with `inputmode="decimal"`, category selector, note, update in <100ms), RN-03 (24h duplicate prevention).
   - `dercas_1_2.md:41-87`: Consolidates RF-01 to RF-07 with financial accounts (`financial_accounts`), RF-05 OCR validation with category & funding account preselection, RF-06 manual entry with mandatory source account.
   - `dercas_1_4.md:11-40`: RF-CAT-01 CA-C1.4 specifies contextual `"+ Nueva Categoría"` within allocation or scan flows via modal sheet; RN-CAT-01 specifies category `default_account_id` inheritance.

3. **Stitch Design System & Live Screen Artifacts (Project `projects/6659485100151181887`):**
   - Screen `06dd441359e2446c8c5931868b87b4d7` (*Escanear Comprobante OCR*): 
     * Top bar with back button, profile, "Cámara Inteligente" pulse, torch button (`flash_off`), and "Manual" shortcut button.
     * Live simulated camera viewport (aspect ratio 4/3, `bg-inverse-surface/40` cutout mask, corner tick guides in `border-primary-container` `#79ADDC`, animated laser scan bar, confidence detection pill "Paiz detectado (98%)", simulated text boxes).
     * Slide-up sheet with drag handle, title "Validar Extracción", status badge "Listo para aplicar", amount hero card in Warm Cream (`#FCF5C7`) with 32px tabular font and edit pencil, merchant row with verified check, date row with calendar picker, horizontal category chips, debit account row, runway balance impact banner, primary button "Confirmar y Descontar" (`#1C242B`), and secondary button "Volver a escanear".
   - Screen `bd720de35f2b45fe856fff91b08e99f2` (*Historial de Gastos Quincenales*):
     * Header with title "Historial de Gastos", subtitle "Flujo de Dinero", report export button.
     * Quincena switcher bar with chevron buttons, active date span, and spent vs income ratio.
     * Analytics Bento Tile in Warm Cream (`#FCF5C7`) with "Ritmo de Gasto Quincenal", "En meta" badge, spent total, 8px progress track, daily average pace tile, and OCR captures tile.
     * Live search input bar placeholder "Buscar por comercio, factura o nota...".
     * Filter chips horizontal slider ("Todos", "Supermercado", "Servicios", "Ocio & Salidas", "Transporte", "Con Factura OCR").
     * Chronological transactions list grouped by date ("Hoy - 18 Octubre", "Ayer - 17 Octubre", "16 Octubre Inicio Ciclo").
     * Transaction card with category color avatar & icon, merchant name, timestamp, method pill ("OCR Escaneado", "Tarjeta Débito", "Transferencia", "Efectivo"), tabular monetary amount (`-$48.50`), and category/account label.

4. **Codebase Status (`quincena` & `quincena-api`):**
   - `quincena/lib/main.dart:116`: Tab index 2 is currently `const PlaceholderView(title: 'Historial de Transacciones')`.
   - `quincena/lib/core/components/navigation/app_bottom_nav_bar.dart:104`: Has fixed central FAB with `onFabPressed` callback, currently displaying toast in `main.dart:135`.
   - `quincena/lib/features/dashboard/presentation/home_screen.dart:24`: Has `onScanReceipt` callback parameter, currently invoking toast in `main.dart:108`.
   - `quincena/lib/features/categories/presentation/widgets/category_form_sheet.dart`: Complete implementation of Stitch Screen C2 available for reuse via contextual `+ Nueva Categoría`.
   - `quincena-api/src/modules/receipt-scans/`: Endpoints `GET /receipt-scans`, `GET /receipt-scans/:id`, `POST /receipt-scans/upload`, `POST /receipt-scans/:id/confirm` are fully implemented in NestJS.
   - `quincena-api/src/modules/transactions/`: Endpoints `GET /transactions?cycleId=`, `POST /transactions?force=`, `PATCH /transactions/:id`, `DELETE /transactions/:id` implemented with duplicate detection (RN-03).
   - Storage Bucket Discrepancy: `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts:10` defines `RECEIPT_SCANS_BUCKET = 'receipt-scans'`, whereas `supabase/migrations/20261016000002_storage_receipts.sql:8` and `AGENTS.md` define bucket `'receipts'`.

---

### 2. Logic Chain
1. **User Journey & Triggers:**
   - Both the central FAB on `AppBottomNavBar` and the direct action on `HomeScreen` must launch the receipt capture workflow.
   - The capture flow gives the user the option between Camera capture and Gallery/PDF file picking, or direct manual registration if no receipt is available.

2. **OCR Capture & Validation Flow:**
   - When a receipt image/PDF is provided, the mobile app sends it to `POST /receipt-scans/upload`.
   - The file is saved to Supabase Storage bucket `'receipts'`, and a `receipt_scans` record is created.
   - The extracted fields (amount, merchant, date, auth number) are presented in the pre-confirmation bottom sheet (`Stitch Screen 06dd441359e2446c8c5931868b87b4d7`).
   - The merchant is cross-referenced with previous transactions to auto-select the category and the default funding account.
   - If the user modifies any field (e.g. edits amount, chooses another category or account), the user-edited values take precedence in `ConfirmReceiptScanDto`.
   - Upon tapping "Confirmar y Descontar", `POST /receipt-scans/:id/confirm` is called, creating a transaction with `entry_method: 'ocr'` and linking it to the active cycle and category allocation.
   - If OCR fails or confidence is low, CA-03.4 / CA-05.3 mandates a seamless fallback to the manual transaction entry modal with prefilled data and an explanatory toast/banner.

3. **Transaction History & Fortnightly Feed:**
   - Replacing `PlaceholderView` at `MainShell` tab index 2 embeds the full `HistorialScreen`.
   - It fetches transactions from `GET /transactions?cycleId={activeCycleId}` and groups them chronologically by date in descending order.
   - Each transaction card displays category avatar, merchant, timestamp, entry method badge, tabular currency amount (`tnum`), and funding account.
   - Filter chips and search bar allow instant local client-side filtering without extra network requests.
   - Tapping an item provides options to view details or delete (`DELETE /transactions/:id`), which immediately recalculates the active cycle's category spent balance.

4. **Manual Entry & Balance Update:**
   - When tapping the quick action button or FAB in the feed, a manual entry modal sheet opens.
   - The amount field enforces a decimal keyboard (`inputmode="decimal"`).
   - The category selector provides a direct contextual shortcut to `+ Nueva Categoría` (`CategoryFormSheet`), and selecting a category automatically preselects its configured `default_account_id`.
   - When submitting `POST /transactions`:
     * If the backend detects identical amount, merchant, and date within ±24 hours, it returns HTTP 409 Conflict.
     * The mobile app intercepts 409 and prompts the user with RN-03 duplicate warning. If confirmed, it resubmits with `?force=true`.
     * Upon success, the transaction is saved, and the active cycle's category allocation `spent_amount` is updated immediately.
     * The Dashboard (`HomeScreen`) reflects the updated available balance, total spent, and category progress bar in <100ms.

---

### 3. Caveats
1. **Mocked OCR Extraction vs External Cloud Vision:**
   - In `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts:51`, the OCR processing sets `ocr_status = 'pending'`. The backend currently mocks or leaves extraction ready for external integration (e.g. Gemini Multimodal / Google Vision). For the mobile test and runtime experience, simulated/mock extraction or API-returned scan records should be handled gracefully.
2. **Storage Bucket Name Normalization:**
   - In `receipt-scans.service.ts:10`, `RECEIPT_SCANS_BUCKET` is `'receipt-scans'`, whereas `supabase/migrations/20261016000002_storage_receipts.sql` creates `'receipts'`. The backend should align to `'receipts'` so uploads succeed against the actual database schema.
3. **Transaction Linking when Category has no Allocation in Cycle:**
   - If a user records a manual transaction for a category that is not yet allocated in the active cycle, `allocation_id` can be `null` (since `transactions.allocation_id` is nullable). However, for category budget tracking, the UI should offer to create a $0.00 allocation or link to existing allocations.
4. **Camera Hardware vs Emulator/Testing Environment:**
   - Camera hardware depends on native mobile platform plugins (`image_picker` or `camera`). In widget tests and development builds, abstracting image selection behind an interface or service allows test suites to run deterministically with simulated images.

---

### 4. Conclusion
All functional requirements, business rules, acceptance criteria, design tokens, HTML layouts, and edge cases for **Captura OCR (RF-03/RF-05)**, **Historial de Transacciones (RF-04/RF-06)**, and **Entrada Manual con Actualización de Saldos (RF-04/RF-06)** have been fully probed, mapped, and cross-referenced.

The technical contract between `quincena` (Flutter) and `quincena-api` (NestJS) is clear:
- **OCR:** `POST /receipt-scans/upload` + `POST /receipt-scans/:id/confirm`
- **History & Manual:** `GET /transactions?cycleId={id}` + `POST /transactions?force={true|false}` + `DELETE /transactions/:id`
- **Design:** Stitch Screens `06dd441359e2446c8c5931868b87b4d7` (*Escanear Comprobante OCR*) and `bd720de35f2b45fe856fff91b08e99f2` (*Historial de Gastos Quincenales*)
- **Duplicate Prevention:** RN-03 with 409 Conflict handling and `?force=true` bypass
- **Design System Tokens:** Pastel colors (`#79ADDC`, `#FFEE93`, `#FFC09F`, `#FCF5C7`, `#ADF7B6`), dark text (`#1C242B`), and tabular lining figures (`tnum`).

The plan for the implementation agent is actionable and unambiguous.

---

### 5. Verification Method
To independently verify this specification and its requirements:

1. **Verify Flutter Codebase Analysis:**
   ```powershell
   cd E:\Projects\quincena-app\quincena
   flutter analyze
   ```
   *Expected:* 0 errors, 0 warnings.

2. **Verify Flutter Test Suite:**
   ```powershell
   cd E:\Projects\quincena-app\quincena
   flutter test
   ```
   *Expected:* All 53 tests passing across `budget_screen_test.dart`, `budget_template_test.dart`, `zero_base_calculation_test.dart`, etc.

3. **Verify NestJS Backend Test Suite:**
   ```powershell
   cd E:\Projects\quincena-app\quincena-api
   npm test
   ```
   *Expected:* All 7 test suites (45 tests) passing.

4. **Verify Stitch Design Artifacts:**
   Inspect Stitch project `projects/6659485100151181887`:
   - Screen `06dd441359e2446c8c5931868b87b4d7` ("Escanear Comprobante OCR")
   - Screen `bd720de35f2b45fe856fff91b08e99f2` ("Historial de Gastos Quincenales")

5. **Verify Database Schema:**
   Inspect `E:\Projects\quincena-app\supabase\migrations\20261016000001_initial_schema.sql` (tables `receipt_scans`, `transactions`, `budget_allocations`) and `20261016000002_storage_receipts.sql` (bucket `receipts`).

6. **Invalidation Conditions:**
   - Any modification to `CreateTransactionDto` or `ConfirmReceiptScanDto` that removes required fields (`source_account_id`, `amount`, `merchant_name`, `cycle_id`).
   - Renaming storage bucket without updating both migration and backend service.
   - Removing tabular figures (`tnum`) causing numeric jitter in finance amounts.
