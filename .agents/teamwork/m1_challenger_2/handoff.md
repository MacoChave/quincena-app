# Handoff Report: Milestone 1 Network Resilience Empirical Challenge

**Author**: Milestone 1 Network Challenger (`m1_challenger_2`)  
**Parent Agent**: `fcccfe2d-36ce-4dac-8218-e4e29818d2eb`  
**Working Directory**: `E:\Projects\quincena-app\.agents\teamwork\m1_challenger_2`  
**Milestone**: Milestone 1 — Backend Bucket Alignment & Mobile Foundation  
**Date**: 2026-10-17T18:14:30Z  
**Verdict**: **REQUEST_CHANGES**

---

## Challenge Summary

**Overall risk assessment**: **HIGH**  
While the network layer in `ApiClient.uploadMultipart` demonstrates robust boundary delimiter preservation, successful 5MB streaming, resilient handling of special characters/emojis in file paths, and safe handling of HTTP 500 HTML error responses without crashing `jsonDecode`, the higher-level service layer `TransactionApiService.createTransaction` contains critical unhandled type casts that cause uncaught Dart runtime `_TypeError` exceptions when receiving malformed HTTP 409 Conflict duplicate payloads (RN-03).

---

## 1. Observation

Adversarial test suite was written in `quincena/test/core/network/api_client_network_challenge_test.dart` (22 tests across 5 challenge domains) and executed with `flutter test test/core/network/api_client_network_challenge_test.dart`.

### Observations Summary:
1. **Challenge 1 (Multipart Stress & Special Characters)**: 4 of 4 tests **PASSED**.
   - Streams 5 MB simulated binary buffer without byte truncation or payload corruption (`capturedStreamedBytes > 5 * 1024 * 1024`).
   - File paths containing Spanish accents, spaces, emojis, hash, and parentheses (`Factura & Recibo #42 (Quincena Octubre - Café, Té & Maíz) 🧾.pdf`) are resolved and attached cleanly by `MultipartFile.fromPath`.
   - 0-byte empty files and long file names (200+ characters) complete without crash.

2. **Challenge 2 (Boundary Delimiter Protection & Header Tampering)**: 3 of 3 tests **PASSED**.
   - Malicious headers containing `Content-Type: application/json` or uppercase `CONTENT-TYPE: text/plain` are filtered out in `ApiClient.uploadMultipart` (lines 148–155), preventing erasure of the multipart boundary.
   - Streamed body bytes verifiably contain standard multipart boundaries (`--$declaredBoundary` and `--$declaredBoundary--`).

3. **Challenge 3 (Network Failure Modes: 500, 403, 404, 502, 504)**: 6 of 6 tests **PASSED**.
   - HTTP 500 with raw HTML error body (`<html><body>500 Internal Server Error</body></html>`) does not throw `FormatException`; `ApiClient` safely preserves raw HTML in `details` and throws `ApiException(500)` with `isServerError: true`.
   - HTTP 403, 404, 502, 503, 504 are mapped cleanly without crashes.
   - `ApiException.extractMessage` handles low-level `SocketException`, `HttpException`, `FormatException`, and null cleanly.

4. **Challenge 4 (HTTP 409 Conflict Malformed Details - RN-03)**: 3 of 6 tests **FAILED** with reproducible `_TypeError`:
   - **Failure 1**: Malformed `existing_transactions` as a `String` (`'CORRUPTED_STRING_NOT_A_LIST'`):
     ```
     Which: threw _TypeError:<type 'String' is not a subtype of type 'List<dynamic>?' in type cast>
     stack package:quincena/features/transactions/data/services/transaction_api_service.dart 113:51 TransactionApiService.createTransaction
     ```
   - **Failure 2**: Malformed `existing_transactions` as an `Integer` (`12345`):
     ```
     Which: threw _TypeError:<type 'int' is not a subtype of type 'List<dynamic>?' in type cast>
     stack package:quincena/features/transactions/data/services/transaction_api_service.dart 113:51 TransactionApiService.createTransaction
     ```
   - **Failure 3**: Malformed item fields inside `existing_transactions` (e.g. integer `id` `99999` or integer `merchant_name` `12345`):
     ```
     Which: threw _TypeError:<type 'int' is not a subtype of type 'String?' in type cast>
     stack package:quincena/features/transactions/data/services/transaction_api_service.dart 24:22 new DuplicateTransactionItem.fromJson
     ```

