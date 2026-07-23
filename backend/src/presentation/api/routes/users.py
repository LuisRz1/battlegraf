"""User management endpoints."""

import csv
from io import StringIO
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import User
from src.domain.enums import Role
from src.infrastructure.auth.password import hash_password
from src.infrastructure.auth.permissions import (
    require_director,
    require_role,
    require_teacher,
)
from src.infrastructure.database.repositories import SQLAlchemySectionRepository, SQLAlchemyUserRepository
from src.infrastructure.database.session import get_db
from src.presentation.api.dependencies import get_user_repo
from src.presentation.schemas.requests.auth_requests import (
    CreateStaffRequest,
    CreateUserRequest,
)
from src.presentation.schemas.responses.auth_responses import UserResponse

router = APIRouter(prefix="/users", tags=["Users"])


def _user_response(user) -> UserResponse:
    return UserResponse(
        id=str(user.id),
        username=user.username,
        email=user.email,
        full_name=user.full_name,
        role=user.role.value,
        school_id=str(user.school_id) if user.school_id else None,
        section_id=str(user.section_id) if user.section_id else None,
        xp=user.xp,
    )


def _require_school_match(payload: dict, school_id: UUID | None) -> None:
    """Ensure the current user can only manage users within their own school."""
    user_school_id = payload.get("school_id")
    if user_school_id is not None and str(school_id) != user_school_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="School mismatch")


@router.get("/school/{school_id}", response_model=list[UserResponse])
async def list_school_users(
    school_id: str,
    role: str | None = Query(None, description="Filter by role label"),
    repo=Depends(get_user_repo),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR, Role.STUDENT)),
):
    _require_school_match(payload, UUID(school_id))
    users = await repo.list_by_school(UUID(school_id))
    if role:
        users = [u for u in users if u.role.value == role]
    return [_user_response(u) for u in users]


@router.get("/section/{section_id}", response_model=list[UserResponse])
async def list_section_users(
    section_id: str,
    repo=Depends(get_user_repo),
    payload=Depends(require_teacher),
):
    users = await repo.list_by_section(UUID(section_id))
    return [_user_response(u) for u in users]


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    body: CreateUserRequest,
    session: AsyncSession = Depends(get_db),
    _=Depends(require_director),
):
    repo = SQLAlchemyUserRepository(session)
    existing = await repo.get_by_username(body.username)
    if existing:
        raise HTTPException(status_code=400, detail="El usuario ya existe")

    try:
        role = Role(body.role)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="Rol invalido") from exc

    user = User(
        username=body.username,
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=body.full_name,
        role=role,
        school_id=UUID(body.school_id) if body.school_id else None,
        section_id=UUID(body.section_id) if body.section_id else None,
    )
    created = await repo.create(user)
    await session.commit()
    return _user_response(created)


@router.post("/staff", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_staff_user(
    body: CreateStaffRequest,
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_director),
):
    """Register a professor or tutor for the director's school."""
    repo = SQLAlchemyUserRepository(session)
    existing = await repo.get_by_username(body.username)
    if existing:
        raise HTTPException(status_code=400, detail="El usuario ya existe")

    if body.role not in {Role.PROFESSOR.value, Role.TUTOR.value}:
        raise HTTPException(status_code=400, detail="Rol invalido: solo professor o tutor")

    director_school_id = payload.get("school_id")
    if not director_school_id and not body.school_id:
        raise HTTPException(status_code=400, detail="Se requiere school_id")

    school_id = UUID(body.school_id) if body.school_id else UUID(director_school_id)

    user = User(
        username=body.username,
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=body.full_name,
        role=Role(body.role),
        school_id=school_id,
        section_id=UUID(body.section_id) if body.section_id else None,
    )
    created = await repo.create(user)
    await session.commit()
    return _user_response(created)


@router.post("/{school_id}/students/csv", status_code=status.HTTP_201_CREATED)
async def bulk_create_students_csv(
    school_id: str,
    section_id: str,
    file: UploadFile = File(...),
    session: AsyncSession = Depends(get_db),
    payload=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)),
):
    """Bulk import students from a CSV file with columns: username,full_name,password."""
    section_repo = SQLAlchemySectionRepository(session)
    section = await section_repo.get_by_id(UUID(section_id))
    if not section or section.school_id != UUID(school_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Seccion no encontrada")

    _require_school_match(payload, UUID(school_id))

    content = await file.read()
    try:
        text = content.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise HTTPException(status_code=400, detail="El archivo CSV debe ser UTF-8") from exc

    reader = csv.DictReader(StringIO(text))
    expected = {"username", "full_name", "password"}
    if not reader.fieldnames or not expected.issubset(set(reader.fieldnames)):
        raise HTTPException(
            status_code=400,
            detail="CSV invalido. Encabezados requeridos: username,full_name,password",
        )

    user_repo = SQLAlchemyUserRepository(session)
    created_count = 0
    errors: list[dict] = []

    for index, row in enumerate(reader, start=1):
        username = (row.get("username") or "").strip()
        full_name = (row.get("full_name") or "").strip()
        password = (row.get("password") or "").strip()
        email = (row.get("email") or f"{username}@battlegraf.local").strip()

        if not username or not full_name or not password:
            errors.append({"row": index, "detail": "Campos vacios"})
            continue

        existing = await user_repo.get_by_username(username)
        if existing:
            errors.append({"row": index, "detail": f"Usuario '{username}' ya existe"})
            continue

        user = User(
            username=username,
            email=email,
            hashed_password=hash_password(password),
            full_name=full_name,
            role=Role.STUDENT,
            school_id=UUID(school_id),
            section_id=UUID(section_id),
        )
        await user_repo.create(user)
        created_count += 1

    await session.commit()

    return {
        "created": created_count,
        "errors": errors,
        "section_id": section_id,
    }
