"""Configuration settings for BattleGraph backend."""

import os
from functools import lru_cache

from pydantic import model_validator
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
    
    cors_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8000",
        "https://battlegraf-landing-five.vercel.app",
    ]
    cors_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

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

    # Supabase (usada por el router Panel y el endpoint público del juego)
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    supabase_secret_key: str = ""  # formato nuevo sb_secret_... (preferido)
    supabase_jwt_secret: str = ""
    supabase_jwks_url: str = ""
    
    @model_validator(mode='after')
    def validate_production_settings(self) -> 'Settings':
        if self.app_env == "production" and "dev-secret" in self.jwt_secret_key:
            raise ValueError("JWT secret key must not contain 'dev-secret' in production")
        return self

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
