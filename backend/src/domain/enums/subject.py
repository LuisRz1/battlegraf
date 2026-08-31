from enum import Enum


class Subject(str, Enum):
    """Materias escolares disponibles."""

    MATH = "mathematics"
    LANGUAGE = "language"
    SCIENCE = "science"
    PHYSICS = "physics"
    CHEMISTRY = "chemistry"
    BIOLOGY = "biology"
    HISTORY = "history"
    GEOGRAPHY = "geography"
    CIVICS = "civics"
    ENGLISH = "english"
    ART = "art"
    PE = "physical_education"

    @property
    def label(self) -> str:
        labels = {
            Subject.MATH: "Matematica",
            Subject.LANGUAGE: "Comunicacion",
            Subject.SCIENCE: "Ciencia y Tecnologia",
            Subject.PHYSICS: "Fisica",
            Subject.CHEMISTRY: "Quimica",
            Subject.BIOLOGY: "Biologia",
            Subject.HISTORY: "Historia",
            Subject.GEOGRAPHY: "Geografia",
            Subject.CIVICS: "Civica",
            Subject.ENGLISH: "Ingles",
            Subject.ART: "Arte",
            Subject.PE: "Educacion Fisica",
        }
        return labels[self]

    @property
    def default_color(self) -> str:
        """Color hexadecimal por defecto para esta materia en el grafo."""
        colors = {
            Subject.MATH: "#FF4444",
            Subject.LANGUAGE: "#4488FF",
            Subject.SCIENCE: "#44CC44",
            Subject.PHYSICS: "#FF8844",
            Subject.CHEMISTRY: "#AA44FF",
            Subject.BIOLOGY: "#44FF88",
            Subject.HISTORY: "#FFAA44",
            Subject.GEOGRAPHY: "#44CCAA",
            Subject.CIVICS: "#FF4488",
            Subject.ENGLISH: "#4488CC",
            Subject.ART: "#CC44FF",
            Subject.PE: "#88CC44",
        }
        return colors[self]
