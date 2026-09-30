# PENDIENTE RELEASE 0.8.0 — Plan de cierre y handoff

> Informe final y handoff para el siguiente modelo/agente. Actualizado: 2026-09-30.
> Checkout operativo: `D:\proyectos_battlegraph\landing-real` (rama `integracion-google`).
> Repo unico: `https://github.com/LuisRz1/battlegraf.git`.
> Guia operativa completa: `D:\proyectos_battlegraph\landing-real\AGENTS.md` y `D:\proyectos_battlegraph\AGENTS.md`.

---

## 1. Resumen en una linea

Se completaron y publicaron las cuentas de alumno (personal y escolar), la campana
individual y cosmeticos, el endurecimiento de RLS/RPC, el alcance del panel y los
20 commits que llegaron al remoto (Godot embebido, reportes IDB, menus de 3 puntos,
config de bot). Las 11 migraciones estan aplicadas; APK `0.8.0+11`, GitHub Release
`v0.8.0`, Railway y Vercel estan publicados. Este documento se incluye en el push
final de `integracion-google`.

---

## 2. Estado del git (ya pusheable)

Rama `integracion-google`, sincronizada con `origin/integracion-google` tras
integrar 20 commits remotos y pushear el trabajo y este informe. Commits propios:

```
a641691 chore(release): update Android 0.8.0 artifact digest
b2e7731 docs: plan de cierre y handoff del release 0.8.0
f5e8be8 Merge remote-tracking branch 'origin/integracion-google' into integracion-google
f477d54 chore(release): prepare Android 0.8.0 download
79ba78c feat(student): add personal accounts and solo journey
d136125 fix(panel): enforce school and course scope
d2b958f feat(supabase): secure student identity and progress
```

- El merge resolvio conflictos en `backend/src/presentation/api/routes/panel.py`,
  `panel_extra.py`, `mobile/lib/core/theme/app_theme.dart` y `src/pages/panel.astro`
  conservando **ambos lados**.
- `src/lib/downloads.ts` coincide con el asset publicado: `58.1 MB` y SHA-256
  `EC44887565BCF2A86316F5235AFBC6F345DD30DD76C5D916ACC590D988620A19`.
- El arbol de trabajo quedo limpio despues del push del release; este informe
  se empuja como commit adicional.

---

## 3. Que se hizo (por commit)

### d2b958f `feat(supabase): secure student identity and progress`

Migraciones nuevas en `supabase/migrations/`:

| Migracion                                                   | Contenido                                                                                                                                            |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `20260924010000_academic_traceability_hardening.sql`        | RLS academico, `can_manage_academic_student`, alcance por colegio, `enroll_student_by_code` endurecido.                                              |
| `20260924020000_student_player_mode.sql`                    | `player_profiles`, `solo_campaign_progress`, `solo_campaign_node_catalog`, `avatar_catalog`, `player_cosmetics`, RPC de onboarding personal/escuela. |
| `20260924030000_classes_rls_activation.sql`                 | Activa RLS en `classes`.                                                                                                                             |
| `20260924040000_solo_progress_integrity.sql`                | `personal_campaign_id` atado a grado/materia reales; anti-farming de cosmeticos; completa nodo validado.                                             |
| `20260924050000_student_onboarding_integrity.sql`           | `link_or_create_student_profile` (reutiliza perfil de roster con seccion), codigos de colegio no ambiguos, `enroll_student_by_code` con seccion.     |
| `20260924060000_canonical_class_enrollments.sql`            | Reapunta matricula legacy al perfil con seccion.                                                                                                     |
| `20260924070000_enrollment_identity_consistency.sql`        | No reasigna matricula si su `student_id` no coincide con el dueno.                                                                                   |
| `20260924080000_reject_conflicting_enrollment_identity.sql` | Rechaza (fail-closed) matriculas con identidad conflictiva antes del `ON CONFLICT`.                                                                  |

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

- Commit inicial de metadatos; el digest final se actualizo en `a641691` tras el build.

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

Las 11 migraciones estan en `public.battlegraf_schema_migrations`:

```
20260913090000_bot_difficulty.sql
20260913091000_report_config.sql
20260913100000_assignment_instructions.sql
20260924010000_academic_traceability_hardening.sql
20260924020000_student_player_mode.sql
20260924030000_classes_rls_activation.sql
20260924040000_solo_progress_integrity.sql
20260924050000_student_onboarding_integrity.sql
20260924060000_canonical_class_enrollments.sql
20260924070000_enrollment_identity_consistency.sql
20260924080000_reject_conflicting_enrollment_identity.sql
```

