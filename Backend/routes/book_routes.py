from fastapi import APIRouter, HTTPException, Body, Depends
from pydantic import BaseModel, field_validator
from sqlmodel import select
from sqlalchemy import func
from typing import Optional, Any, Dict
from uuid import uuid4
import json
from datetime import datetime
from urllib.parse import unquote

from core.db_connection import get_db as get_session
from model.readingsinfo import ReadingsInfo
from model.readingblock import ReadingBlock
from model.readingprogress import ReadingProgress, ReadingProgressRead

# Router
book_router = APIRouter()

# -------------------- Block Models --------------------
class BlockResponse(BaseModel):
    blockid: Optional[int] = None
    ReadingsID: Optional[str] = None
    orderindex: Optional[int] = None
    blocktype: Optional[str] = None
    content: Optional[str] = None
    imageurl: Optional[str] = None
    pagenumber: Optional[int] = None
    stylejson: Optional[Dict[str, Any]] = None

    class Config:
        extra = "ignore"
        validate_assignment = True

# -------------------- Resource Endpoints --------------------

# Fetch all books
@book_router.get("/resources/all")
async def get_all_resources(session = Depends(get_session)) -> list[ReadingsInfo]:
    resources = session.exec(select(ReadingsInfo)).all()
    return resources

@book_router.get("/resources/{resource_id}")
async def get_resource(resource_id: str, session = Depends(get_session)) -> ReadingsInfo:
    resource = session.get(ReadingsInfo, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    return resource

# -------------------- Book Blocks --------------------
class AllBlocksResponse(BaseModel):
    title: str
    blocks: list[dict]

@book_router.get("/book/{readings_id}/all-blocks")
async def get_all_blocks(readings_id: str, session = Depends(get_session)):
    statement = select(ReadingBlock).where(ReadingBlock.ReadingsID == readings_id).order_by(ReadingBlock.orderindex)
    all_blocks = session.exec(statement).all()
    if not all_blocks:
        raise HTTPException(status_code=404, detail=f"No content found for reading ID: {readings_id}")

    resource = session.get(ReadingsInfo, readings_id)
    if not resource:
        raise HTTPException(status_code=404, detail=f"Resource not found for reading ID: {readings_id}")

    result = [_block_to_dict(block) for block in all_blocks]
    return {"title": resource.Title, "blocks": result}

# -------------------- Chapters --------------------
class ChapterResponse(BaseModel):
    title: str
    chapter_title: str
    chapter_number: int
    blocks: list[dict]

@book_router.get("/book/{readings_id}/chapter/{chapter_number}")
async def get_chapter(readings_id: str, chapter_number: int, session = Depends(get_session)):
    statement = select(ReadingBlock).where(ReadingBlock.ReadingsID == readings_id).order_by(ReadingBlock.orderindex)
    all_blocks = session.exec(statement).all()
    if not all_blocks:
        raise HTTPException(status_code=404, detail=f"No content found for reading ID: {readings_id}")

    resource = session.get(ReadingsInfo, readings_id)
    if not resource:
        raise HTTPException(status_code=404, detail=f"Resource not found for reading ID: {readings_id}")

    # Organize chapters
    chapters = []
    current_blocks = []
    current_title = ""
    chapter_num = 0

    for block in all_blocks:
        if block.blocktype.lower() == 'chapter':
            if current_blocks and chapter_num > 0:
                chapters.append({"chapter_number": chapter_num, "chapter_title": current_title, "blocks": current_blocks.copy()})
            chapter_num += 1
            current_title = block.content or f"Chapter {chapter_num}"
            current_blocks = [_block_to_dict(block)]
        else:
            current_blocks.append(_block_to_dict(block))

    if current_blocks and chapter_num > 0:
        chapters.append({"chapter_number": chapter_num, "chapter_title": current_title, "blocks": current_blocks})

    if not chapters and all_blocks:
        chapters.append({"chapter_number": 1, "chapter_title": "Chapter 1", "blocks": [_block_to_dict(block) for block in all_blocks]})

    if chapter_number <= 0 or chapter_number > len(chapters):
        raise HTTPException(status_code=404, detail=f"Chapter {chapter_number} not found")

    requested_chapter = chapters[chapter_number - 1]
    return {
        "title": resource.Title,
        "chapter_title": requested_chapter['chapter_title'],
        "chapter_number": requested_chapter['chapter_number'],
        "blocks": requested_chapter['blocks']
    }

def _block_to_dict(block):
    stylejson_value = block.stylejson
    if stylejson_value is not None:
        if isinstance(stylejson_value, str):
            try:
                stylejson_value = json.loads(stylejson_value)
            except:
                pass
        elif not isinstance(stylejson_value, dict):
            try:
                stylejson_value = dict(stylejson_value)
            except:
                stylejson_value = None
    return {
        "blockid": block.blockid,
        "ReadingsID": block.ReadingsID,
        "orderindex": block.orderindex,
        "blocktype": block.blocktype,
        "content": block.content,
        "imageurl": block.imageurl,
        "stylejson": stylejson_value
    }

# -------------------- Chapter Count --------------------
class ChapterCountResponse(BaseModel):
    total_chapters: int

@book_router.get("/book/{readings_id}/chapters/count", response_model=ChapterCountResponse)
async def get_chapter_count(readings_id: str, session = Depends(get_session)):
    statement = select(func.count(ReadingBlock.blockid)).where(
        (ReadingBlock.ReadingsID == readings_id) & (ReadingBlock.blocktype == "chapter")
    )
    chapter_count = session.exec(statement).first()
    if not chapter_count or chapter_count == 0:
        raise HTTPException(status_code=404, detail="No chapters found")
    return ChapterCountResponse(total_chapters=chapter_count)

# -------------------- Page Endpoint --------------------
class PageResponse(BaseModel):
    title: str
    blocks: list[BlockResponse]

@book_router.get("/book/{readings_id}/page/{page}", response_model=PageResponse)
async def get_page(readings_id: str, page: int, session = Depends(get_session)):
    statement = select(ReadingBlock).where((ReadingBlock.ReadingsID == readings_id) & (ReadingBlock.pagenumber == page)).order_by(ReadingBlock.orderindex)
    page_blocks = session.exec(statement).all()
    if not page_blocks:
        raise HTTPException(status_code=404, detail="Page Not Found")

    resource = session.get(ReadingsInfo, readings_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")

    result = []
    for block in page_blocks:
        stylejson_value = block.stylejson
        if stylejson_value is not None and not isinstance(stylejson_value, (dict, str)):
            try:
                if isinstance(stylejson_value, str):
                    stylejson_value = json.loads(stylejson_value)
                else:
                    stylejson_value = dict(stylejson_value) if stylejson_value else None
            except:
                stylejson_value = None
        result.append(BlockResponse(
            blockid=block.blockid,
            ReadingsID=block.ReadingsID,
            orderindex=block.orderindex,
            blocktype=block.blocktype,
            content=block.content,
            imageurl=block.imageurl,
            pagenumber=block.pagenumber,
            stylejson=stylejson_value
        ))
    return PageResponse(title=resource.Title, blocks=result)

# -------------------- Reading Progress --------------------
class ReadingProgressUpsert(BaseModel):
    mobile_number: str
    readings_id: str
    current_page: int
    last_read_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    # Convert "" to None before parsing
    @field_validator("last_read_at", "completed_at", mode="before")
    def empty_str_to_none(cls, v):
        if v == "" or v is None:
            return None
        return v
    
@book_router.post("/progress/", response_model=ReadingProgressRead)
async def upsert_reading_progress(progress_in: ReadingProgressUpsert = Body(...), session = Depends(get_session)):
    # URL decode the mobile number to handle %2B format
    decoded_mobile = unquote(progress_in.mobile_number)
    
    statement = select(ReadingProgress).where(
        (ReadingProgress.MobileNumber == decoded_mobile) &
        (ReadingProgress.ReadingsID == progress_in.readings_id)
    )
    progress = session.exec(statement).first()

    if progress:
        progress.CurrentPage = progress_in.current_page
        progress.LastReadAt = progress_in.last_read_at
        progress.CompletedAt = progress_in.completed_at
        progress.MobileNumber = decoded_mobile
    else:
        progress = ReadingProgress(
            ProgressID=str(uuid4()),
            ReadingsID=progress_in.readings_id,
            CurrentPage=progress_in.current_page,
            LastReadAt=progress_in.last_read_at,
            CompletedAt=progress_in.completed_at,
            MobileNumber=decoded_mobile
        )
        session.add(progress)

    session.commit()
    session.refresh(progress)
    return progress

# Fetch the reading progress by mobile number (primary endpoint)
@book_router.get("/progress/{mobile_number}/{readings_id}", response_model=ReadingProgressRead)
async def get_reading_progress(mobile_number: str, readings_id: str, session = Depends(get_session)):
    # URL decode the mobile_number to handle %2B format
    decoded_mobile = unquote(mobile_number)
    decoded_readings_id = unquote(readings_id)
    
    print(f"Original mobile_number: {mobile_number}")
    print(f"Decoded mobile_number: {decoded_mobile}")
    
    statement = select(ReadingProgress).where(
        (ReadingProgress.MobileNumber == decoded_mobile) & (ReadingProgress.ReadingsID == decoded_readings_id)
    )
    progress = session.exec(statement).first()
    if not progress:
        raise HTTPException(status_code=404, detail="Reading progress not found")
    return progress

# Bulk fetch all progress for a mobile number (efficient for reading screen)
@book_router.get("/progress-bulk/{mobile_number}", response_model=list[ReadingProgressRead])
async def get_all_progress_by_mobile(mobile_number: str, session = Depends(get_session)):
    # URL decode the mobile_number to handle %2B format
    decoded_mobile = unquote(mobile_number)
    
    print(f"Fetching all progress for mobile: {decoded_mobile}")
    
    statement = select(ReadingProgress).where(ReadingProgress.MobileNumber == decoded_mobile)
    all_progress = session.exec(statement).all()
    
    print(f"Found {len(all_progress)} progress records for mobile: {decoded_mobile}")
    
    return all_progress
