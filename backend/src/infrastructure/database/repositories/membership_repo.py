"""Repositories for memberships and school codes."""

import uuid
from datetime import datetime, timezone
from typing import Sequence
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from src.infrastructure.database.models.membership import SchoolCodeModel, SchoolMembershipModel


class SQLAlchemySchoolCodeRepository:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_by_code(self, code: str) -> SchoolCodeModel | None:
        stmt = select(SchoolCodeModel).where(
            SchoolCodeModel.code == code, SchoolCodeModel.is_active == True
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def create(self, school_id: uuid.UUID, code: str) -> SchoolCodeModel:
        model = SchoolCodeModel(school_id=school_id, code=code)
        self._session.add(model)
        await self._session.flush()
        return model


class SQLAlchemyMembershipRepository:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def get_by_user_and_school(
        self, user_id: uuid.UUID, school_id: uuid.UUID
    ) -> SchoolMembershipModel | None:
        stmt = select(SchoolMembershipModel).where(
            SchoolMembershipModel.user_id == user_id,
            SchoolMembershipModel.school_id == school_id,
            SchoolMembershipModel.is_active == True,
        )
        result = await self._session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_all_by_user(
        self, user_id: uuid.UUID
    ) -> Sequence[SchoolMembershipModel]:
        stmt = select(SchoolMembershipModel).where(
            SchoolMembershipModel.user_id == user_id
        )
        result = await self._session.execute(stmt)
        return result.scalars().all()

    async def create(
        self, user_id: uuid.UUID, school_id: uuid.UUID, role: str
    ) -> SchoolMembershipModel:
        model = SchoolMembershipModel(
            user_id=user_id, school_id=school_id, role=role
        )
        self._session.add(model)
        await self._session.flush()
        return model

    async def deactivate(self, membership_id: uuid.UUID) -> None:
        model = await self._session.get(SchoolMembershipModel, membership_id)
        if model:
            model.is_active = False
            model.can_view_students = False
            model.left_at = datetime.now(timezone.utc)
            await self._session.flush()
