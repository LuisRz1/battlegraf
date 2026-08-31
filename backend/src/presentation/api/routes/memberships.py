"""Memberships endpoints."""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from src.infrastructure.auth.permissions import get_current_user
from src.infrastructure.database.session import get_db
from src.infrastructure.database.repositories.membership_repo import SQLAlchemyMembershipRepository
from src.infrastructure.database.models.membership import MembershipSnapshotModel

router = APIRouter(prefix="/memberships", tags=["Memberships"])

@router.get("")
async def list_memberships(
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    user_id = UUID(payload["sub"])
    mem_repo = SQLAlchemyMembershipRepository(session)
    memberships = await mem_repo.get_all_by_user(user_id)
    
    return [
        {
            "id": str(m.id),
            "school_id": str(m.school_id),
            "role": m.role,
            "is_active": m.is_active
        }
        for m in memberships
    ]

@router.post("/leave", status_code=status.HTTP_200_OK)
async def leave_school(
    payload: dict = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    user_id = UUID(payload["sub"])
    school_id_str = payload.get("school_id")
    
    if not school_id_str:
        raise HTTPException(status_code=400, detail="No perteneces a un colegio")
        
    school_id = UUID(school_id_str)
    
    mem_repo = SQLAlchemyMembershipRepository(session)
    membership = await mem_repo.get_by_user_and_school(user_id, school_id)
    if not membership:
        raise HTTPException(status_code=404, detail="Membresía no encontrada")
        
    await mem_repo.deactivate(membership.id)
    
    # Create snapshot
    snapshot = MembershipSnapshotModel(
        membership_id=membership.id,
        user_id=user_id,
        school_name="Unknown School", # We would fetch this
        role=membership.role,
        final_xp=membership.xp,
        final_rank_name=None,
        battles_played=0,
        battles_won=0,
        materials_count=0
    )
    session.add(snapshot)
    
    from src.infrastructure.database.repositories.user_repo import SQLAlchemyUserRepository
    user_repo = SQLAlchemyUserRepository(session)
    user = await user_repo.get_by_id(user_id)
    if user:
        # Also need to update user to no longer have this school_id
        user.school_id = None
        await user_repo.update(user)
    
    await session.commit()
    
    return {"message": "Saliste del colegio exitosamente"}
