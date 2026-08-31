"""Response schemas for tasks and progression."""

from datetime import datetime

from pydantic import BaseModel


class TaskResponse(BaseModel):
    id: str
    creator_id: str
    section_id: str
    subject: str
    title: str
    description: str
    task_type: str
    due_date: datetime | None
    xp_reward: int
    status: str
    options: dict[str, str]
    correct_option: str | None
    created_at: datetime


class TaskSubmissionResponse(BaseModel):
    id: str
    task_id: str
    student_id: str
    answer: str
    file_url: str | None
    is_graded: bool
    score: int | None
    feedback: str
    xp_awarded: int
    submitted_at: datetime
    graded_at: datetime | None


class RankResponse(BaseModel):
    id: str
    school_id: str
    name: str
    level: int
    xp_required: int
    icon_url: str | None


class ClanResponse(BaseModel):
    id: str
    section_id: str
    name: str
    total_score: int
    member_count: int = 0


class XPTransactionResponse(BaseModel):
    id: str
    amount: int
    source_type: str
    source_id: str
    description: str
    created_at: datetime


class ProgressionProfileResponse(BaseModel):
    user_id: str
    xp: int
    rank: RankResponse | None
    clan: ClanResponse | None
    transactions: list[XPTransactionResponse]


class LeaderboardEntryResponse(BaseModel):
    position: int
    user_id: str
    display_name: str
    xp: int
    rank_id: str | None
    clan_id: str | None
