from .book_routes import book_router as book_routes
from .message_routes import message_router as message_routes
from .userinfo_routes import userinfo_router as userinfo_routes

from .scenario_route import scenario_router as scenario_routes

__all__ = ["book_routes","message_routes", "userinfo_routes","scenario_routes"]
