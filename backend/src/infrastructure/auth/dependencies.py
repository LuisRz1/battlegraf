"""Authentication and authorization dependencies for FastAPI."""

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from src.domain.enums import Role
from src.domain.interfaces.repositories import UserRepository
from src.infrastructure.auth.jwt_handler import decode_token
from src.infrastructure.database.repositories import SQLAlchemyUserRepository
from src.infrastructure.database.session import get_db

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    """Validate token and return decoded payload."""
    payload = decode_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalido o expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return payload


def require_role(*roles: Role):
    """Dependency factory to require specific roles."""
    def dependency(payload: dict = Depends(get_current_user)) -> dict:
        try:
            user_role = Role(payload["role"])
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Rol invalido") from exc

        if user_role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para realizar esta accion",
            )
        return payload
    return dependency


def get_user_repo(session = Depends(get_db)) -> UserRepository:
    """Factory for SQLAlchemy user repository."""
    return SQLAlchemyUserRepository(session)
