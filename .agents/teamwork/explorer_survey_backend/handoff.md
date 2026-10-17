# Handoff Report: Backend & Database Survey for RF-03 and RF-04

**Agent**: `explorer_survey_backend`  
**Date**: 2026-10-17  
**Working Directory**: `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_backend`  
**Handoff Type**: Hard (Investigation complete)

---

## 1. Observation

### 1.1 Database Schema (`supabase/migrations`)
- **`budget_allocations` table definition**:
  - File: `e:\Projects\quincena-app\supabase\migrations\20261016000001_initial_schema.sql`, lines 108–118:
    ```sql
    CREATE TABLE public.budget_allocations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        cycle_id UUID NOT NULL REFERENCES public.biweekly_cycles(id) ON DELETE CASCADE,
        category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE RESTRICT,
        destination_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
        allocated_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (allocated_amount >= 0),
        created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),

        CONSTRAINT uq_cycle_category UNIQUE (cycle_id, category_id)
    );
    ```
  - File: `e:\Projects\quincena-app\supabase\migrations\20261017000001_v1_3_auth_and_account_lifecycle.sql`, lines 17–20:
    Updated `category_id` FK to `ON DELETE CASCADE`.
  - Column name for destination account is `destination_account_id`, referencing `financial_accounts(id)`.

- **`budget_templates` table definition**:
  - File: `e:\Projects\quincena-app\supabase\migrations\20261016000001_initial_schema.sql`, lines 92–103:
    ```sql
    CREATE TABLE public.budget_templates (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
        period quincena_period_enum NOT NULL, -- 'first_half' o 'second_half'
        category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
        destination_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
        default_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (default_amount >= 0),
        created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),

        CONSTRAINT uq_user_period_category UNIQUE (user_id, period, category_id)
    );
    ```

### 1.2 NestJS Backend Endpoints & DTOs (`quincena-api`)
- **Global validation pipe**:
  - File: `e:\Projects\quincena-app\quincena-api\src\main.ts`, lines 17–24:
    ```typescript
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    ```
- **`CreateBudgetAllocationDto`**:
  - File: `e:\Projects\quincena-app\quincena-api\src\modules\budget-allocations\dto\create-budget-allocation.dto.ts`, lines 4–22:
    Field name is `destination_account_id?: string;`. Does not declare `financial_account_id`.
- **`BudgetAllocationsController`**:
  - File: `e:\Projects\quincena-app\quincena-api\src\modules\budget-allocations\budget-allocations.controller.ts`:
    - `GET /budget-allocations?cycleId=<UUID>` (lines 22–34)
    - `POST /budget-allocations` (lines 36–45)
    - `PATCH /budget-allocations/:id` (lines 47–59)
    - `DELETE /budget-allocations/:id` (lines 61–70)
- **`BudgetAllocationsService.findByCycle`**:
  - File: `e:\Projects\quincena-app\quincena-api\src\modules\budget-allocations\budget-allocations.service.ts`, lines 52–54:
    Selects `*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex)`.
    Computes `unallocated: Number(cycle.total_income) - totalAllocated` ("Por Asignar" CA-02.1) at lines 106–109.
- **`BudgetTemplatesService.findByPeriod`**:
  - File: `e:\Projects\quincena-app\quincena-api\src\modules\budget-templates\budget-templates.service.ts`, lines 27–31:
    Selects `'*, categories(id, name, icon, color_hex)'`.
    Omits `destination_account:financial_accounts(id, name, color_hex)`.
- **Template Application in Cycles**:
  - File: `e:\Projects\quincena-app\quincena-api\src\modules\biweekly-cycles\biweekly-cycles.service.ts`, lines 231–247:
    Copies templates into allocations **only** when `initCurrent()` runs for the first time.
    No standalone endpoint exists for `apply-template` or `save-as-template`.

### 1.3 Build and Test Tool Executions
- **`npm run build` in `quincena-api`**:
  - Command: `npm run build`
  - Output: Exit code 0, clean build.
- **`npm run test` in `quincena-api`**:
  - Command: `npm run test`
  - Output: Exit code 1:
    ```
    Error: Cannot find module './builders/react/buildChildren.js'
    Require stack:
    - E:\Projects\quincena-app\quincena-api\node_modules\@babel\types\lib\index.js
    ```
  - Inspection of `node_modules/@babel/types/lib/`: directory `builders/` is missing.

