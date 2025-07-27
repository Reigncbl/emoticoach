from sqlalchemy import Column, String, Integer, Date, ForeignKey
from sqlalchemy.orm import relationship
from core.db_connection import Base

class ReadingProgress(Base):
    __tablename__ = "readingprogress"

    ProgressID = Column(String, primary_key=True)
    UserID = Column(Integer)
    ReadingsID = Column(String, ForeignKey("readingsinfo.ReadingsID"))
    ScrollPosition = Column(String)
    LastReadAt = Column(Date)
    CompletedAt = Column(Date)

    # Relationship
    reading = relationship("ReadingsInfo", back_populates="progresses")
