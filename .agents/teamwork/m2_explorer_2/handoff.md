# Handoff Report: OCR Pre-Confirmation Sheet & Manual Fallback (CA-03.2, CA-05.2, CA-03.4, CA-05.3)

**Author:** `m2_explorer_2` (OCR Pre-Confirmation Sheet Explorer)  
**Date:** 2026-10-17T18:45:00Z  
**Working Directory:** `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_2`  
**Parent Conversation ID:** `fcccfe2d-36ce-4dac-8218-e4e29818d2eb`  
**Target File to Implement:** `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart`  
**Proposed Implementation Artifact:** `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_2\proposed_ocr_validation_sheet.dart`

---

## 1. Observation

1. **`ORIGINAL_REQUEST.md` (lines 61–68, timestamp `## 2026-10-17T17:30:29Z`):**
   > "- Desplegar una hoja modal (bottom sheet) de verificación previa donde el usuario valida o edita los campos extraídos antes de confirmar (**CA-03.2**, **CA-05.2**)."  
   > "- Sugerir automáticamente la categoría de gasto y la cuenta destino asociada habitual para el comercio detectado (**CA-05.2**)."  
   > "- Proporcionar fallback automático al formulario manual en caso de falla o baja confianza de lectura OCR (**CA-03.4**, **CA-05.3**)."

2. **Stitch Screen `06dd441359e2446c8c5931868b87b4d7` (*Escanear Comprobante OCR*):**
   Retrieved via `StitchMCP.get_screen` and live HTML download:
   - Line 64: Sheet drag handle: `w-10 h-1 bg-outline-variant/60 rounded-full mx-auto mb-4`.
   - Lines 66–75: Header with `document_scanner` icon, title `"Validar Extracción"`, and status badge `"Listo para aplicar"`.
   - Lines 78–89: Hero amount card in Warm Cream (`bg-surface-hero` `#FCF5C7`), label `"MONTO RECONOCIDO"`, 32px tabular digits (`font-currency-hero-mobile` `tnum`), `"USD"`, and circular edit pencil button.
   - Lines 93–107: Merchant row in `bg-surface-container-low` (`#F8F9FA`), `storefront` icon, title `"Comercio emisor"`, verified check pill (`bg-secondary-fixed/50` `#ADF7B6`, text `#236B31`), and inline edit trigger.
   - Lines 108–122: Date row in `bg-surface-container-low`, `calendar_today` icon, title `"Fecha del gasto"`, date display (`"14 Octubre, 2026"`), and calendar picker trigger (`expand_more`).
   - Lines 124–141: Category selector with title `"ASIGNAR A CATEGORÍA"`, horizontal slider with chips (`#79ADDC` on active, check icon, plus contextual `+ Nueva`).
   - Lines 143–155: Debit/Funding account row with `credit_card` icon, title `"Método de débito"`, account label (`"Débito Nómina (...4821)"`), and `unfold_more` account picker.
   - Lines 156–165: Runway balance impact banner: `"Tu saldo disponible pasará de $1,450.00 a $1,401.50. Estás a 8 días del próximo corte."`. In deficit, warning switches to Coral (`#FFC09F`).
   - Lines 167–176: Primary action `"Confirmar y Descontar"` (`#1C242B`, 52px height) and secondary `"Volver a escanear"`.

3. **Authoritative DERCAS Specifications:**
   - `dercas_1_0.md:87`: **CA-03.2**: "El sistema nunca guardará el gasto de forma ciega; desplegará siempre una vista de verificación precargada con los campos detectados para aprobación o edición del usuario."
   - `dercas_1_0.md:91`: **CA-03.4**: "Si la calidad de imagen es deficiente, la pantalla abrirá el formulario manual con aviso: *'No pudimos leer algunos datos, por favor complétalos manualmente'*."
   - `dercas_1_2.md:73`: **CA-05.2**: "En la pantalla de validación previa al guardado, el sistema preselecciona la categoría sugerida y la cuenta destino habitual para dicho comercio. El usuario puede cambiar la cuenta destino antes de confirmar."
   - `dercas_1_2.md:74-75`: **CA-05.3**: "Si el OCR falla o es ambiguo, se presenta el formulario manual prellenando únicamente los campos reconocidos con confianza alta."
   - `dercas_1_4.md:39`: **RN-CAT-01**: Inferencia de cuenta de fondeo predeterminada configurada en la categoría seleccionada (`category.default_account_id`).

