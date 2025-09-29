from sqlmodel import Session, select
from model.experienceinfo import ExperienceInfo
from model.levelsystem import LevelSystem

def get_user_level_info(user_id: str, session: Session):
    # Debug logs
    print(f"🔎 Incoming user_id: '{user_id}'")

    # Remove whitespace just in case
    user_id = user_id.strip()

    print(f"🔎 Searching for user_id after strip: '{user_id}'")

    user_exp = session.exec(
        select(ExperienceInfo).where(ExperienceInfo.UserId == user_id)
    ).first()

    if not user_exp:
        print(f"⚠️ No Experience record found for user_id: '{user_id}'")
        return {"error": f"Experience record not found for user {user_id}"}

    print(f"✅ Found user: {user_exp.UserId}, XP: {user_exp.Xp}")

    xp = user_exp.Xp or 0

    # 2. Get levels sorted by required XP
    levels = session.exec(select(LevelSystem).order_by(LevelSystem.Exp)).all()
    if not levels:
        return {"error": "No levels defined in LevelSystem"}

    current_level = levels[0]
    next_level = None

    for lvl in levels:
        if xp >= lvl.Exp:
            current_level = lvl
        else:
            next_level = lvl
            break

    # 3. Calculate progress toward next level
    if next_level:
        progress = (xp - current_level.Exp) / float(next_level.Exp - current_level.Exp)
    else:
        progress = 1.0  # max level reached

    # 4. Return structured data
    return {
        "user_id": user_id,
        "xp": xp,
        "level": current_level.LVL,
        "level_name": current_level.Description,
        "image_url": current_level.Image_url,
        "next_level": next_level.LVL if next_level else None,
        "next_level_xp": next_level.Exp if next_level else None,
        "progress": round(progress, 2)  # limit decimals for frontend
    }
