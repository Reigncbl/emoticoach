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


@overlay_stats_router.get("/daily-usage")
def get_daily_usage(
    user_id: str = Query(..., description="Firebase user ID"),
    period: str = Query(
        "past_week",
        description="one of: today, past_week, past_month, all_time",
    ),
) -> Dict[str, Any]:
    """Return day-by-day usage statistics for the requested period."""

    now = datetime.utcnow().date()
    period_normalized = (period or "").lower()

    # Determine the start date for the requested period
    if period_normalized == "today":
        start_date = now
    elif period_normalized == "past_week":
        start_date = now - timedelta(days=6)
    elif period_normalized == "past_month":
        start_date = now - timedelta(days=29)
    elif period_normalized == "all_time":
        start_date = None
    else:
        raise HTTPException(status_code=400, detail="Invalid period value")

    with Session(engine) as session:
        stmt = select(OverlayUsageStat).where(OverlayUsageStat.user_id == user_id)

        if start_date is not None:
            stmt = stmt.where(OverlayUsageStat.stat_date >= start_date)

        rows = list(session.exec(stmt))

    rows.sort(key=lambda r: r.stat_date)

    if period_normalized == "all_time" and rows:
        start_date = rows[0].stat_date
    elif start_date is None:
        # No data in database – default to the past week window
        start_date = now - timedelta(days=6)

    if start_date is None:
        start_date = now

    if start_date > now:
        start_date = now

    days_span = (now - start_date).days

    # Build lookup for quick access
    rows_by_date = {row.stat_date: row for row in rows}

    daily_points = []
    for offset in range(days_span + 1):
        current_date = start_date + timedelta(days=offset)
        row = rows_by_date.get(current_date)

        messages = row.messages_analyzed if row else 0
        suggestions = row.suggestions_used if row else 0
        rephrased = row.responses_rephrased if row else 0
        total_usage = messages + suggestions + rephrased

        daily_points.append(
            {
                "date": current_date.isoformat(),
                "messagesAnalyzed": messages,
                "suggestionsUsed": suggestions,
                "responsesRephrased": rephrased,
                "totalUsage": total_usage,
            }
        )

    return {
        "success": True,
        "data": {
            "period": period_normalized,
            "points": daily_points,
            "generatedAt": datetime.utcnow().isoformat(),
        },
    }
