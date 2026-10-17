# Report: Backend & Database Survey for RF-03 and RF-04

**Date**: 2026-10-17  
**Explorer**: `explorer_survey_backend`  
**Target Systems**: `e:\Projects\quincena-app\quincena-api` (NestJS) & `e:\Projects\quincena-app\supabase` (PostgreSQL / Supabase)

---

## 1. Executive Summary

This investigation surveys the database schema and NestJS backend implementation to determine readiness for:
- **RF-03**: Biweekly budget distribution, Zero-Base Budgeting ("Por Asignar"), and destination account allocation (`financial_account_id`).
- **RF-04**: Master budget templates for 1st (`first_half`) and 2nd (`second_half`) quincena, including applying templates to active cycles and saving active cycle allocations as templates.

### Key Conclusions:
1. **Naming Discrepancy**: The database and existing NestJS DTOs use the column/field name `destination_account_id` (a foreign key referencing `public.financial_accounts(id)`). The user prompt and RF-03 refer to `financial_account_id`. Because NestJS has `ValidationPipe({ whitelist: true, forbidNonWhitelisted: true })`, sending `financial_account_id` in request payloads will currently trigger HTTP 400 errors unless the DTOs are updated to accept both or the frontend explicitly uses `destination_account_id`.
2. **Template Half Support**: Both DB and API support 1st vs 2nd quincena using `quincena_period_enum` / `QuincenaPeriod` (`'first_half'` | `'second_half'`).
3. **Missing Endpoints for RF-04**:
   - There is **no endpoint to apply a template to an active cycle** (outside of the initial auto-copy during `POST /biweekly-cycles/init-current`).
   - There is **no endpoint to save active cycle allocations as a template**.
4. **Missing Joined Data**: `budget-templates.service.ts` only joins `categories(id, name, icon, color_hex)` and omits joining `destination_account:financial_accounts(id, name, color_hex)`, unlike `budget-allocations.service.ts`.
5. **Build & Test Health**:
   - `npm run build` in `quincena-api` builds cleanly with code `0`.
   - `npm run test` fails with code `1` due to an incomplete/corrupted `@babel/types@7.29.8` installation in `node_modules` (`Cannot find module './builders/react/buildChildren.js'`).

---

## 2. Database Schema Survey (`supabase/migrations`)

### 2.1 Table: `public.budget_allocations`
Defined in `20261016000001_initial_schema.sql` (lines 108–118) and updated in `20261017000001_v1_3_auth_and_account_lifecycle.sql`:

```sql
CREATE TABLE public.budget_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cycle_id UUID NOT NULL REFERENCES public.biweekly_cycles(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    destination_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
    allocated_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (allocated_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),

    CONSTRAINT uq_cycle_category UNIQUE (cycle_id, category_id)
);
```
- **Indexes**:
  - `idx_allocations_cycle ON public.budget_allocations(cycle_id)`
  - `idx_allocations_account ON public.budget_allocations(destination_account_id)`
- **RLS Policy**:
  - `Users can manage own budget allocations` FOR ALL USING `(cycle_id IN (SELECT id FROM biweekly_cycles WHERE user_id = auth.uid()))`.
- **Note on Spent Amount**: `budget_allocations` does not store `spent_amount` as a column; it is computed dynamically by joining `transactions` where `transactions.allocation_id = budget_allocations.id`.

### 2.2 Table: `public.budget_templates`
Defined in `20261016000001_initial_schema.sql` (lines 92–103):

```sql
CREATE TABLE public.budget_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    period quincena_period_enum NOT NULL, -- 'first_half' | 'second_half'
    category_id UUID NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
    destination_account_id UUID REFERENCES public.financial_accounts(id) ON DELETE SET NULL,
    default_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (default_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),

    CONSTRAINT uq_user_period_category UNIQUE (user_id, period, category_id)
);
```
- **Indexes**:
  - `idx_templates_user_period ON public.budget_templates(user_id, period)`
- **RLS Policy**:
  - `Users can manage own templates` FOR ALL USING `(auth.uid() = user_id)`.

