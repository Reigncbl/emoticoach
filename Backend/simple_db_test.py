#!/usr/bin/env python3
"""Simple database test"""
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

print("Environment variables:")
print(f"DB_HOST: {os.getenv('DB_HOST')}")
print(f"DB_PORT: {os.getenv('DB_PORT')}")
print(f"DB_NAME: {os.getenv('DB_NAME')}")
print(f"DB_USER: {os.getenv('DB_USER')}")
print(f"DB_PASSWORD: {'*' * len(os.getenv('DB_PASSWORD', '')) if os.getenv('DB_PASSWORD') else 'Not set'}")

# Test database connection
try:
    from core.db_connection import engine
    print("\n✓ Database engine created successfully")
    
    from sqlmodel import Session, text
    with Session(engine) as session:
        print("✓ Database connection successful")
        
        # Simple query
        result = session.exec(text("SELECT 1 as test"))
        value = result.fetchone()[0]
        print(f"✓ Query test successful: {value}")
        
except Exception as e:
    print(f"✗ Database error: {e}")
    import traceback
    traceback.print_exc()
