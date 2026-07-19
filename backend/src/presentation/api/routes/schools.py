"""Endpoints de colegios."""

from fastapi import APIRouter

router = APIRouter(prefix="/schools")


@router.get("")
async def list_schools():
    """Lista todos los colegios registrados."""
    return {"schools": [], "total": 0}


@router.post("")
async def create_school():
    """Crea un nuevo colegio."""
    return {"message": "Colegio creado (stub)", "school_id": "00000000-0000-0000-0000-000000000000"}
