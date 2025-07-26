import pymupdf
from core.db_connection import get_db_connection
from core.cloud_config import upload_image_to_cloudinary
from utilities.helpers import rgb_int_to_hex
import os

BOOK_ID = 1  # This can be passed as an argument
PDF_PATH = os.getenv("PDF_PATH", "./PDFs/Full.pdf")

def process_pdf_to_html(book_id=BOOK_ID):
    conn = get_db_connection()
    cur = conn.cursor()
    
    doc = fitz.open(PDF_PATH)
    print(f"📄 Total Pages: {len(doc)}")

    for page_num, page in enumerate(doc, start=1):
        html_page = f"<!-- Page {page_num} -->\n"

        # Images
        for img_index, img in enumerate(page.get_images(full=True)):
            xref = img[0]
            base_image = doc.extract_image(xref)
            image_bytes = base_image["image"]
            image_ext = base_image["ext"]

            public_id = f"book{book_id}_page{page_num}_img{img_index + 1}"
            result = upload_image_to_cloudinary(
                image_bytes=image_bytes,
                public_id=public_id,
                folder="pdf_uploads"
            )
            image_url = result["secure_url"]
            html_page += f'<img src="{image_url}" alt="Image {img_index + 1}"><br/>\n'

        # Text
        blocks = page.get_text("dict")["blocks"]
        for block in blocks:
            for line in block.get("lines", []):
                html_line = ""
                for span in line.get("spans", []):
                    text = span["text"].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                    font = span["font"]
                    size = span["size"]
                    color = rgb_int_to_hex(span["color"])

                    is_bold = "Bold" in font or "bold" in font
                    is_italic = "Italic" in font or "Oblique" in font

                    style = f"font-size:{size}px; color:{color};"
                    if is_bold:
                        style += " font-weight:bold;"
                    if is_italic:
                        style += " font-style:italic;"

                    html_line += f'<span style="{style}">{text}</span>'
                html_page += f"<p>{html_line}</p>\n"

        cur.execute("""
            INSERT INTO public.bookinfo ("bookID", "bookPage", "bookHtml")
            VALUES (%s, %s, %s)
        """, (book_id, page_num, html_page))

    conn.commit()
    cur.close()
    conn.close()
    print("✅ All pages processed.")
