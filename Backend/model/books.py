from sqlalchemy import Column, Integer, Text, TIMESTAMP, func
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Book(Base):
    __tablename__ = "book"

    bookID = Column(Integer, primary_key=True, autoincrement=True)
    bookName = Column(Text, nullable=False)
    bookAuthor = Column(Text)
    bookDescription = Column(Text)
    created_at = Column(TIMESTAMP(timezone=True), server_default=func.now())

    # One-to-many: a book has many pages
    pages = relationship("BookPage", back_populates="book", cascade="all, delete-orphan")
