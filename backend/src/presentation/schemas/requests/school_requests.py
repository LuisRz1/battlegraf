"""Request schemas for schools and sections."""

from pydantic import BaseModel


class CreateSchoolRequest(BaseModel):
    name: str
    region: str = ""
    level: str = "both"


class CreateSectionRequest(BaseModel):
    name: str
    grade: int
    level: str = "primary"
    tutor_id: str | None = None


class CreateSectionsRequest(BaseModel):
    sections: list[CreateSectionRequest]


class StudentImportRequest(BaseModel):
    username: str
    full_name: str
    email: str | None = None
    password: str


class BulkCreateStudentsRequest(BaseModel):
    section_id: str
    students: list[StudentImportRequest]
