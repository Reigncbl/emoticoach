import os
from model import ReadingsInfo
from core.db_connection import SessionLocal
from utilities.helpers import generate_readings_id


class ReadingsProcessor:
    def __init__(self, all_metadata):
        self.all_metadata = all_metadata
        self.db = SessionLocal()

    def add_readings_to_db(self):
        try:
            latest = self.db.query(ReadingsInfo).order_by(
                ReadingsInfo.ReadingsID.desc()).first()
            if not latest or not latest.ReadingsID.startswith("R-"):
                next_num = 1
            else:
                try:
                    next_num = int(latest.ReadingsID.split("-")[1]) + 1
                except (IndexError, ValueError):
                    next_num = 1
            added_count = 0
            for meta in self.all_metadata:
                existing = self.db.query(ReadingsInfo).filter(
                    ReadingsInfo.Title == meta["Title"],
                    ReadingsInfo.Author == meta["Author"]
                ).first()
                if existing:
                    print(
                        f" Skipping duplicate: {meta['Title']} by {meta['Author']}")
                    continue
                reading = ReadingsInfo(
                    ReadingsID=f"R-{next_num:05d}",
                    Title=meta["Title"],
                    Author=meta["Author"],
                    Description=meta["Description"],
                    EstimatedMinutes=meta["EstimatedMinutes"],
                    XPValue=meta["XPValue"],
                    Rating=meta["Rating"],
                    ModuleTypeID=meta["ModuleTypeID"]
                )
                self.db.add(reading)
                print(f" Staged for addition: {reading.Title}")
                next_num += 1
                added_count += 1

            if added_count > 0:
                print("\nCommitting readings to the database...")
                self.db.commit()
                print(f" Successfully added {added_count} readings.")
            else:
                print("\nNo new readings to add.")
        except Exception as e:
            self.db.rollback()
            print(f" Error adding readings: {e}")
        finally:
            self.db.close()

    def delete_reading_by_id(self, readings_id):
        db = SessionLocal()
        try:
            reading = db.query(ReadingsInfo).filter(
                ReadingsInfo.ReadingsID == readings_id).first()
            if reading:
                db.delete(reading)
                db.commit()
                print(f" Deleted reading with ID: {readings_id}")
            else:
                print(f" No reading found with ID: {readings_id}")
        except Exception as e:
            db.rollback()
            print(f" Error deleting reading: {e}")
        finally:
            db.close()
