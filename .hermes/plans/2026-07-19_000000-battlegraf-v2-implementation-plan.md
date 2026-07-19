# BattleGraf v2 — Plan de Implementacion Completo

> **For Hermes:** Usa subagent-driven-development para ejecutar este plan tarea por tarea.

**Goal:** Construir la plataforma escolar BattleGraf: backend API (FastAPI + Clean Architecture), app mobile (Flutter retro Balatro-like), motor de grafos, sistema de batallas por turnos, generacion de preguntas con IA, jerarquia de roles, y onboarding de colegios.

**Architecture:** Clean Architecture con capa de presentacion MVC. Backend: Python/FastAPI + PostgreSQL + Redis + WebSocket. Frontend: Flutter + Riverpod + GoRouter + CustomPainter para grafos.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy 2.0 (async), PostgreSQL 16, Redis 7, Celery, LangChain + OpenAI, Flutter 3.x, Docker Compose, GitHub Actions.

---

## Contexto actual

El scaffolding basico existe en `D:\battlegraf\`:
- Entidades de dominio: School, User, Section, Battle, Graph, Question, etc.
- Enums: Role, Subject, BattleStatus, TaskType
- FastAPI base con health check
- Docker Compose (PostgreSQL + Redis + MinIO)
- CI/CD con GitHub Actions
- Git inicializado, remote apuntando a `https://github.com/LuisRz1/battlegraf.git`

**Lo que falta:** Todo el backend funcional, modelos ORM, endpoints reales, autenticacion, motor de batallas, WebSocket, agente IA, app Flutter.

---

## FASE 0: Fundacion (Backend funcional base)

### Task 1: Crear modelos ORM con SQLAlchemy

**Objective:** Mapear entidades de dominio a tablas de PostgreSQL.

**Files:**
- Create: `backend/src/infrastructure/database/models/base.py`
- Create: `backend/src/infrastructure/database/models/school.py`
- Create: `backend/src/infrastructure/database/models/user.py`
- Create: `backend/src/infrastructure/database/models/battle.py`
- Create: `backend/src/infrastructure/database/models/question.py`

**Step 1: Base model con UUID y timestamps**

```python
# backend/src/infrastructure/database/models/base.py
import uuid
from datetime import datetime, timezone
from sqlalchemy import UUID, DateTime
from sqlalchemy.orm import Mapped, mapped_column, DeclarativeBase

class Base(DeclarativeBase):
    pass

class UUIDMixin:
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))
```

**Step 2: Modelo School**

```python
# backend/src/infrastructure/database/models/school.py
from .base import Base, UUIDMixin
from sqlalchemy import String, Boolean
from sqlalchemy.orm import Mapped, mapped_column

class SchoolModel(Base, UUIDMixin):
    __tablename__ = "schools"
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    region: Mapped[str] = mapped_column(String(255), default="")
    level: Mapped[str] = mapped_column(String(20), default="both")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
```

**Step 3: Modelo User con roles**

```python
# backend/src/infrastructure/database/models/user.py
from .base import Base, UUIDMixin
from sqlalchemy import String, Integer, ForeignKey, Boolean
from sqlalchemy.orm import Mapped, mapped_column

class UserModel(Base, UUIDMixin):
    __tablename__ = "users"
    username: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    full_name: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(50), nullable=False)
    school_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("schools.id"), nullable=True)
    section_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("sections.id"), nullable=True)
    xp: Mapped[int] = mapped_column(Integer, default=0)
    rank_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    clan_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
```

**Step 4: Modelo Section**

```python
# backend/src/infrastructure/database/models/section.py
class SectionModel(Base, UUIDMixin):
    __tablename__ = "sections"
    school_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("schools.id"))
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    grade: Mapped[int] = mapped_column(Integer, nullable=False)
    level: Mapped[str] = mapped_column(String(50), default="primary")
    tutor_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
```

**Step 5: Commit**

```bash
git add backend/src/infrastructure/database/models/
git commit -m "feat(db): add ORM models for School, User, Section"
```

---

### Task 2: Configurar Alembic para migraciones

