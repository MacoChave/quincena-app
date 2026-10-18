# Technical Handoff Report: Backend & Storage Alignment (Milestone 1)

**Author**: Explorer Subagent (`m1_explorer_1`)  
**Target Milestone**: Milestone 1 — Backend Bucket Name Normalization  
**Date**: 2026-10-17  
**Working Directory**: `E:\Projects\quincena-app\.agents\teamwork\m1_explorer_1`  
**Target Execution Workspace**: `E:\Projects\quincena-app\quincena-api`  

---

## 1. Observation

### 1.1 Supabase Storage DDL & RLS Policies
- In `supabase/migrations/20261016000002_storage_receipts.sql`:
  - Lines 7-9:
    ```sql
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('receipts', 'receipts', false)
    ON CONFLICT (id) DO NOTHING;
    ```
  - Lines 13-31: RLS policies on `storage.objects` (`"User receipt upload"`, `"User receipt access"`, `"User receipt update"`, `"User receipt delete"`) all mandate:
    ```sql
    bucket_id = 'receipts' AND (storage.foldername(name))[1] = auth.uid()::text
    ```
- In `supabase/migrations/20261017000001_v1_3_auth_and_account_lifecycle.sql`:
  - Lines 59-61 (SQL user purge function):
    ```sql
    DELETE FROM storage.objects
    WHERE bucket_id = 'receipts'
      AND (storage.foldername(name))[1] = current_user_id::text;
    ```

### 1.2 Inconsistency in NestJS API Service Files
- In `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts`:
  - Line 10:
    ```typescript
    const RECEIPT_SCANS_BUCKET = 'receipt-scans';
    ```
  - Lines 66-73:
    ```typescript
    // Subir a Supabase Storage
    const { error: uploadError } = await client.storage
      .from(RECEIPT_SCANS_BUCKET)
      .upload(storagePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });
    ```
- In `quincena-api/src/modules/auth/auth.service.ts`:
  - Line 16:
    ```typescript
    const RECEIPT_SCANS_BUCKET = 'receipt-scans';
    ```
  - Line 171 (JSDoc already anticipates `'receipts'`):
    ```typescript
    * CA-A4.4: Purgado de archivos binarios/imágenes en Supabase Storage (receipts/{user_id}/*).
    ```
  - Lines 195-201:
    ```typescript
    const adminClient = this.supabase.adminClient;
    const { data: files, error: listError } = await adminClient.storage
      .from(RECEIPT_SCANS_BUCKET)
      .list(userId);

    if (!listError && files && files.length > 0) {
      const filePaths = files.map((f) => `${userId}/${f.name}`);
      await adminClient.storage.from(RECEIPT_SCANS_BUCKET).remove(filePaths);
    ```

### 1.3 Audit of Existing Tests in `quincena-api`
- Executed `npm test` in `E:\Projects\quincena-app\quincena-api`:
  ```
  Test Suites: 7 passed, 7 total
  Tests:       45 passed, 45 total
  Snapshots:   0 total
  Time:        36.561 s
  ```
- Executed `npm run build` in `E:\Projects\quincena-app\quincena-api`:
  ```
  > nest build
  Exit code: 0
  ```
- Search for `.spec.ts` files under `quincena-api/src`:
  1. `src/app.controller.spec.ts`
  2. `src/modules/budget-allocations/dto/budget-allocation-dto.spec.ts`
  3. `src/modules/budget-templates/dto/budget-template-dto.spec.ts`
  4. `src/modules/categories/categories.service.spec.ts`
  5. `src/modules/budget-allocations/budget-allocations.service.spec.ts`
  6. `src/modules/budget-templates/budget-templates.controller.spec.ts`
  7. `src/modules/budget-templates/budget-templates.service.spec.ts`
- Search across all `.spec.ts` files for `receipt`, `receipt-scans`, or `bucket`:
  - Result: 0 matches.
  - Neither `receipt-scans.service.spec.ts` nor `auth.service.spec.ts` currently exists in the repository.
  - No existing unit test mock expects `'receipt-scans'` as a storage bucket.
