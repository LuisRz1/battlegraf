from enum import Enum, auto


class Role(str, Enum):
    """Jerarquia de roles del sistema."""

    DIRECTOR = "director"
    SUBDIRECTOR = "subdirector"
    TUTOR = "tutor"
    PROFESSOR = "professor"
    STUDENT = "student"

    @property
    def hierarchy_level(self) -> int:
        """Nivel jerarquico (1 = mayor autoridad)."""
        mapping = {
            Role.DIRECTOR: 1,
            Role.SUBDIRECTOR: 2,
            Role.TUTOR: 3,
            Role.PROFESSOR: 4,
            Role.STUDENT: 5,
        }
        return mapping[self]

    def can_manage(self, other: "Role") -> bool:
        """Determina si este rol puede gestionar a otro."""
        return self.hierarchy_level < other.hierarchy_level

    @property
    def label(self) -> str:
        """Etiqueta legible en espanol."""
        labels = {
            Role.DIRECTOR: "Director",
            Role.SUBDIRECTOR: "Subdirector",
            Role.TUTOR: "Tutor",
            Role.PROFESSOR: "Profesor",
            Role.STUDENT: "Alumno",
        }
        return labels[self]
