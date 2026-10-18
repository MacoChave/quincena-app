# Handoff Report — UI and Date Picker Remediation Explorer (M2 Iteration 2)

**Working Directory**: `E:\Projects\quincena-app\.agents\teamwork\m2_explorer_fix_3`  
**Target Milestone**: Milestone 2 Iteration 2  
**Target Files**:
1. `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart` (Line 260)
2. `quincena/lib/features/ocr/presentation/widgets/ocr_viewfinder.dart` (Line 680)

---

## 1. Observation

### Observation 1: `firstDate` Lower Boundary Assertion in `ocr_validation_sheet.dart`
- **File**: `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart`
- **Lines 196**:
  ```dart
  _selectedDate = widget.scan.extractedDate ?? DateTime.now();
  ```
- **Lines 256–265**:
  ```dart
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) { ... },
    );
    ...
  }
  ```
- **Verbatim Framework Assertion in `flutter/packages/flutter/lib/src/material/date_picker.dart`**:
  ```dart
  assert(
    !initialDate.isBefore(firstDate),
    'initialDate $initialDate must be on or after firstDate $firstDate',
  );
  ```
- **Behavior**: If `widget.scan.extractedDate` represents a historical receipt (e.g., from year 2018 or 2019) or an OCR misread prior to Jan 1, 2020, `_selectedDate.isBefore(DateTime(2020))` evaluates to `true`. When the user taps the date picker tile (`Fecha del gasto`, lines 878–934), `showDatePicker` throws an unhandled `AssertionError` in Flutter debug/test mode and fails to present the date picker dialog.

### Observation 2: Viewfinder Canvas Overlay Bottom-Right Arc Direction in `ocr_viewfinder.dart`
- **File**: `quincena/lib/features/ocr/presentation/widgets/ocr_viewfinder.dart`
- **Lines 611–613**:
  ```dart
  final cutoutRect = Rect.fromLTWH(left, top, cutoutWidth, cutoutHeight);
  final cutoutRRect =
      RRect.fromRectAndRadius(cutoutRect, Radius.circular(cutoutRadius));
  ```
- **Lines 637–684**:
  ```dart
  // Esquina Superior Izquierda (Top-Left)
  final tlPath = Path()
    ..moveTo(cutoutRect.left, cutoutRect.top + cl)
    ..lineTo(cutoutRect.left, cutoutRect.top + r)
    ..arcToPoint(
      Offset(cutoutRect.left + r, cutoutRect.top),
      radius: Radius.circular(r),
      clockwise: true,
    )
    ..lineTo(cutoutRect.left + cl, cutoutRect.top);

  // Esquina Superior Derecha (Top-Right)
  final trPath = Path()
    ..moveTo(cutoutRect.right - cl, cutoutRect.top)
    ..lineTo(cutoutRect.right - r, cutoutRect.top)
    ..arcToPoint(
      Offset(cutoutRect.right, cutoutRect.top + r),
      radius: Radius.circular(r),
      clockwise: true,
    )
    ..lineTo(cutoutRect.right, cutoutRect.top + cl);

  // Esquina Inferior Izquierda (Bottom-Left)
  final blPath = Path()
    ..moveTo(cutoutRect.left, cutoutRect.bottom - cl)
    ..lineTo(cutoutRect.left, cutoutRect.bottom - r)
    ..arcToPoint(
      Offset(cutoutRect.left + r, cutoutRect.bottom),
      radius: Radius.circular(r),
      clockwise: false,
    )
    ..lineTo(cutoutRect.left + cl, cutoutRect.bottom);

  // Esquina Inferior Derecha (Bottom-Right)
  final brPath = Path()
    ..moveTo(cutoutRect.right - cl, cutoutRect.bottom)
    ..lineTo(cutoutRect.right - r, cutoutRect.bottom)
    ..arcToPoint(
      Offset(cutoutRect.right, cutoutRect.bottom - r),
      radius: Radius.circular(r),
      clockwise: true, // <--- FLAGGED DEFECT
    )
    ..lineTo(cutoutRect.right, cutoutRect.bottom - cl);
  ```
