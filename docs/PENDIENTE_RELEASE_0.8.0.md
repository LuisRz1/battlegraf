# PENDIENTE RELEASE 0.8.0 — Plan de cierre y handoff

> Documento de traspaso para el siguiente modelo/agente. Fecha: 2026-09-29.
> Checkout operativo: `D:\proyectos_battlegraph\landing-real` (rama `integracion-google`).
> Repo unico: `https://github.com/LuisRz1/battlegraf.git`.
> Guia operativa completa: `D:\proyectos_battlegraph\landing-real\AGENTS.md` y `D:\proyectos_battlegraph\AGENTS.md`.

---

## 1. Resumen en una linea

Se completaron las cuentas de alumno (personal y escolar), el progreso de campana
personal, el endurecimiento de RLS/RPC y el alcance del panel, todo integrado con
20 commits nuevos del remoto (juego Godot embebido, reportes IDB, menus de 3
puntos, config de bot). **Falta:** aplicar 3 migraciones del remoto, reconstruir
el APK `0.8.0`, publicar el GitHub Release `v0.8.0` y desplegar Vercel.

---

## 2. Estado del git (ya pusheable)

Rama local `integracion-google`, arbol limpio, **5 commits por delante** de
`origin/integracion-google` (que ya avanzo 20 commits; el merge ya se hizo):

```
f5e8be8 Merge remote-tracking branch 'origin/integracion-google' into integracion-google
f477d54 chore(release): prepare Android 0.8.0 download
79ba78c feat(student): add personal accounts and solo journey
d136125 fix(panel): enforce school and course scope
d2b958f feat(supabase): secure student identity and progress
```

- El merge resolvio conflictos en `backend/src/presentation/api/routes/panel.py`,
  `panel_extra.py`, `mobile/lib/core/theme/app_theme.dart` y `src/pages/panel.astro`
  conservando **ambos lados**.
- `downloads.ts` apunta a `v0.8.0` con hash `B7DDB9F9...E9C4C` y `57.4 MB`, pero
  **quedara desactualizado** al reconstruir el APK (ver paso 4). Hay que
  actualizar `androidSize` y `androidSha256` con los valores reales del build final.
- El push aun **no** se ha hecho en esta sesion. Hacer:

```powershell
cd D:\proyectos_battlegraph\landing-real
git push origin integracion-google
```

---

## 3. Que se hizo (por commit)

### d2b958f `feat(supabase): secure student identity and progress`
Migraciones nuevas en `supabase/migrations/`:

| Migracion | Contenido |
|---|---|
| `20260924010000_academic_traceability_hardening.sql` | RLS academico, `can_manage_academic_student`, alcance por colegio, `enroll_student_by_code` endurecido. |
| `20260924020000_student_player_mode.sql` | `player_profiles`, `solo_campaign_progress`, `solo_campaign_node_catalog`, `avatar_catalog`, `player_cosmetics`, RPC de onboarding personal/escuela. |
| `20260924030000_classes_rls_activation.sql` | Activa RLS en `classes`. |
| `20260924040000_solo_progress_integrity.sql` | `personal_campaign_id` atado a grado/materia reales; anti-farming de cosmeticos; completa nodo validado. |
| `20260924050000_student_onboarding_integrity.sql` | `link_or_create_student_profile` (reutiliza perfil de roster con seccion), codigos de colegio no ambiguos, `enroll_student_by_code` con seccion. |
| `20260924060000_canonical_class_enrollments.sql` | Reapunta matricula legacy al perfil con seccion. |
| `20260924070000_enrollment_identity_consistency.sql` | No reasigna matricula si su `student_id` no coincide con el dueno. |
| `20260924080000_reject_conflicting_enrollment_identity.sql` | Rechaza (fail-closed) matriculas con identidad conflictiva antes del `ON CONFLICT`. |

`scripts/verify-db.mjs` se convirtio en compuerta: exige migraciones, RPCs, RLS y
politicas, y falla con exit code 1 si algo falta.

### d136125 `fix(panel): enforce school and course scope`
- `panel.py`: helper `_preferred_student_profiles` (colapsa duplicados de perfil
  eligiendo el que tiene `section_id`); alcance por pareja `(section_id, subject_id)`
  en dashboard para teacher/tutor/student; `join_class` reutiliza y reapunta
  matriculas legacy; rechazo 409 ante identidad inconsistente.
- `panel_extra.py`: `report_staff` conserva clases asignadas por la relacion
  legacy `classes.teacher_membership_id` ademas de `subject_teachers`.
- Tests nuevos: `test_panel_classes.py`, `test_panel_dashboard_scope.py`,
  `test_panel_extra_reports.py`, `test_panel_scoping.py`.