**Objective:** Inicializar Alembic y crear migracion inicial.

**Step 1: Crear alembic.ini**

```ini
# backend/alembic.ini
[alembic]
script_location = src/infrastructure/database/migrations
prepend_sys_path = .
version_path_separator = os
```

**Step 2: Crear directorio de migraciones con env.py**

```python
# backend/src/infrastructure/database/migrations/env.py
from alembic import context
from sqlalchemy import create_engine, pool
from src.infrastructure.database.models.base import Base
from src.infrastructure.config import get_settings

config = context.config
target_metadata = Base.metadata

def run_migrations_online():
    settings = get_settings()
    connectable = create_engine(settings.database_url_sync)
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()

run_migrations_online()
```

**Step 3: Inicializar migracion**

```bash
cd backend
alembic revision --autogenerate -m "init"
alembic upgrade head
```

**Step 4: Commit**

```bash
git add backend/alembic.ini backend/src/infrastructure/database/migrations/
git commit -m "chore: setup alembic migrations"
```

---

### Task 3: Implementar repositorios con SQLAlchemy

**Objective:** Adaptadores concretos de los puertos abstractos del dominio.

**Files:**
- Create: `backend/src/infrastructure/database/repositories/school_repo.py`
- Create: `backend/src/infrastructure/database/repositories/user_repo.py`
- Create: `backend/src/infrastructure/database/repositories/section_repo.py`

**Step 1: Configuracion de base de datos (dependency injection)**

```python
# backend/src/infrastructure/database/session.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import sessionmaker

engine = create_async_engine(get_settings().database_url, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        yield session
```

**Step 2: SchoolRepository concreto**

```python
# backend/src/infrastructure/database/repositories/school_repo.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from src.domain.entities import School
from src.domain.interfaces.repositories import SchoolRepository
from src.infrastructure.database.models.school import SchoolModel

class SQLAlchemySchoolRepository(SchoolRepository):
    def __init__(self, session: AsyncSession):
        self._session = session

    async def create(self, school: School) -> School:
        model = SchoolModel(name=school.name, region=school.region, level=school.level)
        self._session.add(model)
        await self._session.commit()
        school.id = model.id
        return school

    async def get_by_id(self, school_id: uuid.UUID) -> School | None:
        result = await self._session.execute(select(SchoolModel).where(SchoolModel.id == school_id))
        model = result.scalar_one_or_none()
        if not model:
            return None
        return School(id=model.id, name=model.name, region=model.region, level=model.level, is_active=model.is_active, created_at=model.created_at)

    async def list_all(self) -> list[School]:
        result = await self._session.execute(select(SchoolModel).where(SchoolModel.is_active == True))
        return [School(id=m.id, name=m.name, region=m.region, level=m.level) for m in result.scalars().all()]
```

**Step 3: Commit**

```bash
git add backend/src/infrastructure/database/
git commit -m "feat: implement SQLAlchemy repositories with DI"
```

---

### Task 4: Endpoints reales con DI en FastAPI

**Objective:** Conectar casos de uso a rutas HTTP con inyeccion de dependencias.

**Files:**
- Modify: `backend/src/presentation/api/routes/schools.py`
- Create: `backend/src/presentation/api/dependencies.py`
- Create: `backend/src/presentation/schemas/requests/school_requests.py`
- Create: `backend/src/presentation/schemas/responses/school_responses.py`

**Step 1: Dependency injection de repositorios**

```python
# backend/src/presentation/api/dependencies.py
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from src.infrastructure.database.session import get_db
from src.infrastructure.database.repositories.school_repo import SQLAlchemySchoolRepository

def get_school_repo(db: AsyncSession = Depends(get_db)):
    return SQLAlchemySchoolRepository(db)
```

**Step 2: Endpoints con Pydantic schemas**

