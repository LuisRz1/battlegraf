"""JWT token creation and verification."""

from datetime import datetime, timedelta, timezone
from uuid import UUID

from jose import JWTError, jwt

from src.domain.enums import Role
from src.infrastructure.config import get_settings

settings = get_settings()


def create_access_token(user_id: UUID, role: Role, school_id: UUID | None = None, section_id: UUID | None = None) -> str:
    """Create a JWT access token for a user."""
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {
        "sub": str(user_id),
        "role": role.value,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    if school_id:
        payload["school_id"] = str(school_id)
    if section_id:
        payload["section_id"] = str(section_id)
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict | None:
    """Decode and validate a JWT token."""
    try:
        return jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None


def get_user_id_from_token(token: str) -> UUID | None:
    """Extract user id from a valid token."""
    payload = decode_token(token)
    if payload and "sub" in payload:
        return UUID(payload["sub"])
    return None
