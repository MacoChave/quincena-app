## 2026-10-17T17:54:28Z
You are the Milestone 1 Implementation Worker for the Quincena project.
Working Directory: E:\Projects\quincena-app\.agents\teamwork\m1_worker
Read ORIGINAL_REQUEST.md: E:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md (timestamp ## 2026-10-17T17:30:29Z).
Read PROJECT.md: E:\Projects\quincena-app\PROJECT.md.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your task for Milestone 1 (Backend Bucket Alignment & Mobile Foundation):
Implement the verified changes from the three M1 Explorer reports:

1. Backend Storage Bucket Fix (from E:\Projects\quincena-app\.agents\teamwork\m1_explorer_1\handoff.md):
   - In `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts` line 10, change `RECEIPT_SCANS_BUCKET = 'receipt-scans';` to `RECEIPT_SCANS_BUCKET = 'receipts';`.
   - In `quincena-api/src/modules/auth/auth.service.ts` line 16, change `RECEIPT_SCANS_BUCKET = 'receipt-scans';` to `RECEIPT_SCANS_BUCKET = 'receipts';`.
   - Run `npm run build` and `npm test` in `quincena-api/`. Verify clean pass.

2. Mobile Pubspec & Network Layer (from E:\Projects\quincena-app\.agents\teamwork\m1_explorer_2\handoff.md):
   - In `quincena/pubspec.yaml`, add `image_picker: ^1.1.2` under dependencies.
   - Run `flutter pub get` in `quincena/`.
   - Create `quincena/lib/core/network/api_response.dart` with `ApiResponse<T>`.
   - Update `quincena/lib/core/network/api_exception.dart` with `details` and `isConflict`.
   - Update `quincena/lib/core/network/api_client.dart` with `uploadMultipart<T>()` and export `api_response.dart`.
   - Create unit test `quincena/test/core/network/api_client_multipart_test.dart`.

3. Mobile Models & Service Layer (from E:\Projects\quincena-app\.agents\teamwork\m1_explorer_3\handoff.md):
   Copy or adapt the 7 production-ready files from `E:\Projects\quincena-app\.agents\teamwork\m1_explorer_3\`:
   - `proposed_transaction.dart` -> `quincena/lib/features/transactions/data/models/transaction.dart`
   - `proposed_receipt_scan.dart` -> `quincena/lib/features/transactions/data/models/receipt_scan.dart`
   - `proposed_create_transaction_dto.dart` -> `quincena/lib/features/transactions/data/models/create_transaction_dto.dart`
   - `proposed_confirm_receipt_scan_dto.dart` -> `quincena/lib/features/transactions/data/models/confirm_receipt_scan_dto.dart`
   - `proposed_models.dart` -> `quincena/lib/features/transactions/data/models/models.dart`
   - `proposed_transaction_api_service.dart` -> `quincena/lib/features/transactions/data/services/transaction_api_service.dart`
   - `proposed_transaction_models_test.dart` -> `quincena/test/features/transactions/transaction_models_test.dart`

4. Verification:
   - Run `flutter analyze` in `quincena/` (must be 0 errors, 0 warnings).
   - Run `flutter test` in `quincena/` (all tests passing).
   - Run `npm test` and `npm run build` in `quincena-api/`.

5. Documentation:
   - Write your handoff report to `E:\Projects\quincena-app\.agents\teamwork\m1_worker\handoff.md` following the Handoff Protocol (Observation, Logic Chain, Caveats, Conclusion, Verification Method).
   - When finished, notify the orchestrator via send_message.
