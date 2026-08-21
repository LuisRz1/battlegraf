"""Repositories for classes and enrollments."""

import uuid
from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from src.infrastructure.database.models.membership import ClassModel, ClassEnrollmentModel


class SQLAlchemyClassRepository:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_by_code(self, code: str) -> ClassModel | None:
        stmt = select(ClassModel).where(
            ClassModel.code == code, ClassModel.is_active == True
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_professor(
        self, professor_id: uuid.UUID
    ) -> Sequence[ClassModel]:
        stmt = select(ClassModel).where(
            ClassModel.professor_id == professor_id, ClassModel.is_active == True
        )
        result = await self._session.execute(stmt)
        return result.scalars().all()

    async def get_by_id(self, class_id: uuid.UUID) -> ClassModel | None:
        stmt = select(ClassModel).where(
            ClassModel.id == class_id, ClassModel.is_active == True
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(
        self,
        professor_id: uuid.UUID,
        school_id: uuid.UUID,
        name: str,
        code: str,
        subject: str | None = None,
    ) -> ClassModel:
        model = ClassModel(
            professor_id=professor_id,
            school_id=school_id,
            name=name,
            code=code,
            subject=subject,
        )
        self._session.add(model)
        await self._session.flush()
        return model


class SQLAlchemyEnrollmentRepository:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_by_class(
        self, class_id: uuid.UUID
    ) -> Sequence[ClassEnrollmentModel]:
        stmt = select(ClassEnrollmentModel).where(
            ClassEnrollmentModel.class_id == class_id,
            ClassEnrollmentModel.is_active == True,
        )
        result = await self._session.execute(stmt)
        return result.scalars().all()

    async def get_by_student(
        self, student_id: uuid.UUID
    ) -> Sequence[ClassEnrollmentModel]:
        stmt = select(ClassEnrollmentModel).where(
            ClassEnrollmentModel.student_id == student_id,
            ClassEnrollmentModel.is_active == True,
        )
        result = await self._session.execute(stmt)
        return result.scalars().all()

    async def enroll_student(
        self, class_id: uuid.UUID, student_id: uuid.UUID
    ) -> ClassEnrollmentModel:
        model = ClassEnrollmentModel(class_id=class_id, student_id=student_id)
        self._session.add(model)
        await self._session.flush()
        return model

    async def remove_student(
        self, class_id: uuid.UUID, student_id: uuid.UUID
    ) -> None:
        stmt = select(ClassEnrollmentModel).where(
            ClassEnrollmentModel.class_id == class_id,
            ClassEnrollmentModel.student_id == student_id,
            ClassEnrollmentModel.is_active == True,
        )
        result = await self._session.execute(stmt)
        model = result.scalar_one_or_none()
        if model:
            model.is_active = False
            await self._session.flush()
