# Quincena API 🚀

API REST para la aplicación móvil **Quincena** — gestión de presupuesto en ciclos quincenales con soporte OCR de comprobantes.

Construida con **NestJS + TypeScript** y conectada a **Supabase** (PostgreSQL + Auth + Storage).

---

## Stack

| Tecnología | Uso |
|---|---|
| NestJS v10 | Framework HTTP |
| TypeScript | Lenguaje |
| Supabase JS SDK | Base de datos + Auth + Storage |
| class-validator | Validación de DTOs |
| @nestjs/swagger | Documentación OpenAPI |

---

## Configuración

### 1. Variables de entorno

Copia `.env.example` a `.env` y completa los valores:

```bash
cp .env.example .env
```

```env
PORT=3000
NODE_ENV=development
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key
SUPABASE_SERVICE_ROLE_KEY=tu-service-role-key
SUPABASE_JWT_SECRET=tu-jwt-secret
```

> Los valores de `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_JWT_SECRET` los encuentras en:
> Supabase Dashboard → Project Settings → API

### 2. Instalar dependencias

```bash
npm install
```

### 3. Ejecutar en desarrollo

```bash
npm run start:dev
```

---

## Endpoints disponibles

Una vez en ejecución:
- **API REST**: `http://localhost:3000/v1`
- **Swagger UI**: `http://localhost:3000/api`

### Módulos

| Ruta | Descripción |
|---|---|
| `/v1/auth` | Registro, Login, Recuperación de contraseña y Baja de cuenta (DERCAS v1.3) |
| `/v1/profiles` | Perfil del usuario autenticado |
| `/v1/financial-accounts` | Cuentas bancarias y billeteras |
| `/v1/categories` | Categorías de gasto |
| `/v1/budget-templates` | Plantillas de presupuesto por período |
| `/v1/biweekly-cycles` | Ciclos quincenales |
| `/v1/budget-allocations` | Asignación de presupuesto |
| `/v1/transactions` | Registro de gastos |
| `/v1/receipt-scans` | Comprobantes y OCR |

---

## Autenticación

Los endpoints del dominio requieren un **Bearer JWT** de Supabase en el header:

```
Authorization: Bearer <supabase-access-token>
```

El token se obtiene a través de `POST /v1/auth/login` o con el SDK de Supabase desde la app Flutter.

---

## Reglas de Negocio Implementadas

| Regla | Descripción | Endpoint |
|---|---|---|
| **RF-AUTH-01** | Registro con validación de contraseña robusta (min 8 chars, 1 mayús, 1 minús, 1 núm) | `POST /v1/auth/register` |
| **RF-AUTH-01** | Inicio de sesión con emisión de tokens JWT | `POST /v1/auth/login` |
| **RF-AUTH-02** | Recuperación con mitigación de enumeración y deep link | `POST /v1/auth/forgot-password` |
| **RF-AUTH-02** | Actualización de contraseña para sesión autenticada / reset | `POST /v1/auth/update-password` |
| **RF-AUTH-03** | Cierre seguro de sesión invalidando tokens | `POST /v1/auth/logout` |
| **RF-AUTH-04 / RN-AUTH-02** | Eliminación permanente e irreversible con doble factor (password + confirmación) y purgado de Storage | `POST /v1/auth/delete-account` |
| **RN-01** | Ciclos cerrados no aceptan cambios | Todos los endpoints que modifican datos |
| **RN-02** | Rebalanceo entre categorías sin alterar ingreso | `PATCH /budget-allocations/:id` |
| **RN-03** | Detección de duplicados ±24h | `POST /transactions?force=true` para bypassear |
| **CA-01.2** | Modal de remanente al cerrar ciclo | `POST /biweekly-cycles/:id/close` |
| **CA-02.1** | Cálculo de "Por Asignar" | `GET /budget-allocations?cycleId=...` |
| **CA-03.2** | Nunca guardar OCR de forma ciega | `POST /receipt-scans/:id/confirm` |

---

## Scripts

```bash
npm run start:dev      # Servidor en desarrollo con hot-reload
npm run build          # Compilar TypeScript
npm run start:prod     # Servidor en producción
npm run test           # Pruebas unitarias
npm run test:e2e       # Pruebas end-to-end
```
