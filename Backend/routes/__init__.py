from .book_routes import book_router as book_routes
from .message_routes import message_router as message_routes
from .userinfo_routes import userinfo_router as userinfo_routes
from .rag_routes import rag_router as rag_routes
from .multiuser import multiuser_router as multiuser_routes 
from .scenario_route import scenario_router as scenario_routes
from .experience_routes import experience_router as experience_routes
from .overlay_stats_routes import overlay_stats_router as overlay_stats_routes
from .user_achievement_routes import achievement_router as achievement_routes
from .cache_routes import cache_router as cache_routes
from .support_routes import support_router as support_routes

__all__ = [
	"book_routes",
	"message_routes",
	"userinfo_routes",
	"scenario_routes",
	"rag_routes",
	"multiuser_routes",
	"experience_routes",
	"overlay_stats_routes",
	"achievement_routes",
	"cache_routes",
	"support_routes",
]
