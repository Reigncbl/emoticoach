import os
from dotenv import load_dotenv

# Load .env variables before anything else
print("Loading environment variables...")
load_dotenv()

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import (
    book_routes,
    userinfo_routes,
    scenario_routes,
    message_routes,
    rag_routes,
    multiuser_routes,
    experience_routes,
    overlay_stats_routes,
    achievement_routes,
    cache_routes,
    support_routes,
    daily_routes
)

print("Done importing routes...")

# Create FastAPI app
app = FastAPI(
    title="EmotiCoach API",
    description="API for EmotiCoach reading platform",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Include routers with their prefixes
app.include_router(book_routes)
app.include_router(message_routes)
app.include_router(userinfo_routes)
app.include_router(scenario_routes)
app.include_router(rag_routes)
app.include_router(multiuser_routes)
app.include_router(experience_routes)
app.include_router(overlay_stats_routes)
app.include_router(achievement_routes)
app.include_router(cache_routes)
app.include_router(support_routes)
app.include_router(daily_routes)
# Health check endpoint
@app.get("/")
async def root():
    return {"message": "EmotiCoach API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    # For development, run with single worker
    # In production (Docker), use the CMD with multiple workers
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)), workers=1)