"""Classes endpoints."""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from src.domain.enums import Role
from src.infrastructure.auth.permissions import get_current_user
from src.infrastructure.database.session import get_db
from src.infrastructure.database.repositories.class_repo import SQLAlchemyClassRepository, SQLAlchemyEnrollmentRepository
from src.infrastructure.database.repositories.user_repo import SQLAlchemyUserRepository
from src.infrastructure.database.models.membership import ClassModel, ClassEnrollmentModel
from src.infrastructure.database.models.school import UserModel
from src.infrastructure.auth.code_generator import generate_class_code
from src.presentation.schemas.requests.class_requests import CreateClassRequest, JoinClassRequest
from src.presentation.schemas.responses.class_responses import ClassResponse, EnrollmentResponse

router = APIRouter(prefix="/classes", tags=["Classes"])

@router.post("", response_model=ClassResponse, status_code=status.HTTP_201_CREATED)
async def create_class(
    body: CreateClassRequest,
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    user_id = UUID(payload["sub"])
    role = payload.get("role")
    school_id_str = payload.get("school_id")
    
    if role != Role.PROFESSOR.value and role != Role.DIRECTOR.value:
        raise HTTPException(status_code=403, detail="No autorizado para crear clases")
        
    if not school_id_str:
        raise HTTPException(status_code=400, detail="Usuario sin colegio asignado")
        
    school_id = UUID(school_id_str)
    
    class_repo = SQLAlchemyClassRepository(session)
    code = await generate_class_code(session)
    created_class = await class_repo.create(user_id, school_id, body.name, code, body.subject)
    
    user_repo = SQLAlchemyUserRepository(session)
    professor = await user_repo.get_by_id(user_id)
    
    return ClassResponse(
        id=str(created_class.id),
        name=created_class.name,
        subject=created_class.subject,
        code=created_class.code,
        professor_name=professor.full_name if professor else "Unknown",
        school_name="Unknown", # Requires joining school but we will just pass string
        is_active=created_class.is_active,
        student_count=0
    )

@router.get("", response_model=list[ClassResponse])
async def list_classes(
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    user_id = UUID(payload["sub"])
    role = payload.get("role")
    
    class_repo = SQLAlchemyClassRepository(session)
    enroll_repo = SQLAlchemyEnrollmentRepository(session)
    
    classes = []
    
    if role == Role.PROFESSOR.value or role == Role.DIRECTOR.value:
        classes = await class_repo.get_by_professor(user_id)
    elif role == Role.STUDENT.value:
        enrollments = await enroll_repo.get_by_student(user_id)
        classes = [e.class_ for e in enrollments]
        
    result = []
    for c in classes:
        result.append(ClassResponse(
            id=str(c.id),
            name=c.name,
            subject=c.subject,
            code=c.code,
            professor_name="Unknown",
            school_name="Unknown",
            is_active=c.is_active,
            student_count=0
        ))
    return result

@router.get("/{class_id}")
async def get_class(
    class_id: str,
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    class_repo = SQLAlchemyClassRepository(session)
    class_model = await class_repo.get_by_id(UUID(class_id))
    if not class_model:
        raise HTTPException(status_code=404, detail="Clase no encontrada")
        
    return {
        "id": str(class_model.id),
        "name": class_model.name,
        "code": class_model.code
    }

@router.post("/join", status_code=status.HTTP_200_OK)
async def join_class(
    body: JoinClassRequest,
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    user_id = UUID(payload["sub"])
    role = payload.get("role")
    
    if role != Role.STUDENT.value:
        raise HTTPException(status_code=403, detail="Solo los estudiantes pueden unirse")
        
    class_repo = SQLAlchemyClassRepository(session)
    class_model = await class_repo.get_by_code(body.class_code)
    if not class_model:
        raise HTTPException(status_code=404, detail="Clase no encontrada")
        
    enroll_repo = SQLAlchemyEnrollmentRepository(session)
    await enroll_repo.enroll_student(class_model.id, user_id)
    
    return {"message": "Inscrito exitosamente"}

@router.delete("/{class_id}/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_student(
    class_id: str,
    student_id: str,
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    role = payload.get("role")
    
    if role != Role.PROFESSOR.value and role != Role.DIRECTOR.value:
        raise HTTPException(status_code=403, detail="No autorizado")
        
    enroll_repo = SQLAlchemyEnrollmentRepository(session)
    await enroll_repo.remove_student(UUID(class_id), UUID(student_id))
