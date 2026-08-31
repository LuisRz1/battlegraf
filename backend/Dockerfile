# Backend Dockerfile — BattleGraph API
# Build robusto sin depender de uv.lock (repositorio gestiona deps con pip/venv).
FROM python:3.11-slim

WORKDIR /app

# Dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar archivos del proyecto
COPY pyproject.toml alembic.ini ./
COPY alembic/ alembic/
COPY src/ src/

# Instalar dependencias desde el pyproject (sin resolver extras de dev)
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir .

RUN adduser --disabled-password --gecos '' appuser && \
    chown -R appuser:appuser /app
USER appuser

# Exponer el puerto que usa uvicorn
EXPOSE 8000

# Comando por defecto: aplicar migraciones y arrancar la API
CMD ["sh", "-c", "python -m alembic upgrade head && exec python -m uvicorn src.main:app --host 0.0.0.0 --port 8000"]
