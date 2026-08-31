"""Initialize the database tables."""

import asyncio

from sqlalchemy.ext.asyncio import create_async_engine

from ..config import get_settings
from .models import Base


async def init_db() -> None:
    """Create all database tables if they do not exist."""
    settings = get_settings()
    engine = create_async_engine(settings.database_url, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(init_db())
