from fastapi import APIRouter, HTTPException
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