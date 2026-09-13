# AGENTS.md — BattleGraph (monorepo, rama `main`)

Guía operativa para agentes de IA (OpenCode, Claude Code, Codex, etc.).
Última actualización: 2026-09-13.

---

## 1. Qué es BattleGraph

Plataforma escolar de aprendizaje gamificado por grafos: batallas por turnos
(bando rojo vs morado), avance por nodos conectados, preguntas por tema,
conquista/robo y victoria al llegar a la base rival. Incluye IA generadora de
preguntas ("Luna"), sistema institucional (colegios/roles/clases), panel
administrativo, recompensas (insignias, poderes, puntos, misiones), reportes y
juego Godot web + app móvil Flutter.

## 2. Repositorio y ramas (repo ÚNICO: `https://github.com/LuisRz1/battlegraf.git`)

- `main` → **rama unificada y de despliegue**: backend FastAPI (Railway) +
  landing/panel Astro + juego Godot + móvil Flutter. Railway y Vercel despliegan
  automáticamente desde `main` al hacer push.
- `integracion-google` → rama histórica de trabajo del panel/móvil; quedó
  fusionada en `main` (2026-09-13). Trabajar directamente en `main`.

Checkouts locales (mismo repo):
| Ruta | Rama | Uso |
|---|---|---|
| `C:\Users\edwin\Documents\Minedu-Hackathon\battlegraf` | `main` | landing/panel, backend, móvil, supabase, juego (fuente de verdad) |

> El backend se despliega en Railway al pushear `main` (integración GitHub).
> El panel/landing se despliega en Vercel al pushear `main`; el alias `five`
> apunta al deployment de producción.

## 3. Arquitectura (superficies)

```
Landing/panel Astro SSR (Vercel)            Backend FastAPI (Railway)
├─ /, /registro, /iniciar-sesion, /mis-clases ├─ https://battlegraf-production.up.railway.app
├─ /panel (vistas admin, 17)                  ├─ /docs (Swagger, ~112 rutas)
├─ /api/* (proxy a FastAPI)                   ├─ /api/v1/panel/* (panel + rewards + reports + materials)
├─ /game/BattleGraph.html (Godot web)         └─ IA "Luna" + agente con memoria
└─ Supabase Auth (Google + correo)
              │
   Supabase PostgreSQL 17 (BD única)
```

- El **panel** opera vía FastAPI (`/api/v1/panel/*`) con token Supabase; lecturas
  con fallback a Supabase directo.
- El **juego/móvil** consumen `GET /api/v1/public/questions?school_id=&subject=&limit=`.

## 4. Despliegues

### Railway (backend)
- Proyecto `lavish-friendship` (`34b17150-17d5-4603-917d-5d79e04f7003`),
  env `production` (`0aee7eeb-5084-4ab0-bc5d-3a342e524d4a`),
  servicio `battlegraf` (`628a67c5-9c37-4ff4-8d7d-3707bee91b81`).
- **CRÍTICO (build desde GitHub):** el servicio DEBE tener
  **Root Directory = `backend`** y **Dockerfile Path = `Dockerfile`**. Si quedan
  vacíos, Railway usa Railpack sobre la raíz del monorepo y **falla**.
- Deploy manual: `cd backend && railway up -s <svc> -p <proj> -e <env>`
  (CLI en `%LOCALAPPDATA%\hermes\node\railway.cmd`; logueado por OAuth).
- Ajustar settings del servicio vía GraphQL: `railway api` (mutation
  `serviceInstanceUpdate`). Deploy fresco desde GitHub:
  `serviceInstanceDeploy(serviceId, environmentId, latestCommit: true)`.

### Vercel (landing/panel)
```bash
export NODE_TLS_REJECT_UNAUTHORIZED=0 VERCEL_TELEMETRY_DISABLED=1
unset VERCEL_TOKEN                      # con VERCEL_TOKEN el deploy rompe
cd D:\proyectos_battlegraph\landing-real
npm run build --strict-ssl=false        # requiere .env.local
vercel deploy --prebuilt --prod --yes
# REASIGNAR el alias (no se mueve solo):
curl -X POST "https://api.vercel.com/v1/deployments/<deploy-url>/aliases" \
  -H "Authorization: Bearer <token-de-auth.json>" -H "Content-Type: application/json" \
  -d '{"alias":"battlegraf-landing-five.vercel.app"}'
```
- Proyecto `battlegraf-landing` (`prj_wN7HoAO7PbpQghxwYA02YbiN75Ui`).
- Token en `%APPDATA%\xdg.data\com.vercel.cli\auth.json`.
- **`vercel.json` en la raíz** fuerza `framework: astro` + `buildCommand`, para que
  el deploy automático desde GitHub compile (el proyecto tenía Framework Preset
  `Other`, por eso los builds salían vacíos con 404). Si se cambia el preset en
  el dashboard, este archivo es redundante pero inofensivo.