- Global search across `quincena-api`:
  - Other occurrences of `'receipt-scans'` are only in `ReceiptScansController` routing (`@Controller('receipt-scans')`, `@ApiTags('receipt-scans')`) and `main.ts` Swagger documentation. These are REST endpoints (`POST /receipt-scans/upload`) and must NOT be changed.

---

## 2. Logic Chain

1. **Storage Bucket Name Mismatch**:
   - Observation 1.1 establishes that the Supabase database migration `20261016000002_storage_receipts.sql` creates only the bucket `'receipts'` and configures RLS policies strictly matching `bucket_id = 'receipts'`.
   - Observation 1.2 demonstrates that `quincena-api` uses `const RECEIPT_SCANS_BUCKET = 'receipt-scans'`.
   - In Supabase Storage, referencing `'receipt-scans'` targets a non-existent bucket or fails the RLS security check, causing `uploadAndCreateScan` to throw `BadRequestException('Error al subir el archivo: ...')` and causing `deleteAccount` to silently fail purging stored files.

2. **Storage Path Alignment**:
   - In `receipt-scans.service.ts:64`, `storagePath` is generated as `${userId}/${Date.now()}.${ext}`.
   - When using bucket `'receipts'`, the first folder component `(storage.foldername(name))[1]` equals `${userId}`, which strictly satisfies the RLS condition `(storage.foldername(name))[1] = auth.uid()::text`.
   - Aligning `RECEIPT_SCANS_BUCKET = 'receipts'` directly resolves the upload authorization and storage persistence.

3. **Account Deletion Cascade Alignment**:
   - In `auth.service.ts:196-201`, the admin client purges `${userId}` folder contents upon user deletion.
   - Aligning `RECEIPT_SCANS_BUCKET = 'receipts'` makes this NestJS purge logic operate on the exact same bucket targeted by the SQL migration `20261017000001_v1_3_auth_and_account_lifecycle.sql:60`.

4. **Zero Regression Risk in Test Suite**:
   - Observation 1.3 confirms that none of the 7 existing test suites (45 tests) mock or assert on the storage bucket name.
   - Updating `RECEIPT_SCANS_BUCKET` to `'receipts'` will not break any existing unit tests or build commands.

---

## 3. Caveats

