# Reporte de Exploración de Código: Quincena Mobile (Flutter)

**Fecha**: 2026-10-17  
**Workspace**: `e:\Projects\quincena-app\quincena`  
**Objetivo**: Inspección técnica exhaustiva de la aplicación móvil Flutter para la implementación de RF-03 (Distribución Quincenal y Presupuestos Base Cero con Cuenta Destino) y RF-04 (Plantillas Predefinidas para 1ra y 2da Quincena).

---

## 1. Navegación Principal y Shell (`MainShell`)

### Ubicación del Entrypoint y Navegación
* **Archivo**: `quincena/lib/main.dart`
* **Widget Shell**: `MainShell` (líneas 77-143).
* **Navegación**: Utiliza un `Scaffold` con `IndexedStack` controlado por `_currentIndex` y sincronizado con `AppBottomNavBar` (`core/components/navigation/app_bottom_nav_bar.dart`).
* **Ubicación de Presupuestos Quincenales**:
  * En `_MainShellState.build()` (línea 113 de `main.dart`), el índice 1 del arreglo de pantallas está ocupado actualmente por el marcador de posición:
    ```dart
    const PlaceholderView(title: 'Presupuestos Quincenales')
    ```
  * En la barra de navegación `AppBottomNavBar`, el elemento en índice 1 corresponde a:
    ```dart
    AppNavItem(
      label: 'Presupuesto',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    )
    ```
  * Las cuatro pestañas del shell son:
    * Índice 0: `HomeScreen` (Inicio / Dashboard Quincena Activa).
    * Índice 1: `PlaceholderView(title: 'Presupuestos Quincenales')` -> **Punto de anclaje para RF-03 y RF-04**.
    * Índice 2: `PlaceholderView(title: 'Historial de Transacciones')`.
    * Índice 3: `ProfileScreen` (Ajustes, Perfil, Cuentas Financieras).
  * En el centro dockeado se encuentra el `AppFab` para el escaneo OCR de tickets.

---

## 2. Arquitectura de Estado, Red y Modelos

### Gestión de Estado
* **Patrón**: State Management nativo y desacoplado mediante Flutter Vanilla (`ChangeNotifier`, `ListenableBuilder`, `StatefulWidget` con `setState`, `FutureBuilder` y `showModalBottomSheet`).
* No se utilizan paquetes pesados de terceros como Riverpod o Bloc; el proyecto mantiene dependencias ligeras y limpias (`google_fonts`, `http`, `cupertino_icons`).
* **Autenticación**: `AuthSessionManager` (`lib/features/auth/data/auth_session_manager.dart`) es un `ChangeNotifier` global inyectado desde `main.dart` a `AuthGate` y `MainShell`. Expone `apiClient`, `user`, `profile`, `isAuthenticated`.

### Capa de Red (`ApiClient`)
* **Archivo**: `lib/core/network/api_client.dart`
* Gestiona cabeceras `Content-Type: application/json` y `Authorization: Bearer <token>`.
* Métodos HTTP disponibles: `get`, `post`, `patch`, `delete`.
* Manejo de errores: Lanza `ApiException(statusCode, message, error)`.
* URL Base:
  * Android: `http://10.0.2.2:3000/v1`
  * Web / Desktop / Otros: `http://localhost:3000/v1`
* Invocación de interceptor `onUnauthorized` ante respuestas HTTP 401.

### Modelos Existentes en el Proyecto
* `DashboardData`, `DashboardCycle`, `DashboardSummary`, `DashboardCategory` en `lib/features/dashboard/data/models/dashboard_data.dart`.
* `FinancialAccount`, `AccountType` en `lib/features/financial_accounts/models/financial_account.dart`.
* `AuthUser`, `AuthTokens` en `lib/features/auth/data/models/`.
* `UserProfile` en `lib/features/profile/data/models/user_profile.dart`.

### Modelos Faltantes Necesarios para RF-03 y RF-04
1. **`BudgetAllocation`**: ID, ciclo (`cycleId`), categoría (`categoryId`), cuenta destino (`destinationAccountId`), monto presupuestado (`allocatedAmount`), monto gastado (`spentAmount`), saldo disponible (`availableAmount`), porcentaje de consumo (`spentPercentage`), y objetos anidados `category` y `destinationAccount`.
2. **`AllocationsSummary`**: Total ingresos (`totalIncome`), total asignado (`totalAllocated`), saldo "Por Asignar" (`unallocated`), total gastado (`totalSpent`), saldo disponible total (`totalAvailable`), `isBalanced`, `isClosed`.
3. **`FundingAccountSummary`**: Agrupación por cuenta financiera destino: nombre de cuenta, color, icono, monto total a fondear en la quincena.
4. **`BudgetTemplate`**: ID, usuario (`userId`), período (`first_half` | `second_half`), categoría (`categoryId`), cuenta destino (`destinationAccountId`), monto base (`defaultAmount`), y metadatos de categoría / cuenta asociados.
5. **`Category`**: ID, nombre (`name`), icono (`icon`), color (`colorHex`), cuenta por defecto (`defaultAccountId`), estado archivado (`isArchived`).

