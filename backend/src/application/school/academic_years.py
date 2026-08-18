"""Servicio de anios academicos (periodo lectivo por colegio)."""

import uuid
from datetime import date, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.infrastructure.database.models import AcademicYearModel


async def get_or_create_academic_year(
    session: AsyncSession, school_id: uuid.UUID
) -> AcademicYearModel:
    """Devuelve el anio activo del colegio; lo crea (periodo marzo-dic) si no existe."""
    result = await session.execute(
        select(AcademicYearModel)
        .where(AcademicYearModel.school_id == school_id)
        .where(AcademicYearModel.is_active.is_(True))
        .limit(1)
    )
    year_model = result.scalar_one_or_none()
    if year_model:
        return year_model

    year = date.today().year
    model = AcademicYearModel(
        id=uuid.uuid4(),
        school_id=school_id,
        label=str(year),
        starts_on=datetime(year, 3, 1),
        ends_on=datetime(year, 12, 20),
        is_active=True,
    )
    session.add(model)
    await session.flush()
    return model