from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlmodel import select
from model.readingsinfo import ReadingsInfo
from model.readingblock import ReadingBlock
from core.db_connection import SessionDep

# Create router instead of FastAPI app
book_router = APIRouter()

@book_router.get("/resources/all")
async def get_all_resources(session: SessionDep) -> list[ReadingsInfo]:
    """Get all reading resources"""
    resources = session.exec(select(ReadingsInfo)).all()
    return resources

@book_router.get("/resources/{resource_id}")
async def get_resource(
    resource_id: str,
    session: SessionDep,
) -> ReadingsInfo:
    """Get a specific reading resource by ID"""
    resource = session.get(ReadingsInfo, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    return resource

@book_router.get("/book/{readings_id}/{page}")
async def get_page(
    readings_id:str,
    page:int,
    session:SessionDep,
    )-> list[dict]:
    statement = select(ReadingBlock).where((ReadingBlock.ReadingsID == readings_id) & (ReadingBlock.pagenumber == page)).order_by(ReadingBlock.orderindex)
    page_blocks = session.exec(statement).all()
    if not page_blocks:
        raise HTTPException(status_code=404,detail="Page Not Found" )
    
    # Convert SQLModel objects to dictionaries to ensure proper JSON serialization
    result = []
    for block in page_blocks:
        block_dict = {
            "blockid": block.blockid,
            "ReadingsID": block.ReadingsID,
            "orderindex": block.orderindex,
            "blocktype": block.blocktype,
            "content": block.content,
            "imageurl": block.imageurl,
            "pagenumber": block.pagenumber,
            "stylejson": block.stylejson
        }
        result.append(block_dict)
    
    return result

# === For AppBar of ReadingContentScreen

# Response model for AppBar data
class AppBarData(BaseModel):
    title: str              # Book title
    chapter: str            # Current chapter name, e.g. "Chapter 2"
    percentage: float       # e.g. 0.42 for 42%

@book_router.get("/appbar/{readings_id}/{current_page}")
async def get_appbar_data(
    readings_id: str,
    current_page: int,
    session: SessionDep,
) -> AppBarData:
    """Get data needed for Flutter AppBar (title, chapter, progress)"""

    # Debug log
    print(f"[DEBUG] readings_id={readings_id}, current_page={current_page}")

    # Get the reading resource
    resource = session.get(ReadingsInfo, readings_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")

    # Get total pages using pagenumber
    max_page_query = (
        select(ReadingBlock.pagenumber)
        .where(ReadingBlock.ReadingsID == readings_id)
        .order_by(ReadingBlock.pagenumber.desc())
        .limit(1)
    )
    max_page_result = session.exec(max_page_query).first()
    total_pages = max_page_result if max_page_result else 1
    print(f"[DEBUG] total_pages={total_pages}")

    # Get current chapter (nearest chapter <= current_page)
    chapter_query = (
        select(ReadingBlock.content)
        .where(
            (ReadingBlock.ReadingsID == readings_id) &
            (ReadingBlock.blocktype == "chapter") &
            (ReadingBlock.pagenumber <= current_page)
        )
        .order_by(ReadingBlock.pagenumber.desc())
        .limit(1)
    )
    chapter_result = session.exec(chapter_query).first()
    print(f"[DEBUG] chapter_result={chapter_result}")

    chapter_name = chapter_result if chapter_result else "Unknown Chapter"

    percentage = current_page / total_pages if total_pages > 0 else 0.0
    print(f"[DEBUG] percentage={percentage}")

    return AppBarData(
        title=resource.Title,
        chapter=chapter_name,
        percentage=percentage
    )



