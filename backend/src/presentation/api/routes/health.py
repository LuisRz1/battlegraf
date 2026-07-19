"""Endpoints de health check."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health_check():
    return {"status": "ok", "service": "battlegraf-api", "version": "0.1.0"}