### 2.3 Other Related Tables
- `public.biweekly_cycles`:
  - Columns: `id`, `user_id`, `year` (smallint), `month` (smallint 1..12), `period` (`first_half` | `second_half`), `start_date`, `end_date`, `total_income`, `income_destination_account_id`, `is_closed`, `rolled_over_amount`.
  - Constraint: `uq_user_cycle UNIQUE (user_id, year, month, period)`.
- `public.financial_accounts`:
  - Columns: `id`, `user_id`, `name`, `account_type` (`checking`, `savings`, `cash`, `credit_card`, `digital_wallet`), `currency`, `color_hex`, `icon`, `initial_balance`, `is_default`, `is_archived`.
- `public.categories`:
  - Columns: `id`, `user_id`, `name`, `icon`, `color_hex`, `default_account_id`, `is_archived`.

---

## 3. NestJS Backend Survey (`quincena-api`)

### 3.1 Module: `budget-allocations`

**Files**:
- `src/modules/budget-allocations/dto/create-budget-allocation.dto.ts`
- `src/modules/budget-allocations/dto/update-budget-allocation.dto.ts`
- `src/modules/budget-allocations/budget-allocations.controller.ts`
- `src/modules/budget-allocations/budget-allocations.service.ts`

#### DTO Definitions:
```typescript
// CreateBudgetAllocationDto
export class CreateBudgetAllocationDto {
  @IsUUID() cycle_id: string;
  @IsUUID() category_id: string;
  @IsOptional() @IsUUID() destination_account_id?: string;
  @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) allocated_amount: number;
}

// UpdateBudgetAllocationDto
export class UpdateBudgetAllocationDto {
  @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) allocated_amount?: number;
  @IsOptional() @IsUUID() destination_account_id?: string;
}
```

#### Existing Endpoints:
| Method | Path | Summary & Behavior |
| :--- | :--- | :--- |
| `GET` | `/v1/budget-allocations?cycleId=<UUID>` | Returns `{ allocations: AllocationWithSpent[], summary: BudgetSummary }`. Joins category details and `destination_account(id, name, color_hex)`. Computes `spent_amount`, `available_amount`, `spent_percentage`, and `summary.unallocated` ("Por Asignar"). |
| `POST` | `/v1/budget-allocations` | Creates a new allocation. Checks if cycle is open (`is_closed == false`); returns 400 if closed, 409 if category duplicate. |
| `PATCH` | `/v1/budget-allocations/:id` | Rebalances/updates `allocated_amount` and/or `destination_account_id`. Checks ownership and open status. |
| `DELETE`| `/v1/budget-allocations/:id` | Deletes an allocation. Checks ownership. |

#### Analysis for RF-03:
1. **`destination_account_id` vs `financial_account_id`**:
   The entity and DTO strictly expect `destination_account_id`. Because `forbidNonWhitelisted: true` is active in `main.ts`, if the frontend sends `financial_account_id`, validation fails.
   *Recommendation*: In `CreateBudgetAllocationDto` and `UpdateBudgetAllocationDto`, accept both `destination_account_id` and `financial_account_id` (mapping `destination_account_id = destination_account_id ?? financial_account_id`).
2. **Account Grouping Summary**:
   `GET /v1/budget-allocations` returns `summary`:
   ```typescript
   {
     total_income: number;
     total_allocated: number;
     unallocated: number; // "Por Asignar" (RF-03)
     total_spent: number;
     total_available: number;
     is_balanced: boolean;
     is_closed: boolean;
   }
   ```
   Each allocation in `allocations` includes `destination_account_id` and `destination_account: { id, name, color_hex }`. The mobile app can group allocations by `destination_account_id` to display the account funding breakdown.

---

### 3.2 Module: `budget-templates`

**Files**:
- `src/modules/budget-templates/dto/create-budget-template.dto.ts`
- `src/modules/budget-templates/dto/update-budget-template.dto.ts`
- `src/modules/budget-templates/budget-templates.controller.ts`
- `src/modules/budget-templates/budget-templates.service.ts`