### 79ba78c `feat(student): add personal accounts and solo journey`
- Movil: `student_app_shell.dart`, `student_home_tab.dart`, `student_school_tab.dart`,
  `student_activity_tab.dart`, `solo_route_view.dart`, `player_avatar_tab.dart`,
  `player_avatar.dart`, `solo_campaign.dart`, `player_profile_provider.dart`,
  `solo_journey_provider.dart`.
- Auth movil: registro personal gratuito y vinculacion escolar por codigo;
  `auth_provider.dart`, `register_view.dart`, `login_view.dart`, router, tema.
- Web: `onboarding.ts`, `auth/callback.ts`, `unir-clase.ts`, `mis-clases.astro`,
  `registro.astro`, `iniciar-sesion*.astro`, `panel.astro`, assets de panel.
- Version movil: `0.8.0+11`.

### f477d54 `chore(release): prepare Android 0.8.0 download`
- `src/lib/downloads.ts` apunta al release `v0.8.0`. **Requiere refresh tras rebuild.**

### f5e8be8 `Merge remote-tracking branch 'origin/integracion-google'`
Producto del merge: features del remoto que ahora conviven con lo anterior:
- `mobile/lib/presentation/views/battle/godot_battle_view.dart` (batalla Godot
  embebida con `webview_flutter`), cambios en `battle_setup_view.dart`.
- Reportes IDB: `docs/METODOLOGIA_DESEMPENO.md`, `panel_extra.py` (`_school_metrics`),
  `src/pages/api/reportes.ts`, `panel.astro`.
- Panel: menus de 3 puntos, bloqueo de borrados con dependencias
  (`_dependency_blockers`, `_raise_if_dependencies`), asignacion de cursos por
  seccion, y `src/styles/global.css` ampliado.
- `vercel.json` (framework astro) y `.gitignore` (artefactos Kotlin).
- Fix aplicado en el merge: `backend/src/presentation/api/routes/panel.py`
  `delete_subject` combina bloqueo de dependencias + filtro `school_id`.
- Fix aplicado en el merge: `panel_extra.py` `report_staff` mezcla columnas IDB
  (`Secciones`, `Desempeno IDB`, `Asistencia%`) con conteo real de alumnos
  (`len(student_keys)`).
- Fix aplicado en el merge: `mobile/lib/core/theme/app_theme.dart` conserva la
  paleta roja/morada del remoto (sin dorado).
- Fix aplicado en el merge: `src/pages/panel.astro` menú de acciones envuelto en
  `{(canManageSubjects || canDeleteSubjects) && (...)}` y sin `⋮` literal (usa `&#8942;`).
- Fix de bug del remoto: `src/pages/api/recursos.ts` usaba `r.detail` antes de
  declarar `r` en el flujo de subida de material; ahora lee `data?.detail` de la
  respuesta `fetch`.

---

## 4. Migraciones de Supabase

### Aplicadas y verificadas en produccion (proyecto `fepfoabnjldabzghvpvv`)
`20260924010000` ... `20260924080000` (8 migraciones). Verificado con
`scripts/verify-db.mjs`: RLS de jugador activo, RPCs instaladas, guard de
identidad presente, 0 perfiles ambiguos y 0 perfiles de roster sin vincular.

### PENDIENTES de aplicar (las trajo el remoto)
```
20260913090000_bot_difficulty.sql            -> battle_events.bot_difficulty
20260913091000_report_config.sql             -> school_settings.report_config
20260913100000_assignment_instructions.sql   -> assignments.instructions + assignments.points
```
Ya estan añadidas a `requiredMigrations`, a `appliedMigrations` y al nuevo
chequeo `mergedFeatureSchema` en `scripts/verify-db.mjs`.

### Como aplicar (deriva `POSTGRES_URL` desde `DATABASE_URL` sin imprimir secretos)
```powershell
cd D:\proyectos_battlegraph\landing-real
$databaseUrl = & node --env-file="D:\proyectos_battlegraph\proyectos_battlegraph\battlegraf\backend\.env" -e "process.stdout.write(process.env.DATABASE_URL || '')"
$normalizedUrl = $databaseUrl -replace '^postgresql\+(asyncpg|psycopg):', 'postgresql:' -replace '^postgres\+asyncpg:', 'postgres:' -replace '\?.*$', ''
$env:POSTGRES_URL = $normalizedUrl
node scripts/migrate.mjs
node scripts/verify-db.mjs
```
Esperado en `verify-db`: `mergedFeatureSchema` todo `true`,
`allRequiredMigrationsApplied: true` y `securityChecks` todo `true`.