---

## 3. Tokens del Sistema de Diseño ("Serene Bi-Weekly Finance")

### Colores Semánticos (`AppColors` en `lib/core/theme/app_colors.dart`)
* **Marca y Barras < 70%**: Soft Sky Blue (`#79ADDC`, `Color(0xFF79ADDC)`).
* **Alerta y Umbral 70% - 90%**: Soft Sunshine (`#FFEE93`, `Color(0xFFFFEE93)`).
* **Gastos Críticos / Sobregiro / Desbalance > 90%**: Muted Coral (`#FFC09F`, `Color(0xFFFFC09F)`).
* **Ingresos y Presupuesto Equilibrado ($0 Por Asignar)**: Mint Pastel (`#ADF7B6`, `Color(0xFFADF7B6)`).
* **Superficie Hero Card**: Warm Cream (`#FCF5C7`, `Color(0xFFFCF5C7)`).
* **Superficie Base**: Blanco (`#FFFFFF`).
* **Texto Principal**: Deep Navy Charcoal (`#1C242B`) — regla del DS: nunca usar blanco sobre tonos pasteles.
* **Bordes**: `borderSubtle` (`#E2E6EA`), `borderHairline` (`0x1F1C242B`).

### Tipografía y Números Tabulares (`AppTypography` en `lib/core/theme/app_typography.dart`)
* Familia de fuente: **Plus Jakarta Sans** vía `google_fonts`.
* Soporte tabular estricto: `FontFeature.tabularFigures()` activo en:
  * `AppTypography.currencyHero` (38px, w800)
  * `AppTypography.currencyHeroMobile` (32px, w800)
  * `AppTypography.currencyMd` (18px, w700)
  * `AppTypography.numericRow` (14px, w500)
* Evita parpadeos y desalineaciones en listas financieras numéricas al actualizar en tiempo real.

### Componentes Reutilizables Disponibles (`lib/core/components/`)
* **`AppProgressBar`**: Implementa semáforo automático `< 70%` (`#79ADDC`), `70-90%` (`#FFEE93`), `> 90%` (`#FFC09F`).
* **`AppHeroCard`**: Tarjeta destacada en fondo crema con métricas monetarias.
* **`AppBadge`**: Variantes `standard`, `income`, `warning`, `expense`.
* **`AppCard`**: Tarjeta blanca con bordes redondeados (16px), sombra ambiental y `InkWell` opcional.
* **`AppAmountInput`**: Input monetario con símbolo, estilo tabular y validación visual.
* **`AppButton`**: Botón primario (`#1C242B`), secundario, tinted (`#79ADDC`), y con estado de carga integrado.
* **`AppTextField`**: Input estándar con etiquetas, helpers e iconos.
* **`AppAppBar`**: Barra superior estándar con soporte de acciones y botón de regreso.

---

## 4. Estado del Tooling y Pruebas

### Diagnóstico de `flutter analyze`
* **Resultado**: 1 issue detectado en `test/widget_test.dart:16:35`.
  ```
  error - The name 'MyApp' isn't a class. Try correcting the name to match an existing class - test\widget_test.dart:16:35 - creation_with_non_type
  ```
* **Evaluación de `lib/`**: El código fuente en `quincena/lib/` está **100% libre de errores y advertencias de linter**.
* **Causa**: El archivo `widget_test.dart` proviene de la plantilla por defecto generada por Flutter (`flutter create`) que buscaba `MyApp`, mientras que el proyecto utiliza `QuincenaApp`.

### Diagnóstico de `flutter test`
* Falla debido al error de compilación en `test/widget_test.dart`.
* **Acción requerida**: Corregir `widget_test.dart` y agregar la suite de pruebas unitarias y de widgets para RF-03 (cálculo Base Cero y agrupación de cuentas) y RF-04 (plantillas por período).

### Diagnóstico del Backend (`quincena-api`)
* `npm run build` en `quincena-api` compila exitosamente con código de salida 0.

---

## 5. Mapeo de Archivos para RF-03 y RF-04

### A. Nuevos Archivos a Crear en `quincena/lib/features/budget/`

1. **Modelos**:
   * `quincena/lib/features/budget/models/budget_allocation.dart`
     * `BudgetAllocation`: Entidad para las asignaciones del ciclo activo con montos gastados, disponibles y referencias a categoría y cuenta destino.
     * `AllocationsSummary`: Resumen general con total ingresos, total presupuestado, "Por Asignar" y banderas de equilibrio (`isBalanced`).
     * `FundingAccountSummary`: Modelo auxiliar para el resumen agrupado por cuenta de fondeo (CA-03.3).
   * `quincena/lib/features/budget/models/budget_template.dart`
     * `BudgetTemplate`: Partida de plantilla maestra con período (`first_half` / `second_half`), categoría, cuenta destino predeterminada y monto base.
     * `QuincenaPeriod`: Enum o helper para `first_half` y `second_half`.
   * `quincena/lib/features/budget/models/category.dart`
     * `Category`: Modelo completo de categoría para selección en dropdowns/modales.

