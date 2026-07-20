"""Local file storage service."""

import uuid
from pathlib import Path

from fastapi import UploadFile

from src.infrastructure.config import get_settings


class LocalStorageService:
    """Service to save uploaded files to local disk."""

    def __init__(self, base_path: str | None = None) -> None:
        settings = get_settings()
        self.base_path = Path(base_path or settings.storage_path)
        self.base_path.mkdir(parents=True, exist_ok=True)

    async def save(self, file: UploadFile, folder: str = "materials") -> str:
        """Save an uploaded file and return its absolute path."""
        target_dir = self.base_path / folder
        target_dir.mkdir(parents=True, exist_ok=True)
        ext = Path(file.filename or "unknown.txt").suffix
        unique_name = f"{uuid.uuid4()}{ext}"
        file_path = target_dir / unique_name
        contents = await file.read()
        file_path.write_bytes(contents)
        return str(file_path)

    def get_path(self, relative_path: str) -> Path:
        return self.base_path / relative_path
