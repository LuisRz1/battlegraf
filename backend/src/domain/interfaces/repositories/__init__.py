"""Interfaces abstractas del dominio — puertos que infraestructura debe implementar."""

from abc import ABC, abstractmethod
from uuid import UUID

from ..entities import School, Section, User
from ..enums import Role, Subject


class SchoolRepository(ABC):
    """Puerto para persistencia de colegios."""

    @abstractmethod
    async def create(self, school: School) -> School:
        ...

    @abstractmethod
    async def get_by_id(self, school_id: UUID) -> School | None:
        ...

    @abstractmethod
    async def list_all(self) -> list[School]:
        ...


class UserRepository(ABC):
    """Puerto para persistencia de usuarios."""

    @abstractmethod
    async def create(self, user: User) -> User:
        ...

    @abstractmethod
    async def get_by_id(self, user_id: UUID) -> User | None:
        ...

    @abstractmethod
    async def get_by_username(self, username: str) -> User | None:
        ...

    @abstractmethod
    async def list_by_school(self, school_id: UUID, role: Role | None = None) -> list[User]:
        ...

    @abstractmethod
    async def list_by_section(self, section_id: UUID) -> list[User]:
        ...


class SectionRepository(ABC):
    """Puerto para persistencia de secciones."""

    @abstractmethod
    async def create(self, section: Section) -> School:
        ...

    @abstractmethod
    async def get_by_id(self, section_id: UUID) -> Section | None:
        ...

    @abstractmethod
    async def list_by_school(self, school_id: UUID) -> list[Section]:
        ...


class QuestionAgent(ABC):
    """Puerto para el agente de IA que genera preguntas."""

    @abstractmethod
    async def generate_questions(
        self,
        material_text: str,
        subject: Subject,
        count: int = 100,
    ) -> list[dict]:
        """Genera `count` preguntas de alternativa multiple basadas en el material."""
        ...

    @abstractmethod
    async def extract_text_from_file(self, file_path: str) -> str:
        """Extrae texto de un archivo (PDF, PPT, DOCX, IMG)."""
        ...