---

## 5. Verificaciones realizadas (ultima pasada)

| Superficie | Comando | Resultado |
|---|---|---|
| Backend | `pytest -q tests/unit` | **52 passed** |
| Backend lint | `ruff check` + `black --check` en archivos tocados | OK |
| Astro | `npm run check` | 0 errores, 0 warnings, 2 hints preexistentes |
| Astro | `npm run build` | OK (adapter `@astrojs/vercel`) |
| Flutter | `flutter test` | **42 passed** (una corrida intermedia fallo en `battle_map_generator_test.dart` por aleatoriedad; en aislamiento y segunda corrida pasa) |
| Flutter | `flutter analyze` | **NO ejecutable**: ver bloqueo 6.1 |

Nota: el lint global de Ruff (`ruff check src`) sigue mostrando **83 avisos
heredados** en modulos ajenos a este trabajo; por eso se valida por archivo.

---

## 6. Bloqueos y trampas conocidas

### 6.1 Developer Mode de Windows (bloqueo actual del APK/analyze)
`webview_flutter` (traido por el remoto) exige symlinks. Al correr `flutter analyze`
o `flutter build apk` aparece:
```
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```
Accion: activar **Modo Desarrollador** en Windows
(`start ms-settings:developers`) y reintentar. `flutter test` si funciona sin esto.
Es requisito bloqueante para reconstruir el APK y para `flutter analyze`.

### 6.2 Firma Android
`mobile/android/app/build.gradle.kts` firma `release` con la clave **debug**
(`signingConfigs.getByName("debug")`). El APK **no es apto para Play Store**.
Verificado que el certificado debug coincide con el APK publicado `v0.7.1`
(SHA-256 `2fba3282...2606`), por lo que la actualizacion directa por GitHub si
mantiene continuidad. Resolver keystore real queda para cuando se suba a tiendas.

### 6.3 Flaky test
`mobile/test/battle_map_generator_test.dart` ("los mapas varian entre partidas")
puede fallar por azar cuando corre en la suite completa. No es regresion; si
molesta, sembrar el RNG del test.

### 6.4 Otras trampas del proyecto
- No reescribir archivos con acentos con `Set-Content` (corrompe UTF-8).
- `unset VERCEL_TOKEN` antes de `vercel deploy`; siempre reasignar el alias `five`.
- Railway exige `Root Directory = backend` y `Dockerfile Path = Dockerfile`.

---

## 7. Plan de cierre (paso a paso, en orden)

### Paso 1 — Aplicar migraciones pendientes
Ver seccion 4.

### Paso 2 — Reconstruir el APK `0.8.0`
1. Activar Modo Desarrollador (ver 6.1).
2. Toolchain (no esta en PATH):
```powershell
$env:JAVA_HOME="D:\flutter_setup\jdk17\jdk-17.0.20.1+1"
$env:ANDROID_HOME="D:\flutter_setup\android-sdk"; $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:GRADLE_USER_HOME="D:\flutter_setup\gradle"
$env:PATH="D:\flutter_setup\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:PATH"
cd D:\proyectos_battlegraph\landing-real\mobile
flutter pub get
flutter analyze          # debe quedar sin issues
flutter test             # 42/42
flutter build apk --release --dart-define-from-file=dart_defines.local.json
```
3. Ruta del artefacto: `mobile/build/app/outputs/flutter-apk/app-release.apk`.
4. (Opcional, recomendado) bump de version en `mobile/pubspec.yaml` si se decide
   `0.8.0+12`; el documento asume `0.8.0+11`.

### Paso 3 — Actualizar metadatos de descarga
```powershell
$apk = "mobile\build\app\outputs\flutter-apk\app-release.apk"
(Get-Item -LiteralPath $apk).Length          # bytes
Get-FileHash -Algorithm SHA256 -LiteralPath $apk
```
Editar `src/lib/downloads.ts`: `version: "0.8.0"`, `androidSize` (formato `55.9 MB`),
`androidSha256` (hex mayusculas). El nombre real del asset en el release debe ser
`battlegraf-android.apk` (asi lo espera `downloads.ts`).

### Paso 4 — Commit y push
```powershell
cd D:\proyectos_battlegraph\landing-real
git add src/lib/downloads.ts
git commit -m "chore(release): update Android 0.8.0 artifact digest"
git push origin integracion-google
```