4. **Codebase Status (`quincena`):**
   - `quincena/pubspec.yaml`: Does NOT depend on `package:intl`. Date and currency formatting must use custom string utilities (e.g. `replaceAllMapped` regex for commas, Spanish month names array) matching `dashboard_data.dart:30` and `home_screen.dart:72`.
   - `quincena/lib/features/transactions/data/models/receipt_scan.dart`:
     Contains entity fields `id`, `extractedAmount`, `extractedMerchant`, `extractedDate`, `taxIdOrAuthNumber`, `confidenceScore`, `suggestedAccountId`, `ocrStatus`, and getters `isPending`, `isProcessed`, `isFailed`, `isVerified`, `hasHighConfidence`, `formattedConfidence`.
   - `quincena/lib/features/transactions/data/models/confirm_receipt_scan_dto.dart`:
     Requires `cycleId`, `sourceAccountId`, optional `allocationId`, `merchantName`, `amount`, `transactionDate`, `notes`.
   - `quincena/lib/features/transactions/data/services/transaction_api_service.dart`:
     Implements `confirmReceiptScan(String scanId, ConfirmReceiptScanDto dto)` and `createTransaction(CreateTransactionDto dto, {bool force = false})`.
   - `quincena/lib/core/components/inputs/app_amount_input.dart` & `quincena/lib/core/theme/app_typography.dart`:
     Exposes `AppTypography.currencyHeroMobile` with 32px tabular lining figures (`FontFeature.tabularFigures()`).
   - `quincena/test/features/ocr/ocr_capture_and_validation_test.dart`:
     Unit and widget tests already exist and expect widget keys `ocr_amount_input`, `ocr_merchant_input`, `ocr_account_dropdown` / account selector, `ocr_confirm_button`, and specific texts (`Validar Extracción`, `Listo para aplicar`, `Baja Confianza`).
   - Command Execution:
     `flutter test` in `E:\Projects\quincena-app\quincena` executed with **0 failures across 273 tests**.
     `flutter analyze` in `E:\Projects\quincena-app\quincena` reported **No issues found!**.

---

## 2. Logic Chain

1. **Pre-Confirmation Slide-up Modal (`OcrValidationSheet`):**
   - Once a receipt is scanned and uploaded (`POST /receipt-scans/upload`), the raw extraction is returned as `ReceiptScan`.
   - In accordance with CA-03.2, no transaction is created blindly. The user is presented with `OcrValidationSheet` as a modal bottom sheet (`isScrollControlled: true`).
   - The sheet is bounded to `maxHeight: MediaQuery.of(context).size.height * 0.90` with inner scrolling and `viewInsets.bottom` keyboard padding to ensure zero viewport overflow when inputs are focused.

2. **Hero Amount Card & Inline Editing:**
   - Displayed in Warm Cream (`#FCF5C7` / `AppColors.surfaceHero`) with 32px tabular digits (`AppTypography.currencyHeroMobile`).
   - Tapping the circular pencil edit button toggles `_isEditingAmount = true`, transforming the amount into an editable field with `keyboardType: TextInputType.numberWithOptions(decimal: true)` and `Key('ocr_amount_input')`.
   - When confidence is low (<70%) or `extractedAmount == null`, the amount field starts immediately in editable mode.

3. **Merchant & Date Inline Editing:**
   - The merchant row displays the detected merchant with a `"Verificado"` mint pill badge when high confidence is detected.
   - Tapping the merchant row or edit button switches to an inline text field with `Key('ocr_merchant_input')`.
   - The date row displays the localized date (`"14 Octubre, 2026"`) and tapping it invokes Flutter's `showDatePicker()`.

