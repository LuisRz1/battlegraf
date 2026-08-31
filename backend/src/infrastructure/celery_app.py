"""Celery application used by background workers."""

from celery import Celery

from src.infrastructure.config import get_settings

settings = get_settings()

app = Celery(
    "battlegraf",
    broker=settings.celery_broker_url,
    backend=settings.redis_url,
)
app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="America/Bogota",
    enable_utc=True,
)
