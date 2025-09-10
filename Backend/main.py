import os
from dotenv import load_dotenv

# Load .env variables before anything else

print("Loading environment variables...")
load_dotenv()

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

print("Import user routes...")

#from routes import message_routes

from routes import userinfo_routes

print("Import scenario routes...")

from routes import scenario_routes

print("Import book routes...")

from routes import book_routes


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

# Include routers
app.include_router(book_routes)
#app.include_router(message_routes)
app.include_router(userinfo_routes)
app.include_router(scenario_routes)


# Health check endpoint
@app.get("/")
async def root():
    return {"message": "EmotiCoach API is running"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)