- Variables requeridas por el build en Vercel: `NEXT_PUBLIC_SUPABASE_URL`,
  `NEXT_PUBLIC_SUPABASE_ANON_KEY` (ya presentes). Para rutas que usan service
  role conviene agregar `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
  `SUPABASE_SECRET_KEY` y `PANEL_API_URL`.

### Supabase (BD)
- Proyecto `fepfoabnjldabzghvpvv` (`https://fepfoabnjldabzghvpvv.supabase.co`).
- Migraciones en `supabase/migrations/`; aplicar con `node scripts/migrate.mjs`
  y `POSTGRES_URL` (de `backend/.env`, quitar `+psycopg` y la query).
- Claves: usar `SUPABASE_SECRET_KEY` (`sb_secret_…`, service role) y
  `SUPABASE_PUBLISHABLE_KEY` (`sb_publishable_…`). Las `eyJ2…` viejas NO sirven.

## 5. Comandos

### Backend (FastAPI)
```powershell
cd D:\proyectos_battlegraph\landing-real\backend
..\..\  # venv en el otro checkout:
D:\proyectos_battlegraph\proyectos_battlegraph\battlegraf\backend\.venv\Scripts\python.exe -m pytest -q tests/unit
...\python.exe -m ruff check src
...\python.exe -m black src
```
- Tests: `pytest` (unit en verde). Lint: `ruff` + `black`.
- `main.py` monta los routers; el panel se separa en `panel.py`, `panel_extra.py`
  (rewards/reports/materials/powerups) y `panel_assistant.py` (asistente/memoria).

### Landing (Astro)
- Paquete **bun** (`package-lock.json` ignorado). Compilar con `npm run build`.
- `output: 'server'` + adapter `@astrojs/vercel` (SSR).

