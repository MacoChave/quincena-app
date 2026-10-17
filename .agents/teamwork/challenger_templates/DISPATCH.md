# Dispatch: Challenger 2 (Templates & Workflow Invariants)

## Objective
Empirically test and challenge the master template logic (1ra vs 2da quincena), apply/save workflows, cycle isolation invariants, and navigation shell integration.

## Mandatory Reading
- `e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md`
- `e:\Projects\quincena-app\PROJECT.md`
- `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\report.md`
- `e:\Projects\quincena-app\.agents\teamwork\worker_mobile\handoff.md`
- `e:\Projects\quincena-app\.agents\teamwork\worker_m1_backend\handoff.md`

## Tasks
1. Verify that `first_half` and `second_half` templates operate independently without state bleed.
2. Verify that applying a template to an active cycle correctly loads items into the cycle without modifying the master template.
3. Verify that modifying an allocation in an active cycle does NOT alter the master template unless explicitly saved.
4. Verify that "Guardar ciclo actual como plantilla" does not alter closed cycles.
5. Verify that in `MainShell` (`quincena/lib/main.dart`), switching between tabs properly maintains or refreshes state and does not crash.
6. Write test scripts/cases or integration tests in `quincena/test/` to empirically assert these invariants.
7. Run tests to confirm correctness.
8. Provide a clear verdict: `APPROVE` or `REQUEST_CHANGES`.
9. Write your report in `e:\Projects\quincena-app\.agents\teamwork\challenger_templates\report.md` and handoff in `e:\Projects\quincena-app\.agents\teamwork\challenger_templates\handoff.md`.


## 2026-10-17T04:30:52Z
Sender: b55e68a7-e802-4dba-a48c-1f79ad9d2856
Content: You are an adversarial challenger focusing on Templates and Workflow Invariants.
Your working directory is: e:\Projects\quincena-app\.agents\teamwork\challenger_templates
You MUST read:
1. e:\Projects\quincena-app\.agents\teamwork\ORIGINAL_REQUEST.md
2. e:\Projects\quincena-app\PROJECT.md
3. e:\Projects\quincena-app\.agents\teamwork\challenger_templates\DISPATCH.md
4. e:\Projects\quincena-app\.agents\teamwork\worker_mobile\handoff.md

Empirically challenge 1ra vs 2da quincena templates: independent state, apply template to active cycle, modify active cycle without mutating master template, save cycle as template without mutating closed cycles, and MainShell tab switching.
Run tests and verify correctness.
Provide your verdict: APPROVE or REQUEST_CHANGES.
Write report to: e:\Projects\quincena-app\.agents\teamwork\challenger_templates\report.md
Write handoff to: e:\Projects\quincena-app\.agents\teamwork\challenger_templates\handoff.md
Send a message to caller when done.
