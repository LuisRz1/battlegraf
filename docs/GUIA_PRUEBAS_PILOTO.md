# Guía de pruebas piloto de BattleGraph

## Qué está listo para probar

La misma cuenta institucional de Supabase funciona en el panel web y en la
aplicación Flutter. El backend aplica el alcance del rol incluso cuando consulta
con credenciales administrativas.

- Director, subdirector y coordinador: resumen de todo el colegio.
- Tutor: únicamente los alumnos de sus secciones asignadas.
- Profesor: alumnos de las secciones donde dicta un curso activo.
- Alumno: únicamente su propia ficha.

La ficha académica contiene cursos y docentes, asistencia, tardanzas, faltas,
notas, promedio, observaciones, tareas entregadas, clases, XP, rango y batallas.

## Preparar el entorno local

1. Copiar `.env.example` como `.env` y completar sólo en el equipo local.
2. Iniciar el backend:

   ```powershell
   cd backend
   uv sync --extra dev
   uv run uvicorn src.main:app --reload --port 8000
   ```

3. Iniciar el panel web:

   ```powershell
   bun install
   bun run dev
   ```

4. Abrir `http://localhost:4321/iniciar-sesion`.

La base compartida se actualiza con `bun run db:migrate` usando
`POSTGRES_URL_NON_POOLING`. Nunca se debe guardar esa URL en Git.

## Cargar información de demostración

1. Ingresar como director.
2. Abrir **Seguimiento académico**.
3. Si el colegio aún no tiene datos académicos, pulsar **Crear datos de prueba**.
4. Confirmar que aparecen notas y asistencia para los alumnos existentes.

Los registros creados por este botón están marcados como demostración. La
operación es idempotente: repetirla no duplica la información.

## Prueba de director

1. Revisar las métricas de asistencia, promedio, alertas y seguimientos.
2. Abrir la ficha de un alumno y comprobar todos sus bloques.
3. Registrar asistencia para uno o varios alumnos.
4. Crear una evaluación indicando curso, sección, periodo, puntaje y peso.
5. Registrar una nota y retroalimentación.
6. Crear una observación con categoría, visibilidad y fecha de seguimiento.
7. Volver al resumen y confirmar que promedio y riesgo se recalculan.

## Prueba de tutor o profesor

1. Ingresar con una cuenta vinculada a `staff_profiles`.
2. Confirmar que sólo aparecen sus alumnos asignados.
3. Repetir asistencia, nota y observación.
4. Intentar abrir el identificador de un alumno ajeno: la API debe responder 403.

Para que el alcance funcione, el tutor debe estar asignado en
`sections.tutor_staff_id`; el profesor debe figurar en `subject_teachers` y la
clase activa debe tener curso y sección.

## Prueba de alumno

1. Ingresar con una cuenta cuya membresía tenga rol `student` y esté vinculada a
   `student_profiles.membership_id`.
2. Abrir **Mi avance**.
3. Confirmar que sólo aparece su información.
4. Confirmar que no aparecen usuarios, auditoría, configuración ni banco de
   preguntas.

## Aplicación Flutter: Android

Crear `mobile/dart_defines.local.json` a partir del archivo de ejemplo y ejecutar:

```powershell
cd mobile
flutter pub get
flutter run --dart-define-from-file=dart_defines.local.json
```

Para generar el instalador:

```powershell
flutter build apk --debug --dart-define-from-file=dart_defines.local.json
```

El APK queda en `mobile/build/app/outputs/flutter-apk/app-debug.apk`.

El APK de pruebas entregado está firmado con el certificado Android Debug y fue
instalado en un emulador Android API 30. En esa instalación se validaron el
ícono, el splash, el acceso del alumno, el lobby por rol y la carga de la clase
`PIL5AMAT`. Para publicar en Play Store se debe crear un keystore de producción;
el certificado debug es únicamente para pruebas internas.

### Recorrido completo de la interfaz móvil

1. Iniciar sesión y confirmar que el lobby sólo muestra los módulos permitidos
   para el rol.
2. Abrir **Mi perfil** y revisar identidad, institución y plan.
3. En **Centro** revisar métricas y accesos rápidos.
4. Como dirección, recorrer colegio, personas, secciones, cursos, clases,
   contenidos, tareas, batallas, progreso y actividad.
5. Crear y editar un registro piloto; comprobar que el listado se actualiza sin
   cerrar la pantalla. Eliminarlo y aceptar el diálogo de confirmación.
6. En contenidos, crear material y pregunta, aprobar la pregunta y revisar su
   estado.
7. En seguimiento, registrar asistencia, crear evaluación, guardar nota y añadir
   una observación desde la ficha del alumno.
8. Como alumno, usar **Unirme a una clase** con el código entregado por el
   docente y confirmar que no aparecen acciones administrativas.
9. Abrir **Batallas**, iniciar **Jugar vs BOT** y completar por lo menos un turno
   correcto y uno incorrecto.
10. Cerrar sesión y repetir con tutor, docente y alumno para comprobar el alcance
    de cada cuenta.

Las cuentas piloto usan los correos `piloto.director@battlegraf.app`,
`piloto.tutor@battlegraf.app`, `piloto.docente@battlegraf.app` y
`piloto.alumno@battlegraf.app`. La contraseña temporal se entrega por un canal
seguro y no se guarda en Git.

## Aplicación Flutter: iOS

El código, el identificador `io.battlegraf.app` y el enlace de retorno de
autenticación ya están preparados. El AppIcon y el splash usan la marca oficial
de BattleGraph y el mínimo configurado es iOS 13. En un Mac:

```bash
cd mobile
flutter pub get
open ios/Runner.xcworkspace
```

En Xcode se debe seleccionar el equipo de Apple Developer, configurar firma y
ejecutar en un iPhone o simulador. Supabase debe permitir el redirect
`io.battlegraf.app://login-callback`.

## Verificación automática

```powershell
cd backend
uv run ruff check src\presentation\api\routes\panel.py --ignore E501
uv run pytest -q

cd ..
bun run check
bun run build

cd mobile
flutter analyze
flutter test
```

## Criterios de aceptación

- No se muestran alumnos fuera del alcance del rol.
- Las escrituras académicas aparecen inmediatamente en web y móvil.
- El promedio se normaliza a porcentaje aunque una evaluación use otra escala.
- Una asistencia menor a 75 %, un promedio menor a 60 % o seguimientos abiertos
  generan alertas visibles.
- Los datos académicos reales y los de demostración se pueden distinguir en la
  base.
- Ninguna service key, contraseña, token de Railway ni clave de OpenAI se incluye
  en el repositorio o en el APK.