#### DTO Definitions:
```typescript
export enum QuincenaPeriod {
  FIRST_HALF = 'first_half',
  SECOND_HALF = 'second_half',
}

// CreateBudgetTemplateDto
export class CreateBudgetTemplateDto {
  @IsEnum(QuincenaPeriod) period: QuincenaPeriod;
  @IsUUID() category_id: string;
  @IsOptional() @IsUUID() destination_account_id?: string;
  @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) default_amount: number;
}

// UpdateBudgetTemplateDto
export class UpdateBudgetTemplateDto {
  @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) default_amount?: number;
  @IsOptional() @IsUUID() destination_account_id?: string;
}
```

#### Existing Endpoints:
| Method | Path | Summary & Behavior |
| :--- | :--- | :--- |
| `GET` | `/v1/budget-templates?period=first_half\|second_half` | List templates for user and period with `categories(id, name, icon, color_hex)`. |
| `POST` | `/v1/budget-templates` | Create a template entry. Returns 409 if category already exists in that period. |
| `PATCH` | `/v1/budget-templates/:id` | Update `default_amount` and/or `destination_account_id`. |
| `DELETE`| `/v1/budget-templates/:id` | Delete a template entry. |

#### Gaps & Findings for RF-04:
1. **Missing Joined Relation in `GET /v1/budget-templates`**:
   In `budget-templates.service.ts` line 28:
   ```typescript
   .select('*, categories(id, name, icon, color_hex)')
   ```
   Notice that `destination_account:financial_accounts(id, name, color_hex)` is **NOT** included in the select query.
   As a result, the returned list has `destination_account_id` as a raw UUID string, but lacks the account's `name` and `color_hex`.
2. **Missing Endpoint: Apply Template to Active Cycle**:
   RF-04 requires: *"Brindar la funcionalidad de 'Aplicar plantilla predefinida' al ciclo activo cuando este no posea asignaciones previas, precargando todas las bolsas con sus montos y cuentas."*
   Currently, only `POST /v1/biweekly-cycles/init-current` copies templates when a new cycle is initially created. If the cycle is already created, there is **no endpoint** to apply/copy the template.
3. **Missing Endpoint: Save Active Cycle as Template**:
   RF-04 requires: *"Permitir la opción de 'Guardar ciclo actual como plantilla' para actualizar la plantilla maestra a partir del estado de la quincena en curso sin afectar ciclos cerrados."*
   There is **no endpoint** currently implemented to copy active cycle allocations into `budget_templates`.

---

### 3.3 Module: `biweekly-cycles`

**Files**:
- `src/modules/biweekly-cycles/biweekly-cycles.controller.ts`
- `src/modules/biweekly-cycles/biweekly-cycles.service.ts`

