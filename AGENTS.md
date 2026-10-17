# Equipo de Agentes - Proyecto Quincena

Este documento define la estructura y responsabilidades del equipo de subagentes especializados para el proyecto **Quincena**, así como los canales de comunicación y flujo de trabajo.

---

## 👥 Miembros del Equipo y Roles

| Agente | Nombre Clave | Workspace Principal | Responsabilidades |
| :--- | :--- | :--- | :--- |
| **DBA** | `quincena-dba` | `supabase/migrations/` | • Esquemas DDL (v1.1, v1.2, v1.3).<br>• Migraciones PostgreSQL / Supabase CLI.<br>• Políticas RLS y funciones PL/pgSQL.<br>• Storage buckets y permisos (`receipts`). |
| **Backend** | `quincena-backend` | `quincena-api/` | • API REST en NestJS con TypeScript.<br>• Integración con `@supabase/supabase-js`.<br>• DTOs, validaciones y documentación Swagger.<br>• Lógica de negocio y autenticación. |
| **Mobile** | `quincena-mobile` | `quincena/` | • Aplicación móvil en Flutter (Dart).<br>• UI/UX según design system y colores.<br>• Integración con Supabase Auth y API NestJS.<br>• Captura y procesamiento de tickets OCR. |
| **DevOps** | `quincena-devops` | Raíz / Infraestructura | • Configuración de entornos y variables (.env).<br>• Pipelines CI/CD y automatización Docker.<br>• Despliegue de migraciones (`supabase db push`).<br>• Compilación y empaquetado para tiendas. |

---

## 🔄 Matriz de Comunicación e Interacción

```mermaid
flowchart TD
    DBA["quincena-dba<br>(Base de Datos & Supabase)"]
    BE["quincena-backend<br>(API NestJS)"]
    MOB["quincena-mobile<br>(App Flutter)"]
    OPS["quincena-devops<br>(Infraestructura & Despliegues)"]

    DBA <-->|"Esquemas, tipos y RLS"| BE
    DBA <-->|"Modelos de datos y Storage"| MOB
    BE <-->|"Endpoints REST y Contratos"| MOB
    OPS -->|"Aplica migraciones (db push)"| DBA
    OPS -->|"Despliegues y Contenedores"| BE
    OPS -->|"Builds y Publicación"| MOB
```

---

## 💬 Canales de Mensajería Inter-Agente

* **Mensajería síncrona/asíncrona:** Se realiza utilizando la herramienta `send_message` enviando al `conversationID` de cada subagente cuando es invocado mediante `invoke_subagent`.
* **Conversación Directa del DBA (este chat):**
  * **Conversation ID:** `922797b3-ac8f-4456-9ab5-92a8f1989090`
  * **Enlace directo:** [quincena-dba](conversation://922797b3-ac8f-4456-9ab5-92a8f1989090)
