# BattleGraf

Plataforma escolar multiplayer de aprendizaje gamificado por grafos. Convierte la practica curricular en batallas estrategicas sobre un tablero de nodos, donde cada respuesta correcta conquista territorio y cada partida genera datos utiles para el docente.

## Stack

| Capa | Tecnologia |
|------|-----------|
| Backend API | Python 3.11 + FastAPI |
| Base de datos | PostgreSQL 16 + Redis |
| Cola de tareas | Celery + Redis |
| IA | LangChain + OpenAI |
| Almacenamiento | MinIO (S3-compatible) |
| Mobile | Flutter 3.x (iOS + Android) |
| Infra | Docker Compose, GitHub Actions |

## Arquitectura

Clean Architecture con MVC en la capa de presentacion:

```
Domain (entidades, value objects, interfaces)
  -> Application (casos de uso)
    -> Infrastructure (DB, IA, cache, auth)
      -> Presentation (FastAPI / Flutter MVC)
```

## Estructura

```
battlegraf/
├── backend/         # API Python + FastAPI
│   ├── src/
│   │   ├── domain/
│   │   ├── application/
│   │   ├── infrastructure/
│   │   └── presentation/
│   └── tests/
├── mobile/          # App Flutter multiplataforma
└── docs/            # Documentacion (referencia al vault Obsidian)
```

## Inicio rapido

```bash
# Backend
cd backend
docker compose up -d        # PostgreSQL + Redis + MinIO
cp .env.example .env         # Configurar variables
uv sync                      # Instalar dependencias
alembic upgrade head         # Migraciones
uvicorn src.main:app --reload

# Mobile
cd mobile
flutter pub get
flutter run
```

## Documentacion completa

La documentacion detallada (requerimientos, arquitectura, plan de implementacion) se encuentra en el vault de Obsidian:

`C:\Users\edwin\Documents\Minedu-Hackathon\Obsidian\04 - Prototipo\`

- Documento maestro de requerimientos
- Arquitectura del sistema
- Plan de implementacion
- Roadmap
