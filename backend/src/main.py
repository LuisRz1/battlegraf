"""BattleGraf API — Aplicacion FastAPI principal."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .presentation.api.routes import health, schools


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manejo del ciclo de vida de la aplicacion."""
    # Startup
    yield
    # Shutdown


def create_app() -> FastAPI:
    """Fabrica de la aplicacion FastAPI con todas las rutas y middlewares."""

    app = FastAPI(
        title="BattleGraf API",
        description="Plataforma escolar multiplayer de aprendizaje gamificado por grafos",
        version="0.1.0",
        lifespan=lifespan,
    )

    # CORS — permisivo en desarrollo
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Registrar rutas
    app.include_router(health.router, tags=["Health"])
    app.include_router(schools.router, prefix="/api/v1", tags=["Schools"])

    return app


app = create_app()
