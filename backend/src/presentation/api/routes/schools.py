"""School and section management endpoints."""

import uuid
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import Section, User
from src.domain.enums import Role
from src.infrastructure.auth.password import hash_password
from src.infrastructure.auth.permissions import require_role
from src.infrastructure.database.session import get_db
from src.presentation.api.dependencies import get_school_repo, get_section_repo
from src.presentation.schemas.requests.school_requests import (
    AcademicYearCreateRequest,
    AcademicYearUpdateRequest,
    BulkCreateStudentsRequest,
    CreateSchoolRequest,
    CreateSectionsRequest,
    UpdateSchoolRequest,
    UpdateSectionRequest,
)
from src.presentation.schemas.responses.school_responses import (
    AcademicYearResponse,
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
        name=model.name or "",
        grade=model.grade,
        level=model.level,
        academic_year_id=str(model.academic_year_id) if model.academic_year_id else None,
        section_label=model.section_label,
        code=model.code,
        display_name=model.display_name,
        tutor_name=model.tutor_name,
        max_students=model.max_students or 30,
        status=model.status or "active",
        tutor_id=str(model.tutor_id) if model.tutor_id else None,
        is_active=model.is_active,
        created_at=model.created_at,
    )


def _academic_year_response(model) -> AcademicYearResponse:
    return AcademicYearResponse(
        id=str(model.id),
        school_id=str(model.school_id),
        label=model.label,
        starts_on=model.starts_on,
        ends_on=model.ends_on,
        is_active=model.is_active,
        created_at=model.created_at,
        updated_at=getattr(model, "updated_at", model.created_at),
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


@router.get("/{school_id}", response_model=SchoolResponse)
async def get_school(
    school_id: str,
    repo=Depends(get_school_repo),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    school = await repo.get_by_id(UUID(school_id))
    if school is None:
        raise HTTPException(status_code=404, detail="Escuela no encontrada")
    return _school_response(school)


@router.patch("/{school_id}", response_model=SchoolResponse)
async def update_school(
    school_id: str,
    body: UpdateSchoolRequest,
    repo=Depends(get_school_repo),
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    from src.domain.entities import School

    current = await repo.get_by_id(UUID(school_id))
    if current is None:
        raise HTTPException(status_code=404, detail="Escuela no encontrada")

    updated = School(
        id=current.id,
        name=body.name if body.name is not None else current.name,
        region=body.region if body.region is not None else current.region,
        level=body.level if body.level is not None else current.level,
        is_active=body.is_active if body.is_active is not None else current.is_active,
        created_at=current.created_at,
    )
    saved = await repo.update(updated)
    await session.commit()
    return _school_response(saved)


@router.delete("/{school_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_school(
    school_id: str,
    repo=Depends(get_school_repo),
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    school = await repo.get_by_id(UUID(school_id))
    if school is None:
        raise HTTPException(status_code=404, detail="Escuela no encontrada")
    await repo.delete(school.id)
    await session.commit()


@router.get("/{school_id}/academic-years", response_model=list[AcademicYearResponse])
async def list_academic_years(
    school_id: str,
    session: AsyncSession = Depends(get_db),
    payload=Depends(
        require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)
    ),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    from src.infrastructure.database.models import AcademicYearModel

    result = await session.execute(
        select(AcademicYearModel)
        .where(AcademicYearModel.school_id == UUID(school_id))
        .order_by(AcademicYearModel.label.desc())
    )
    return [_academic_year_response(m) for m in result.scalars().all()]


@router.post(
    "/{school_id}/academic-years",
    response_model=AcademicYearResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_academic_year(
    school_id: str,
    body: AcademicYearCreateRequest,
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR)),
    response: Response = None,
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    from src.infrastructure.database.models import AcademicYearModel
    from sqlalchemy.exc import IntegrityError

    # Idempotente: si ya existe un anio con la misma etiqueta para el colegio,
    # devolverlo (200) en lugar de fallar. El registro de director auto-crea
    # el anio lectivo activo; este POST cubre el caso de re-envio o edicion UI.
    existing = await session.execute(
        select(AcademicYearModel).where(
            AcademicYearModel.school_id == UUID(school_id),
            AcademicYearModel.label == body.label,
        )
    )
    current = existing.scalar_one_or_none()
    if current is not None:
        response.status_code = status.HTTP_200_OK
        return _academic_year_response(current)

    model = AcademicYearModel(
        id=uuid.uuid4(),
        school_id=UUID(school_id),
        label=body.label,
        starts_on=datetime.fromisoformat(body.starts_on) if body.starts_on else None,
        ends_on=datetime.fromisoformat(body.ends_on) if body.ends_on else None,
        is_active=body.is_active,
    )
    session.add(model)
    try:
        await session.commit()
    except IntegrityError:
        # Raza posible si dos peticiones crean el mismo anio a la vez
        await session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"El anio academico '{body.label}' ya existe para este colegio",
        )
    await session.refresh(model)
    return _academic_year_response(model)


@router.patch(
    "/{school_id}/academic-years/{year_id}", response_model=AcademicYearResponse
)
async def update_academic_year(
    school_id: str,
    year_id: str,
    body: AcademicYearUpdateRequest,
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    from src.infrastructure.database.models import AcademicYearModel

    result = await session.execute(
        select(AcademicYearModel).where(AcademicYearModel.id == UUID(year_id))
    )
    model = result.scalar_one_or_none()
    if model is None or str(model.school_id) != school_id:
        raise HTTPException(status_code=404, detail="Anio academico no encontrado")
    if body.label is not None:
        model.label = body.label
    if body.starts_on is not None:
        model.starts_on = datetime.fromisoformat(body.starts_on)
    if body.ends_on is not None:
        model.ends_on = datetime.fromisoformat(body.ends_on)
    if body.is_active is not None:
        model.is_active = body.is_active
    await session.commit()
    await session.refresh(model)
    return _academic_year_response(model)


@router.delete(
    "/{school_id}/academic-years/{year_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def delete_academic_year(
    school_id: str,
    year_id: str,
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    from src.infrastructure.database.models import AcademicYearModel

    result = await session.execute(
        select(AcademicYearModel).where(AcademicYearModel.id == UUID(year_id))
    )
    model = result.scalar_one_or_none()
    if model is None or str(model.school_id) != school_id:
        raise HTTPException(status_code=404, detail="Anio academico no encontrado")
    await session.delete(model)
    await session.commit()


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


@router.get("/{school_id}/sections/{section_id}", response_model=SectionResponse)
async def get_section(
    school_id: str,
    section_id: str,
    repo=Depends(get_section_repo),
    payload=Depends(
        require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)
    ),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    section = await repo.get_by_id(UUID(section_id))
    if section is None or str(section.school_id) != school_id:
        raise HTTPException(status_code=404, detail="Seccion no encontrada")
    return _section_response(section)


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


@router.patch("/{school_id}/sections/{section_id}", response_model=SectionResponse)
async def update_section(
    school_id: str,
    section_id: str,
    body: UpdateSectionRequest,
    repo=Depends(get_section_repo),
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    current = await repo.get_by_id(UUID(section_id))
    if current is None or str(current.school_id) != school_id:
        raise HTTPException(status_code=404, detail="Seccion no encontrada")

    name = body.name if body.name is not None else current.name
    grade = body.grade if body.grade is not None else current.grade
    level = body.level if body.level is not None else current.level
    section_label = body.section_label if body.section_label is not None else current.section_label
    code = body.code if body.code is not None else current.code
    display_name = body.display_name if body.display_name is not None else current.display_name
    tutor_name = body.tutor_name if body.tutor_name is not None else current.tutor_name
    max_students = body.max_students if body.max_students is not None else current.max_students
    status_v = body.status if body.status is not None else current.status
    tutor_id = body.tutor_id if body.tutor_id is not None else current.tutor_id
    ay_id = body.academic_year_id if body.academic_year_id else current.academic_year_id

    # Si vienen cambios semanticos y no hay code, regenerar el codigo
    new_code = code
    if code is None and (body.name is not None or body.grade is not None or body.level is not None):
        existing_codes = {s.code for s in await repo.list_by_school(UUID(school_id)) if s.code}
        _ = _build_section_meta(
            type("D", (), {"name": name or "A", "grade": grade or "1", "level": level or "primary"})(),
            existing_codes,
        )
        # use the returned meta for consistency
        meta = _build_section_meta(
            type("D", (), {"name": section_label or name or "A", "grade": grade or "1", "level": level or "primary"})(),
            existing_codes,
        )
        new_code = meta["code"]
        section_label = meta["section_label"]
        display_name = meta["display_name"]

    updated = Section(
        id=current.id,
        school_id=current.school_id,
        name=name,
        grade=grade,
        level=level,
        academic_year_id=ay_id,
        section_label=section_label,
        code=new_code,
        display_name=display_name,
        tutor_name=tutor_name,
        max_students=max_students,
        status=status_v,
        tutor_id=tutor_id,
        is_active=body.is_active if body.is_active is not None else current.is_active,
        created_at=current.created_at,
    )
    saved = await repo.update(updated)
    await session.commit()
    return _section_response(saved)


@router.delete(
    "/{school_id}/sections/{section_id}", status_code=status.HTTP_204_NO_CONTENT
)
async def delete_section(
    school_id: str,
    section_id: str,
    repo=Depends(get_section_repo),
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    if payload.get("school_id") != school_id:
        raise HTTPException(status_code=403, detail="School mismatch")
    section = await repo.get_by_id(UUID(section_id))
    if section is None or str(section.school_id) != school_id:
        raise HTTPException(status_code=404, detail="Seccion no encontrada")
    await repo.delete(section.id)
    await session.commit()


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