5. **Challenge 5 (Service Resilience Under Unexpected Payloads)**: 3 of 3 tests **PASSED**.
   - `getTransactions` returns empty list on unexpected JSON object.
   - `confirmReceiptScan` propagates 500 cleanly.
   - `uploadReceiptScan` handles missing `'scan'` root key without crash.

---

## 2. Logic Chain

1. In `quincena/lib/features/transactions/data/services/transaction_api_service.dart` line 112–119:
   ```dart
   if (rawDetails is Map<String, dynamic>) {
     final existing =
         rawDetails['existing_transactions'] as List<dynamic>?;
     if (existing != null) {
       duplicates = existing
           .whereType<Map<String, dynamic>>()
           .map((m) => DuplicateTransactionItem.fromJson(m))
           .toList();
     }
   }
   ```
2. Step 1: When a reverse proxy, API gateway, or modified backend response returns a 409 Conflict with non-array `existing_transactions` (e.g. string message, boolean flag, or error code), `rawDetails['existing_transactions'] as List<dynamic>?` is executed.
3. Step 2: Under Dart's sound type system, casting a non-list runtime type with `as List<dynamic>?` throws a runtime `_TypeError`.
4. Step 3: `TransactionApiService.createTransaction` catches only `ApiException` (line 100), so the `_TypeError` escapes unhandled to the UI layer, causing an app crash instead of displaying an error message or throwing `DuplicateTransactionException`.
5. Step 4: In `DuplicateTransactionItem.fromJson` (line 24–33):
   ```dart
   id: json['id'] as String? ?? '',
   merchantName: json['merchant_name'] as String? ?? '',
   amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
   ```
   If any item in `existing_transactions` has a numeric ID (e.g. legacy integer ID from another system or auto-increment) or non-string merchant name, casting with `as String?` throws `_TypeError: type 'int' is not a subtype of type 'String?' in type cast`.

---

## 3. Caveats

1. **Backend Contract**:
   `quincena-api`'s current NestJS implementation returns `existing_transactions` as an array under normal conditions. The failure mode occurs under adversarial or edge conditions: upstream proxy rewrites, corrupted responses, or unexpected server error payloads during duplicate detection.
2. **Review-Only Constraint**:
   Per the Empirical Challenger role instructions, implementation files were NOT modified by this challenger. The fixes must be applied by the implementation worker.

---

## 4. Conclusion

**Verdict: REQUEST_CHANGES**

The mobile foundation must be hardened against malformed duplicate warning payloads before proceeding to Milestone 2.

### Required Changes for Implementation Worker:
1. **Defensive Parsing in `TransactionApiService.createTransaction`**:
   Replace unsafe cast `as List<dynamic>?` with safe type check:
   ```dart
   final rawExisting = rawDetails['existing_transactions'];
   if (rawExisting is List) {
     duplicates = rawExisting
         .whereType<Map<String, dynamic>>()
         .map((m) => DuplicateTransactionItem.fromJson(m))
         .toList();
   }
   ```
2. **Defensive Serialization in `DuplicateTransactionItem.fromJson`**:
   Use `.toString()` and `num.tryParse` rather than direct `as` casts:
   ```dart
   factory DuplicateTransactionItem.fromJson(Map<String, dynamic> json) {
     final rawAmount = json['amount'];
     final double parsedAmount = rawAmount is num
         ? rawAmount.toDouble()
         : (double.tryParse(rawAmount?.toString() ?? '') ?? 0.0);

     return DuplicateTransactionItem(
       id: json['id']?.toString() ?? '',
       merchantName: json['merchant_name']?.toString() ?? '',
       amount: parsedAmount,
       transactionDate: json['transaction_date'] != null
           ? DateTime.tryParse(json['transaction_date'].toString())
           : null,
       createdAt: json['created_at'] != null
           ? DateTime.tryParse(json['created_at'].toString())
           : null,
     );
   }
   ```

---

## 5. Verification Method

To independently reproduce the failures and verify the empirical challenge:

1. **Run the Adversarial Test Suite**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter test test/core/network/api_client_network_challenge_test.dart
   ```
   *Expected Current Output*: Exits with code 1; 19 tests pass, 3 tests fail with `_TypeError` in `transaction_api_service.dart:113` and `transaction_api_service.dart:24`.

2. **Verify Static Analysis**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena
   flutter analyze test/core/network/api_client_network_challenge_test.dart
   ```
   *Expected Current Output*: `No issues found! (ran in 4.4s)`.

3. **Invalidation Condition**:
   Once the implementation worker updates `transaction_api_service.dart` with defensive `is List` checks and safe string/num coercion, all 22 tests in `test/core/network/api_client_network_challenge_test.dart` will pass (exit code 0).