```python
# backend/src/presentation/api/routes/schools.py
from fastapi import APIRouter, Depends
from src.application.school import CreateSchoolUseCase
from src.domain.interfaces.repositories import SchoolRepository
from src.presentation.api.dependencies import get_school_repo
from src.presentation.schemas.requests.school_requests import CreateSchoolRequest
from src.presentation.schemas.responses.school_responses import SchoolResponse

router = APIRouter(prefix="/schools")

@router.post("", response_model=SchoolResponse, status_code=201)
async def create_school(
    body: CreateSchoolRequest,
    repo: SchoolRepository = Depends(get_school_repo),
):
    use_case = CreateSchoolUseCase(repo)
    result = await use_case.execute(body)
    return SchoolResponse(id=result.school.id, name=result.school.name, region=result.school.region)

@router.get("", response_model=list[SchoolResponse])
async def list_schools(repo: SchoolRepository = Depends(get_school_repo)):
    schools = await repo.list_all()
    return [SchoolResponse(id=s.id, name=s.name, region=s.region) for s in schools]
```

**Step 3: Verificacion**

```bash
cd backend
uv run uvicorn src.main:app --reload
# Probar en otro terminal:
curl -X POST http://localhost:8000/api/v1/schools -H "Content-Type: application/json" -d '{"name": "Colegio Test", "region": "Lima"}'
# Expected: {"id": "uuid", "name": "Colegio Test", "region": "Lima"}
```

**Step 4: Commit**

```bash
git add backend/src/presentation/
git commit -m "feat(api): real endpoints for School CRUD with DI"
```

---

### Task 5: Autenticacion JWT

**Objective:** Sistema de login con JWT, hash de passwords, y middleware de roles.

**Files:**
- Create: `backend/src/infrastructure/auth/jwt_handler.py`
- Create: `backend/src/infrastructure/auth/password.py`
- Create: `backend/src/presentation/api/routes/auth.py`

**Step 1: Password hashing**

```python
# backend/src/infrastructure/auth/password.py
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)
```

**Step 2: JWT handler**

```python
# backend/src/infrastructure/auth/jwt_handler.py
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from src.domain.enums import Role

SECRET_KEY = "dev-secret-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440

def create_access_token(user_id: str, role: Role) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "role": role.value, "exp": expire}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def decode_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        return None
```

**Step 3: Endpoints de auth**

```python
# backend/src/presentation/api/routes/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm

router = APIRouter(prefix="/auth")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

@router.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends(), repo = Depends(get_user_repo)):
    user = await repo.get_by_username(form_data.username)
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    token = create_access_token(user.id, user.role)
    return {"access_token": token, "token_type": "bearer"}
```

**Step 4: Commit**

```bash
git add backend/src/infrastructure/auth/ backend/src/presentation/api/routes/auth.py
git commit -m "feat(auth): JWT login with password hashing and role claims"
```

---

## FASE 1: Gestion de Colegios completa

### Task 6: Carga masiva de alumnos por CSV

**Objective:** Endpoint para crear multiples usuarios (alumnos) desde CSV.

**Files:**
- Create: `backend/src/presentation/api/routes/users.py`
- Create: `backend/src/application/school/bulk_create_users.py`

**Step 1: Caso de uso**

```python
# backend/src/application/school/bulk_create_users.py
import csv
from io import StringIO

class BulkCreateUsersUseCase:
    async def execute(self, csv_content: str, school_id: str, section_id: str) -> list[User]:
        reader = csv.DictReader(StringIO(csv_content))
        created = []
        for row in reader:
            user = User(
                username=row["username"],
                full_name=row["full_name"],
                role=Role.STUDENT,
                school_id=UUID(school_id),
                section_id=UUID(section_id),
                hashed_password=hash_password(row["password"]),
            )
            created.append(await self._user_repo.create(user))
        return created
```

**Step 2: Commit**

```bash
git commit -m "feat: bulk CSV import for students"
```

---

### Task 7: Middleware de roles y permisos

**Objective:** Decorador/proteccion de endpoints segun jerarquia de roles.

**Files:**
- Create: `backend/src/infrastructure/auth/permissions.py`
- Modify: `backend/src/presentation/api/routes/schools.py` (agregar depends)

**Step 1: Dependency de rol requerido**

