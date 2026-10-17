# Original User Request

## 2026-10-17T03:50:10Z

# Teamwork Project Prompt

Implementar de punta a punta la pantalla y funcionalidad de **Distribución Quincenal y Presupuestos Base Cero (RF-03 y RF-04)** en la aplicación móvil Flutter (`quincena`), garantizando su plena integración con el backend NestJS (`quincena-api`) y la navegación principal de la app.

Working directory: E:\Projects\quincena-app
Integrity mode: development

## Requirements

### R1. Distribución Quincenal y Presupuestos Base Cero con Cuenta Destino (RF-03)
- En la app móvil Flutter, implementar la pantalla interactiva de distribución presupuestaria para el ciclo quincenal activo.
- Permitir la asignación monetaria por categoría/bolsa (`budget_allocations`), asociando cada partida a una cuenta financiera destino (`financial_account_id`) de donde se fondeará el gasto.
- Calcular y mostrar en tiempo real el indicador de Presupuesto Base Cero: monto total **"Por Asignar"** (Ingreso neto del ciclo activo menos la suma de las bolsas presupuestadas).
- Proporcionar una vista/resumen agrupado por cuenta financiera de fondeo para que el usuario conozca cuánto saldo debe fondear en cada cuenta durante la quincena.
- Aplicar la semaforización y reglas del Design System (paleta pastel: `#79ADDC` <70%, `#FFEE93` 70-90%, `#FFC09F` >90% o sobregiro, tipografía con números tabulares).

### R2. Plantillas Predefinidas para 1ra y 2da Quincena (RF-04)
- Crear una interfaz con pestañas independientes `[1ra Quincena]` y `[2da Quincena]` para configurar y mantener las plantillas maestras (`budget_templates`).
- Cada partida de plantilla debe contener: categoría asociada, monto base asignado y cuenta destino predeterminada.
- Brindar la funcionalidad de *"Aplicar plantilla predefinida"* al ciclo activo cuando este no posea asignaciones previas, precargando todas las bolsas con sus montos y cuentas.
- Permitir la opción de *"Guardar ciclo actual como plantilla"* para actualizar la plantilla maestra a partir del estado de la quincena en curso sin afectar ciclos cerrados.

### R3. Integración en Navegación y Cobertura Full-stack
- Conectar la pantalla en la pestaña de `Presupuestos Quincenales` en `MainShell` (reemplazando el `PlaceholderView` actual).
- Implementar los modelos de datos, servicios HTTP (`ApiClient`) y manejo de estado en Flutter correspondientes.
- Si se detectan endpoints faltantes o ajustes necesarios en `quincena-api` (módulos `budget-allocations` o `budget-templates`), actualizar o extender la API de NestJS asegurando validación de DTOs y compatibilidad con el esquema de base de datos.

## Acceptance Criteria

### Distribución Quincenal y Base Cero (RF-03)
- [ ] La pantalla muestra el cálculo dinámico "Por Asignar" restando los presupuestos creados al ingreso neto ingresado.
- [ ] Es posible crear, editar y eliminar partidas presupuestarias asignándoles una cuenta destino opcional u obligatoria.
- [ ] Se visualiza la distribución de fondos agrupada por cuenta bancaria/efectivo.

### Plantillas Quincenales (RF-04)
- [ ] Existen pestañas claramente diferenciadas para `1ra Quincena` y `2da Quincena`.
- [ ] La acción de aplicar plantilla precarga correctamente los renglones en el ciclo activo.
- [ ] Modificar una partida quincenal activa no altera la plantilla maestra a menos que el usuario guarde explícitamente el ciclo como plantilla.

### Calidad de Código y Verificación
- [ ] `flutter analyze` en `quincena/` se ejecuta con 0 errores y 0 advertencias severas.
- [ ] Pruebas unitarias o de widgets en Flutter verifican el cálculo de "Por Asignar" y la carga de datos de plantillas.
- [ ] En caso de modificaciones en el backend, `npm run build` y `npm run test` en `quincena-api/` compilan y pasan exitosamente.
