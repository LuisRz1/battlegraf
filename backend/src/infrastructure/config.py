"""Configuration settings for BattleGraph backend."""

import os
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables and .env files."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    debug: bool = True
    log_level: str = "DEBUG"

    database_url: str = "sqlite+aiosqlite:///./battlegraf.db"
    database_url_sync: str = "sqlite:///./battlegraf.db"

    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"

    jwt_secret_key: str = "dev-secret-change-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 1440

    # Agente IA generador de preguntas (compatible con la API de OpenAI)
    # openai_base_url vacio = endpoint oficial de OpenAI
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    openai_base_url: str = ""

    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "materials"
    minio_secure: bool = False

    @property
    def storage_path(self) -> str:
        """Local path for file storage when MinIO is not configured."""
        path = os.environ.get("BATTLEGRAF_STORAGE_PATH", "./storage")
        os.makedirs(path, exist_ok=True)
        return path


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
