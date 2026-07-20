"""School and section management endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import Section, User
from src.domain.enums import Role
from src.infrastructure.auth.password import hash_password
from src.infrastructure.auth.permissions import require_role
from src.infrastructure.database.session import get_db
from src.presentation.api.dependencies import get_school_repo, get_section_repo, get_user_repo
from src.presentation.schemas.requests.school_requests import (
    BulkCreateStudentsRequest,
    CreateSchoolRequest,
    CreateSectionsRequest,
)
from src.presentation.schemas.responses.school_responses import SchoolResponse, SectionResponse

router = APIRouter(prefix="/schools", tags=["Schools"])


def _school_response(model) -> SchoolResponse:
    return SchoolResponse(
        id=str(model.id),
        name=model.name,
        region=model.region,
        level=model.level,
        is_active=model.is_active,
        created_at=model.created_at,
    )


def _section_response(model) -> SectionResponse:
    return SectionResponse(
        id=str(model.id),
        school_id=str(model.school_id),
        name=model.name,
        grade=model.grade,
        level=model.level,
        tutor_id=str(model.tutor_id) if model.tutor_id else None,
        is_active=model.is_active,
        created_at=model.created_at,
    )


@router.get("", response_model=list[SchoolResponse])
async def list_schools(
    repo=Depends(get_school_repo),
    _=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    schools = await repo.list_all()
    return [_school_response(s) for s in schools]


@router.post("", response_model=SchoolResponse, status_code=status.HTTP_201_CREATED)
async def create_school(
    body: CreateSchoolRequest,
    repo=Depends(get_school_repo),
    _=Depends(require_role(Role.DIRECTOR)),
):
    from src.domain.entities import School

    school = School(name=body.name, region=body.region, level=body.level)
    created = await repo.create(school)
    return _school_response(created)


@router.get("/{school_id}/sections", response_model=list[SectionResponse])
async def list_sections(
    school_id: str,
    repo=Depends(get_section_repo),
    _=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)),
):
    sections = await repo.list_by_school(UUID(school_id))
    return [_section_response(s) for s in sections]


@router.post("/{school_id}/sections", response_model=list[SectionResponse], status_code=status.HTTP_201_CREATED)
async def create_sections(
    school_id: str,
    body: CreateSectionsRequest,
    repo=Depends(get_section_repo),
    session: AsyncSession = Depends(get_db),
    _=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)),
):
    created = []
    for section_data in body.sections:
        section = Section(
            school_id=UUID(school_id),
            name=section_data.name,
            grade=section_data.grade,
            level=section_data.level,
            tutor_id=UUID(section_data.tutor_id) if section_data.tutor_id else None,
        )
        created.append(await repo.create(section))
    await session.commit()
    return [_section_response(s) for s in created]


@router.post("/{school_id}/students/bulk", status_code=status.HTTP_201_CREATED)
async def bulk_create_students(
    school_id: str,
    body: BulkCreateStudentsRequest,
    session: AsyncSession = Depends(get_db),
    _=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)),
):
    """Create multiple students in one section."""
    from src.infrastructure.database.repositories import SQLAlchemySectionRepository, SQLAlchemyUserRepository

    user_repo = SQLAlchemyUserRepository(session)
    section_repo = SQLAlchemySectionRepository(session)
    section = await section_repo.get_by_id(UUID(body.section_id))
    if not section or section.school_id != UUID(school_id):
        raise HTTPException(status_code=404, detail="Seccion no encontrada")

    created = []
    for student_data in body.students:
        user = User(
            username=student_data.username,
            email=student_data.email or f"{student_data.username}@battlegraf.local",
            hashed_password=hash_password(student_data.password),
            full_name=student_data.full_name,
            role=Role.STUDENT,
            school_id=UUID(school_id),
            section_id=UUID(body.section_id),
        )
        created.append(await user_repo.create(user))

    await session.commit()
    return {"created": len(created)}
