"""BattleGraf API \u2014 Aplicacion FastAPI principal."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.infrastructure.database.init_db import init_db
from src.presentation.api.routes import (
    auth,
    battles,
    health,
    progression,
    questions,
    schools,
    tasks,
    users,
)
from src.presentation.api.websocket import battle_ws


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manejo del ciclo de vida de la aplicacion."""
    await init_db()
    yield


def create_app() -> FastAPI:
    """Fabrica de la aplicacion FastAPI con todas las rutas y middlewares."""

    app = FastAPI(
        title="BattleGraf API",
        description="Plataforma escolar multiplayer de aprendizaje gamificado por grafos",
        version="0.3.0",
        lifespan=lifespan,
    )

    # CORS \u2014 permisivo en desarrollo
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Registrar rutas
    app.include_router(health.router, prefix="/api/v1", tags=["Health"])
    app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
    app.include_router(schools.router, prefix="/api/v1", tags=["Schools"])
    app.include_router(users.router, prefix="/api/v1", tags=["Users"])
    app.include_router(questions.router, prefix="/api/v1", tags=["Questions"])
    app.include_router(battles.router, prefix="/api/v1", tags=["Battles"])
    app.include_router(tasks.router, prefix="/api/v1", tags=["Tasks"])
    app.include_router(
        progression.router,
        prefix="/api/v1",
        tags=["Progression"],
    )
    app.include_router(battle_ws.router, tags=["WebSocket"])

    return app


app = create_app()