### Móvil (Flutter) — **NO está en el PATH**
```powershell
$env:JAVA_HOME="D:\flutter_setup\jdk17\jdk-17.0.20.1+1"
$env:ANDROID_HOME="D:\flutter_setup\android-sdk"; $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:GRADLE_USER_HOME="D:\flutter_setup\gradle"   # C: está lleno; caches en D:
$env:PATH="D:\flutter_setup\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:PATH"
flutter pub get
flutter analyze          # solo 3 infos preexistentes en app_theme.dart
flutter test             # 35/35
flutter build apk --release --dart-define-from-file=dart_defines.local.json
```
- `mobile/dart_defines.local.json` (gitignored) con `API_BASE_URL`,
  `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `AUTH_CALLBACK_URL`.
- Publicar APK: crear GitHub Release `vX.Y.Z`, subir el APK como
  `battlegraf-android.apk`, y actualizar `src/lib/downloads.ts` (versión, URL,
  size, sha256) → commit → deploy landing.

### Juego Godot (web)
- Fuente reconstruida desde el `.pck` (ver `game-recovered` en temp). Export web
  a `public/game/` con Godot 4.7 portable.
- **Al actualizar el juego, BUMBEAR `CACHE_VERSION` en
  `public/game/BattleGraph.service.worker.js`** (el SW cachea el pck).
- El juego llama al backend en `core/remote_questions.gd` (`API_BASE` hardcodeado).

## 6. Estructura del repo

- `src/` (Astro): `pages/panel.astro` (panel), `pages/api/*` (proxy), `components/`, `styles/global.css`.
- `backend/src/`: `domain/`, `application/`, `infrastructure/` (rewards, ai, database), `presentation/api/routes/`.
- `mobile/lib/`: `core/`, `domain/`, `presentation/` (providers, views, widgets), `features/institution/`.
- `supabase/migrations/`.
- `public/game/` (export), `public/assets/`, `public/fonts/`.
- `scripts/` (migrate, seed, verify).

## 7. Supabase — tablas clave

Núcleo: `schools`, `academic_years`, `sections`, `memberships`, `staff_profiles`,
`student_profiles`, `subjects`, `section_subjects`, `classes`, `class_enrollments`,
`question_bank`, `assignments`, `battle_events`, `rank_definitions`, `school_settings`.

Seguimiento académico: `academic_periods`, `attendance_records`, `grade_items`,
`student_grades`, `student_observations`, `subject_teachers`.

Nuevo (2026-09-11):
- `assignment_submissions` (entregas de tareas), `battle_results` (historial de batallas del alumno).
- `badges`, `student_badges`, `reward_powerups`, `student_powerups`,
  `points_ledger`, `missions`, `student_missions` (sistema de recompensas).
- `study_goals` (metas de estudio por grado/materia), `account_memory` (memoria por cuenta).
- `learning_materials` ampliada: `storage_path`, `extracted_text`, `grade`, `char_count`, `uploaded_by_membership_id`.
- RPC `seed_rewards(school_id)` siembra insignias/poderes por defecto.

## 8. Panel `/panel` — vistas

`centro`, `perfil`, `colegio`, `clases`, `secciones`, `materias`, `personas`,
`academico`, `materiales`, `preguntas`, `tareas`, `batallas`, `progreso`,
`recompensas`, `misiones`, `metas`, `reportes`, `asistente`, `auditoria`.

- Todo en español; estados traducidos (`trEstado/trRol/...`).
- Botones acción: `.btn-edit` (destaca) / `.btn-del` (rojo); confirmación con `data-confirm`.
- Las acciones académicas (asistencia, evaluación, nota, observación) se abren
  desde la vista `academico`.

## 9. Juego

- **Web (Godot)**: mapa configurable base a base (`_generate_configured_map`),
  preguntas reales del colegio, habilidades por nodo, bot.
- **Móvil (Flutter nativo)**: `BotBattleDemoController` genera **mapas dinámicos
  y aleatorios por batalla** (base a base, capas/nodos configurables), usa
  preguntas reales y permite equipar/consumir poderes ("USAR PODER").
- Rutas móvil: `/student` (dashboard), `/student-detail`, `/battle/setup`,
  `/battle/play`, `/assistant`.

## 10. IA

- `backend/src/infrastructure/ai/openai_agent.py` — genera preguntas (Luna:
  `OPENAI_MODEL=gpt-5.6-luna`, base `https://opencode.ai/zen/go/v1`).
- `backend/src/infrastructure/ai/assistant.py` — asistente con memoria.
- `account_memory` guarda contexto/resumen/historial por cuenta.
- **El proveedor Luna es intermitente (500)**; ambos módulos tienen fallback
  local y no rompen el flujo.

## 11. Convenciones y trampas (pitfalls)

1. **No uses `Set-Content`/PowerShell para reescribir archivos con acentos**:
   corrompe UTF-8 (mojibake `Ã©`). Edita con las herramientas del editor.
2. **Railway GitHub build**: requiere `rootDirectory=backend` + `dockerfilePath=Dockerfile` (ver §4).
3. **Vercel**: `unset VERCEL_TOKEN` antes de `vercel deploy`; reasignar el alias `five` siempre.
4. **Supabase**: usar claves `sb_secret_`/`sb_publishable_`; las `eyJ2…` de Vercel están encriptadas.
5. **Kaspersky MITM**: `NODE_TLS_REJECT_UNAUTHORIZED=0` / `--strict-ssl=false` en dev.
6. **C: casi lleno**: caches de Gradle/pub en D: (`GRADLE_USER_HOME`).
7. No commitear `.env*`, `dart_defines.local.json` ni claves.
8. Commits **específicos por cambio** (no un commit general).
9. **Idempotencia** en recompensas/XP: `(source_type, source_id)` con unique.

## 12. Estado actual (2026-09-11)

- ✅ Landing/panel Astro en Vercel (`battlegraf-landing-five.vercel.app`).
- ✅ Backend FastAPI en Railway (~112 rutas) con recompensas, reportes,
  materiales IA, asistente y consumo de poderes.
- ✅ Móvil Flutter 0.7.0 con dashboard, batallas dinámicas, poderes, asistente.
- ✅ Juego Godot web con mapas corregidos (`CACHE_VERSION v11`).
- ⏳ Pendientes: iOS, APK firmado para tiendas, multijugador alumno vs alumno en
  vivo, proveedor IA estable, chat/asistente con UI más rica, pruebas de campo.