#### Existing Endpoints:
| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/v1/biweekly-cycles` | List all biweekly cycles for the authenticated user. |
| `GET` | `/v1/biweekly-cycles/dashboard` | Consolidated dashboard: active cycle, summary, categories, or suggested period. |
| `GET` | `/v1/biweekly-cycles/current/dashboard` | Alias for dashboard. |
| `GET` | `/v1/biweekly-cycles/current` | Active cycle (matching today or latest open cycle). |
| `POST` | `/v1/biweekly-cycles/init-current` | 1-tap cycle initialization. Copies default income & templates. |
| `POST` | `/v1/biweekly-cycles` | Manual creation (`year, month, period, start_date, end_date, total_income`). |
| `PATCH`| `/v1/biweekly-cycles/:id` | Update open cycle (`total_income`, `income_destination_account_id`). |
| `POST` | `/v1/biweekly-cycles/:id/close` | Closes cycle and applies rollover action (add to new cycle, transfer to savings, archive). |

---

### 3.4 Modules: `categories` & `financial-accounts`

#### Categories (`src/modules/categories/`):
- `GET /v1/categories`: Returns active (non-archived) categories sorted by name (`id`, `name`, `icon`, `color_hex`, `default_account_id`).
- `POST /v1/categories`: Create category (`name`, `icon`, `color_hex`, `default_account_id`).
- `PATCH /v1/categories/:id`: Update category.
- `DELETE /v1/categories/:id`: Soft delete (`is_archived = true`).

#### Financial Accounts (`src/modules/financial-accounts/`):
- `GET /v1/financial-accounts?include_archived=false`: Returns accounts with dynamically computed `current_balance` (`initial_balance - sum(expenses)`).
- `POST /v1/financial-accounts`: Create account (`name`, `account_type`, `currency`, `color_hex`, `icon`, `initial_balance`, `is_default`).
- `PATCH /v1/financial-accounts/:id`: Update account.
- `PATCH /v1/financial-accounts/:id/unarchive`: Unarchive account.
- `DELETE /v1/financial-accounts/:id`: Soft delete (`is_archived = true`).

---

## 4. Build and Test Verification

### 4.1 Build (`npm run build`)
Command: `npm run build` in `e:\Projects\quincena-app\quincena-api`  
Result: **SUCCESS (Exit code 0)**  
All TypeScript sources compile without errors into `dist/`.

### 4.2 Unit Tests (`npm run test`)
Command: `npm run test` in `e:\Projects\quincena-app\quincena-api`  
Result: **FAILED (Exit code 1)**  

**Verbatim error output**:
```
Error: Cannot find module './builders/react/buildChildren.js'
Require stack:
- E:\Projects\quincena-app\quincena-api\node_modules\@babel\types\lib\index.js
- E:\Projects\quincena-app\quincena-api\node_modules\@babel\generator\lib\node\parentheses.js
...
- E:\Projects\quincena-app\quincena-api\node_modules\jest\bin\jest.js
```

**Root Cause**:
In `node_modules/@babel/types/lib/index.js`, it attempts to require `./builders/react/buildChildren.js`. Inspection of `node_modules/@babel/types/lib/` shows that the `builders/` directory is completely absent, indicating a corrupted or incomplete `node_modules` installation of `@babel/types@7.29.8`.

**Remediation**:
Running `npm install @babel/types@7.29.8` or `npm install` in `quincena-api` will restore the missing files. (Note: As an explorer with read-only constraints on source/dependencies, this was diagnosed without modifying files).

---

## 5. Architectural Recommendations & Proposed Contract Extensions

### 5.1 Recommendation 1: Align `destination_account_id` and `financial_account_id`
In `CreateBudgetAllocationDto` and `UpdateBudgetAllocationDto` (and `CreateBudgetTemplateDto` / `UpdateBudgetTemplateDto`), support `financial_account_id` as an alias:

```typescript
export class CreateBudgetAllocationDto {
  @ApiProperty({ description: 'ID del ciclo quincenal' })
  @IsUUID()
  cycle_id: string;

  @ApiProperty({ description: 'ID de la categoría' })
  @IsUUID()
  category_id: string;

  @ApiPropertyOptional({ description: 'ID de la cuenta destino' })
  @IsOptional()
  @IsUUID()
  destination_account_id?: string;

  @ApiPropertyOptional({ description: 'Alias para destination_account_id' })
  @IsOptional()
  @IsUUID()
  financial_account_id?: string;

