import os
from utilities.extractor import PDFMetadataExtractor
# Assumes this prints nicely from model
from utilities.readinginfo import ReadingsProcessor
from core.db_connection import engine
from sqlalchemy import text


# ADDS BOOKS
if __name__ == "__main__":
    PDF_ROOT = r"C:\Users\John Carlo\emoticoach\emoticoach\Backend\PDFs"

    if not os.path.isdir(PDF_ROOT):
        print(f" Folder not found: {PDF_ROOT}")
    else:
        print(" Scanning PDFs...")
        extractor = PDFMetadataExtractor(PDF_ROOT)
        extractor.scan()

        if extractor.results:
            print("Inserting to DB...")
            ReadingsProcessor(extractor.results).add_readings_to_db()
        else:
            print(" No metadata found.")
