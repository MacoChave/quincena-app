# Handoff Report: Specification Mining (RF-03 & RF-04)

**Agent:** `explorer_survey_spec`  
**Recipient / Parent:** Orchestrator (`b55e68a7-e802-4dba-a48c-1f79ad9d2856`)  
**Type:** Hard Handoff (Specification Task Complete)  
**Date:** 2026-10-17T04:08:00Z  

---

## 1. Observation

1. **Requerimiento Original (`ORIGINAL_REQUEST.md`):**
   - Líneas 14–26: R1 (RF-03) exige cálculo dinámico "Por Asignar" = ingreso neto del ciclo activo menos suma de bolsas presupuestadas, campo de cuenta financiera destino (`financial_account_id` / `destination_account_id`), resumen agrupado por cuenta de fondeo, y semaforización pastel (`#79ADDC` <70%, `#FFEE93` 70-90%, `#FFC09F` >90% o sobregiro).
   - R2 (RF-04) exige pestañas independientes `[1ra Quincena]` y `[2da Quincena]`, ítems con categoría, monto base y cuenta predeterminada, y los flujos "Aplicar plantilla predefinida" y "Guardar ciclo actual como plantilla".
   - Línea 28: Conectar la pantalla en la pestaña de `Presupuestos Quincenales` en `MainShell` reemplazando el `PlaceholderView` actual.

2. **Especificación DERCAS (`c:\Users\totto\OneDrive\Desarrollo\Quincena`):**
   - `dercas_quincena.md` (Líneas 51–57): "CA-02.1: La pantalla de asignación debe calcular dinámicamente el valor `Por Asignar = Ingresos Totales - Suma de Categorías`. CA-02.2: La interfaz debe marcar en verde `#ADF7B6` cuando el valor disponible llegue exactamente a $0.00. CA-02.3: Si el usuario presupuesta por encima de su ingreso, mostrar alerta en color coral `#FFC09F` sin bloquear la creación".
   - `dercas_1_1_quincena.md` (Líneas 11–19, 24–31): "RF-06: Destinos y Plantillas Presupuestarias Predefinidas... selector segmentado explícito: `[1ra Quincena (1–15)]` y `[2da Quincena (16–Fin de mes)]`... CA-06.4: Modificar montos dentro de un ciclo vivo no altera la plantilla maestra guardada... CA-06.5: Guardar distribución actual como plantilla de esta quincena... RN-04.2: Una misma categoría no puede estar duplicada dentro de la plantilla de un mismo período".
   - `dercas_1_2.md` (Líneas 54–68): "RF-03: Asignación Presupuestaria con Cuenta Destino... CA-03.3: El sistema ofrece una vista agrupada por cuenta para saber cuánto dinero debe haber fondeado en cada cuenta durante la quincena".

3. **Tokens de Color y Accesibilidad (`colors_quincena.md` y `design-system_quincena.md`):**
   - `colors_quincena.md` (Líneas 9–15): Core swatches: `#79ADDC` (Soft Sky), `#FFC09F` (Muted Coral), `#FFEE93` (Soft Sunshine), `#FCF5C7` (Warm Cream), `#ADF7B6` (Mint Pastel).
   - Líneas 130–132: "Regla de contraste sobre pasteles: Nunca colocar texto blanco (`#FFFFFF`) sobre `#FFEE93`, `#ADF7B6` ni `#FCF5C7`. Emplear siempre `--text-main` (`#1C242B`) o variantes semánticas oscuras... Cifras con `tabular-nums`".

4. **Base de Datos (`DDL_quincena.sql`):**
   - Tabla `budget_allocations` (Líneas 111–121): Columnas `id`, `cycle_id`, `category_id`, `destination_account_id` (FK a `financial_accounts`), `allocated_amount` (`NUMERIC(12,2) CHECK >= 0`), y `CONSTRAINT uq_cycle_category UNIQUE (cycle_id, category_id)`.
   - Tabla `budget_templates` (Líneas 95–106): Columnas `id`, `user_id`, `period` (`quincena_period_enum`), `category_id`, `destination_account_id`, `default_amount`, y `CONSTRAINT uq_user_period_category UNIQUE (user_id, period, category_id)`.
   - Vista `v_financial_accounts_balance` (Líneas 318–348): Provee `current_balance` por cuenta.

5. **Estado del Backend (`quincena-api/src/modules/`):**
   - `budget-allocations.controller.ts` & `budget-allocations.service.ts`: Proveen endpoints individuales (`GET /budget-allocations?cycleId=...`, `POST`, `PATCH :id`, `DELETE :id`). El GET ya calcula `unallocated` e `is_balanced` en su resumen.
   - `budget-templates.controller.ts` & `budget-templates.service.ts`: Proveen endpoints CRUD (`GET ?period=...`, `POST`, `PATCH :id`, `DELETE :id`), pero la consulta `select()` omite la relación con `destination_account`. No existen endpoints batch atómicos dedicados para `apply-template` ni `save-from-cycle`.

6. **Estado del Frontend (`quincena/lib/`):**
   - `main.dart` (Línea 113): Tab 1 de `MainShell` es `const PlaceholderView(title: 'Presupuestos Quincenales')`.
   - `core/components/`: Existen componentes listos: `AppHeroCard`, `AppProgressBar`, `AppBadge`, `AppAmountInput`.
   - `features/`: No existe aún la carpeta `budgets/` o `budget_allocations/`.

---

## 2. Logic Chain