  @ApiProperty({ example: 800.00, description: 'Monto asignado' })
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  allocated_amount: number;
}
```
In the service, resolve: `const accountId = dto.destination_account_id ?? dto.financial_account_id ?? null;`.

### 5.2 Recommendation 2: Join `destination_account` in `BudgetTemplatesService.findByPeriod`
In `src/modules/budget-templates/budget-templates.service.ts`:
Change line 28 to:
```typescript
.select('*, categories(id, name, icon, color_hex), destination_account:financial_accounts(id, name, color_hex)')
```
This mirrors `budget-allocations` so mobile receives `destination_account` details when loading templates.

### 5.3 Recommendation 3: Add "Apply Template to Active Cycle" Endpoint
Add to `biweekly-cycles.controller.ts` (or `budget-allocations.controller.ts`):
```typescript
@Post(':id/apply-template')
@ApiOperation({ summary: 'Aplicar plantilla predefinida al ciclo activo (RF-04)' })
applyTemplate(
  @Param('id', ParseUUIDPipe) cycleId: string,
  @CurrentUser() user: User,
  @AccessToken() token: string,
)
```
**Service Logic**:
1. Verify cycle belongs to `user.id` and `is_closed == false`.
2. Check if cycle already has allocations:
   - If allocations exist, reject with `409 Conflict: El ciclo ya posee asignaciones` (or support an optional query flag `?overwrite=true`).
3. Fetch all `budget_templates` matching `user_id` and `cycle.period`.
4. If no templates found, return `{ message: 'No hay plantillas configuradas para este período', applied: 0 }`.
5. Map and bulk-insert into `budget_allocations`.
6. Return `findByCycle(cycleId, userId, token)`.

### 5.4 Recommendation 4: Add "Save Active Cycle as Template" Endpoint
Add to `budget-templates.controller.ts` (or `biweekly-cycles.controller.ts`):
```typescript
@Post('save-from-cycle/:cycleId')
@ApiOperation({ summary: 'Guardar asignaciones del ciclo activo como plantilla maestra (RF-04)' })
saveFromCycle(
  @Param('cycleId', ParseUUIDPipe) cycleId: string,
  @CurrentUser() user: User,
  @AccessToken() token: string,
)
```
**Service Logic**:
1. Fetch cycle and verify ownership (`cycle.user_id === user.id`).
2. Read all `budget_allocations` for `cycle.id`.
3. Upsert into `budget_templates` (`user_id`, `period: cycle.period`, `category_id`, `destination_account_id`, `default_amount: allocated_amount`) on conflict `(user_id, period, category_id)`.
4. Return updated templates for that period.

---

## 6. Summary Matrix of Endpoints for Mobile Implementation

| Feature | Action | Endpoint | Status | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **RF-03** | Get Allocations & "Por Asignar" | `GET /v1/budget-allocations?cycleId=<id>` | ✅ Exists | Returns summary & allocations |
| **RF-03** | Create Allocation | `POST /v1/budget-allocations` | ✅ Exists | Uses `destination_account_id` |
| **RF-03** | Update Allocation | `PATCH /v1/budget-allocations/:id` | ✅ Exists | Uses `destination_account_id` |
| **RF-03** | Delete Allocation | `DELETE /v1/budget-allocations/:id` | ✅ Exists | Removes allocation |
| **RF-03** | Grouping by Destination Account | Handled client-side | ✅ Feasible | Enriched with `destination_account` |
| **RF-04** | Get Templates (1ra / 2da) | `GET /v1/budget-templates?period=first_half\|second_half` | ⚠️ Exists | Needs `destination_account` join |
| **RF-04** | Create Template Entry | `POST /v1/budget-templates` | ✅ Exists | Period + category + account + amount |
| **RF-04** | Update Template Entry | `PATCH /v1/budget-templates/:id` | ✅ Exists | Update default_amount / account |
| **RF-04** | Delete Template Entry | `DELETE /v1/budget-templates/:id` | ✅ Exists | Remove entry |
| **RF-04** | Apply Template to Cycle | `POST /v1/biweekly-cycles/:id/apply-template` | ❌ Missing | Needs implementation in NestJS |
| **RF-04** | Save Cycle as Template | `POST /v1/budget-templates/save-from-cycle/:cycleId` | ❌ Missing | Needs implementation in NestJS |
| **Shared** | Get Active Cycle & Dashboard | `GET /v1/biweekly-cycles/dashboard` | ✅ Exists | Returns active cycle and categories |
| **Shared** | List Financial Accounts | `GET /v1/financial-accounts` | ✅ Exists | Returns accounts with balances |
| **Shared** | List Categories | `GET /v1/categories` | ✅ Exists | Returns master category list |
