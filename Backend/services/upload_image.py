from core.cloud_config import upload_image

def handle_pdf_image_upload(image_bytes, book_id, page, index):
    public_id = f"books/book{book_id}_page{page}_img{index}"
    return upload_image(image_bytes, public_id=public_id, folder="books")