### Paso 5 — GitHub Release `v0.8.0`
**Importante:** sin `--target` el tag se crea desde `main`. Indicar la rama:
```powershell
cd D:\proyectos_battlegraph\landing-real
# renombrar/ubicar el APK como battlegraf-android.apk
Copy-Item "mobile\build\app\outputs\flutter-apk\app-release.apk" "$env:TEMP\battlegraf-android.apk"
gh release create v0.8.0 "$env:TEMP\battlegraf-android.apk" `
  --repo LuisRz1/battlegraf --target integracion-google --latest `
  --title "BattleGraph 0.8.0" `
  --notes "Cuentas de alumno (personal y escolar), campana individual, cosmeticos, batalla Godot embebida, reportes IDB y mejoras de panel."
```
Verificar: `gh release view v0.8.0 --repo LuisRz1/battlegraf`.
Si el asset quedara con otro nombre, subirlo con nombre exacto:
```powershell
gh release upload v0.8.0 "$env:TEMP\battlegraf-android.apk#battlegraf-android.apk" --repo LuisRz1/battlegraf
```
Nota: subir un asset conservando el nombre `battlegraf-android.apk` puede requerir
la API con `?name=battlegraf-android.apk` si el archivo local tiene otro nombre.

### Paso 6 — Deploy Vercel + alias `five`
```powershell
$env:NODE_TLS_REJECT_UNAUTHORIZED=0; $env:VERCEL_TELEMETRY_DISABLED=1
Remove-Item Env:VERCEL_TOKEN -ErrorAction SilentlyContinue
cd D:\proyectos_battlegraph\landing-real
npm run build
vercel deploy --prebuilt --prod --yes
```
Luego reasignar el alias (no se mueve solo):
```powershell
$token = (Get-Content "$env:APPDATA\xdg.data\com.vercel.cli\auth.json" | ConvertFrom-Json).token
curl.exe -X POST "https://api.vercel.com/v1/deployments/<DEPLOY_URL>/aliases" `
  -H "Authorization: Bearer $token" -H "Content-Type: application/json" `
  -d '{\"alias\":\"battlegraf-landing-five.vercel.app\"}'
```
Proyecto `battlegraf-landing` (`prj_wN7HoAO7PbpQghxwYA02YbiN75Ui`).

### Paso 7 — Verificacion post-deploy
- `https://battlegraf-landing-five.vercel.app` carga y el link `v0.8.0` del APK descarga.
- `https://battlegraf-production.up.railway.app/openapi.json` responde 200.
- Probar en la app: registro personal, vincular colegio por codigo, unirse a clase
  por `CL-XXXX`, completar un nodo de campana, equipar un cosmetico.

---

## 8. Pendientes de producto (fuera de este release)

- Firma Android de produccion (keystore) para tiendas.
- iOS.
- Revisar que `report_staff` del remoto no duplique conteos al combinar IDB con
  el alcance por rol (validar con datos reales de un colegio).
- Reducir los 83 avisos heredados de Ruff si se quiere lint global limpio.
- Proveedor IA "Luna" intermitente (500): hay fallback local, no bloquea.

---

## 9. Archivos clave para retomar

- `supabase/migrations/20260924*` (8) + `scripts/verify-db.mjs` (compuerta).
- `backend/src/presentation/api/routes/panel.py`, `panel_extra.py` + tests en
  `backend/tests/unit/test_panel_*.py`.
- Movil: `mobile/lib/presentation/views/student/*`, `solo_route_view.dart`,
  `player_avatar_tab.dart`, `mobile/lib/presentation/providers/{auth,solo_journey,player_profile}_provider.dart`,
  `mobile/lib/domain/models/solo_campaign.dart`.
- Web: `src/pages/api/recursos.ts`, `src/pages/panel.astro`, `src/lib/onboarding.ts`,
  `src/pages/auth/callback.ts`, `src/lib/downloads.ts`.
- Remoto integrado: `mobile/lib/presentation/views/battle/godot_battle_view.dart`,
  `docs/METODOLOGIA_DESEMPENO.md`, `vercel.json`, `src/styles/global.css`.

---

## 10. Checklist rapido

- [x] Merge con `origin/integracion-google` resuelto
- [x] Migraciones `20260924*` aplicadas y verificadas
- [x] Backend 52 tests + Ruff/Black scoped
- [x] Astro check/build
- [x] Flutter test 42/42
- [x] Fix del bug `recursos.ts` heredado del remoto
- [ ] Aplicar migraciones `20260913*`
- [ ] Activar Modo Desarrollador (bloquea analyze/APK)
- [ ] `flutter analyze` limpio
- [ ] Rebuild APK `0.8.0` + actualizar `downloads.ts`
- [ ] Push `integracion-google`
- [ ] GitHub Release `v0.8.0` (target `integracion-google`, asset `battlegraf-android.apk`)
- [ ] Vercel deploy + alias `battlegraf-landing-five.vercel.app`