2. **Servicio API**:
   * `quincena/lib/features/budget/data/budget_api_service.dart`
     * `getCycleAllocations(String cycleId)` -> `GET /budget-allocations?cycleId=...`
     * `createAllocation(...)` -> `POST /budget-allocations`
     * `updateAllocation(...)` -> `PATCH /budget-allocations/:id`
     * `deleteAllocation(...)` -> `DELETE /budget-allocations/:id`
     * `getTemplates(String period)` -> `GET /budget-templates?period=...`
     * `createTemplate(...)` -> `POST /budget-templates`
     * `updateTemplate(...)` -> `PATCH /budget-templates/:id`
     * `deleteTemplate(...)` -> `DELETE /budget-templates/:id`
     * `applyTemplateToCycle(String cycleId, String period)` -> Aplica la plantilla al ciclo activo.
     * `saveCycleAsTemplate(String cycleId, String period)` -> Guarda el estado del ciclo activo como plantilla maestra.
     * `getCategories()` -> `GET /categories`

3. **Presentación (Pantalla y Widgets)**:
   * `quincena/lib/features/budget/presentation/budget_screen.dart`
     * Pantalla principal con pestañas o segmento superior:
       * **[Distribución Quincenal]** (RF-03): Presupuestos Base Cero del ciclo activo.
       * **[Plantillas Maestras]** (RF-04): Sub-pestañas `[1ra Quincena]` y `[2da Quincena]`.
   * `quincena/lib/features/budget/presentation/widgets/zero_base_header_card.dart`
     * Indicador visual en tiempo real de "Por Asignar" (Ingreso neto - Asignaciones).
     * Semaforización Pastel:
       * Balance exacto ($0.00): Verde pastel `#ADF7B6` con mensaje "Presupuesto Base Cero logrado".
       * Fondos restantes (> $0.00): Amarillo pastel `#FFEE93` con advertencia de fondos sin asignar.
       * Sobreasignado (< $0.00): Rojo/Coral pastel `#FFC09F` indicando déficit.
   * `quincena/lib/features/budget/presentation/widgets/funding_accounts_summary.dart`
     * Tarjeta de desglose por cuenta de fondeo (RF-03 / R1): muestra cuánto saldo debe transferirse o fondearse en cada banco/efectivo.
   * `quincena/lib/features/budget/presentation/widgets/allocation_item_tile.dart`
     * Fila interactiva para cada partida presupuestaria con barra de progreso, cuenta asociada, botón de edición y eliminación.
   * `quincena/lib/features/budget/presentation/widgets/allocation_form_sheet.dart`
     * Modal bottom sheet para crear o editar una asignación presupuestaria (categoría, cuenta financiera destino, monto con `AppAmountInput`).
   * `quincena/lib/features/budget/presentation/widgets/templates_tab_view.dart`
     * Vista de plantillas con selector de `1ra Quincena` y `2da Quincena`, botones de acción rápida *"Aplicar plantilla al ciclo"* y *"Guardar ciclo actual como plantilla"*, y lista de partidas base.
   * `quincena/lib/features/budget/presentation/widgets/template_form_sheet.dart`
     * Modal bottom sheet para configurar una partida en la plantilla maestra.

### B. Archivos a Modificar
1. **`quincena/lib/main.dart`**:
   * Reemplazar la línea 113:
     ```dart
     // ANTES:
     const PlaceholderView(title: 'Presupuestos Quincenales'),
     // DESPUÉS:
     BudgetScreen(
       apiClient: widget.apiClient,
       sessionManager: widget.sessionManager,
     ),
     ```
2. **`quincena/test/widget_test.dart`**:
   * Corregir el test roto reemplazando la referencia a `MyApp` por una prueba funcional o de renderizado del shell.
3. **`quincena/test/features/budget/zero_base_calculation_test.dart`**:
   * Pruebas unitarias que validen:
     * Cálculo de "Por Asignar" (`unallocated = totalIncome - sum(allocated)`).
     * Agrupación de fondos requeridos por cuenta financiera destino (`Map<String, double>`).
     * Detección de balance cero (`unallocated == 0`).
4. **`quincena/test/features/budget/budget_screen_test.dart`**:
   * Prueba de widget verificando el renderizado de la pantalla de presupuestos y el cambio entre la pestaña de Distribución y Plantillas.

### C. Ajustes Recomendados en el Backend (`quincena-api`)
Para que la integración sea completamente atómica y cumpla RF-04 a la perfección:
1. En `modules/budget-templates/budget-templates.service.ts` y controller:
   * Agregar endpoint `POST /budget-templates/apply` para copiar las plantillas del período correspondiente hacia las asignaciones del ciclo activo (verificando que no tenga asignaciones previas o sobreescribiendo si está vacío).
   * Agregar endpoint `POST /budget-templates/save-from-cycle` para actualizar la plantilla maestra a partir de las asignaciones actuales del ciclo activo.
   * En `findByPeriod()`, incluir `destination_account:financial_accounts(id, name, color_hex)` en el `select` para que la app reciba directamente los datos visuales de la cuenta asignada a cada plantilla.
