"""SQLAlchemy implementation of user repository."""

import uuid
from typing import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import User
from src.domain.enums import Role
from src.domain.interfaces.repositories import UserRepository
from src.infrastructure.database.models import UserModel


class SQLAlchemyUserRepository(UserRepository):
    """Repository for User entities."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    def _to_entity(self, model: UserModel) -> User:
        return User(
            id=model.id,
            username=model.username,
            email=model.email,
            hashed_password=model.hashed_password,
            full_name=model.full_name,
            role=Role(model.role),
            school_id=model.school_id,
            section_id=model.section_id,
            xp=model.xp,
            rank_id=model.rank_id,
            clan_id=model.clan_id,
            is_active=model.is_active,
            created_at=model.created_at,
        )

    async def create(self, user: User) -> User:
        model = UserModel(
            id=user.id,
            username=user.username,
            email=user.email,
            hashed_password=user.hashed_password,
            full_name=user.full_name,
            role=user.role.value,
            school_id=user.school_id,
            section_id=user.section_id,
            xp=user.xp,
            rank_id=user.rank_id,
            clan_id=user.clan_id,
            is_active=user.is_active,
        )
        self._session.add(model)
        await self._session.flush()
        return self._to_entity(model)

    async def get_by_id(self, user_id: uuid.UUID) -> User | None:
        result = await self._session.execute(
            select(UserModel).where(UserModel.id == user_id)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def get_by_username(self, username: str) -> User | None:
        result = await self._session.execute(
            select(UserModel).where(UserModel.username == username)
        )
        model = result.scalar_one_or_none()
        return self._to_entity(model) if model else None

    async def list_by_school(self, school_id: uuid.UUID) -> Sequence[User]:
        result = await self._session.execute(
            select(UserModel)
            .where(UserModel.school_id == school_id)
            .where(UserModel.is_active.is_(True))
            .order_by(UserModel.role.asc(), UserModel.username.asc())
        )
        return [self._to_entity(m) for m in result.scalars().all()]

    async def list_by_section(self, section_id: uuid.UUID) -> Sequence[User]:
        result = await self._session.execute(
            select(UserModel)
            .where(UserModel.section_id == section_id)
            .where(UserModel.is_active.is_(True))
        )
        return [self._to_entity(m) for m in result.scalars().all()]

    async def update(self, user: User) -> User:
        result = await self._session.execute(
            select(UserModel).where(UserModel.id == user.id)
        )
        model = result.scalar_one_or_none()
        if not model:
            raise ValueError("User not found")
        model.xp = user.xp
        model.rank_id = user.rank_id
        model.clan_id = user.clan_id
        model.section_id = user.section_id
        model.is_active = user.is_active
        await self._session.flush()
        return self._to_entity(model)