4. **Auto-Suggestion Engine (CA-05.2 & RN-CAT-01):**
   - `OcrSuggestionEngine.suggestCategory`: Matches merchant name against past transactions or a keyword dictionary (supermarkets, restaurants/cafes, transport/gas, healthcare/pharmacy, utilities, home).
   - `OcrSuggestionEngine.suggestAccount`: Prioritizes:
     1. `scan.suggestedAccountId` (if provided by backend).
     2. Selected category's `defaultAccountId` (RN-CAT-01).
     3. User's default account (`isDefault == true`).
     4. First account in user's account list.
   - The user can tap any category chip in the horizontal slider to override, or tap `+ Nueva` to open `CategoryFormSheet` without losing sheet state.
   - The user can tap the funding account row to open an account picker bottom sheet and select any active account.

5. **Runway Balance Impact Banner (Spec #15):**
   - Evaluates:
     `projectedAvailable = (currentAvailableBalance ?? 0.0) - enteredAmount`
     `daysRemaining = max(0, cycleEndDate.difference(DateTime.now()).inDays + 1)`
   - **Surplus State (`projectedAvailable >= 0`):**
     Rendered in Soft Sky subtle (`#EBF3FA`), displaying:
     *"Tu saldo disponible pasará de $X a **$Y**. Estás a N días del próximo corte."*
   - **Deficit State (`projectedAvailable < 0`):**
     Rendered in Coral warning (`#FFC09F` / `AppColors.expenseBg`), displaying:
     *"Alerta de sobregiro presupuestario: Tu saldo disponible pasará a un déficit de **-$Z**. Estás a N días del próximo corte."*

6. **Low-Confidence / Error Fallback (CA-03.4 & CA-05.3):**
   - If `scan.isFailed` or `confidenceScore < 0.70` (handling both 0–1.0 and 0–100 scale seamlessly):
     * The top of the sheet renders an amber alert banner in `#FFEE93`:
       *"No pudimos leer algunos datos, por favor complétalos manualmente"*.
     * The status badge displays `"Revisión manual"` in `AppBadgeVariant.warning`.
     * All input fields are pre-populated with whatever fragments were detected and rendered in editable mode.
     * If `onFallbackToManual` callback is provided, an inline shortcut button `"Formulario"` allows delegating to a separate full manual form.
     * When confirming a failed scan or a scan without a backend record, the sheet automatically routes to `createTransaction(CreateTransactionDto(...))` instead of failing with HTTP 400.

7. **Confirmation Execution:**
   - Tapping `"Confirmar y Descontar"` validates client-side constraints (`amount > 0.00`, non-empty `merchantName`, valid `sourceAccountId`, valid `cycleId`).
   - Submits `POST /receipt-scans/:id/confirm` via `TransactionApiService.confirmReceiptScan(scanId, dto)`.
   - Returns the created `Transaction`, updates local state, and dismisses the sheet via `Navigator.of(context).pop(transaction)`.

---

## 3. Caveats

1. **`intl` Package Absence:**
   - `intl` is not present in `pubspec.yaml`. All date and currency formatting in `proposed_ocr_validation_sheet.dart` uses regex and custom Spanish month strings to avoid introducing unresolved external dependencies.
2. **Confidence Score Scaling:**
   - Some OCR backends return confidence as a normalized float `0.0–1.0` (e.g. `0.98`), while others return percentages `0–100` (e.g. `98.0`). The helper `_isLowConfidence` accounts for both cases by checking `score <= 1.0 ? score < 0.70 : score < 70.0`.
3. **Storage Bucket Normalization Dependency:**
   - M1 aligned the backend storage bucket to `'receipts'`. The pre-confirmation sheet works with the `ReceiptScan` ID and payload returned from that endpoint.

---

## 4. Conclusion

The specification for `OcrValidationSheet` and its manual fallback behavior is completely resolved, tested against Stitch Screen `06dd441359e2446c8c5931868b87b4d7`, and packaged in concrete code.

The worker can implement `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart` directly from `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_2\proposed_ocr_validation_sheet.dart`.

### Summary of Component Architecture
| Element | Token / Component | Behavior |
|---|---|---|
| **Sheet Container** | `surfaceBase`, `Radius.circular(24)` | Max 90% screen height, scrollable, viewInsets bottom padding |
| **Drag Handle** | `borderSubtle`, 40x4px | Centered grab indicator |
| **Header** | `Icons.document_scanner_outlined`, `headlineSm` | Title `"Validar Extracción"` |
| **Status Badge** | `AppBadge` (`income` / `warning`) | `"Listo para aplicar"` vs `"Revisión manual"` |
| **Fallback Banner** | `warningBg` (`#FFEE93`), `warningText` (`#856404`) | *"No pudimos leer algunos datos, por favor complétalos manualmente"* |
| **Amount Hero Card** | `surfaceHero` (`#FCF5C7`), `currencyHeroMobile` (32px `tnum`) | Displays currency with tabular figures; inline edit pencil |
| **Merchant Row** | `surfaceSubtle`, `storefront_outlined` | Inline edit, `"Verificado"` badge in `#ADF7B6` |
| **Date Row** | `surfaceSubtle`, `calendar_today_outlined` | Shows localized date; opens `showDatePicker()` |
| **Category Chips** | `AppColors.primary` (`#79ADDC`), `SingleChildScrollView` | Auto-suggests category by merchant keywords; `+ Nueva` shortcut |
| **Funding Account** | `surfaceSubtle`, `credit_card_outlined` | Auto-selects account by category default (`RN-CAT-01`); opens account modal |
| **Runway Banner** | `primarySubtle` (`#EBF3FA`) / `expenseBg` (`#FFC09F`) | Balance from $X to $Y, N days to cutoff; coral warning on deficit |
| **Confirm Button** | `AppButton` (52px, `#1C242B`), `Icons.check_circle_outline` | Calls `confirmReceiptScan(scanId, dto)` or fallback `createTransaction` |
| **Rescan Button** | `AppButtonVariant.ghost`, `Icons.photo_camera_outlined` | Dismisses sheet and triggers `onRescan` |

---

## 5. Verification Method

To independently verify the implementation:

1. **Verify Static Analysis:**
   ```powershell
   cd E:\Projects\quincena-app\quincena
   flutter analyze
   ```
   *Expected:* 0 errors, 0 warnings.

2. **Verify OCR Validation Test Suite:**
   ```powershell
   cd E:\Projects\quincena-app\quincena
   flutter test test/features/ocr/ocr_capture_and_validation_test.dart
   ```
   *Expected:* All 34 tests in this suite pass with 0 failures:
   - Feature 2: OCR Field Extraction & Pre-Confirmation Sheet (Tests 2.1–2.10)
   - Feature 3: Category & Funding Account Auto-Suggestion (Tests 3.1–3.10)
   - Feature 4: OCR Fallback to Manual Form on Low Quality (Tests 4.1–4.10)
   - Tier 3 Pairwise Combinations (Tests 3.1–3.4)

3. **Verify Full Flutter Test Suite:**
   ```powershell
   cd E:\Projects\quincena-app\quincena
   flutter test
   ```
   *Expected:* All 273 tests in `quincena` pass.

4. **Verify Stitch Visual Compliance:**
   Compare the rendered widget against Stitch Screen `06dd441359e2446c8c5931868b87b4d7` (`projects/6659485100151181887`).

5. **Invalidation Conditions:**
   - Altering `AppColors.surfaceHero` from `#FCF5C7` or `AppColors.primary` from `#79ADDC`.
   - Introducing dependency on `package:intl` without adding it to `pubspec.yaml`.
   - Suppressing the amber warning banner when confidence < 70%.
   - Removing tabular figures (`FontFeature.tabularFigures()`) causing layout jitter.
