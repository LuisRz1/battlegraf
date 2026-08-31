"""SQLAlchemy implementations of school repositories."""

import uuid
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import School, Section
from src.domain.interfaces.repositories import SchoolRepository, SectionRepository
from src.infrastructure.database.models import SchoolModel, SectionModel


def _to_school_entity(model: SchoolModel) -> School:
    return School(
        id=model.id,
        name=model.name,
        region=model.region,
        level=model.level,
        is_active=model.is_active,
        created_at=model.created_at,
    )


def _to_section_entity(model: SectionModel) -> Section:
    return Section(
        id=model.id,
        school_id=model.school_id,
        name=model.name or "",
        grade=model.grade,
        level=model.level,
        academic_year_id=model.academic_year_id,
        section_label=model.section_label or "",
        code=model.code or "",
        display_name=model.display_name or "",
        tutor_name=model.tutor_name,
        max_students=model.max_students,
        status=model.status,
        tutor_id=model.tutor_id,
        is_active=model.is_active,
        created_at=model.created_at,
    )


class SQLAlchemySchoolRepository(SchoolRepository):
    """Repository for School aggregate root."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: SchoolModel) -> School:
        return _to_school_entity(model)

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

    async def update(self, school: School) -> School:
        result = await self._session.execute(
            select(SchoolModel).where(SchoolModel.id == school.id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("School not found")
        model.name = school.name if school.name else model.name
        model.region = school.region if school.region is not None else model.region
        model.level = school.level if school.level else model.level
        model.is_active = school.is_active
        await self._session.flush()
        return self._to_entity(model)

    async def delete(self, school_id: uuid.UUID) -> None:
        result = await self._session.execute(
            select(SchoolModel).where(SchoolModel.id == school_id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("School not found")
        model.is_active = False
        await self._session.flush()


class SQLAlchemySectionRepository(SectionRepository):
    """Repository for Section aggregate."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: SectionModel) -> Section:
        return _to_section_entity(model)

    async def create(self, section: Section) -> Section:
        model = SectionModel(
            id=section.id,
            school_id=section.school_id,
            name=section.name or None,
            grade=section.grade,
            level=section.level,
            academic_year_id=section.academic_year_id,
            section_label=section.section_label,
            code=section.code,
            display_name=section.display_name,
            tutor_name=section.tutor_name,
            max_students=section.max_students,
            status=section.status,
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
        from sqlalchemy.orm import selectinload

        result = await self._session.execute(
            select(SectionModel)
            .where(SectionModel.school_id == school_id)
            .where(SectionModel.is_active.is_(True))
            .options(selectinload(SectionModel.users))
        )
        return [self._to_entity(m) for m in result.scalars().all()]

    async def assign_tutor(
        self, section_id: uuid.UUID, tutor_id: uuid.UUID
    ) -> Section | None:
        result = await self._session.execute(
            select(SectionModel).where(SectionModel.id == section_id)
        )
        model = result.scalar_one_or_none()
        if not model:
            return None
        model.tutor_id = tutor_id
        await self._session.flush()
        return self._to_entity(model)

    async def update(self, section: Section) -> Section:
        result = await self._session.execute(
            select(SectionModel).where(SectionModel.id == section.id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("Section not found")
        if section.name is not None:
            model.name = section.name or None
        if section.grade is not None:
            model.grade = section.grade
        if section.level is not None:
            model.level = section.level
        if section.section_label is not None:
            model.section_label = section.section_label
        if section.code is not None:
            model.code = section.code
        if section.display_name is not None:
            model.display_name = section.display_name
        if section.tutor_name is not None:
            model.tutor_name = section.tutor_name
        if section.max_students is not None:
            model.max_students = section.max_students
        if section.status is not None:
            model.status = section.status
        if section.tutor_id is not None:
            model.tutor_id = section.tutor_id
        if section.academic_year_id is not None:
            model.academic_year_id = section.academic_year_id
        model.is_active = section.is_active
        await self._session.flush()
        return self._to_entity(model)

    async def delete(self, section_id: uuid.UUID) -> None:
        result = await self._session.execute(
            select(SectionModel).where(SectionModel.id == section_id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("Section not found")
        model.is_active = False
        await self._session.flush()
