# services/daily_service.py

from typing import Optional, Dict, Any, List
from datetime import datetime, timezone, timedelta

from sqlmodel import Session, select

from model.daily import Challenge, DailyChallengeItem, UserChallengeClaim
from model.experienceinfo import ExperienceInfo


# ---- Helper: today's date in Asia/Manila ----
def today_ph():
  """
  Return today's date in Asia/Manila timezone as a date object.
  """
  ph_tz = timezone(timedelta(hours=8))
  return datetime.now(ph_tz).date()


class DailyService:
    """
    DB-only daily challenges:
      - get today's single challenge
      - generate today's challenge (admin utility)
      - claim challenge (adds XP into ExperienceInfo; idempotent via PK)
    """

    # --------- READ today's challenge ---------
    @staticmethod
    def get_today(db: Session) -> Optional[Challenge]:
        d = today_ph()

        # Find today's assignment
        row = db.exec(
            select(DailyChallengeItem).where(DailyChallengeItem.date == d)
        ).first()

        if not row:
            return None

        ch = db.get(Challenge, row.challenge_id)
        return ch

    # --------- GENERATE today's challenge (1 per day) ---------
    @staticmethod
    def generate_today(db: Session, count: int = 1) -> Dict[str, Any]:
        """
        Generate today's daily challenge.
        Right now we pick ONE random challenge from `challenges`.
        """
        d = today_ph()

        # Clear existing items for today
        db.exec(f"DELETE FROM daily_challenge_items WHERE date = '{d.isoformat()}'")

        # Pick ONE random challenge
        rows = db.exec(
            "SELECT id FROM challenges ORDER BY random() LIMIT :n",
            params={"n": count},
        ).all()

        if not rows:
            return {"ok": False, "date": d.isoformat(), "error": "No challenges found"}

        # Insert all selected ids (usually 1)
        for (cid,) in rows:
            db.add(DailyChallengeItem(date=d, challenge_id=cid))
        db.commit()

        # Return the first one as today's main id
        first_id = rows[0][0]

        return {
            "ok": True,
            "date": d.isoformat(),
            "challenge_id": first_id,
        }

    # --------- CLAIM today's challenge (no rules) ---------
    @staticmethod
    def claim(
        db: Session,
        uid: str,
        challenge_id: int,
    ) -> Dict[str, Any]:
        d = today_ph()

        # 1) Must be today's challenge
        in_set = db.get(DailyChallengeItem, (d, challenge_id))
        if not in_set:
            return {"ok": False, "error": "Challenge is not available today"}

        # 2) Challenge must exist
        ch = db.get(Challenge, challenge_id)
        if not ch:
            return {"ok": False, "error": "Challenge not found"}

        # 3) No extra rule checks for now: opening is enough
        # (If you add rules back later, enforce them here.)
        try:
            # Idempotent claim – composite PK (user_id, challenge_id, date)
            db.add(UserChallengeClaim(user_id=uid, challenge_id=ch.id, date=d))

            # Ensure ExperienceInfo row exists, then update XP
            xp_row = db.get(ExperienceInfo, uid)
            if not xp_row:
                xp_row = ExperienceInfo(UserId=uid, Xp=0)
                db.add(xp_row)
                db.flush()

            xp_row.Xp += ch.xp_reward
            db.commit()

            return {"ok": True, "awarded": ch.xp_reward, "totalXp": xp_row.Xp}

        except Exception:
            # Likely duplicate (user already claimed this challenge today)
            db.rollback()
            xp_row = db.get(ExperienceInfo, uid)
            return {
                "ok": True,
                "awarded": 0,
                "alreadyClaimed": True,
                "totalXp": (xp_row.Xp if xp_row else None),
            }
