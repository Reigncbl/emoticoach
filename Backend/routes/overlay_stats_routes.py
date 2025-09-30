from datetime import datetime, timedelta, date
from fastapi import APIRouter, HTTPException, Query
from sqlmodel import Session, select
from typing import Optional, Dict, Any

from core.db_connection import engine
from model.overlay_usage_stat import OverlayUsageStat

overlay_stats_router = APIRouter(prefix="/overlay-stats", tags=["OverlayStats"])


def _start_of_day_utc(d: date) -> datetime:
    return datetime(d.year, d.month, d.day)


def _end_of_day_utc(d: date) -> datetime:
    return datetime(d.year, d.month, d.day, 23, 59, 59, 999999)


@overlay_stats_router.post("/upsert")
def upsert_today_stats(
    user_id: str = Query(..., description="Firebase user ID"),
    messages_analyzed: int = Query(0, ge=0),
    suggestions_used: int = Query(0, ge=0),
    responses_rephrased: int = Query(0, ge=0),
) -> Dict[str, Any]:
    """
    Upsert today's stats for a user by incrementing the provided values.
    If a row for today's date doesn't exist, it will be created.
    """
    today = datetime.utcnow().date()

    with Session(engine) as session:
        stmt = select(OverlayUsageStat).where(
            OverlayUsageStat.user_id == user_id,
            OverlayUsageStat.stat_date == today,
        )
        row = session.exec(stmt).first()
        if row is None:
            row = OverlayUsageStat(
                user_id=user_id,
                stat_date=today,
                messages_analyzed=messages_analyzed,
                suggestions_used=suggestions_used,
                responses_rephrased=responses_rephrased,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
            )
            session.add(row)
        else:
            row.messages_analyzed += messages_analyzed
            row.suggestions_used += suggestions_used
            row.responses_rephrased += responses_rephrased
            row.updated_at = datetime.utcnow()
        session.commit()
        session.refresh(row)
        return {"success": True, "data": row}


@overlay_stats_router.get("/aggregate")
def aggregate_stats(
    user_id: str = Query(..., description="Firebase user ID"),
    period: str = Query("past_week", description="one of: today, past_week, past_month, all_time"),
) -> Dict[str, Any]:
    """
    Return aggregated stats for the requested period for a given user.
    Matches the three counters used by the overlay UI.
    """
    now = datetime.utcnow()

    period = (period or "").lower()
    start: Optional[datetime] = None

    if period == "today":
        start = _start_of_day_utc(now.date())
    elif period == "past_week":
        start = _start_of_day_utc((now - timedelta(days=7)).date())
    elif period == "past_month":
        start = _start_of_day_utc((now - timedelta(days=30)).date())
    elif period == "all_time":
        start = None
    else:
        raise HTTPException(status_code=400, detail="Invalid period value")

    with Session(engine) as session:
        stmt = select(OverlayUsageStat).where(OverlayUsageStat.user_id == user_id)
        if start is not None:
            stmt = stmt.where(OverlayUsageStat.stat_date >= start.date())
        rows = session.exec(stmt).all()

        total_messages = sum(r.messages_analyzed for r in rows)
        total_suggestions = sum(r.suggestions_used for r in rows)
        total_rephrased = sum(r.responses_rephrased for r in rows)

        return {
            "success": True,
            "data": {
                "messagesAnalyzed": total_messages,
                "suggestionsUsed": total_suggestions,
                "responsesRephrased": total_rephrased,
                "period": period,
                "lastUpdated": now.isoformat(),
            },
        }