```python
# backend/src/infrastructure/auth/permissions.py
from fastapi import Depends, HTTPException, status
from src.domain.enums import Role

def require_role(*roles: Role):
    def dependency(token: str = Depends(oauth2_scheme)):
        payload = decode_token(token)
        if not payload:
            raise HTTPException(status_code=401, detail="Token invalido")
        user_role = Role(payload["role"])
        if user_role not in roles:
            raise HTTPException(status_code=403, detail="Permiso denegado")
        return payload
    return Depends(dependency)
```

**Step 2: Commit**

```bash
git commit -m "feat(auth): role-based access control middleware"
```

---

## FASE 2: Banco de Preguntas e IA

### Task 8: Upload de archivos y extraccion de texto

**Objective:** Profesores suben PDF/PPT/DOCX/IMG, el sistema extrae texto.

**Files:**
- Create: `backend/src/infrastructure/storage/minio_client.py`
- Create: `backend/src/infrastructure/ai/document_processor.py`
- Create: `backend/src/presentation/api/routes/materials.py`

**Step 1: MinIO client**

```python
# backend/src/infrastructure/storage/minio_client.py
from minio import Minio

class MinioStorage:
    def __init__(self, endpoint: str, access_key: str, secret_key: str, secure: bool = False):
        self.client = Minio(endpoint, access_key=access_key, secret_key=secret_key, secure=secure)
        self.bucket = "materials"
        if not self.client.bucket_exists(self.bucket):
            self.client.make_bucket(self.bucket)

    def upload(self, file_data: bytes, object_name: str) -> str:
        from io import BytesIO
        self.client.put_object(self.bucket, object_name, BytesIO(file_data), len(file_data))
        return f"{self.bucket}/{object_name}"
```

**Step 2: Document processor**

```python
# backend/src/infrastructure/ai/document_processor.py
from pypdf import PdfReader

def extract_text_from_pdf(file_path: str) -> str:
    reader = PdfReader(file_path)
    return "\n".join(page.extract_text() or "" for page in reader.pages)

def extract_text(file_path: str) -> str:
    if file_path.endswith(".pdf"):
        return extract_text_from_pdf(file_path)
    # PPT, DOCX, OCR por implementar en iteraciones futuras
    return ""
```

**Step 3: Commit**

```bash
git commit -m "feat(storage): MinIO upload and PDF text extraction"
```

---

### Task 9: Agente IA para generacion de preguntas

**Objective:** LangChain + OpenAI genera 100 preguntas de alternativa multiple.

**Files:**
- Create: `backend/src/infrastructure/ai/question_generator.py`

**Step 1: Generador con LangChain**

```python
# backend/src/infrastructure/ai/question_generator.py
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import JsonOutputParser

class OpenAIQuestionGenerator:
    def __init__(self, api_key: str, model: str = "gpt-4o-mini"):
        self.llm = ChatOpenAI(api_key=api_key, model=model, temperature=0.7)
        self.parser = JsonOutputParser()
        self.prompt = ChatPromptTemplate.from_messages([
            ("system", "Eres un experto en educacion. Genera preguntas de alternativa multiple basadas en el material proporcionado. Devuelve un JSON con 'questions' como array de objetos. Cada objeto: text, options (A-D), correct_option (A/B/C/D), explanation. Genera exactamente {count} preguntas."),
            ("human", "Materia: {subject}\n\nMaterial:\n{material_text}")
        ])

    async def generate(self, material_text: str, subject: str, count: int = 100) -> list[dict]:
        chain = self.prompt | self.llm | self.parser
        result = await chain.ainvoke({"material_text": material_text, "subject": subject, "count": count})
        return result.get("questions", [])
```

**Step 2: Endpoint**

```python
# backend/src/presentation/api/routes/questions.py
@router.post("/{subject_id}/generate")
async def generate_questions(
    subject_id: str,
    material_id: str,
    generator: QuestionAgent = Depends(get_question_generator),
    user = require_role(Role.PROFESSOR),
):
    material = await get_material(material_id)
    text = extract_text(material.file_path)
    questions = await generator.generate(text, subject_id, count=100)
    # Guardar en banco
    return {"generated": len(questions), "pending_review": True}
```

