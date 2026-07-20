"""Authentication endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import School, User
from src.domain.enums import Role
from src.infrastructure.auth.permissions import get_current_user
from src.infrastructure.auth.jwt_handler import create_access_token
from src.infrastructure.auth.password import hash_password, verify_password
from src.infrastructure.database.repositories import SQLAlchemySchoolRepository, SQLAlchemyUserRepository
from src.infrastructure.database.session import get_db
from src.presentation.schemas.requests.auth_requests import CreateDirectorRequest
from src.presentation.schemas.responses.auth_responses import TokenResponse, UserResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    session: AsyncSession = Depends(get_db),
):
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_username(form_data.username)
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales incorrectas")

    token = create_access_token(user.id, user.role, user.school_id, user.section_id)
    return TokenResponse(access_token=token, token_type="bearer")


@router.post("/register/director", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def register_director(
    body: CreateDirectorRequest,
    session: AsyncSession = Depends(get_db),
):
    user_repo = SQLAlchemyUserRepository(session)
    existing = await user_repo.get_by_username(body.username)
    if existing:
        raise HTTPException(status_code=400, detail="El nombre de usuario ya existe")

    school_repo = SQLAlchemySchoolRepository(session)
    school = School(name=body.school_name, region=body.region)
    created_school = await school_repo.create(school)

    user = User(
        username=body.username,
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=body.full_name,
        role=Role.DIRECTOR,
        school_id=created_school.id,
    )
    created_user = await user_repo.create(user)
    await session.commit()

    return UserResponse(
        id=str(created_user.id),
        username=created_user.username,
        email=created_user.email,
        full_name=created_user.full_name,
        role=created_user.role.value,
        school_id=str(created_user.school_id) if created_user.school_id else None,
        section_id=None,
        xp=created_user.xp,
    )


@router.get("/me", response_model=UserResponse)
async def me(
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    user_repo = SQLAlchemyUserRepository(session)
    user = await user_repo.get_by_id(UUID(payload["sub"]))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

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
