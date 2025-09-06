from sqlmodel import Field, Session, SQLModel, create_engine, select
from fastapi import Depends, FastAPI, HTTPException, Query
from typing import Annotated
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = (
    f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASSWORD')}@"
    f"{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
)

# Create engine with connection pooling and timeout settings
engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,  # Validates connections before use
    pool_recycle=3600,   # Recycle connections every hour
    connect_args={
        "connect_timeout": 10,
        "application_name": "emoticoach_backend",
    }
)

def get_db():
    with Session(engine, autoflush=False, autocommit=False) as db:
        yield db
SessionDep = Annotated[Session, Depends(get_db)]

# Create tables if they don't exist
SQLModel.metadata.create_all(engine)