---

## 2. Logic Chain

1. **Premise**: RF-03 requires associating budget allocations with a destination financial account (`financial_account_id`).
   - *Observation 1.1*: Database column is `destination_account_id`.
   - *Observation 1.2*: Backend DTO declares `destination_account_id` and NestJS uses `forbidNonWhitelisted: true`.
   - *Deduction*: Sending `financial_account_id` directly will fail with HTTP 400 unless the DTO is updated to accept both or the frontend uses `destination_account_id`.

2. **Premise**: RF-04 requires managing 1st and 2nd quincena templates.
   - *Observation 1.1*: `budget_templates.period` uses `quincena_period_enum` (`first_half` / `second_half`).
   - *Observation 1.2*: Controller provides `GET /budget-templates?period=first_half|second_half` with CRUD.
   - *Observation 1.2*: Service query for templates omits joining `destination_account:financial_accounts`, so mobile cannot display account name/color without an extra query.
   - *Deduction*: 1st vs 2nd quincena template management is supported, but joining `destination_account` in `findByPeriod` is needed for clean UI display.

3. **Premise**: RF-04 requires "Aplicar plantilla predefinida" to an active cycle and "Guardar ciclo actual como plantilla".
   - *Observation 1.2*: Grep across `quincena-api/src` for `apply` yielded 0 matches; template insertion is hardcoded only in `biweekly-cycles.service.ts:231-247` inside `initCurrent()`.
   - *Deduction*: Both endpoints (`apply-template` and `save-from-cycle`) are currently missing and must be added to the backend.

4. **Premise**: Backend health check.
   - *Observation 1.3*: `npm run build` succeeds (code 0). `npm run test` fails (code 1) due to missing `./builders/react/buildChildren.js` in `@babel/types`.
   - *Deduction*: Source code has no syntax or type errors. The test failure is an environment/node_modules issue remediated by re-installing `@babel/types`.

---

## 3. Caveats

1. **Read-Only Scope**: In accordance with the explorer archetype and instructions, no files in `quincena-api` or `supabase` were modified.
2. **Batch Allocation**: Individual CRUD endpoints exist for allocations; if the mobile UI allows batch-editing all categories simultaneously, each item currently issues an individual PATCH request unless a bulk endpoint is introduced.
3. **Account Grouping Summary**: The backend `GET /budget-allocations` computes "Por Asignar" and total allocations, but does not provide pre-grouped balances per funding account; this grouping can easily be performed on mobile from the enriched `allocations` list.

---

## 4. Conclusion

The NestJS backend and Supabase database provide a solid foundation for RF-03 and RF-04, but three specific backend adjustments are necessary for full end-to-end integration:

1. **DTO Compatibility**: Allow `financial_account_id` as an alias for `destination_account_id` in `CreateBudgetAllocationDto`, `UpdateBudgetAllocationDto`, `CreateBudgetTemplateDto`, and `UpdateBudgetTemplateDto`.
2. **Template Destination Account Join**: Enrich `budget-templates.service.ts` line 28 to include `destination_account:financial_accounts(id, name, color_hex)` in the select statement.
3. **New RF-04 Endpoints**:
   - `POST /v1/biweekly-cycles/:id/apply-template`: Copies template rows for the cycle's period into `budget_allocations`.
   - `POST /v1/budget-templates/save-from-cycle/:cycleId`: Upserts active cycle allocations into `budget_templates` for that period.

---

## 5. Verification Method

To independently verify these findings:

1. **Inspect DTOs and Validation**:
   - File: `e:\Projects\quincena-app\quincena-api\src\modules\budget-allocations\dto\create-budget-allocation.dto.ts`
   - File: `e:\Projects\quincena-app\quincena-api\src\main.ts` (lines 17–24)
2. **Inspect Template Query Join**:
   - File: `e:\Projects\quincena-app\quincena-api\src\modules\budget-templates\budget-templates.service.ts` (line 28)
3. **Execute Build**:
   ```pwsh
   cd e:\Projects\quincena-app\quincena-api
   npm run build
   # Verify exit code 0
   ```
4. **Reproduce Test Failure & Verify Node Modules**:
   ```pwsh
   cd e:\Projects\quincena-app\quincena-api
   npm run test
   # Observe: Error: Cannot find module './builders/react/buildChildren.js'
   ```
