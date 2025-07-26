from sqlalchemy import Column, Integer, BigInteger, Text, ForeignKey
from sqlalchemy.orm import relationship
from Model.books import Base

class BookPage(Base):
    __tablename__ = "bookinfo"  # or "book_page" if you prefer

    id = Column(Integer, primary_key=True, autoincrement=True)
    bookID = Column(Integer, ForeignKey("book.bookID"), nullable=False)
    bookPage = Column(BigInteger)  # could be Integer if not exceeding 2 billion
    bookHtml = Column(Text)

    # Relationship
    book = relationship("Book", back_populates="pages")
