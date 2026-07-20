"""Request schemas for authentication."""

from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class CreateDirectorRequest(BaseModel):
    username: str
    email: str
    full_name: str
    password: str
    school_name: str
    region: str = ""


class CreateUserRequest(BaseModel):
    username: str
    email: str
    full_name: str
    password: str
    role: str
    section_id: str | None = None
