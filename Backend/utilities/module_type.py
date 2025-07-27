from model.moduletype import ModuleType
from core.db_connection import SessionLocal
import os
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


class ModuleSeeder:
    def __init__(self):
        self.session = SessionLocal()
        self.base_modules = {
            "COM": "Explores the foundational principles and theories of communication studies.",
            "GEN": "Covers broad skills in both verbal and non-verbal general communication.",
            "GRO": "Focuses on group dynamics and communication strategies in collaborative settings.",
            "INT": "Highlights effective interpersonal communication across relationships and contexts.",
            "ONL": "Provides insights into digital communication within online platforms and media."
        }
        self.category_suffixes = {
            "Article": "A",
            "Book": "B"
        }

    def seed(self):
        for prefix, description in self.base_modules.items():
            for category, suffix in self.category_suffixes.items():
                mod_id = f"{prefix}-{suffix}"
                if self.session.query(ModuleType).filter_by(ModuleTypeID=mod_id).first():
                    continue
                module = ModuleType(
                    ModuleTypeID=mod_id,
                    Category=category,
                    Description=description
                )
                self.session.add(module)
                print(f"➕ Inserted {mod_id}: {category}")
        self.session.commit()

    def close(self):
        self.session.close()
        print("✅ All module types inserted and session closed.")


# Usage
if __name__ == "__main__":
    seeder = ModuleSeeder()
    seeder.seed()
    seeder.close()
