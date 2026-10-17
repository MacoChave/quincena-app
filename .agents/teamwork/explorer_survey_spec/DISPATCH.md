# Dispatch: Explorer Spec & Requirements

## Objective
Analyze in depth the business logic, UI specifications, acceptance criteria, and edge cases for RF-03 (Distribución Quincenal y Presupuestos Base Cero) and RF-04 (Plantillas 1ra y 2da Quincena).

## Scope & Tasks
1. Read `e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md`.
2. Inspect `AGENTS.md` and any documentation/spec files in `c:\Users\totto\OneDrive\Desarrollo\Quincena` or `e:\Projects\quincena-app`.
3. Break down RF-03:
   - What constitutes the net income ("Ingreso neto del ciclo activo")? How is it defined in the cycle or entered?
   - How does real-time "Por Asignar" calculation work? (net income - sum(allocations)). What happens if sum > net income? (negative Por Asignar / alert).
   - How is the funding account (`financial_account_id`) grouped and summarized?
   - Pastel semaphorization rules (<70% `#79ADDC`, 70-90% `#FFEE93`, >90% or deficit `#FFC09F`).
4. Break down RF-04:
   - Tabs `[1ra Quincena]` and `[2da Quincena]`.
   - Data structure of templates: base allocated amount, associated category, default destination financial account.
   - Flow: "Aplicar plantilla predefinida" (validation: cycle has no prior allocations, or confirmation if overwriting; preloading allocations).
   - Flow: "Guardar ciclo actual como plantilla" (saving active cycle's allocations into master template for 1st or 2nd quincena).
5. Enumerate all edge cases, corner cases, and boundary scenarios for testing.
6. Write your findings in `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\report.md` and complete with `handoff.md`.


## 2026-10-17T03:52:41Z
You are a specification investigator and requirements miner.
Your working directory is: e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec
You MUST first read ORIGINAL_REQUEST.md at: e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md
Also read your instructions in: e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\DISPATCH.md

Your goal is to investigate all requirements and specifications:
1. Examine `ORIGINAL_REQUEST.md`, `AGENTS.md`, and any files in `c:\Users\totto\OneDrive\Desarrollo\Quincena` (design system, DDL, business rules).
2. Detail precise specifications for RF-03:
   - Dynamic Base Zero formula: "Por Asignar" = net income - sum(allocated budgets). Real-time recalculation upon edit.
   - Allocation fields: category, allocated amount, target financial account (`financial_account_id`).
   - Grouped summary by funding financial account (total to fund per bank/cash account).
   - Semaphorization pastel colors (<70% `#79ADDC`, 70-90% `#FFEE93`, >90% or overbudget `#FFC09F`).
3. Detail precise specifications for RF-04:
   - Tabs `[1ra Quincena]` and `[2da Quincena]`.
   - Template item structure (category, base amount, default target account).
   - "Aplicar plantilla predefinida" flow (precondition: active cycle has no allocations, or overwrite confirmation; loads all items into active cycle).
   - "Guardar ciclo actual como plantilla" flow (saves current cycle allocations into master template without altering closed cycles).
4. Enumerate test scenarios across all tiers (Tier 1: Feature coverage, Tier 2: Boundary/Corner cases, Tier 3: Interactions, Tier 4: Real-world scenarios).

Document your full analysis in:
`e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\report.md`
And write your final handoff in `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\handoff.md`.
When finished, send a message to the orchestrator (caller) with a summary and path to your handoff.
