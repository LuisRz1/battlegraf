# Backend Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Instalar uv para gestion de paquetes rapida
RUN pip install uv

# Copiar archivos del proyecto
COPY pyproject.toml .
COPY src/ src/

# Instalar dependencias
RUN uv sync --frozen --no-dev

# Exponer puerto
EXPOSE 8000

# Comando por defecto
CMD ["uv", "run", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
