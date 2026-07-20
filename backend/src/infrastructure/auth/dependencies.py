"""Authentication and authorization dependencies for FastAPI."""

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.interfaces.repositories import UserRepository
from src.infrastructure.auth.permissions import (
    get_current_user,
    get_user_id,
    require_director,
    require_director_or_subdirector,
    require_professor,
    require_role,
    require_school_admin,
    require_student,
    require_subdirector,
    require_teacher,
    require_tutor,
)
from src.infrastructure.database.repositories import SQLAlchemyUserRepository
from src.infrastructure.database.session import get_db


def get_user_repo(session: AsyncSession = Depends(get_db)) -> UserRepository:
    """Factory for the SQLAlchemy user repository."""
    return SQLAlchemyUserRepository(session)


__all__ = [
    "get_current_user",
    "get_user_id",
    "get_user_repo",
    "require_director",
    "require_director_or_subdirector",
    "require_professor",
    "require_role",
    "require_school_admin",
    "require_student",
    "require_subdirector",
    "require_teacher",
    "require_tutor",
]
