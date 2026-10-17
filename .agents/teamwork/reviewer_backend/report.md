# Quality Review and Adversarial Report: Milestone 1 (Backend API)

**Reviewer**: `reviewer_backend`  
**Target**: `quincena-api` (M1: RF-03 & RF-04 Backend Enhancements)  
**Date**: 2026-10-17  

---

## 1. Review Summary

**Verdict**: **APPROVE**

The backend enhancements implemented in `quincena-api` by `worker_m1_backend` meet all functional and non-functional requirements specified in `PROJECT.md` and `ORIGINAL_REQUEST.md`. Specifically:
1. **DTO Compatibility**: Both `destination_account_id` and alias `financial_account_id` are supported and pass NestJS global `ValidationPipe` (`whitelist: true, forbidNonWhitelisted: true`) without throwing 400 Bad Request.
2. **Account Enrichment**: All queries on `budget_templates` and `budget_allocations` correctly join `destination_account:financial_accounts(id, name, color_hex, icon)`.
3. **Template Business Logic (RF-04)**:
   - `POST /budget-templates/apply` enforces RN-01 rejection on closed cycles, conflict checking on existing allocations without overwrite, overwrite cleanup, and returns complete cycle financial summaries identical to `GET /budget-allocations?cycleId=...`.
   - `POST /budget-templates/save-from-cycle` validates ownership, rejects empty cycles, and upserts template items targeting `(user_id, period, category_id)` without altering closed or historical cycles.
4. **Integrity & Build Verification**:
   - `npm run build` completed with exit code 0.
   - `npm run test` completed with 6 test suites and 39 tests passing cleanly.
   - Zero hardcoded mock results, dummy facades, or shortcuts detected.

---

## 2. Findings

### [Minor] Finding 1: Transaction Disassociation on Allocation Overwrite
- **What**: When applying a template with `overwrite: true` on a cycle that already contains transactions, deleting existing allocations triggers PostgreSQL `ON DELETE SET NULL` on `transactions.allocation_id`.
- **Where**: `quincena-api/src/modules/budget-templates/budget-templates.service.ts:201` (`delete().eq('cycle_id', dto.cycle_id)`) and `supabase/migrations/20261016000001_initial_schema.sql:145`.
- **Why**: While database integrity is preserved (no foreign key error), transactions in that cycle lose their link to a specific category allocation, moving into unallocated spent funds.
- **Suggestion**: The Flutter mobile client should prompt a clear confirmation dialog whenever `overwrite: true` is triggered on a cycle that already has recorded transactions.

### [Minor] Finding 2: Missing Enum Validation on `GET /budget-templates?period=...`
- **What**: Query parameter `period` in `BudgetTemplatesController.findByPeriod` is typed as `QuincenaPeriod` but lacks `ParseEnumPipe(QuincenaPeriod)`.
- **Where**: `quincena-api/src/modules/budget-templates/budget-templates.controller.ts:52`.
- **Why**: If a client passes an invalid period or omits it entirely, it passes through to Supabase query `.eq('period', undefined)` rather than rejecting immediately with HTTP 400.
- **Suggestion**: In a subsequent refactor, add `@Query('period', new ParseEnumPipe(QuincenaPeriod)) period: QuincenaPeriod`.

### [Minor] Finding 3: Defense-in-Depth Ownership Check in `BudgetAllocationsService.remove`
- **What**: `BudgetAllocationsService.remove` selects `biweekly_cycles!inner(user_id)` but does not explicitly check `if (cycle.user_id !== userId)` in application code before deletion (unlike `update`).
- **Where**: `quincena-api/src/modules/budget-allocations/budget-allocations.service.ts:255-265`.
- **Why**: Pre-existing code relying primarily on Supabase RLS policies (`Users can manage own budget allocations`).
- **Suggestion**: Add explicit `if (cycle.user_id !== userId) throw new NotFoundException(...)` for consistency with `update`.

---

## 3. Verified Claims

