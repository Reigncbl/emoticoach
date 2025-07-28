from sqlalchemy import Column, Integer, String, Text, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import JSONB
from core.db_connection import Base


class ReadingBlock(Base):
    __tablename__ = "readingblocks"

    BlockID = Column('blockid', Integer, primary_key=True, index=True, autoincrement=True)
    ReadingsID = Column('ReadingsID', String(8), ForeignKey(
        "readingsinfo.ReadingsID"), nullable=False)
    OrderIndex = Column('orderindex', Integer, nullable=False)
    # 'heading', 'paragraph', 'image', etc.
    BlockType = Column('blocktype', String(20), nullable=False)
    Content = Column('content', Text)  # Text content
    ImageURL = Column('imageurl', Text)  # For 'image' blocks only
    PageNumber = Column('pagenumber', Integer, nullable=False)
    # Optional: {"fontSize": 18, "fontWeight": "bold", "align": "center"}
    StyleJSON = Column('stylejson', JSONB)

    reading = relationship("ReadingsInfo", back_populates="blocks")
