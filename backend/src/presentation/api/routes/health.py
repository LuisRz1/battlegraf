"""Endpoints de health check."""

from fastapi import APIRouter

router = APIRouter(prefix="/health")


@router.get("")
async def health_check():
    return {"status": "ok", "service": "battlegraf-api", "version": "0.2.0"}
