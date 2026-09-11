"""Motor de recompensas de BattleGraph (insignias, poderes, puntos y misiones).

Todas las operaciones son idempotentes usando (source_type, source_id) para no
otorgar dos veces una recompensa. Trabaja contra Supabase (service role).
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

DEFAULT_REWARD_RULES: dict[str, int] = {
    "points_per_correct_answer": 5,
    "points_per_task": 20,
    "points_per_battle_win": 30,
    "points_per_battle_played": 10,
    "points_per_badge": 15,
}


def _first(rows: list[dict] | None) -> dict | None:
    return rows[0] if rows else None


def reward_rules(supabase: Any, school_id: str) -> dict[str, int]:
    try:
        rows = (
            supabase.table("school_settings")
            .select("reward_rules")
            .eq("school_id", school_id)
            .limit(1)
            .execute()
            .data
        )
        rules = dict(DEFAULT_REWARD_RULES)
        rules.update((_first(rows) or {}).get("reward_rules") or {})
        return rules
    except Exception:  # noqa: BLE001
        return dict(DEFAULT_REWARD_RULES)


def points_balance(supabase: Any, student_id: str) -> int:
    rows = (
        supabase.table("points_ledger")
        .select("amount")
        .eq("student_profile_id", student_id)
        .execute()
        .data
        or []
    )
    return sum(int(r.get("amount") or 0) for r in rows)


def award_points(
    supabase: Any,
    school_id: str,
    student_id: str,
    amount: int,
    reason: str,
    source_type: str | None = None,
    source_id: str | None = None,
    membership_id: str | None = None,
) -> bool:
    if amount == 0:
        return False
    try:
        supabase.table("points_ledger").insert(
            {
                "school_id": school_id,
                "student_profile_id": student_id,
                "amount": int(amount),
                "reason": reason,
                "source_type": source_type,
                "source_id": source_id,
                "created_by_membership_id": membership_id,
            }
        ).execute()
        return True
    except Exception:  # noqa: BLE001 - duplicado o tabla ausente
        return False


def award_badge_by_code(
    supabase: Any,
    school_id: str,
    student_id: str,
    code: str,
    source_type: str | None = None,
    source_id: str | None = None,
    membership_id: str | None = None,
) -> bool:
    try:
        badge = _first(
            supabase.table("badges")
            .select("id, points")
            .eq("school_id", school_id)
            .eq("code", code)
            .limit(1)
            .execute()
            .data
        )
        if not badge:
            return False
        exists = (
            supabase.table("student_badges")
            .select("id")
            .eq("student_profile_id", student_id)
            .eq("badge_id", badge["id"])
            .limit(1)
            .execute()
            .data
        )
        if exists:
            return False
        supabase.table("student_badges").insert(
            {
                "school_id": school_id,
                "student_profile_id": student_id,
                "badge_id": badge["id"],
                "source_type": source_type,
                "source_id": source_id,
                "awarded_by_membership_id": membership_id,
            }
        ).execute()
        bonus = int(badge.get("points") or 0)
        if bonus:
            award_points(
                supabase,
                school_id,
                student_id,
                bonus,
                f"insignia:{code}",
                source_type="badge",
                source_id=f"{code}:{student_id}",
            )
        return True
    except Exception:  # noqa: BLE001
        return False


def grant_powerup(
    supabase: Any,
    school_id: str,
    student_id: str,
    powerup_id: str,
    quantity: int = 1,
    source_type: str | None = None,
    source_id: str | None = None,
) -> bool:
    if quantity <= 0:
        return False
    try:
        existing = _first(
            supabase.table("student_powerups")
            .select("id, quantity")
            .eq("student_profile_id", student_id)
            .eq("powerup_id", powerup_id)
            .limit(1)
            .execute()
            .data
        )
        if existing:
            supabase.table("student_powerups").update(
                {"quantity": int(existing.get("quantity") or 0) + quantity}
            ).eq("id", existing["id"]).execute()
        else:
            supabase.table("student_powerups").insert(
                {
                    "school_id": school_id,
                    "student_profile_id": student_id,
                    "powerup_id": powerup_id,
                    "quantity": quantity,
                    "source_type": source_type,
                    "source_id": source_id,
                }
            ).execute()
        return True
    except Exception:  # noqa: BLE001
        return False


def _student_context(supabase: Any, school_id: str, student_id: str) -> dict:
    student = (
        _first(
            supabase.table("student_profiles")
            .select("id, section_id, school_id")
            .eq("id", student_id)
            .limit(1)
            .execute()
            .data
        )
        or {}
    )
    grade = None
    if student.get("section_id"):
        section = _first(
            supabase.table("sections")
            .select("grade")
            .eq("id", student["section_id"])
            .limit(1)
            .execute()
            .data
        )
        grade = (section or {}).get("grade")
    return {"section_id": student.get("section_id"), "grade": grade}


def _grade_average(supabase: Any, student_id: str) -> float | None:
    rows = (
        supabase.table("student_grades")
        .select("score, grade_items(max_score)")
        .eq("student_profile_id", student_id)
        .eq("status", "graded")
        .execute()
        .data
        or []
    )
    values: list[float] = []
    for row in rows:
        score = row.get("score")
        item = row.get("grade_items") or {}
        max_score = float(item.get("max_score") or 0)
        if score is not None and max_score > 0:
            values.append((float(score) / max_score) * 100)
    if not values:
        return None
    return round(sum(values) / len(values), 1)


def _xp_total(supabase: Any, student_id: str) -> int:
    student = (
        _first(
            supabase.table("student_profiles")
            .select("membership_id")
            .eq("id", student_id)
            .limit(1)
            .execute()
            .data
        )
        or {}
    )
    membership_id = student.get("membership_id")
    if not membership_id:
        return 0
    mem = (
        _first(
            supabase.table("memberships")
            .select("user_id")
            .eq("id", membership_id)
            .limit(1)
            .execute()
            .data
        )
        or {}
    )
    if not mem.get("user_id"):
        return 0
    rows = (
        supabase.table("xp_transactions")
        .select("amount")
        .eq("user_id", mem["user_id"])
        .execute()
        .data
        or []
    )
    return sum(int(r.get("amount") or 0) for r in rows)


def _active_missions_for(supabase: Any, school_id: str, ctx: dict) -> list[dict]:
    rows = (
        supabase.table("missions")
        .select(
            "id, scope, grade, section_id, subject_id, goal_type, goal_value, "
            "reward_points, reward_badge_id, reward_powerup_id, reward_powerup_qty"
        )
        .eq("school_id", school_id)
        .eq("status", "active")
        .execute()
        .data
        or []
    )
    result = []
    for mission in rows:
        scope = mission.get("scope")
        matches = (
            scope in {"school", "subject"}
            or (scope == "grade" and mission.get("grade") == ctx.get("grade"))
            or (
                scope == "section"
                and str(mission.get("section_id")) == str(ctx.get("section_id"))
            )
        )
        if matches:
            result.append(mission)
    return result


def _grant_mission_rewards(
    supabase: Any, school_id: str, student_id: str, mission: dict
) -> None:
    points = int(mission.get("reward_points") or 0)
    if points:
        award_points(
            supabase,
            school_id,
            student_id,
            points,
            f"mision:{mission.get('id')}",
            source_type="mission",
            source_id=f"{mission.get('id')}:{student_id}",
        )
    badge_id = mission.get("reward_badge_id")
    if badge_id:
        try:
            code = _first(
                supabase.table("badges")
                .select("code")
                .eq("id", badge_id)
                .limit(1)
                .execute()
                .data
            )
            if code:
                award_badge_by_code(
                    supabase,
                    school_id,
                    student_id,
                    code["code"],
                    source_type="mission",
                    source_id=f"{mission.get('id')}:{student_id}",
                )
        except Exception:  # noqa: BLE001
            pass
    powerup_id = mission.get("reward_powerup_id")
    qty = int(mission.get("reward_powerup_qty") or 0)
    if powerup_id and qty > 0:
        grant_powerup(supabase, school_id, student_id, powerup_id, qty)


def evaluate_event(
    supabase: Any,
    school_id: str,
    student_id: str,
    event_type: str,
    amount: int = 1,
) -> None:
    """Actualiza misiones y entrega recompensas tras un evento del alumno.

    event_type: tasks_completed | tasks_graded | battles_won | battles_played |
                attendance_streak | grade_average | xp_earned | correct_answers
    """
    if not student_id:
        return
    try:
        ctx = _student_context(supabase, school_id, student_id)
        missions = _active_missions_for(supabase, school_id, ctx)
        for mission in missions:
            try:
                _advance_mission(
                    supabase, school_id, student_id, mission, event_type, amount
                )
            except Exception:  # noqa: BLE001
                continue
        _evaluate_default_badges(supabase, school_id, student_id, ctx, event_type)
    except Exception:  # noqa: BLE001
        return


def _advance_mission(
    supabase: Any,
    school_id: str,
    student_id: str,
    mission: dict,
    event_type: str,
    amount: int,
) -> None:
    goal = mission.get("goal_type")
    if goal != event_type:
        return
    current = _first(
        supabase.table("student_missions")
        .select("id, progress, completed")
        .eq("student_profile_id", student_id)
        .eq("mission_id", mission["id"])
        .limit(1)
        .execute()
        .data
    )
    if current and current.get("completed"):
        return
    if goal == "grade_average":
        value = _grade_average(supabase, student_id) or 0
    elif goal == "xp_earned":
        value = _xp_total(supabase, student_id)
    else:
        value = float((current or {}).get("progress") or 0) + amount
    completed = value >= float(mission.get("goal_value") or 0)
    payload = {
        "progress": value,
        "completed": completed,
    }
    if completed:
        payload["completed_at"] = datetime.now(timezone.utc).isoformat()
    if current:
        supabase.table("student_missions").update(payload).eq(
            "id", current["id"]
        ).execute()
    else:
        payload.update(
            {
                "school_id": school_id,
                "student_profile_id": student_id,
                "mission_id": mission["id"],
            }
        )
        supabase.table("student_missions").insert(payload).execute()
    if completed:
        _grant_mission_rewards(supabase, school_id, student_id, mission)


def _evaluate_default_badges(
    supabase: Any, school_id: str, student_id: str, ctx: dict, event_type: str
) -> None:
    if event_type == "tasks_completed":
        count = len(
            supabase.table("assignment_submissions")
            .select("id")
            .eq("student_profile_id", student_id)
            .execute()
            .data
            or []
        )
        if count >= 1:
            award_badge_by_code(
                supabase,
                school_id,
                student_id,
                "primer_paso",
                source_type="auto",
                source_id=f"tasks1:{student_id}",
            )
    if event_type == "battles_won":
        wins = (
            supabase.table("battle_results")
            .select("id")
            .eq("student_profile_id", student_id)
            .eq("result", "victoria")
            .execute()
            .data
            or []
        )
        if len(wins) >= 1:
            award_badge_by_code(
                supabase,
                school_id,
                student_id,
                "conquistador",
                source_type="auto",
                source_id=f"win1:{student_id}",
            )
        if len(wins) >= 5:
            award_badge_by_code(
                supabase,
                school_id,
                student_id,
                "estratega",
                source_type="auto",
                source_id=f"win5:{student_id}",
            )
    if event_type == "grade_average":
        avg = _grade_average(supabase, student_id)
        if avg is not None and avg >= 90:
            award_badge_by_code(
                supabase,
                school_id,
                student_id,
                "mente_brillante",
                source_type="auto",
                source_id=f"avg90:{student_id}",
            )
