"""Role-based access control dependencies for FastAPI."""

from collections.abc import Sequence
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from src.domain.enums import Role
from src.infrastructure.auth.jwt_handler import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    """Validate the JWT token and return the decoded payload."""
    payload = decode_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload


def get_user_id(token: str = Depends(oauth2_scheme)) -> UUID:
    """Extract the current user id from the JWT token."""
    payload = get_current_user(token)
    return UUID(payload["sub"])


def require_role(*roles: Role):
    """Dependency factory that requires the current user to have one of the given roles."""
    allowed_roles: Sequence[Role] = roles

    def dependency(payload: dict = Depends(get_current_user)) -> dict:
        try:
            user_role = Role(payload["role"])
        except (KeyError, ValueError) as exc:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid role",
            ) from exc

        if user_role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions",
            )
        return payload

    return dependency


require_director = require_role(Role.DIRECTOR)
require_subdirector = require_role(Role.SUBDIRECTOR)
require_tutor = require_role(Role.TUTOR)
require_professor = require_role(Role.PROFESSOR)
require_student = require_role(Role.STUDENT)

require_director_or_subdirector = require_role(Role.DIRECTOR, Role.SUBDIRECTOR)
require_school_admin = require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)
require_teacher = require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR, Role.PROFESSOR)


def require_same_school_or_admin(payload: dict, school_id: UUID | str | None) -> None:
    """Verify that a non-admin user only accesses their own school data."""
    if school_id is None:
        return
    user_school = payload.get("school_id")
    user_role = payload.get("role")
    if user_role in {Role.DIRECTOR.value, Role.SUBDIRECTOR.value}:
        return
    if user_school is None or str(user_school) != str(school_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No puedes acceder a datos de otro colegio",
        )