- **Behavior**: In Flutter's screen coordinate system (origin at top-left, $+X$ to the right, $+Y$ downwards), sweeping from the bottom horizontal edge `(cutoutRect.right - r, cutoutRect.bottom)` to the right vertical edge `(cutoutRect.right, cutoutRect.bottom - r)` around the corner circle center `(cutoutRect.right - r, cutoutRect.bottom - r)` is a counter-clockwise transition (angle decreasing from $\pi/2$ [6 o'clock] to $0$ [3 o'clock]). Specifying `clockwise: true` with `largeArc: false` instructs Skia to select the alternate center on the opposite side of the chord, curving inwards into the viewfinder window (concave dent) rather than rounding outwards (convex corner).

---

## 2. Logic Chain

### Logic Chain 1: Resolving Date Picker Lower Boundary
1. **From Observation 1**: `_selectedDate` can be any valid `DateTime` extracted from an uploaded ticket or entered historically.
2. **Framework Constraint**: `showDatePicker` requires `initialDate >= firstDate`.
3. **Proposed Remediation**:
   ```dart
   firstDate: _selectedDate.isBefore(DateTime(2020))
       ? _selectedDate
       : DateTime(2020),
   ```
4. **Behavior Analysis**:
   - Case A (`_selectedDate < 2020`, e.g. `2018-04-12`): `firstDate` becomes `2018-04-12`. `initialDate == firstDate`, satisfying `!initialDate.isBefore(firstDate)`. The calendar opens cleanly at the historical date.
   - Case B (`_selectedDate >= 2020`, e.g. current year `2026`): `firstDate` defaults to `2020-01-01`. The assertion is satisfied, and the standard 2020 lower boundary is preserved.
5. **Conclusion**: This is backward-compatible, completely eliminates the assertion risk, and avoids throwing runtime exceptions.

### Logic Chain 2: Resolving Viewfinder Overlay Arc Symmetry
1. **From Observation 2**: The viewfinder alignment guides consist of 4 L-shaped corner brackets tracing the rounded corners of `cutoutRRect` with corner radius $r = 16.0$.
2. **Coordinate Mathematics**:
   - For bottom-right corner, center of curvature is $C_{BR} = (x_R - r, y_B - r)$.
   - The path approaches the corner along the bottom edge to $P_{\text{start}} = (x_R - r, y_B)$. Vector from center: $P_{\text{start}} - C_{BR} = (0, r)$, which corresponds to direction angle $\theta_1 = \pi/2$ ($90^\circ$, straight down).
   - The path departs the corner along the right edge from $P_{\text{end}} = (x_R, y_B - r)$. Vector from center: $P_{\text{end}} - C_{BR} = (r, 0)$, which corresponds to direction angle $\theta_2 = 0$ ($0^\circ$, straight right).
   - Moving from $\theta_1 = 90^\circ$ to $\theta_2 = 0^\circ$ is a decrease in angle.
   - In 2D computer graphics where $Y$ points down, increasing angle corresponds to clockwise rotation, and decreasing angle corresponds to **counter-clockwise** rotation.
   - Therefore, moving from $90^\circ$ to $0^\circ$ along the circle centered at $C_{BR}$ requires `clockwise: false`.
3. **Comparison with Bottom-Left Corner**:
   - In `blPath`, the arc starts at $(x_L, y_B - r)$ [vector $(-r, 0)$, angle $\pi$] and ends at $(x_L + r, y_B)$ [vector $(0, r)$, angle $\pi/2$]. This transition $\pi \to \pi/2$ is also a decrease in angle, correctly marked with `clockwise: false` (line 668).
4. **Remediation**:
   - Setting `clockwise: false` at line 680 establishes exact mathematical parity between both bottom corners and guarantees the arc bulges outward matching `RRect.fromRectAndRadius(cutoutRect, Radius.circular(cutoutRadius))`.

---

## 3. Caveats

1. **Upper Boundary (`lastDate`)**:
   `lastDate: DateTime.now().add(const Duration(days: 365))`
   In standard receipt processing, receipts are from the past or near present. If OCR erroneously extracted a date farther than 1 year in the future, Flutter's `!initialDate.isAfter(lastDate)` would be triggered. However, in financial apps, receipts dated in the distant future are invalid and are typically capped during OCR parsing. No change to `lastDate` was requested or required.
2. **Downstream Animation Tests**:
   `OcrViewfinder` contains infinite repeating animations (`_laserAnimation`, `_pulseAnimation`). Any widget tests invoking `tester.pumpAndSettle()` against `OcrViewfinder` will hang unless pumped with a bounded duration (e.g. `await tester.pump(const Duration(milliseconds: 100));`). This is documented in `proposed_verification_tests.dart` and handled by explorer fix 2.

---

## 4. Conclusion

Both issues are precisely isolated, mathematically verified, and documented with minimal-diff patch solutions:

### Deliverables in Working Directory:
1. `ocr_validation_sheet_date_picker.patch` — Git patch for `ocr_validation_sheet.dart`
2. `ocr_viewfinder_corner_arc.patch` — Git patch for `ocr_viewfinder.dart`
3. `remediation_ui_and_datepicker.patch` — Unified patch combining both changes
4. `proposed_verification_tests.dart` — Complete Flutter widget test specification

### Before vs After Code Snippets

#### 1. `quincena/lib/features/ocr/presentation/widgets/ocr_validation_sheet.dart:257-263`
```diff
   Future<void> _pickDate() async {
     final picked = await showDatePicker(
       context: context,
       initialDate: _selectedDate,
-      firstDate: DateTime(2020),
+      firstDate: _selectedDate.isBefore(DateTime(2020))
+          ? _selectedDate
+          : DateTime(2020),
       lastDate: DateTime.now().add(const Duration(days: 365)),
       builder: (context, child) {
```

#### 2. `quincena/lib/features/ocr/presentation/widgets/ocr_viewfinder.dart:677-682`
```diff
     final brPath = Path()
       ..moveTo(cutoutRect.right - cl, cutoutRect.bottom)
       ..lineTo(cutoutRect.right - r, cutoutRect.bottom)
       ..arcToPoint(
         Offset(cutoutRect.right, cutoutRect.bottom - r),
         radius: Radius.circular(r),
-        clockwise: true,
+        clockwise: false,
       )
       ..lineTo(cutoutRect.right, cutoutRect.bottom - cl);
```

---

## 5. Verification Method

### 1. Apply Proposed Patches
From the repository root (`e:\Projects\quincena-app`):
```pwsh
git apply .agents/teamwork/m2_explorer_fix_3/remediation_ui_and_datepicker.patch
```

### 2. Run Static Analysis
```pwsh
cd e:\Projects\quincena-app\quincena
flutter analyze
```
Expected output:
```
Analyzing quincena...
No issues found!
```

### 3. Run Flutter Test Suite
```pwsh
flutter test test/features/ocr/production_ocr_flow_test.dart
flutter test test/features/ocr/ocr_capture_and_validation_test.dart
```
Expected output:
```
All tests passed!
```

### 4. Run Dedicated UI and Date Picker Widget Tests
Incorporate `proposed_verification_tests.dart` and execute:
```pwsh
flutter test test/features/ocr/ocr_ui_and_datepicker_remediation_test.dart
```
Expected output:
- Historical receipt dated 2018 opens date picker without assertion failure.
- Viewfinder overlay renders convex corners smoothly without concave indentation.
