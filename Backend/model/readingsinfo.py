from sqlalchemy import Column, String, Integer, ForeignKey
from sqlalchemy.orm import relationship
from core.db_connection import Base

class ReadingsInfo(Base):
    __tablename__ = "readingsinfo"

    ReadingsID = Column(String(8), primary_key=True, nullable=False)
    Title = Column(String(255), nullable=False)
    Author = Column(String(255), nullable=False)
    Description = Column(String(250), nullable=False)
    EstimatedMinutes = Column(Integer, nullable=False)
    XPValue = Column(Integer, nullable=False)
    Rating = Column(Integer, nullable=False)
    ModuleTypeID = Column(String(5), ForeignKey("moduletype.ModuleTypeID"), nullable=False)

    # Relationships
    module_type = relationship("ModuleType", back_populates="readings")
    progresses = relationship("ReadingProgress", back_populates="reading")
    blocks = relationship("ReadingBlock", back_populates="reading")