**Step 3: Commit**

```bash
git commit -m "feat(ai): LangChain + OpenAI question generator with PDF extraction"
```

---

## FASE 3: Motor de Grafos y Batallas

### Task 10: Algoritmo de generacion de grafos

**Objective:** Crear grafos validos: capas, nodos, conexiones, colores.

**Files:**
- Create: `backend/src/domain/services/graph_builder.py`

**Step 1: Builder con validacion de caminos**

```python
# backend/src/domain/services/graph_builder.py
import random
from src.domain.entities import Graph, GraphNode
from src.domain.enums import Subject

class GraphBuilder:
    def build(self, num_layers: int, min_nodes: int, max_nodes: int, subjects: list[Subject]) -> Graph:
        nodes = []
        # Crear capas
        for layer in range(num_layers):
            num_nodes = random.randint(min_nodes, max_nodes)
            for pos in range(num_nodes):
                subject = random.choice(subjects)
                nodes.append(GraphNode(
                    layer=layer,
                    position=pos,
                    subject=subject,
                    color=subject.default_color,
                ))
        # Conectar capas adyacentes
        for i, node in enumerate(nodes):
            if node.layer < num_layers - 1:
                # Conectar a 1-2 nodos de la siguiente capa
                next_layer_nodes = [n for n in nodes if n.layer == node.layer + 1]
                connections = random.sample(next_layer_nodes, k=min(2, len(next_layer_nodes)))
                node.connected_to = [c.id for c in connections]
                # Conectar bidireccionalmente
                for c in connections:
                    if node.id not in c.connected_to:
                        c.connected_to.append(node.id)
        # Validar: cada nodo debe tener al menos una conexion hacia adelante o atras
        return Graph(num_layers=num_layers, min_nodes_per_layer=min_nodes, max_nodes_per_layer=max_nodes, nodes=nodes, subjects=subjects)
```

**Step 2: Commit**

```bash
git commit -m "feat(graph): random graph builder with layer connections"
```

---

### Task 11: Motor de batalla

**Objective:** Estado, turnos, conquista, robo de nodos, condicion de victoria.

**Files:**
- Create: `backend/src/domain/services/battle_engine.py`
- Create: `backend/src/presentation/api/websocket/battle_ws.py`

**Step 1: Engine de batalla**

```python
# backend/src/domain/services/battle_engine.py
from src.domain.entities import Battle, BattleNodeState, BattleMove
from src.domain.enums import BattleStatus

class BattleEngine:
    def __init__(self, battle: Battle):
        self.battle = battle

    def can_select_node(self, player_index: int, node_id: uuid.UUID) -> bool:
        # Verificar si el nodo es accesible desde nodos conquistados
        ...

    def conquer_node(self, player_index: int, node_id: uuid.UUID, is_correct: bool, time_ms: int) -> bool:
        if is_correct:
            state = self.battle.node_states.get(node_id) or BattleNodeState(node_id=node_id)
            state.owner = player_index
            state.attempt_count += 1
            state.best_time_ms = min(state.best_time_ms or 999999, time_ms)
            self.battle.node_states[node_id] = state
            return True
        return False

    def steal_node(self, attacker_index: int, defender_index: int, node_id: uuid.UUID, attacker_time: int, defender_time: int) -> bool:
        state = self.battle.node_states[node_id]
        if state.owner != defender_index:
            return False
        # Ambos responden. Gana quien responde correctamente en menor tiempo
        # Nota: la correccion de respuesta ya se valido antes
        if attacker_time < defender_time:
            state.owner = attacker_index
            return True
        return False

    def check_victory(self) -> int | None:
        # El jugador 0 gana si conquista un nodo en la capa N-1
        # El jugador 1 gana si conquista un nodo en la capa 0
        for state in self.battle.node_states.values():
            node = self._get_node(state.node_id)
            if state.owner == 0 and node.layer == self.battle.graph.num_layers - 1:
                return 0
            if state.owner == 1 and node.layer == 0:
                return 1
        return None
```

