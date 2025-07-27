import os
import fitz  # PyMuPDF


class PDFMetadataExtractor:
    MODULE_TYPE_MAP = {
        "Communication Studies": {"Books": "COM-B", "Articles": "COM-A"},
        "General Communication Skills": {"Books": "GEN-B", "Articles": "GEN-A"},
        "Group Comm": {"Books": "GRO-B", "Articles": "GRO-A"},
        "Interpersonal Comm": {"Books": "INT-B", "Articles": "INT-A"},
        "Online": {"Books": "ONL-B", "Articles": "ONL-A"},
    }

    def __init__(self, root_dir):
        self.root_dir = root_dir
        self.results = []

    def get_module_type_id(self, dirpath):
        parts = dirpath.split(os.sep)
        if len(parts) < 2:
            return "GEN-B"
        parent_folder = parts[-2]
        type_folder = parts[-1]
        return self.MODULE_TYPE_MAP.get(parent_folder, {}).get(type_folder, "GEN-B")

    def get_title_and_author_from_filename(self, path):
        name = os.path.splitext(os.path.basename(path))[0]
        if " - " in name:
            title, author = name.rsplit(" - ", 1)
        else:
            title, author = name, "UNKNOWN"
        return title.title(), author.strip().upper()

    def extract_pdf_metadata(self, pdf_path, module_type):
        doc = fitz.open(pdf_path)
        meta = doc.metadata
        page_count = doc.page_count
        doc.close()

        title = meta.get("title") or None
        author = meta.get("author") or None
        description = meta.get("subject") or "No description available."

        if not title or len(title.strip()) < 3:
            title, _ = self.get_title_and_author_from_filename(pdf_path)
        if not author or author.lower() in ["", "unknown", "anonymous"]:
            _, author = self.get_title_and_author_from_filename(pdf_path)

        estimated_minutes = max(1, round(page_count))
        xp_value = estimated_minutes * 10
        rating = 3

        return {
            "Title": title,
            "Author": author,
            "Description": description[:250],
            "EstimatedMinutes": estimated_minutes,
            "XPValue": xp_value,
            "Rating": rating,
            "ModuleTypeID": module_type,
            "PDFPath": os.path.splitext(pdf_path)[0],
        }

    def scan(self):
        for dirpath, _, filenames in os.walk(self.root_dir):
            module_type = self.get_module_type_id(dirpath)
            for file in filenames:
                if file.lower().endswith(".pdf"):
                    pdf_path = os.path.join(dirpath, file)
                    metadata = self.extract_pdf_metadata(pdf_path, module_type)
                    self.results.append(metadata)

    def print_all(self):
        for idx, meta in enumerate(self.results, 1):
            print(f"\n📄 {meta['Title']}")
            print(f"  ReadingsID: R-{idx:05d}")
            for k, v in meta.items():
                print(f"  {k}: {v}")
