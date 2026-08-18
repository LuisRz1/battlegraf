"""School and section management endpoints."""

import uuid
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import Section, User
from src.domain.enums import Role
from src.infrastructure.auth.password import hash_password
from src.infrastructure.auth.permissions import require_role
from src.infrastructure.database.session import get_db
from src.presentation.api.dependencies import get_school_repo, get_section_repo
from src.presentation.schemas.requests.school_requests import (
    BulkCreateStudentsRequest,
    CreateSchoolRequest,
    CreateSectionsRequest,
)
from src.presentation.schemas.responses.school_responses import (
    SchoolResponse,
    SectionResponse,
)

router = APIRouter(prefix="/schools", tags=["Schools"])


def _level_code(level: str) -> str:
    """Abreviatura de nivel para el code de seccion (P/S)."""
    lowered = (level or "").lower()
    if lowered.startswith("prim"):
        return "P"
    if lowered.startswith("sec"):
        return "S"
    return "?"


def _grade_number(grade: str) -> str:
    """Extrae el numero del grado ('1ro' -> '1', '5' -> '5', fallback al texto)."""
    digits = "".join(ch for ch in (grade or "") if ch.isdigit())
    return digits or (grade or "0").strip()


def _build_section_meta(section_data, existing_codes: set[str]) -> dict:
    """Genera code unico (por school), section_label y display_name tipo landing."""
    label = (section_data.name or "A").strip() or "A"
    grade = (section_data.grade or "1").strip()
    level = section_data.level or "primary"
    lvl_code = _level_code(level)
    gnum = _grade_number(grade)
    base = f"{gnum}{lvl_code}-{label}"
    code = base
    n = 2
    while code in existing_codes:
        code = f"{base}-{n}"
        n += 1
    existing_codes.add(code)
    level_title = "Primaria" if lvl_code == "P" else "Secundaria" if lvl_code == "S" else level
    return {
        "code": code,
        "section_label": label,
        "display_name": f"{grade}. {level_title} {label}",
    }


async def _get_or_create_academic_year(
    session: AsyncSession, school_id: UUID
) -> UUID:
    """Devuelve el anio activo del colegio; lo crea (2026) si no existe."""
    from src.application.school.academic_years import get_or_create_academic_year

    return (await get_or_create_academic_year(session, school_id)).id


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
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    school_id = payload.get("school_id")
    if school_id is None:
        return []
    school = await repo.get_by_id(UUID(school_id))
    return [_school_response(school)] if school else []


@router.post("", response_model=SchoolResponse, status_code=status.HTTP_201_CREATED)
async def create_school(
    body: CreateSchoolRequest,
    repo=Depends(get_school_repo),
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR)),
):
    from src.domain.entities import School

    if payload.get("school_id"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Director already belongs to a school",
        )
    school = School(name=body.name, region=body.region, level=body.level)
    created = await repo.create(school)
    await _get_or_create_academic_year(session, created.id)
    await session.commit()
    return _school_response(created)


@router.get("/{school_id}/sections", response_model=list[SectionResponse])
async def list_sections(
    school_id: str,
    repo=Depends(get_section_repo),
    payload=Depends(
        require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)
    ),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    sections = await repo.list_by_school(UUID(school_id))
    return [_section_response(s) for s in sections]


@router.post(
    "/{school_id}/sections",
    response_model=list[SectionResponse],
    status_code=status.HTTP_201_CREATED,
)
async def create_sections(
    school_id: str,
    body: CreateSectionsRequest,
    repo=Depends(get_section_repo),
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    academic_year_id = await _get_or_create_academic_year(session, UUID(school_id))
    existing = await repo.list_by_school(UUID(school_id))
    existing_codes = {s.code for s in existing if s.code}
    created = []
    for section_data in body.sections:
        meta = _build_section_meta(section_data, existing_codes)
        section = Section(
            school_id=UUID(school_id),
            name=section_data.name,
            grade=section_data.grade,
            level=section_data.level,
            academic_year_id=academic_year_id,
            section_label=meta["section_label"],
            code=meta["code"],
            display_name=meta["display_name"],
            tutor_name="Tutor por asignar" if not section_data.tutor_id else None,
            max_students=30,
            status="active",
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
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)),
):
    """Create multiple students in one section."""
    from src.infrastructure.database.repositories import (
        SQLAlchemySectionRepository,
        SQLAlchemyUserRepository,
    )

    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
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