from .book_routes import book_router as book_routes
from .message_routes import message_router as message_routes
from .scenario_route import scenario_router as scenario_routes

__all__ = ["book_routes","message_routes","scenario_routes"]