from fastapi import APIRouter, Depends, HTTPException, Header
from sqlmodel import Session
from pydantic import BaseModel
from typing import Optional

from core.db_connection import get_db as get_session
from services.daily_service import DailyService

router = APIRouter(prefix="/daily", tags=["DailyChallenges"])

class ChallengeOut(BaseModel):
    id: int
    code: str
    title: str
    description: Optional[str] = None
    type: str
    xp_reward: int


class ClaimRequest(BaseModel):
    challenge_id: int


class GenerateResponse(BaseModel):
    ok: bool
    date: str
    challenge_id: Optional[int] = None
    error: Optional[str] = None


class ClaimResponse(BaseModel):
    ok: bool
    awarded: int
    totalXp: Optional[int] = None
    alreadyClaimed: Optional[bool] = None


# -----------------------------
# Get Today’s Challenge
# -----------------------------

@router.get("/challenge", response_model=ChallengeOut)
def get_today_challenge(
    db: Session = Depends(get_session),   # ✅ use get_session everywhere
):
    ch = DailyService.get_today(db)
    if not ch:
        raise HTTPException(status_code=404, detail="No daily challenge for today")

    return ChallengeOut(
        id=ch.id,
        code=ch.code,
        title=ch.title,
        description=ch.description,
        type=ch.type,
        xp_reward=ch.xp_reward,
    )


# -----------------------------
# Generate Today’s Challenge (Optional)
# -----------------------------

@router.post("/generate", response_model=GenerateResponse)
def generate_today_challenge(
    db: Session = Depends(get_session),
):
    result = DailyService.generate_today(db)
    if not result.get("ok"):
        raise HTTPException(status_code=400, detail=result.get("error", "Generation failed"))

    return GenerateResponse(**result)


# -----------------------------
# Claim Challenge
# -----------------------------

@router.post("/claim", response_model=ClaimResponse)
def claim_today_challenge(
    req: ClaimRequest,
    db: Session = Depends(get_session),
    x_uid: str = Header(..., alias="X-UID"),
):
    result = DailyService.claim(
        db=db,
        uid=x_uid,
        challenge_id=req.challenge_id,
    )

    if not result.get("ok"):
        raise HTTPException(
            status_code=400,
            detail=result.get("error", "Claim failed"),
        )

    return ClaimResponse(
        ok=True,
        awarded=result.get("awarded", 0),
        totalXp=result.get("totalXp"),
        alreadyClaimed=result.get("alreadyClaimed", False),
    )