`node scripts/verify-db.mjs` confirmo `mergedFeatureSchema` todo `true`, todas las
RPC, todas las comprobaciones de seguridad `true`, cero membresias con perfiles
duplicados y cero perfiles de roster sin vincular.

---

## 5. Verificaciones realizadas (ultima pasada)

| Superficie    | Comando                                                                                | Resultado                                                                                                       |
| ------------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Backend       | `pytest -q tests/unit`                                                                 | **52 passed**                                                                                                   |
| Backend lint  | `ruff check` + `black --check` en archivos tocados                                     | OK                                                                                                              |
| Astro         | `npm run check`                                                                        | 0 errores, 0 warnings, 2 hints preexistentes                                                                    |
| Astro         | `npm run build`                                                                        | OK (adapter `@astrojs/vercel`)                                                                                  |
| Flutter       | `flutter test`                                                                         | **42 passed** (una primera corrida post-merge fallo en un test aleatorio; aislado y en la segunda corrida paso) |
| Flutter       | `flutter analyze --no-pub`                                                             | No issues found                                                                                                 |
| Flutter       | `flutter build apk --release --no-pub --dart-define-from-file=dart_defines.local.json` | OK, 153.8s                                                                                                      |
| Android       | APK final                                                                              | 60,896,578 bytes; SHA-256 `EC44887565BCF2A86316F5235AFBC6F345DD30DD76C5D916ACC590D988620A19`                    |
| Android firma | `apksigner verify --print-certs`                                                       | Certificado debug igual a `v0.7.1`                                                                              |
| Supabase      | `node scripts/migrate.mjs` + `node scripts/verify-db.mjs`                              | 11 migraciones, esquema mergeado y seguridad todo `true`                                                        |
| Railway       | deployment `4e42ff80-21d8-4f44-abfa-af4487c5178e`                                      | `SUCCESS`; `/openapi.json` HTTP 200                                                                             |
| GitHub        | Release `v0.8.0`                                                                       | Publicado, asset `battlegraf-android.apk` verificado                                                            |
| Vercel        | deployment `battlegraf-landing-n03gmf97h-luisrz1s-projects.vercel.app`                 | `Ready`; alias `battlegraf-landing-five.vercel.app` verificado                                                  |

Nota: el lint global de Ruff (`ruff check src`) sigue mostrando **83 hallazgos
heredados** en modulos ajenos a este trabajo; por eso se valida por archivo.

---

## 6. Bloqueos y trampas conocidas

### 6.1 Symlinks de Flutter en Windows

Con `webview_flutter` (traido por el remoto), el flujo normal `flutter analyze` /
`flutter build apk` puede fallar al resolver los plugins con:

```
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

El APK y el analyze se completaron usando `--no-pub` (con dependencias ya resueltas):
`flutter analyze --no-pub` y `flutter build apk --release --no-pub ...` pasan.
Si se requiere `flutter pub get` o resolver plugins desde cero, habilitar **Modo
Desarrollador** en Windows (`start ms-settings:developers`) o usar una maquina con
symlink support. El usuario actual no era administrador y el proveedor GUI Orca
no estaba disponible; no se cambio el ajuste global del sistema.

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

## 7. Cierre realizado

Todos los pasos de publicacion se completaron el 2026-09-30. Los resultados
definitivos se registran a continuacion; no repetir releases ni migraciones para
esta version.

### Paso 1 — Migraciones

Completado: las 11 migraciones listadas en la seccion 4 estan aplicadas y verificadas.

### Paso 2 — APK `0.8.0+11`

Completado. Se uso `--no-pub` para evitar la necesidad de resolver symlinks de
plugins de escritorio en Windows. Toolchain (no esta en PATH):

```powershell
$env:JAVA_HOME="D:\flutter_setup\jdk17\jdk-17.0.20.1+1"
$env:ANDROID_HOME="D:\flutter_setup\android-sdk"; $env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:GRADLE_USER_HOME="D:\flutter_setup\gradle"
$env:PATH="D:\flutter_setup\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:PATH"
cd D:\proyectos_battlegraph\landing-real\mobile
flutter analyze --no-pub
flutter test
flutter build apk --release --no-pub --dart-define-from-file=dart_defines.local.json
```

Artefacto: `mobile/build/app/outputs/flutter-apk/app-release.apk`.

### Paso 3 — Metadatos de descarga

Completado; `src/lib/downloads.ts` coincide con el APK y asset publicados:
`58.1 MB`, SHA-256 `EC44887565BCF2A86316F5235AFBC6F345DD30DD76C5D916ACC590D988620A19`.

```powershell
$apk = "mobile\build\app\outputs\flutter-apk\app-release.apk"
(Get-Item -LiteralPath $apk).Length          # bytes
Get-FileHash -Algorithm SHA256 -LiteralPath $apk
```

### Paso 4 — Commit y push

Completado: digest en `a641691`; rama `integracion-google` sincronizada con
`origin` junto con este informe de cierre.

### Paso 5 — GitHub Release `v0.8.0` (completado)

Publicado y verificado: <https://github.com/LuisRz1/battlegraf/releases/tag/v0.8.0>.
El tag apunta a `integracion-google`, esta marcado latest y lleva el asset
`battlegraf-android.apk` (60,896,578 bytes; digest verificado). Se creo como
borrador, se subio el APK via GitHub upload API con el nombre exacto y se publico.
**No volver a crear el release.**
El flujo de creacion de abajo es historico y no debe repetirse. Se publico con
target `integracion-google`; `gh release view` confirma `isDraft=false`.

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

### Paso 6 — Railway (completado)

Deployment `4e42ff80-21d8-4f44-abfa-af4487c5178e` figura `SUCCESS`; se hizo
`railway up` desde la raiz `landing-real` para que el `rootDirectory=backend` del
servicio resuelva correctamente. El primer intento desde `backend/` fallo al
buscar `backend/backend`; no cambio el deployment activo. OpenAPI HTTP 200.

### Paso 7 — Deploy Vercel + alias `five` (completado)

Deployment: `battlegraf-landing-n03gmf97h-luisrz1s-projects.vercel.app`.
Alias `battlegraf-landing-five.vercel.app` reasignado via API al deployment
`dpl_CFbb887vems1z9RxmgvqLYXUoe98`; la comprobacion publica respondio HTTP 200.
La CLI de alias dio `User not found`; se uso el token local con la API, sin
imprimirlo. No hay pasos Vercel pendientes para este release; los comandos de
deploy y reasignacion que siguen son solo referencia historica.

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

### Paso 8 — Verificacion post-deploy (completado)

- `https://battlegraf-landing-five.vercel.app` carga y el link `v0.8.0` del APK descarga.
- `https://battlegraf-production.up.railway.app/openapi.json` responde 200.
- Pruebas automatizadas Flutter/backend y verificadores de base pasan. Queda
  recomendada una prueba manual en dispositivo real de registro, vinculo, clase,
  campana y cosmetico.

---

## 8. Pendientes de producto (fuera de este release)

- Firma Android de produccion (keystore) para tiendas.
- iOS.
- Revisar que `report_staff` del remoto no duplique conteos al combinar IDB con
  el alcance por rol (validar con datos reales de un colegio).
- Reducir los 83 avisos heredados de Ruff si se quiere lint global limpio.
- Proveedor IA "Luna" intermitente (500): hay fallback local, no bloquea.

---

## 9. Archivos clave

- `supabase/migrations/20260913*` y `20260924*` (11) + `scripts/verify-db.mjs` (compuerta).
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
- [x] Migraciones `20260913*` y `20260924*` aplicadas/verificadas (11 total)
- [x] Backend 52 tests + Ruff/Black scoped
- [x] Astro check/build
- [x] Flutter test 42/42
- [x] Flutter analyze --no-pub sin issues
- [x] APK release `0.8.0+11` reconstruido; size/digest actualizados
- [x] Fix del bug `recursos.ts` heredado del remoto
- [x] Push `integracion-google` con codigo, merge y handoff
- [x] GitHub Release `v0.8.0` (target `integracion-google`, asset `battlegraf-android.apk`)
- [x] Railway deploy `4e42ff80-21d8-4f44-abfa-af4487c5178e` y OpenAPI HTTP 200
- [x] Vercel production deploy + alias `battlegraf-landing-five.vercel.app`
