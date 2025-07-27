from sqlalchemy import Column, Integer, String, Text, ForeignKey
from sqlalchemy.orm import relationship
from core.db_connection import Base


class ReadingBlock(Base):
    __tablename__ = "readingblocks"

    BlockID = Column(Integer, primary_key=True, index=True, autoincrement=True)
    ReadingsID = Column(String, ForeignKey(
        "readingsinfo.ReadingsID"), nullable=False)
    OrderIndex = Column(Integer, nullable=False)
    # 'heading', 'paragraph', 'image', etc.
    BlockType = Column(String, nullable=False)
    Content = Column(Text)  # Text content
    ImageURL = Column(Text)  # For 'image' blocks only
    PageNumber = Column(Integer)
    # Optional: {"fontSize": 18, "fontWeight": "bold", "align": "center"}
    StyleJSON = Column(Text)

    reading = relationship("ReadingsInfo", back_populates="blocks")
