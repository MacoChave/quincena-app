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


## 2026-10-17T17:30:29Z

# Teamwork Project Prompt

Implementar de punta a punta la **Captura de Gastos vía OCR (RF-03 / RF-05)** y el **Registro Manual con Historial de Transacciones (RF-04 / RF-06)** en la aplicación móvil Flutter (`quincena`), conectándolo con los servicios existentes de `quincena-api` y reemplazando las vistas de placeholder de navegación según los diseños de Stitch.

Working directory: E:\Projects\quincena-app
Integrity mode: development

## Requirements

### R1. Captura de Gastos vía OCR y Validación Previa (RF-03 DERCAS 1.0 / RF-05 DERCAS 1.2)
- Habilitar el disparador central (FAB) en la barra de navegación y el acceso directo desde el Dashboard para abrir la experiencia de captura (cámara o selector de galería/PDF).
- Implementar la pantalla basada en el diseño de Stitch *Escanear Comprobante OCR* con visor, marco de alineación (`#79ADDC`) y máscara oscura semitransparente.
- Enviar el comprobante al endpoint de escaneo (`/receipt-scans`) para extracción automatizada de datos (monto total, comercio/establecimiento, fecha y número de referencia o autorización).
- Desplegar una hoja modal (bottom sheet) de verificación previa donde el usuario valida o edita los campos extraídos antes de confirmar (**CA-03.2**, **CA-05.2**).
- Sugerir automáticamente la categoría de gasto y la cuenta destino asociada habitual para el comercio detectado (**CA-05.2**).
- Proporcionar fallback automático al formulario manual en caso de falla o baja confianza de lectura OCR (**CA-03.4**, **CA-05.3**).

### R2. Historial de Transacciones y Feed Quincenal (RF-04 DERCAS 1.0 / RF-06 DERCAS 1.2)
- Reemplazar el `PlaceholderView` de la pestaña *Historial* en `MainShell` con la pantalla basada en el diseño de Stitch *Historial de Gastos Quincenales*.
- Mostrar el listado cronológico de gastos agrupados por fecha para el ciclo quincenal activo.
- Cada tarjeta de transacción debe exhibir: nombre del comercio/nota, fecha/hora, avatar de categoría con icono y color distintivo, cuenta bancaria/efectivo de origen y monto monetario formateado con cifras tabulares (`tnum`).
- Proveer filtros rápidos de visualización por categoría y por cuenta financiera de débito.
- Incluir un botón flotante o de acción rápida para registrar un nuevo gasto manual sin comprobante fotográfico.

### R3. Entrada Manual de Transacciones y Actualización de Saldos (RF-04 DERCAS 1.0 / RF-06 DERCAS 1.2)
- Implementar el formulario modal para registro manual de gastos con los siguientes campos:
  - Monto numérico obligatorio con teclado decimal activo (`inputmode="decimal"`).
  - Selector de categoría obligatoria (con acceso directo en contexto a `+ Nueva Categoría`).
  - Selector de cuenta financiera origen/destino obligatoria.
  - Fecha de la operación (por defecto fecha y hora actuales).
  - Campo de comercio o nota descriptiva.
- Advertencia preventiva de posible duplicado si se detecta un gasto con idéntico monto, comercio y fecha dentro de las últimas 24 horas (**RN-03**).
- Al guardar la transacción, descontar inmediatamente del saldo disponible de la categoría en el ciclo activo y actualizar las métricas de gasto en el Dashboard (**CA-04.2**, **CA-06.2**).

### R4. Integración Full-stack, Persistencia y Cobertura de Pruebas
- Conectar los nuevos flujos de Flutter (`quincena`) con los módulos existentes `transactions` y `receipt-scans` de `quincena-api`.
- Garantizar que los comprobantes escaneados se almacenen y vinculen en Supabase Storage (bucket `receipts`).
- Desarrollar pruebas unitarias y de widgets en Flutter que verifiquen el flujo de registro manual, validación de OCR, deduplicación y filtros del feed.
- Mantener `flutter analyze` en 0 errores y advertencias, y asegurar que la suite de NestJS (`npm run test` y `npm run build`) permanezca en verde.

## Acceptance Criteria

### Captura OCR (RF-03 / RF-05)
- [ ] El FAB de la barra de navegación y el botón de escaneo en HomeScreen abren el flujo de captura de comprobantes (cámara/galería).
- [ ] Se despliega el bottom sheet de confirmación con los datos extraídos para aprobación o edición del usuario antes de persistir.
- [ ] Se sugieren la categoría y cuenta bancaria/efectivo en la vista de confirmación.
- [ ] En caso de error o ilegibilidad del comprobante, se ofrece abrir el formulario manual prellenado.

### Historial y Entrada Manual (RF-04 / RF-06)
- [ ] La pestaña Historial de `MainShell` muestra el listado cronológico de transacciones del ciclo activo en lugar del placeholder.
- [ ] Es posible filtrar las transacciones por categoría y por cuenta financiera.
- [ ] El modal de entrada manual permite registrar un gasto con monto, categoría, cuenta, fecha y nota.
- [ ] Al guardar una transacción (manual o validada por OCR), se descuenta de inmediato del presupuesto asignado a la categoría y se refleja en el Dashboard en tiempo real.
- [ ] Se emite alerta preventiva si se intenta registrar un gasto duplicado en menos de 24 horas.

### Calidad de Código y Estándares
- [ ] `flutter analyze` en `quincena/` se ejecuta con 0 errores y 0 advertencias.
- [ ] Pruebas automatizadas en Flutter cubren el cálculo de impacto, filtros de historial y formularios.
- [ ] `npm run build` y `npm test` en `quincena-api/` finalizan exitosamente sin regresiones.
