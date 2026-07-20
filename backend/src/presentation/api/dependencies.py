"""FastAPI dependencies for repositories and services."""

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.interfaces.repositories import SchoolRepository, SectionRepository, UserRepository
from src.infrastructure.database.repositories import (
    SQLAlchemySchoolRepository,
    SQLAlchemySectionRepository,
    SQLAlchemyUserRepository,
)
from src.infrastructure.database.session import get_db


def get_school_repo(session: AsyncSession = Depends(get_db)) -> SchoolRepository:
    return SQLAlchemySchoolRepository(session)


def get_section_repo(session: AsyncSession = Depends(get_db)) -> SectionRepository:
    return SQLAlchemySectionRepository(session)


def get_user_repo(session: AsyncSession = Depends(get_db)) -> UserRepository:
    return SQLAlchemyUserRepository(session)
