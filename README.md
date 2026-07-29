# BattleGraf

Plataforma escolar de aprendizaje gamificado en la que los estudiantes avanzan
por un grafo de materias mediante preguntas, tareas y batallas por turnos.

## Estado real

El repositorio contiene un **MVP técnico parcial**, no un producto terminado ni
listo para producción. El flujo base de autenticación, banco de preguntas,
batalla 1 contra 1, tareas y progresión ya tiene implementación y pruebas, pero
siguen pendientes el onboarding escolar completo, la administración docente en
Flutter, las competencias entre secciones, los dashboards, el control de tiempo
oficial del servidor y el despliegue productivo.

La evaluación detallada y la trazabilidad con los requerimientos están en
[`AUDITORIA_ESTADO_2026-07-27.md`](AUDITORIA_ESTADO_2026-07-27.md).

## Componentes

| Componente | Tecnología | Estado |
|---|---|---|
| API | Python 3.11, FastAPI, SQLAlchemy | Funcional con pruebas |
| Base de datos | SQLite local, PostgreSQL en Docker | Migración inicial disponible |
| Tiempo real | WebSocket autenticado | Parcial; falta reconexión robusta |
| Procesamiento asíncrono | Celery y Redis | Infraestructura base, sin flujo IA en cola |
| Archivos | Almacenamiento local validado | MinIO aún no integrado al servicio |
| IA | OpenAI con fallback local | Generación básica; falta gobierno de costos |
| Aplicación | Flutter para Android/iOS | MVP de estudiante parcial |
| Infraestructura | Docker Compose y GitHub Actions | Configurada; falta prueba de despliegue |

## Inicio local

### Backend

```powershell
cd D:\battlegraf\backend
Copy-Item .env.example .env
uv sync --extra dev
uv run alembic upgrade head
uv run uvicorn src.main:app --reload --port 8000
```

La API queda disponible en `http://127.0.0.1:8000` y la documentación OpenAPI
en `http://127.0.0.1:8000/docs`.

Si ya existe un `battlegraf.db` de una versión anterior, la migración conserva
los datos y agrega las columnas de la fase 5. Antes de migrar datos importantes,
se recomienda guardar una copia del archivo.

### Aplicación Flutter

```powershell
cd D:\battlegraf\mobile
flutter pub get
flutter run
```

Android Emulator usa por defecto `http://10.0.2.2:8000/api/v1`. Para un
dispositivo físico u otro host:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api/v1
```

### Entorno Docker

```powershell
cd D:\battlegraf
docker compose up --build
```

El servicio de API ejecuta `alembic upgrade head` antes de iniciar. Se requiere
una instalación de Docker que incluya Compose v2.

## Validación

```powershell
cd D:\battlegraf\backend
uv run black --check src tests alembic
uv run ruff check src tests alembic
uv run mypy src
uv run pytest -q

cd D:\battlegraf\mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## Documentación funcional

El vault de Obsidian está en:

`C:\Users\edwin\Documents\Minedu-Hackathon\Obsidian`

Las fuentes se interpretan en este orden:

1. `06 - Gestion\Decisiones.md`
2. `07 - Producto\00 - Mapa funcional.md` y el manual funcional
3. `04 - Prototipo\Documento maestro de requerimientos.md`
4. El código y las pruebas para determinar qué está realmente implementado

`BattleGraf_Documento_Completo.md` se conserva como especificación integral;
la presencia de una función en ese documento no significa que ya exista en el
código.