| Claim from Worker Handoff | Independent Verification Method | Result |
|---------------------------|----------------------------------|--------|
| Corrupted `@babel/types` resolved in `node_modules` | Inspected dependency in `package.json`, ran Jest runner | **PASS** |
| `npm run build` succeeds with exit code 0 | Executed `npm run build` via terminal task-20 | **PASS** (Exit 0) |
| `npm run test` passes 6 suites / 39 tests | Executed `npm run test` via terminal task-25 | **PASS** (6 suites, 39 tests) |
| Test coverage is authentic and comprehensive | Executed `jest --coverage` via terminal task-98 | **PASS** (100% on all DTOs, >80% on services) |
| DTOs accept both `destination_account_id` and `financial_account_id` | Verified in `budget-allocation-dto.spec.ts` & `budget-template-dto.spec.ts` | **PASS** |
| SQL join includes `destination_account:financial_accounts(id, name, color_hex, icon)` | Inspected `budget-templates.service.ts` (lines 39, 73, 117, 302) and `budget-allocations.service.ts` (lines 74, 173, 242) | **PASS** |
| RN-01 rejection on closed cycles | Inspected logic in `apply` and `create`, verified tests in `service.spec.ts` | **PASS** |
| Overwrite flag honored with 409 Conflict | Verified logic and tests in `budget-templates.service.spec.ts` | **PASS** |
| Cycle snapshot saves to templates without modifying closed cycles | Inspected `saveFromCycle` upsert target (`budget_templates`) | **PASS** |

---

## 4. Adversarial Challenges & Stress Testing

### Challenge 1: Non-whitelisted Field Injection
- **Assumption**: NestJS global `ValidationPipe` will reject unexpected payload fields while accepting the alias `financial_account_id`.
- **Attack Scenario**: Client sends `{ extra_field: 'malicious', financial_account_id: 'uuid' }`.
- **Result**: `forbidNonWhitelisted: true` correctly catches and rejects `extra_field` with HTTP 400 Bad Request, while `financial_account_id` is an explicitly decorated `@ApiPropertyOptional()` `@IsOptional()` `@IsUUID()` field and passes validation. **PASSED**.

### Challenge 2: Closed Cycle Tampering (RN-01)
- **Assumption**: Users cannot apply templates or add allocations to historic or archived cycles.
- **Attack Scenario**: Malicious or stale client calls `POST /budget-templates/apply` or `POST /budget-allocations` targeting a closed cycle (`is_closed: true`).
- **Result**: Both endpoints query `biweekly_cycles.is_closed` and immediately reject with `BadRequestException('No se puede aplicar plantilla a un ciclo cerrado (RN-01)')` before executing any write operations. **PASSED**.

### Challenge 3: Multi-Tenant Data Leakage or Cross-User Overwrite
- **Assumption**: User A cannot apply a template to User B's cycle or overwrite User B's templates.
- **Attack Scenario**: User A submits `cycle_id` belonging to User B.
- **Result**: Service queries `.eq('user_id', userId).eq('id', dto.cycle_id)`. If cycle does not belong to User A, query yields null and throws `NotFoundException('Ciclo no encontrado')`. Supabase RLS further guarantees row isolation. **PASSED**.

### Challenge 4: Empty Cycle Snapshot
- **Assumption**: User saves a cycle that has zero allocations to master templates.
- **Attack Scenario**: User executes `POST /budget-templates/save-from-cycle` on an unconfigured cycle.
- **Result**: Service validates `allocations.length === 0` and throws `BadRequestException('El ciclo no posee asignaciones para guardar como plantilla')`, preventing template erasure. **PASSED**.

---

## 5. Coverage Gaps & Unverified Items

- **End-to-End Live Supabase Network Roundtrip**: Tests use unit mock providers because backend runs in local offline development container. Unit tests mock Supabase database responses, foreign key constraints, and Postgres error code `23505`. This is standard for local verification.
- **Risk Level**: Very Low. Schemas and migrations match column names and types identically.

---

## 6. Integrity Attestation

- Hardcoded test outputs: **NONE**
- Facade or dummy implementations: **NONE**
- Task bypassing shortcuts: **NONE**
- Fabricated reports or logs: **NONE**
- Genuine verification executed: **YES** (Fresh builds and tests executed independently).
