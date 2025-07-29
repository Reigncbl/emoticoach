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
engine = create_engine(DATABASE_URL)

def get_db():
    with Session(engine, autoflush=False, autocommit=False) as db:
        yield db
SessionDep = Annotated[Session, Depends(get_db)]

# Create tables if they don't exist
SQLModel.metadata.create_all(engine)