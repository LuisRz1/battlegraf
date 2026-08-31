"""Request schemas for schools and sections."""

from pydantic import BaseModel, Field


class CreateSchoolRequest(BaseModel):
    name: str
    region: str = ""
    level: str = "both"


class UpdateSchoolRequest(BaseModel):
    name: str | None = None
    region: str | None = None
    level: str | None = None
    is_active: bool | None = None


class CreateSectionRequest(BaseModel):
    name: str
    grade: str
    level: str = "primary"
    tutor_id: str | None = None


class CreateSectionsRequest(BaseModel):
    sections: list[CreateSectionRequest]


class UpdateSectionRequest(BaseModel):
    name: str | None = None
    grade: str | None = None
    level: str | None = None
    section_label: str | None = None
    code: str | None = None
    display_name: str | None = None
    tutor_name: str | None = None
    max_students: int | None = Field(default=None, ge=1, le=100)
    status: str | None = None
    tutor_id: str | None = None
    academic_year_id: str | None = None
    is_active: bool | None = None


class StudentImportRequest(BaseModel):
    username: str
    full_name: str
    email: str | None = None
    password: str


class BulkCreateStudentsRequest(BaseModel):
    section_id: str
    students: list[StudentImportRequest]


class AcademicYearCreateRequest(BaseModel):
    label: str
    starts_on: str | None = None
    ends_on: str | None = None
    is_active: bool = True


class AcademicYearUpdateRequest(BaseModel):
    label: str | None = None
    starts_on: str | None = None
    ends_on: str | None = None
    is_active: bool | None = None