**Step 2: WebSocket handler**

```python
# backend/src/presentation/api/websocket/battle_ws.py
from fastapi import WebSocket, WebSocketDisconnect
import json

class BattleWebSocketManager:
    def __init__(self):
        self.connections: dict[str, list[WebSocket]] = {}

    async def connect(self, battle_id: str, websocket: WebSocket):
        await websocket.accept()
        if battle_id not in self.connections:
            self.connections[battle_id] = []
        self.connections[battle_id].append(websocket)

    async def broadcast(self, battle_id: str, message: dict):
        for ws in self.connections.get(battle_id, []):
            await ws.send_json(message)

manager = BattleWebSocketManager()

@router.websocket("/{battle_id}/ws")
async def battle_ws(battle_id: str, websocket: WebSocket):
    await manager.connect(battle_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            # Procesar: select_node, submit_answer, etc.
            await manager.broadcast(battle_id, {"event": "ack", "data": data})
    except WebSocketDisconnect:
        # Manejar desconexion
        pass
```

**Step 3: Commit**

```bash
git commit -m "feat(battle): battle engine with turn-based logic and WebSocket real-time"
```

---

## FASE 4: Flutter Mobile con tema retro

### Task 12: Inicializar proyecto Flutter

**Objective:** Scaffolding con arquitectura limpia y tema retro rojo/morado.

**Step 1: Crear proyecto**

```bash
cd /d/battlegraf
flutter create --org com.battlegraf mobile
cd mobile
```

**Step 2: Estructura Clean Architecture**

```
mobile/lib/
  core/
    theme/
      app_theme.dart        # Paleta Balatro-like
      typography.dart       # Press Start 2P + Space Mono
    router/
      app_router.dart       # GoRouter
    di/
      providers.dart        # Riverpod providers
    network/
      api_client.dart       # Dio + interceptors
      websocket_client.dart
  domain/
    entities/
    repositories/           # Abstractos
    usecases/
  data/
    datasources/
    repositories/           # Implementaciones
    models/
  presentation/
    controllers/          # MVC Controllers
    views/
      login/
      lobby/
      battle/
      profile/
    widgets/
      graph_board.dart     # CustomPainter del grafo
      node_card.dart
      battle_hud.dart
```

**Step 3: Tema retro**

```dart
// mobile/lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static const Color deepPurple = Color(0xFF1A0A2E);
  static const Color crimsonRed = Color(0xFF8B0000);
  static const Color gold = Color(0xFFC9A84C);
  static const Color offWhite = Color(0xFFF5F0E8);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: deepPurple,
    colorScheme: ColorScheme.dark(
      primary: crimsonRed,
      secondary: gold,
      surface: Color(0xFF2D1B4E),
      background: deepPurple,
      onSurface: offWhite,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(fontFamily: 'PressStart2P', color: gold, fontSize: 24),
      bodyLarge: TextStyle(fontFamily: 'SpaceMono', color: offWhite, fontSize: 16),
    ),
  );
}
```

**Step 4: Agregar dependencias**

```yaml
# mobile/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  go_router: ^14.0.0
  dio: ^5.4.0
  hive_flutter: ^1.1.0
  custom_refresh_indicator: ^2.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  fonts:
    - family: PressStart2P
      fonts:
        - asset: assets/fonts/PressStart2P-Regular.ttf
    - family: SpaceMono
      fonts:
        - asset: assets/fonts/SpaceMono-Regular.ttf
```

**Step 5: Commit**

```bash
git add mobile/
git commit -m "feat(mobile): Flutter scaffolding with Clean Architecture and retro theme"
```

---

### Task 13: Pantalla de login y navegacion

**Objective:** Login con JWT, navegacion con GoRouter, state con Riverpod.

**Files:**
- Create: `mobile/lib/presentation/views/login/login_view.dart`
- Create: `mobile/lib/presentation/views/lobby/lobby_view.dart`
- Create: `mobile/lib/core/router/app_router.dart`
- Create: `mobile/lib/presentation/controllers/auth_controller.dart`

