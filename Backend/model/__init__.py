# Import all models to ensure they are registered with SQLAlchemy
from .moduletype import ModuleType
from .readingsinfo import ReadingsInfo
from .readingprogress import ReadingProgress
from .readingblock import ReadingBlock
from .userinfo import UserInfo
from .scenario_with_config import ScenarioWithConfig
from .scenario_completion import ScenarioCompletion
from .badgeinfo import BadgeInfo
from .levelsystem import LevelSystem
from .userachievement import UserAchievement
from .experienceinfo import ExperienceInfo
from .skillinfo import SkillInfo
from .daily import Challenge, DailyChallengeItem, UserChallengeClaim



__all__ = ["ModuleType", "ReadingsInfo", "ReadingProgress", "ReadingBlock", "UserInfo", "ScenarioWithConfig", "ScenarioCompletion","BadgeInfo","LevelSystem","UserAchievement","ExperienceInfo","SkillInfo","Challenge","DailyChallengeItem","UserChallengeClaim"]