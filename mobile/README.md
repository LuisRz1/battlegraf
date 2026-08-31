# BattleGraph Mobile

Aplicación Flutter de BattleGraph para Android, iOS y web. Comparte las cuentas
institucionales de Supabase y consume el centro de mando desplegado en Railway.

## Funciones

- acceso por correo o Google;
- navegación y datos limitados por rol (dirección, tutor, docente y alumno);
- centro de mando, perfil, colegio, personas, secciones, cursos y clases;
- materiales, banco de preguntas, tareas, batallas, rangos, clanes y auditoría;
- seguimiento académico con asistencia, notas, observaciones y ficha integral;
- creación, edición, aprobación y eliminación según permisos;
- modo de batalla contra BOT disponible sin conexión.

## Configuración local

Copiar `dart_defines.example.json` como `dart_defines.local.json` y completar
únicamente valores públicos:

```json
{
  "API_BASE_URL": "https://battlegraf-production.up.railway.app/api/v1",
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "TU_CLAVE_PUBLICA",
  "AUTH_CALLBACK_URL": "io.battlegraf.app://login-callback"
}
```

No colocar claves `service_role`, secretos JWT, contraseñas ni tokens de Railway
en Flutter: cualquier valor incluido con `--dart-define` puede extraerse del
binario.

## Ejecutar y verificar

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=dart_defines.local.json
flutter build apk --debug --dart-define-from-file=dart_defines.local.json
flutter build apk --release --dart-define-from-file=dart_defines.local.json
```

El APK debug es para pruebas internas. Las firmas finales de Android e iOS deben
configurarse con los certificados de la organización; iOS se compila en
macOS/Xcode seleccionando el equipo de Apple Developer. Consulta
[ARCHITECTURE.md](ARCHITECTURE.md) para la estructura Clean/Hexagonal y
`../docs/GUIA_PRUEBAS_PILOTO.md` para el recorrido funcional.