1. **Delimitación de Dominio y Fórmulas:**
   - De las observaciones 1 y 2, el cálculo en tiempo real de "Por Asignar" debe ser:
     $$\text{Por Asignar} = \text{total\_income} - \sum \text{allocated\_amount}$$
   - Si $\text{Por Asignar} == 0.00$: Estado balanceado (verde pastel `#ADF7B6`, texto `#1C242B` / `#236B31`).
   - Si $\text{Por Asignar} > 0.00$: Fondos por distribuir (azul pastel `#79ADDC`, texto `#1C242B`).
   - Si $\text{Por Asignar} < 0.00$: Déficit (coral pastel `#FFC09F`, texto `#A33F19`). No bloquea el guardado, pero emite alerta visual obligatoria.

2. **Agrupación por Cuenta Financiera:**
   - De las observaciones 2 y 4, cada partida tiene `destination_account_id` opcional.
   - Para construir el resumen de fondeo requerido por RF-03, el frontend o backend debe agrupar:
     $$\text{Total a Fondear por Cuenta} = \sum_{a \in \text{allocations, } a.\text{account\_id} = A} a.\text{allocated\_amount}$$
   - Contrastar contra `current_balance` de la cuenta para mostrar si los fondos disponibles son suficientes o si se requiere fondear la diferencia.

3. **Flujos de Plantillas Maestras (RF-04):**
   - De las observaciones 2, 4 y 5, `budget_templates` utiliza el enum `first_half` y `second_half`.
   - Para "Aplicar plantilla predefinida": si el ciclo no tiene asignaciones, se copian en lote todas las plantillas del período del ciclo. Si el ciclo ya tiene asignaciones, se presenta un diálogo modal de confirmación (Sobrescribir / Combinar / Cancelar).
   - Para "Guardar ciclo actual como plantilla": se realiza un snapshot de las asignaciones del ciclo activo hacia `budget_templates` para el `period` del ciclo. Los ciclos cerrados o pasados quedan intactos.

4. **Identificación de Brechas (Gaps) y Recomendaciones:**
   - En NestJS (`quincena-api`), añadir `destination_account:financial_accounts(id, name, color_hex, icon)` en `budget-templates.service.ts:findByPeriod` para que la UI de plantillas conozca el nombre e icono de la cuenta destino.
   - En NestJS, proveer endpoints atómicos `POST /budget-allocations/apply-template` y `POST /budget-templates/save-from-cycle` o documentar su fallback cliente.
   - En Flutter (`quincena`), crear el módulo `lib/features/budgets/` y reemplazar el `PlaceholderView` en `MainShell`.

---

## 3. Caveats

- **Cuentas Archivadas:** Si una cuenta financiera vinculada a una plantilla o asignación es archivada por el usuario, la base de datos conserva la referencia histórica (`is_archived = true`), pero en la UI debe mostrarse un tag `(Archivada)` y no sugerirse para nuevas asignaciones.
- **Transacciones Vinculadas a Bolsas al Sobrescribir:** Si un ciclo ya tiene transacciones ejecutadas (`transactions.allocation_id != null`) y el usuario solicita "Sobrescribir todo con plantilla", la base de datos tiene `ON DELETE SET NULL` en transacciones, por lo que el gasto no se borra pero queda desvinculado de la bolsa. Se recomienda advertir de esto en el modal.

---

## 4. Conclusion

La especificación técnica de RF-03 y RF-04 ha quedado completamente desglosada, validada y documentada en `report.md`. Se definieron todas las fórmulas matemáticas, esquemas de datos, contratos API, semáforos de diseño con accesibilidad estricta, flujos de usuario con diagramas de secuencia, matriz de 12 características descubiertas, matriz de 12 casos extremos y 32 escenarios de prueba divididos en 4 niveles (Tier 1 a Tier 4).

Los agentes de implementación (`quincena-mobile` y `quincena-backend`) cuentan con una base de especificación inequívoca para proceder con el desarrollo.

---

## 5. Verification Method

Para verificar independientemente los hallazgos documentados:

1. **Inspección de Archivos de Especificación y Reporte:**
   - Reporte completo: `e:\Projects\quincena-app\.agents\teamwork\explorer_survey_spec\report.md`
   - DERCAS base: `c:\Users\totto\OneDrive\Desarrollo\Quincena\dercas_quincena.md` (Sección 4, RF-02)
   - DERCAS plantillas: `c:\Users\totto\OneDrive\Desarrollo\Quincena\dercas_1_1_quincena.md` (Sección 4, RF-06)
   - DERCAS cuentas: `c:\Users\totto\OneDrive\Desarrollo\Quincena\dercas_1_2.md` (Sección 4, RF-03 y RF-04)
   - Tokens y colores: `c:\Users\totto\OneDrive\Desarrollo\Quincena\colors_quincena.md`
   - DDL y restricciones: `c:\Users\totto\OneDrive\Desarrollo\Quincena\DDL_quincena.sql` (tablas `budget_allocations` y `budget_templates`)
   - Navegación actual: `e:\Projects\quincena-app\quincena\lib\main.dart` (línea 113)

2. **Condiciones de Invalidación:**
   - Si la fórmula de Presupuesto Base Cero se definiera de modo distinto a `total_income - sum(allocated_amount)`.
   - Si se permitieran duplicados de una misma categoría en un mismo ciclo o plantilla (invalidado por las restricciones UNIQUE `uq_cycle_category` y `uq_user_period_category` en `DDL_quincena.sql`).
