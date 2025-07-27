from sqlalchemy import Column, String
from sqlalchemy.orm import relationship
from core.db_connection import Base

class ModuleType(Base):
    __tablename__ = "moduletype"

    ModuleTypeID = Column(String, primary_key=True)
    Category = Column(String)
    Description = Column(String)

    # Relationship to readingsinfo
    readings = relationship("ReadingsInfo", back_populates="module_type")
