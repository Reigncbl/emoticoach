#!/usr/bin/env python3
"""Check database tables and content"""
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from core.db_connection import engine
from sqlmodel import Session, text

def check_database():
    print("Checking database...")
    
    try:
        with Session(engine) as session:
            # List all tables
            result = session.exec(text("SELECT name FROM sqlite_master WHERE type='table';"))
            tables = result.fetchall()
            print("Tables in database:")
            for table in tables:
                print(f"  - {table[0]}")
            
            # Check if scenarios_with_config table exists
            if any('scenarios_with_config' in str(table) for table in tables):
                print("\n✓ scenarios_with_config table exists")
                
                # Count rows
                result = session.exec(text("SELECT COUNT(*) FROM scenarios_with_config;"))
                count = result.fetchone()[0]
                print(f"Number of rows: {count}")
                
                # Show all rows
                if count > 0:
                    result = session.exec(text("SELECT id, title, category, is_active FROM scenarios_with_config;"))
                    rows = result.fetchall()
                    print("Scenarios:")
                    for row in rows:
                        print(f"  - ID: {row[0]}, Title: {row[1]}, Category: {row[2]}, Active: {row[3]}")
                else:
                    print("No scenarios found in database")
            else:
                print("✗ scenarios_with_config table does not exist")
                
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    check_database()