**Step 1: Router**

```dart
// mobile/lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LoginView()),
    GoRoute(path: '/lobby', builder: (_, __) => const LobbyView()),
    GoRoute(path: '/battle/:id', builder: (_, state) => BattleView(id: state.pathParameters['id']!)),
  ],
);
```

**Step 2: Auth controller con Riverpod**

```dart
// mobile/lib/presentation/controllers/auth_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.ref) : super(AuthState.initial());
  final Ref ref;

  Future<void> login(String username, String password) async {
    state = AuthState.loading();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/auth/login', data: {'username': username, 'password': password});
      final token = response.data['access_token'];
      await ref.read(storageProvider).setToken(token);
      state = AuthState.authenticated(token);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}
```

**Step 3: Commit**

```bash
git commit -m "feat(mobile): login, GoRouter navigation, Riverpod auth state"
```

---

### Task 14: Renderizado del grafo con CustomPainter

**Objective:** Dibujar el grafo de batalla: nodos como cartas/casillas, conexiones como lineas, colores por materia.

**Files:**
- Create: `mobile/lib/presentation/widgets/graph_board.dart`
- Create: `mobile/lib/presentation/widgets/node_card.dart`

**Step 1: CustomPainter del grafo**

```dart
// mobile/lib/presentation/widgets/graph_board.dart
import 'package:flutter/material.dart';

class GraphPainter extends CustomPainter {
  final List<NodeData> nodes;
  final List<ConnectionData> connections;
  final String? selectedNodeId;

  GraphPainter({required this.nodes, required this.connections, this.selectedNodeId});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Dibujar conexiones
    for (final conn in connections) {
      final from = nodes.firstWhere((n) => n.id == conn.fromId);
      final to = nodes.firstWhere((n) => n.id == conn.toId);
      paint.color = Colors.white.withOpacity(0.3);
      canvas.drawLine(Offset(from.x, from.y), Offset(to.x, to.y), paint);
    }

    // Dibujar nodos
    for (final node in nodes) {
      final nodePaint = Paint()
        ..color = node.color
        ..style = node.owner == null ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 3;
      
      // Forma de hexagono o rectangulo redondeado estilo carta
      final rect = Rect.fromCenter(center: Offset(node.x, node.y), width: 60, height: 80);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, nodePaint);
      
      // Texto de materia
      final textPainter = TextPainter(
        text: TextSpan(text: node.subject.substring(0, 3), style: TextStyle(color: Colors.white, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(node.x - 10, node.y - 5));
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) => true;
}
```

**Step 2: Commit**

```bash
git commit -m "feat(mobile): custom graph renderer with node colors and connections"
```

---

## FASE 5: Tareas, Rangos y Progresion

### Task 15: Sistema de rangos y XP

**Objective:** Alumnos ganan XP por batallas y tareas, suben de rango.

**Files:**
- Create: `backend/src/application/gamification/xp_calculator.py`
- Create: `backend/src/presentation/api/routes/ranks.py`

**Step 1: Calculador de XP**

```python
# backend/src/application/gamification/xp_calculator.py
class XPCalculator:
    BASE_BATTLE_WIN = 50
    BASE_BATTLE_LOSS = 10
    BASE_TASK_COMPLETE = 30
    STEAL_BONUS = 20

    def for_battle(self, won: bool, nodes_conquered: int, steals: int) -> int:
        base = self.BASE_BATTLE_WIN if won else self.BASE_BATTLE_LOSS
        return base + (nodes_conquered * 5) + (steals * self.STEAL_BONUS)

    def for_task(self, task_type: TaskType, score: float) -> int:
        base = self.BASE_TASK_COMPLETE
        multiplier = score / 100.0
        return int(base * multiplier)
```

**Step 2: Commit**

```bash
git commit -m "feat(gamification): XP calculator for battles and tasks"
```

---

### Task 16: CRUD de tareas

**Objective:** Profesores crean tareas, alumnos las completan.

**Files:**
- Create: `backend/src/presentation/api/routes/tasks.py`

