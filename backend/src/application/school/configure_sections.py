"""Caso de uso: configurar secciones de un colegio."""

from dataclasses import dataclass, field

from ...domain.entities import Section
from ...domain.interfaces.repositories import SectionRepository


@dataclass
class ConfigureSectionItem:
    name: str
    grade: int
    level: str = "primary"


@dataclass
class ConfigureSectionsRequest:
    school_id: str
    sections: list[ConfigureSectionItem] = field(default_factory=list)


@dataclass
class ConfigureSectionsResponse:
    sections: list[Section]


class ConfigureSectionsUseCase:
    """Crea multiples secciones para un colegio."""

    def __init__(self, section_repo: SectionRepository):
        self._section_repo = section_repo

    async def execute(self, request: ConfigureSectionsRequest) -> ConfigureSectionsResponse:
        import uuid

        school_id = uuid.UUID(request.school_id)
        created = []

        for item in request.sections:
            section = Section(
                school_id=school_id,
                name=item.name,
                grade=item.grade,
                level=item.level,
            )
            result = await self._section_repo.create(section)
            created.append(result)

        return ConfigureSectionsResponse(sections=created)
