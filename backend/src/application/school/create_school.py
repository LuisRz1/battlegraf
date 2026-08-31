"""Caso de uso: crear un colegio."""

from dataclasses import dataclass

from ...domain.entities import School
from ...domain.interfaces.repositories import SchoolRepository


@dataclass
class CreateSchoolRequest:
    name: str
    region: str = ""
    level: str = "both"


@dataclass
class CreateSchoolResponse:
    school: School


class CreateSchoolUseCase:
    """Crea un nuevo colegio en el sistema."""

    def __init__(self, school_repo: SchoolRepository):
        self._school_repo = school_repo

    async def execute(self, request: CreateSchoolRequest) -> CreateSchoolResponse:
        school = School(
            name=request.name,
            region=request.region,
            level=request.level,
        )
        created = await self._school_repo.create(school)
        return CreateSchoolResponse(school=created)