**Step 1: Endpoints**

```python
# backend/src/presentation/api/routes/tasks.py
@router.post("", status_code=201)
async def create_task(body: CreateTaskRequest, user = require_role(Role.PROFESSOR, Role.TUTOR)):
    ...

@router.get("/my")
async def list_my_tasks(user = require_role(Role.STUDENT)):
    ...

@router.post("/{task_id}/submit")
async def submit_task(task_id: str, body: TaskSubmissionRequest, user = require_role(Role.STUDENT)):
    ...
```

**Step 2: Commit**

```bash
git commit -m "feat(tasks): CRUD for assignments and submissions"
```

---

## FASE 6: Batallas entre Secciones y Dashboard

### Task 17: Matchmaking entre secciones

**Objective:** Emparejar secciones A vs seccion B, sistema de equipos.

**Step 1: Commit**

```bash
git commit -m "feat(matchmaking): inter-section battles with team scoring"
```

---

### Task 18: Dashboard de metricas

**Objective:** Endpoints para directivos ver estadisticas del colegio.

**Files:**
- Create: `backend/src/presentation/api/routes/dashboard.py`

**Step 1: Metricas**

```python
# backend/src/presentation/api/routes/dashboard.py
@router.get("/director")
async def director_dashboard(school_id: str, user = require_role(Role.DIRECTOR)):
    return {
        "total_battles": await battle_repo.count_by_school(school_id),
        "active_students": await user_repo.count_active_by_school(school_id),
        "top_sections": await section_repo.get_top_by_xp(school_id),
        "subjects_difficulty": await question_repo.get_error_rates_by_subject(school_id),
    }
```

**Step 2: Commit**

```bash
git commit -m "feat(dashboard): director metrics and section leaderboards"
```

---

## FASE 7: Pulido y Produccion

### Task 19: Animaciones Flutter

**Objective:** Transiciones fluidas, micro-interacciones, sonidos.

**Files:**
- Modify: `mobile/lib/presentation/widgets/node_card.dart`
- Create: `mobile/lib/presentation/widgets/animations/`

**Step 1: Animacion de conquista**

```dart
// Animated node with scale and color transition
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutBack,
  transform: Matrix4.identity()..scale(node.justConquered ? 1.2 : 1.0),
  decoration: BoxDecoration(
    color: node.owner == 0 ? AppTheme.crimsonRed : AppTheme.deepPurple,
    borderRadius: BorderRadius.circular(8),
  ),
)
```

**Step 2: Commit**

```bash
git commit -m "feat(ui): node conquest animations and transitions"
```

---

### Task 20: Configuracion de produccion

**Objective:** Docker Compose produccion, variables de entorno seguras.

**Step 1: docker-compose.prod.yml**

```yaml
version: "3.8"
services:
  api:
    build: ./backend
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - JWT_SECRET_KEY=${JWT_SECRET_KEY}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    ports:
      - "8000:8000"
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
  redis:
    image: redis:7-alpine
```

**Step 2: Commit**

```bash
git commit -m "chore: production docker compose and env config"
```

---

## Push final al repositorio

```bash
git push -u origin main
```

---

## Resumen de cambios esperados

| Fase | Archivos nuevos | Commits esperados |
|------|----------------|-------------------|
| 0 | 15+ | 5 |
| 1 | 5+ | 2 |
| 2 | 8+ | 2 |
| 3 | 6+ | 2 |
| 4 | 25+ | 3 |
| 5 | 4+ | 2 |
| 6 | 3+ | 2 |
| 7 | 5+ | 2 |

---

## Riesgos y consideraciones

1. **Costo de OpenAI:** 100 preguntas por materia x materias x colegios. Implementar cache agresivo y rate limiting.
2. **Latencia WebSocket:** En zonas con mala conexion, considerar turnos asincronos con tiempo limite largo.
3. **Escalabilidad de grafos:** Generar grafos puede ser CPU-intensivo. Cachear configuraciones comunes.
4. **Seguridad de preguntas:** Las respuestas correctas NUNCA deben enviarse al cliente antes de responder.