1. **Controller Route Stability**:
   - The REST endpoint path `@Controller('receipt-scans')` and `@ApiTags('receipt-scans')` in `receipt-scans.controller.ts` MUST NOT be renamed to `'receipts'`. The mobile application and API contracts (PROJECT.md Interface Contract #1) expect `POST /receipt-scans/upload` and `POST /receipt-scans/:id/confirm`. Only the internal storage bucket constant is changing.
2. **Missing Unit Tests for ReceiptScansService**:
   - Currently, `quincena-api` has no unit test for `ReceiptScansService`. While not strictly required for Milestone 1 normalization, adding a unit test file ensures long-term regression prevention. A proposed test structure is included in this report.
3. **Database Bucket Provisioning**:
   - In production or local Supabase instances, migration `20261016000002_storage_receipts.sql` must have been executed (`supabase db push`) so that the `'receipts'` bucket actually exists in the `storage.buckets` table.

---

## 4. Conclusion & Actionable Execution Plan for Worker

The normalization of the bucket name is straightforward and zero-risk. The worker agent must apply the following exact modifications.

### 4.1 Modifications

#### File 1: `quincena-api/src/modules/receipt-scans/receipt-scans.service.ts`
- **Line 10**:
  Change `const RECEIPT_SCANS_BUCKET = 'receipt-scans';` to `const RECEIPT_SCANS_BUCKET = 'receipts';`

```diff
--- a/quincena-api/src/modules/receipt-scans/receipt-scans.service.ts
+++ b/quincena-api/src/modules/receipt-scans/receipt-scans.service.ts
@@ -7,7 +7,7 @@ import { SupabaseService } from '../../supabase/supabase.service';
 import { ConfirmReceiptScanDto } from './dto/confirm-receipt-scan.dto';
 
-const RECEIPT_SCANS_BUCKET = 'receipt-scans';
+const RECEIPT_SCANS_BUCKET = 'receipts';
 
 @Injectable()
 export class ReceiptScansService {
```

#### File 2: `quincena-api/src/modules/auth/auth.service.ts`
- **Line 16**:
  Change `const RECEIPT_SCANS_BUCKET = 'receipt-scans';` to `const RECEIPT_SCANS_BUCKET = 'receipts';`

```diff
--- a/quincena-api/src/modules/auth/auth.service.ts
+++ b/quincena-api/src/modules/auth/auth.service.ts
@@ -13,7 +13,7 @@ import { DeleteAccountDto } from './dto/delete-account.dto';
 import { User } from '@supabase/supabase-js';
 
-const RECEIPT_SCANS_BUCKET = 'receipt-scans';
+const RECEIPT_SCANS_BUCKET = 'receipts';
 
 @Injectable()
 export class AuthService {
```

#### File 3 (Optional Enhancement): `quincena-api/src/modules/receipt-scans/receipt-scans.service.spec.ts`
To lock in test coverage for bucket usage, create `src/modules/receipt-scans/receipt-scans.service.spec.ts`:

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { ReceiptScansService } from './receipt-scans.service';
import { SupabaseService } from '../../supabase/supabase.service';

describe('ReceiptScansService', () => {
  let service: ReceiptScansService;
  let mockSupabaseService: any;
  let mockClient: any;
  let mockStorage: any;
  let mockBucket: any;

  beforeEach(async () => {
    mockBucket = {
      upload: jest.fn().mockResolvedValue({ data: { path: 'path' }, error: null }),
    };

    mockStorage = {
      from: jest.fn().mockReturnValue(mockBucket),
    };

    mockClient = {
      storage: mockStorage,
      from: jest.fn().mockReturnValue({
        insert: jest.fn().mockReturnThis(),
        select: jest.fn().mockReturnThis(),
        single: jest.fn().mockResolvedValue({
          data: { id: 'scan-1', storage_path: 'user-1/123.jpg', ocr_status: 'pending' },
          error: null,
        }),
      }),
    };

    mockSupabaseService = {
      getAuthenticatedClient: jest.fn().mockReturnValue(mockClient),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ReceiptScansService,
        { provide: SupabaseService, useValue: mockSupabaseService },
        { provide: ConfigService, useValue: { get: jest.fn() } },
      ],
    }).compile();

    service = module.get<ReceiptScansService>(ReceiptScansService);
  });

  it('debe subir comprobantes al bucket "receipts"', async () => {
    const mockFile: any = {
      originalname: 'recibo.jpg',
      mimetype: 'image/jpeg',
      buffer: Buffer.from('fake-image-bytes'),
    };

    const result = await service.uploadAndCreateScan('user-1', mockFile, 'mock-token');

    expect(mockStorage.from).toHaveBeenCalledWith('receipts');
    expect(mockBucket.upload).toHaveBeenCalledWith(
      expect.stringMatching(/^user-1\/\d+\.jpg$/),
      mockFile.buffer,
      expect.objectContaining({ contentType: 'image/jpeg' }),
    );
    expect(result.scan.ocr_status).toBe('pending');
  });
});
```

---

## 5. Verification Method

To verify the changes applied by the worker:

1. **Verify Line Changes**:
   - Run grep in `quincena-api/src/`:
     ```pwsh
     git diff src/modules/receipt-scans/receipt-scans.service.ts
     git diff src/modules/auth/auth.service.ts
     ```
   - Confirm that line 10 in `receipt-scans.service.ts` and line 16 in `auth.service.ts` are set to `'receipts'`.

2. **Run Static Analysis & Build**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena-api
   npm run build
   ```
   Must exit with code 0.

3. **Run Unit Tests**:
   ```pwsh
   cd E:\Projects\quincena-app\quincena-api
   npm test
   ```
   All test suites must pass cleanly (exit code 0).
