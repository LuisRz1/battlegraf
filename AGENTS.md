# AGENTS.md — BattleGraph (rama `main`)

Este checkout es un **snapshot del monorepo** sobre la rama `main` (backend + landing/panel + móvil + juego). La **rama operativa** del producto es `integracion-google`.

> **Guía completa y actualizada para agentes:** `D:\proyectos_battlegraph\landing-real\AGENTS.md`
> **Guía maestra del proyecto (fuera del repo):** `D:\proyectos_battlegraph\AGENTS.md`

## Lo esencial

- Repo ÚNICO: `https://github.com/LuisRz1/battlegraf.git`.
  - `main` → backend FastAPI (Railway).
  - `integracion-google` → landing/panel Astro + móvil Flutter + juego Godot (Vercel).
- **Backend**: `backend/` (FastAPI). Deploy manual:
  `cd backend && railway up -s 628a67c5-... -p 34b17150-... -e 0aee7eeb-...`
  El servicio Railway exige **Root Directory = `backend`** y **Dockerfile Path = `Dockerfile`** (si no, el build desde GitHub falla con Railpack).
- **Landing/panel Astro**: `src/pages/panel.astro`, `src/pages/api/*`. Build `npm run build` + `vercel deploy --prebuilt --prod --yes` y **reasignar el alias `five`**.
- **Móvil Flutter**: `mobile/`. Toolchain en `D:\flutter_setup` (Flutter, android-sdk, `jdk17\jdk-17.0.20.1+1`); `GRADLE_USER_HOME` en D:. Build con `--dart-define-from-file=dart_defines.local.json`.
- **Juego**: export Godot en `public/game/`; al actualizar, **bumpear `CACHE_VERSION`** en `BattleGraph.service.worker.js`.
- **Supabase**: proyecto `fepfoabnjldabzghvpvv`; migraciones en `supabase/migrations/` (aplicar con `node scripts/migrate.mjs` + `POSTGRES_URL`).

## Trampas
- No reescribir archivos con acentos con `Set-Content` de PowerShell (corrompe UTF-8).
- `unset VERCEL_TOKEN` antes de desplegar; reasignar el alias `five`.
- Claves Supabase: usar `sb_secret_…` / `sb_publishable_…`.
- No commitear `.env*`, `dart_defines.local.json` ni llaves.
- Commits **específicos por cambio**.

## Estado (2026-09-11)
Backend ~112 rutas (recompensas, reportes, materiales IA, asistente, consumo de poderes); panel Astro con 17 vistas; móvil 0.7.0 (dashboard, mapas dinámicos, poderes, asistente, paleta rojo→morado); juego con mapas base a base (`CACHE_VERSION v11`).
Detalle: [[11 - Recompensas, asistente y reportes 2026]] del vault de Obsidian.
