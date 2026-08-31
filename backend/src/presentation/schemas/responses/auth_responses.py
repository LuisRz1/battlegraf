"""Response schemas for authentication."""

from pydantic import BaseModel


class TokenResponse(BaseModel):
    access_token: str
    token_type: str


class UserResponse(BaseModel):
    id: str
    username: str
    email: str
    full_name: str
    last_name: str = ""
    phone: str = ""
    role: str
    school_id: str | None
    school_code: str | None = None
    section_id: str | None
    xp: int
