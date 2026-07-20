"""SQLAlchemy implementations of school repositories."""

import uuid
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import School, Section
from src.domain.interfaces.repositories import SchoolRepository, SectionRepository
from src.infrastructure.database.models import SchoolModel, SectionModel


class SQLAlchemySchoolRepository(SchoolRepository):
    """Repository for School aggregate root."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: SchoolModel) -> School:
        return School(
            id=model.id,
            name=model.name,
            region=model.region,
            level=model.level,
            is_active=model.is_active,
            created_at=model.created_at,
        )

    async def create(self, school: School) -> School:
        model = SchoolModel(
            id=school.id,
            name=school.name,
            region=school.region,
            level=school.level,
            is_active=school.is_active,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, school_id: uuid.UUID) -> School | None:
        result = await self._session.execute(
            select(SchoolModel).where(SchoolModel.id == school_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_all(self) -> Sequence[School]:
        result = await self._session.execute(
            select(SchoolModel).where(SchoolModel.is_active.is_(True))
        )
        return [self._to_entity(m) for m in result.scalars().all()]


class SQLAlchemySectionRepository(SectionRepository):
    """Repository for Section aggregate."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: SectionModel) -> Section:
        return Section(
            id=model.id,
            school_id=model.school_id,
            name=model.name,
            grade=model.grade,
            level=model.level,
            tutor_id=model.tutor_id,
            is_active=model.is_active,
            created_at=model.created_at,
        )

    async def create(self, section: Section) -> Section:
        model = SectionModel(
            id=section.id,
            school_id=section.school_id,
            name=section.name,
            grade=section.grade,
            level=section.level,
            tutor_id=section.tutor_id,
            is_active=section.is_active,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, section_id: uuid.UUID) -> Section | None:
        result = await self._session.execute(
            select(SectionModel).where(SectionModel.id == section_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_by_school(self, school_id: uuid.UUID) -> Sequence[Section]:
        result = await self._session.execute(
            select(SectionModel)
            .where(SectionModel.school_id == school_id)
            .where(SectionModel.is_active.is_(True))
        )
        return [self._to_entity(m) for m in result.scalars().all()]
