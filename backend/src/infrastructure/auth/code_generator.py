"""Helper for generating short alphanumeric codes."""

import random
import string
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from src.infrastructure.database.models.membership import SchoolCodeModel, ClassModel

def _generate_code(prefix: str, length: int = 4) -> str:
    """Generate a random code with prefix."""
    chars = string.ascii_uppercase + string.digits
    random_str = "".join(random.choices(chars, k=length))
    return f"{prefix}-{random_str}"

async def generate_school_code(session: AsyncSession) -> str:
    """Generate a unique school code."""
    while True:
        code = _generate_code("BG")
        result = await session.execute(select(SchoolCodeModel).where(SchoolCodeModel.code == code))
        exists = result.scalar_one_or_none()
        if not exists:
            return code

async def generate_class_code(session: AsyncSession) -> str:
    """Generate a unique class code."""
    while True:
        code = _generate_code("CL")
        result = await session.execute(select(ClassModel).where(ClassModel.code == code))
        exists = result.scalar_one_or_none()
        if not exists:
            return code
