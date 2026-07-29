"""Ranks, XP profiles, leaderboards, and clan endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from src.domain.entities import Clan, Rank
from src.domain.enums import Role
from src.infrastructure.auth.permissions import get_current_user, require_role
from src.infrastructure.database.repositories import (
    SQLAlchemyClanRepository,
    SQLAlchemyRankRepository,
    SQLAlchemySectionRepository,
    SQLAlchemyUserRepository,
    SQLAlchemyXPTransactionRepository,
)
from src.infrastructure.database.session import get_db
from src.presentation.schemas.requests.task_requests import (
    CreateClanRequest,
    CreateRankRequest,
)
from src.presentation.schemas.responses.task_responses import (
    ClanResponse,
    LeaderboardEntryResponse,
    ProgressionProfileResponse,
    RankResponse,
    XPTransactionResponse,
)

router = APIRouter(prefix="/progression", tags=["Progression"])
rank_admin_access = require_role(Role.DIRECTOR, Role.SUBDIRECTOR)
clan_admin_access = require_role(Role.DIRECTOR, Role.SUBDIRECTOR, Role.TUTOR)

DEFAULT_RANKS = (
    ("Novato", 1, 0),
    ("Aprendiz", 2, 100),
    ("Explorador", 3, 300),
    ("Estratega", 4, 600),
    ("Campeón", 5, 1000),
    ("Maestro", 6, 1500),
    ("Leyenda", 7, 2500),
)


def _rank_response(rank: Rank) -> RankResponse:
    return RankResponse(
        id=str(rank.id),
        school_id=str(rank.school_id),
        name=rank.name,
        level=rank.level,
        xp_required=rank.xp_required,
        icon_url=rank.icon_url,
    )


async def _clan_response(
    clan: Clan,
    user_repo: SQLAlchemyUserRepository,
) -> ClanResponse:
    users = await user_repo.list_by_section(clan.section_id)
    return ClanResponse(
        id=str(clan.id),
        section_id=str(clan.section_id),
        name=clan.name,
        total_score=clan.total_score,
        member_count=sum(user.clan_id == clan.id for user in users),
    )


def _require_same_school(payload: dict, school_id: UUID) -> None:
    if payload.get("school_id") != str(school_id):
        raise HTTPException(status_code=403, detail="School mismatch")


@router.get("/me", response_model=ProgressionProfileResponse)
async def get_my_progression(
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    user_repo = SQLAlchemyUserRepository(session)
    user = await user_repo.get_by_id(UUID(payload["sub"]))
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    rank = None
    if user.school_id is not None:
        rank = await SQLAlchemyRankRepository(session).get_for_xp(
            user.school_id,
            user.xp,
        )
    clan = (
        await SQLAlchemyClanRepository(session).get_by_id(user.clan_id)
        if user.clan_id
        else None
    )
    transactions = await SQLAlchemyXPTransactionRepository(session).list_by_user(
        user.id
    )
    return ProgressionProfileResponse(
        user_id=str(user.id),
        xp=user.xp,
        rank=_rank_response(rank) if rank else None,
        clan=await _clan_response(clan, user_repo) if clan else None,
        transactions=[
            XPTransactionResponse(
                id=str(transaction.id),
                amount=transaction.amount,
                source_type=transaction.source_type,
                source_id=str(transaction.source_id),
                description=transaction.description,
                created_at=transaction.created_at,
            )
            for transaction in transactions
        ],
    )


@router.get("/ranks", response_model=list[RankResponse])
async def list_ranks(
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    school_id = payload.get("school_id")
    if school_id is None:
        return []
    ranks = await SQLAlchemyRankRepository(session).list_by_school(UUID(school_id))
    return [_rank_response(rank) for rank in ranks]


@router.post(
    "/ranks",
    response_model=RankResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_rank(
    body: CreateRankRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(rank_admin_access),
):
    school_id = payload.get("school_id")
    if school_id is None:
        raise HTTPException(status_code=400, detail="Administrator has no school")
    existing = await SQLAlchemyRankRepository(session).list_by_school(UUID(school_id))
    if any(
        rank.level == body.level or rank.name.casefold() == body.name.casefold()
        for rank in existing
    ):
        raise HTTPException(status_code=409, detail="Rank level or name already exists")
    if existing and body.xp_required <= max(rank.xp_required for rank in existing):
        raise HTTPException(
            status_code=400,
            detail="New rank XP must exceed the current highest threshold",
        )
    rank = await SQLAlchemyRankRepository(session).create(
        Rank(
            school_id=UUID(school_id),
            name=body.name.strip(),
            level=body.level,
            xp_required=body.xp_required,
            icon_url=body.icon_url,
        )
    )
    await session.commit()
    return _rank_response(rank)


@router.post("/ranks/defaults", response_model=list[RankResponse])
async def create_default_ranks(
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(rank_admin_access),
):
    school_id_value = payload.get("school_id")
    if school_id_value is None:
        raise HTTPException(status_code=400, detail="Administrator has no school")
    school_id = UUID(school_id_value)
    repo = SQLAlchemyRankRepository(session)
    existing = await repo.list_by_school(school_id)
    if existing:
        return [_rank_response(rank) for rank in existing]
    created = [
        await repo.create(
            Rank(
                school_id=school_id,
                name=name,
                level=level,
                xp_required=xp_required,
            )
        )
        for name, level, xp_required in DEFAULT_RANKS
    ]
    await session.commit()
    return [_rank_response(rank) for rank in created]


async def _leaderboard_entries(users) -> list[LeaderboardEntryResponse]:
    students = sorted(
        (user for user in users if user.role == Role.STUDENT),
        key=lambda user: (-user.xp, user.username.casefold()),
    )
    return [
        LeaderboardEntryResponse(
            position=index,
            user_id=str(user.id),
            display_name=user.username,
            xp=user.xp,
            rank_id=str(user.rank_id) if user.rank_id else None,
            clan_id=str(user.clan_id) if user.clan_id else None,
        )
        for index, user in enumerate(students, start=1)
    ]


@router.get(
    "/leaderboards/section/{section_id}",
    response_model=list[LeaderboardEntryResponse],
)
async def section_leaderboard(
    section_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    section = await SQLAlchemySectionRepository(session).get_by_id(UUID(section_id))
    if section is None:
        raise HTTPException(status_code=404, detail="Section not found")
    _require_same_school(payload, section.school_id)
    if (
        payload["role"] == Role.STUDENT.value
        and payload.get("section_id") != section_id
    ):
        raise HTTPException(status_code=403, detail="Cannot view another section")
    users = await SQLAlchemyUserRepository(session).list_by_section(section.id)
    return await _leaderboard_entries(users)


@router.get(
    "/leaderboards/school/{school_id}",
    response_model=list[LeaderboardEntryResponse],
)
async def school_leaderboard(
    school_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    _require_same_school(payload, UUID(school_id))
    users = await SQLAlchemyUserRepository(session).list_by_school(UUID(school_id))
    return await _leaderboard_entries(users)


@router.post(
    "/clans",
    response_model=ClanResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_clan(
    body: CreateClanRequest,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(clan_admin_access),
):
    section = await SQLAlchemySectionRepository(session).get_by_id(
        UUID(body.section_id)
    )
    if section is None:
        raise HTTPException(status_code=404, detail="Section not found")
    _require_same_school(payload, section.school_id)
    repo = SQLAlchemyClanRepository(session)
    existing = await repo.list_by_section(section.id)
    if any(clan.name.casefold() == body.name.casefold() for clan in existing):
        raise HTTPException(status_code=409, detail="Clan name already exists")
    clan = await repo.create(Clan(section_id=section.id, name=body.name.strip()))
    await session.commit()
    return await _clan_response(clan, SQLAlchemyUserRepository(session))


@router.get(
    "/clans/section/{section_id}",
    response_model=list[ClanResponse],
)
async def list_clans(
    section_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(get_current_user),
):
    section = await SQLAlchemySectionRepository(session).get_by_id(UUID(section_id))
    if section is None:
        raise HTTPException(status_code=404, detail="Section not found")
    _require_same_school(payload, section.school_id)
    if (
        payload["role"] == Role.STUDENT.value
        and payload.get("section_id") != section_id
    ):
        raise HTTPException(status_code=403, detail="Cannot view another section")
    user_repo = SQLAlchemyUserRepository(session)
    return [
        await _clan_response(clan, user_repo)
        for clan in await SQLAlchemyClanRepository(session).list_by_section(section.id)
    ]


@router.post("/clans/{clan_id}/members/{student_id}", response_model=ClanResponse)
async def add_clan_member(
    clan_id: str,
    student_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(clan_admin_access),
):
    clan_repo = SQLAlchemyClanRepository(session)
    clan = await clan_repo.get_by_id(UUID(clan_id))
    if clan is None:
        raise HTTPException(status_code=404, detail="Clan not found")
    section = await SQLAlchemySectionRepository(session).get_by_id(clan.section_id)
    if section is None:
        raise HTTPException(status_code=404, detail="Section not found")
    _require_same_school(payload, section.school_id)
    user_repo = SQLAlchemyUserRepository(session)
    student = await user_repo.get_by_id(UUID(student_id))
    if (
        student is None
        or student.role != Role.STUDENT
        or student.section_id != clan.section_id
    ):
        raise HTTPException(status_code=400, detail="Student is not in clan section")
    student.clan_id = clan.id
    await user_repo.update(student)
    await session.commit()
    return await _clan_response(clan, user_repo)


@router.delete(
    "/clans/{clan_id}/members/{student_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def remove_clan_member(
    clan_id: str,
    student_id: str,
    session: AsyncSession = Depends(get_db),
    payload: dict = Depends(clan_admin_access),
) -> None:
    clan = await SQLAlchemyClanRepository(session).get_by_id(UUID(clan_id))
    if clan is None:
        raise HTTPException(status_code=404, detail="Clan not found")
    section = await SQLAlchemySectionRepository(session).get_by_id(clan.section_id)
    if section is None:
        raise HTTPException(status_code=404, detail="Section not found")
    _require_same_school(payload, section.school_id)
    user_repo = SQLAlchemyUserRepository(session)
    student = await user_repo.get_by_id(UUID(student_id))
    if student is None or student.clan_id != clan.id:
        raise HTTPException(status_code=404, detail="Clan member not found")
    student.clan_id = None
    await user_repo.update(student)
    await session.commit()
