import os
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))


from core.cloud_config import upload_image
from model import ReadingsInfo, ReadingBlock
from core.db_connection import SessionLocal, engine, Base
from utilities.extractor import PDFUtility
from sqlalchemy.orm import Session
import fitz  # PyMuPDF
import json
import sqlalchemy as sa
from sqlalchemy import text, inspect
from sqlalchemy.exc import NoSuchTableError
from sqlalchemy import func, and_
from core.cloud_config import init_cloudinary

# ========== Helpers ==========

# Initialize PDF utility instance
pdf_utility = PDFUtility("")


def classify_block(text, font_size):
    if len(text.strip()) < 100 and font_size >= 16:
        return "heading"
    return "paragraph"


def get_reading_by_title_author(session: Session, title, author):
    author_parts = [part.strip() for part in author.split('and')]
    filters = [
        func.lower(ReadingsInfo.Title) == func.lower(title)
    ]
    for part in author_parts:
        if part:
            filters.append(func.lower(
                ReadingsInfo.Author).contains(func.lower(part)))

    return session.query(ReadingsInfo).filter(and_(*filters)).first()


def handle_pdf_image_upload(image_bytes, book_id, page, index):
    public_id = f"books/book{book_id}_page{page}_img{index}"
    return upload_image(image_bytes, public_id=public_id, folder="books")

# ========== Main Extraction Logic ==========


def extract_blocks_from_pdf(session: Session, path):
    # Use PDF utility method instead of local function
    title, author = pdf_utility.get_title_and_author_from_filename(path)
    print(f"🔍 Looking for: Title='{title}', Author='{author}'")

    reading = get_reading_by_title_author(session, title, author)

    if not reading:
        print(f"❌ No reading found for: {title} by {author}")
        # Let's also check what's actually in the database
        all_readings = session.query(ReadingsInfo).all()
        print(f"📚 Available readings in database:")
        for r in all_readings[:5]:  # Show first 5
            print(f"   Title='{r.Title}', Author='{r.Author}'")
        return

    reading_id = reading.ReadingsID
    existing_blocks = session.query(ReadingBlock).filter(ReadingBlock.ReadingsID == reading_id).count()
    if existing_blocks > 0:
        print(f"✅ Blocks already exist for '{title}', skipping")
        return
    doc = fitz.open(path)
    block_order = 0

    for page_number, page in enumerate(doc, start=1):
        blocks_on_page = page.get_text("dict")["blocks"]

        for b in blocks_on_page:
            if "lines" in b:
                text = ""
                max_font_size = 0
                bold = False

                for line in b["lines"]:
                    for span in line["spans"]:
                        text += span["text"] + " "
                        max_font_size = max(max_font_size, span["size"])
                        if "bold" in span.get("font", "").lower():
                            bold = True

                text = text.strip()
                if not text:
                    continue

                style = json.dumps({
                    "fontSize": round(max_font_size),
                    "fontWeight": "bold" if bold else "normal",
                    "align": "left"
                })

                block = ReadingBlock(
                    ReadingsID=reading_id,
                    OrderIndex=block_order,
                    BlockType=classify_block(text, max_font_size),
                    Content=text,
                    ImageURL=None,
                    PageNumber=page_number,
                    StyleJSON=style
                )
                session.add(block)
                block_order += 1

            elif b.get("image"):
                # HD image extraction
                zoom_matrix = fitz.Matrix(5.0, 5.0)
                pix = page.get_pixmap(matrix=zoom_matrix, clip=b["bbox"])

                image_url = handle_pdf_image_upload(pix.tobytes(
                    "png"), reading_id, page_number, block_order)

                block = ReadingBlock(
                    ReadingsID=reading_id,
                    OrderIndex=block_order,
                    BlockType="image",
                    Content=None,
                    ImageURL=image_url.get('secure_url'),
                    PageNumber=page_number,
                    StyleJSON=None
                )
                session.add(block)
                block_order += 1

    session.commit()
    print(f"✅ {block_order} blocks inserted for '{title}'")

# ========== Entry ==========


def main():
    init_cloudinary()
    rootdir = os.getcwd()
    session = SessionLocal()
  
    try:
        for subdir, dirs, files in os.walk(rootdir):
            for file in files:
                # print os.path.join(subdir, file)
                filepath = subdir + os.sep + file

                if filepath.endswith(".pdf"):
                    print(filepath)
                 
                    extract_blocks_from_pdf(session, filepath)
    finally:
        session.close()


if __name__ == "__main__":
    main()
