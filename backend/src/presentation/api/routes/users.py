"""User management endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import User
from src.domain.enums import Role
from src.infrastructure.auth.dependencies import get_current_user, require_role
from src.infrastructure.auth.password import hash_password
from src.infrastructure.database.session import get_db
from src.presentation.api.dependencies import get_user_repo
from src.presentation.schemas.requests.auth_requests import CreateUserRequest
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


@router.get("/school/{school_id}", response_model=list[UserResponse])
async def list_school_users(
    school_id: str,
    repo=Depends(get_user_repo),
    _=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)),
):
    users = await repo.list_by_school(UUID(school_id))
    return [_user_response(u) for u in users]


@router.get("/section/{section_id}", response_model=list[UserResponse])
async def list_section_users(
    section_id: str,
    repo=Depends(get_user_repo),
    _=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)),
):
    users = await repo.list_by_section(UUID(section_id))
    return [_user_response(u) for u in users]


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(
    body: CreateUserRequest,
    session: AsyncSession = Depends(get_db),
    _=Depends(require_role(Role.DIRECTOR, Role.SUBDIRECTOR)),
):
    from src.infrastructure.database.repositories import SQLAlchemyUserRepository

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
        section_id=UUID(body.section_id) if body.section_id else None,
    )
    created = await repo.create(user)
    await session.commit()
    return _user_response(created)
