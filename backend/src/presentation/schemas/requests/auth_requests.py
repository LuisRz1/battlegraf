"""Request schemas for authentication."""

from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    username: str
    password: str


class CreateDirectorRequest(BaseModel):
    username: str
    email: EmailStr
    full_name: str
    password: str
    school_name: str
    region: str = ""


class CreateUserRequest(BaseModel):
    username: str
    email: EmailStr
    full_name: str
    password: str
    role: str
    school_id: str | None = None
    section_id: str | None = None


class CreateStaffRequest(BaseModel):
    username: str
    email: EmailStr
    full_name: str
    password: str
    role: str
    school_id: str | None = None
    section_id: str | None = None
