"""Shared test fixtures for the BattleGraf backend."""

import asyncio
import os
from collections.abc import AsyncGenerator
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from src.domain.entities import School, Section, User
from src.domain.enums import Role
from src.infrastructure.auth.jwt_handler import create_access_token
from src.infrastructure.auth.password import hash_password
from src.infrastructure.database.models import Base
from src.infrastructure.database.repositories import SQLAlchemySchoolRepository, SQLAlchemySectionRepository, SQLAlchemyUserRepository
from src.infrastructure.database.session import get_db
from src.main import app, create_app


@pytest.fixture(scope="session")
def event_loop():
    """Provide a shared event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def db_engine():
    """Create an in-memory async SQLite engine for testing."""
    database_url = "sqlite+aiosqlite:///:memory:"
    engine = create_async_engine(database_url, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def db_session(db_engine) -> AsyncGenerator[AsyncSession, None]:
    """Yield a fresh database session for each test."""
    AsyncSessionLocal = async_sessionmaker(
        db_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False,
    )
    async with AsyncSessionLocal() as session:
        yield session
        await session.rollback()


@pytest.fixture
def test_client(db_session) -> TestClient:
    """Build a FastAPI TestClient with the test session injected."""
    test_app = create_app()

    async def override_get_db() -> AsyncGenerator[AsyncSession, None]:
        yield db_session

    test_app.dependency_overrides[get_db] = override_get_db
    return TestClient(test_app)


@pytest.fixture
async def school_repo(db_session):
    return SQLAlchemySchoolRepository(db_session)


@pytest.fixture
async def section_repo(db_session):
    return SQLAlchemySectionRepository(db_session)


@pytest.fixture
async def user_repo(db_session):
    return SQLAlchemyUserRepository(db_session)


@pytest.fixture
async def sample_school(school_repo):
    school = School(name="Colegio Test", region="Lima", level="both")
    return await school_repo.create(school)


@pytest.fixture
async def sample_section(section_repo, sample_school):
    section = Section(
        school_id=sample_school.id,
        name="5to A",
        grade=5,
        level="primary",
    )
    return await section_repo.create(section)


@pytest.fixture
async def director(db_session, sample_school):
    repo = SQLAlchemyUserRepository(db_session)
    user = User(
        username="director_test",
        email="director@battlegraf.local",
        hashed_password=hash_password("password123"),
        full_name="Director Test",
        role=Role.DIRECTOR,
        school_id=sample_school.id,
    )
    created = await repo.create(user)
    await db_session.commit()
    return created


@pytest.fixture
def director_token(director):
    return create_access_token(director.id, director.role)


@pytest.fixture
async def professor(db_session, sample_school):
    repo = SQLAlchemyUserRepository(db_session)
    user = User(
        username="professor_test",
        email="professor@battlegraf.local",
        hashed_password=hash_password("password123"),
        full_name="Professor Test",
        role=Role.PROFESSOR,
        school_id=sample_school.id,
    )
    created = await repo.create(user)
    await db_session.commit()
    return created


@pytest.fixture
def professor_token(professor):
    return create_access_token(professor.id, professor.role)


@pytest.fixture
async def tutor(db_session, sample_school):
    repo = SQLAlchemyUserRepository(db_session)
    user = User(
        username="tutor_test",
        email="tutor@battlegraf.local",
        hashed_password=hash_password("password123"),
        full_name="Tutor Test",
        role=Role.TUTOR,
        school_id=sample_school.id,
    )
    created = await repo.create(user)
    await db_session.commit()
    return created


@pytest.fixture
def tutor_token(tutor):
    return create_access_token(tutor.id, tutor.role)
