"""Authentication endpoints."""

import uuid as uuid_mod
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import School, User
from src.domain.enums import Role
from src.infrastructure.auth.code_generator import generate_school_code
from src.infrastructure.auth.jwt_handler import create_access_token
from src.infrastructure.auth.password import hash_password, verify_password
from src.infrastructure.auth.permissions import get_current_user
from src.infrastructure.database.repositories import (
    SQLAlchemySchoolRepository,
    SQLAlchemyUserRepository,
)
from src.infrastructure.database.repositories.membership_repo import (
    SQLAlchemyMembershipRepository,
    SQLAlchemySchoolCodeRepository,
)
from src.infrastructure.database.session import get_db
from src.presentation.schemas.requests.auth_requests import (
    CreateDirectorRequest,
    RegisterProfessorRequest,
    RegisterStudentRequest,
)
from src.presentation.schemas.responses.auth_responses import (
    TokenResponse,
    UserResponse,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    session: AsyncSession = Depends(get_db),
):
    repo = SQLAlchemyUserRepository(session)
    user = await repo.get_by_username(form_data.username)
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Credenciales incorrectas"
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La cuenta se encuentra desactivada",
        )

    token = create_access_token(user.id, user.role, user.school_id, user.section_id)
    return TokenResponse(access_token=token, token_type="bearer")


@router.post(
    "/register/director",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
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

    from src.application.school.academic_years import get_or_create_academic_year

    await get_or_create_academic_year(session, created_school.id)

    user = User(
        username=body.username,
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=body.full_name,
        last_name=body.last_name,
        phone=body.phone,
        role=Role.DIRECTOR,
        school_id=created_school.id,
    )
    created_user = await user_repo.create(user)

    # Generar código de colegio y membresía
    code_repo = SQLAlchemySchoolCodeRepository(session)
    code = await generate_school_code(session)
    await code_repo.create(created_school.id, code)

    mem_repo = SQLAlchemyMembershipRepository(session)
    await mem_repo.create(created_user.id, created_school.id, Role.DIRECTOR.value)

    await session.commit()

    return UserResponse(
        id=str(created_user.id),
        username=created_user.username,
        email=created_user.email,
        full_name=created_user.full_name,
        last_name=created_user.last_name,
        phone=created_user.phone,
        role=created_user.role.value,
        school_id=str(created_user.school_id) if created_user.school_id else None,
        school_code=code,
        section_id=None,
        xp=created_user.xp,
    )


@router.post(
    "/register/professor",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_professor(
    body: RegisterProfessorRequest,
    session: AsyncSession = Depends(get_db),
):
    code_repo = SQLAlchemySchoolCodeRepository(session)
    school_code = await code_repo.get_by_code(body.school_code)
    if not school_code:
        raise HTTPException(status_code=400, detail="Código de colegio inválido")

    user_repo = SQLAlchemyUserRepository(session)
    username = f"{body.first_name[:3]}{body.last_name[:3]}".lower()
    existing = await user_repo.get_by_username(username)
    if existing:
        username = f"{username}{str(uuid_mod.uuid4())[:4]}"

    user = User(
        username=username,
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=f"{body.first_name} {body.last_name}",
        last_name=body.last_name,
        phone=body.phone,
        role=Role.PROFESSOR,
        school_id=school_code.school_id,
    )
    created_user = await user_repo.create(user)

    mem_repo = SQLAlchemyMembershipRepository(session)
    await mem_repo.create(created_user.id, school_code.school_id, Role.PROFESSOR.value)

    await session.commit()

    return UserResponse(
        id=str(created_user.id),
        username=created_user.username,
        email=created_user.email,
        full_name=created_user.full_name,
        last_name=created_user.last_name,
        phone=created_user.phone,
        role=created_user.role.value,
        school_id=str(created_user.school_id),
        school_code=body.school_code,
        section_id=None,
        xp=created_user.xp,
    )


@router.post(
    "/register/student",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_student(
    body: RegisterStudentRequest,
    session: AsyncSession = Depends(get_db),
):
    code_repo = SQLAlchemySchoolCodeRepository(session)
    school_code = await code_repo.get_by_code(body.school_code)
    if not school_code:
        raise HTTPException(status_code=400, detail="Código de colegio inválido")

    user_repo = SQLAlchemyUserRepository(session)
    username = f"{body.first_name[:3]}{body.last_name[:3]}".lower()
    existing = await user_repo.get_by_username(username)
    if existing:
        username = f"{username}{str(uuid_mod.uuid4())[:4]}"

    user = User(
        username=username,
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=f"{body.first_name} {body.last_name}",
        last_name=body.last_name,
        phone=body.phone,
        role=Role.STUDENT,
        school_id=school_code.school_id,
    )
    created_user = await user_repo.create(user)

    mem_repo = SQLAlchemyMembershipRepository(session)
    await mem_repo.create(created_user.id, school_code.school_id, Role.STUDENT.value)

    await session.commit()

    return UserResponse(
        id=str(created_user.id),
        username=created_user.username,
        email=created_user.email,
        full_name=created_user.full_name,
        last_name=created_user.last_name,
        phone=created_user.phone,
        role=created_user.role.value,
        school_id=str(created_user.school_id),
        school_code=body.school_code,
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado"
        )

    return UserResponse(
        id=str(user.id),
        username=user.username,
        email=user.email,
        full_name=user.full_name,
        last_name=getattr(user, "last_name", ""),
        phone=getattr(user, "phone", ""),
        role=user.role.value,
        school_id=str(user.school_id) if user.school_id else None,
        section_id=str(user.section_id) if user.section_id else None,
        xp=user.xp,
    )
