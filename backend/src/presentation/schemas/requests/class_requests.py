"""Request schemas for classes."""

from pydantic import BaseModel

class CreateClassRequest(BaseModel):
    name: str
    subject: str | None = None

class JoinClassRequest(BaseModel):
    class_code: str
