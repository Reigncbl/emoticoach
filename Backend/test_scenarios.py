#!/usr/bin/env python3
"""Test script to check scenarios in database"""
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.scenario import get_available_scenarios
from core.db_connection import engine
from sqlmodel import Session
from model.scenario_with_config import ScenarioWithConfig

def test_scenarios():
    print("Testing scenario database access...")
    
    try:
        # Check database connection
        with Session(engine) as session:
            print("✓ Database connection successful")
            
            # Count scenarios
            count = session.query(ScenarioWithConfig).count()
            print(f"✓ Total scenarios in database: {count}")
            
            # Get active scenarios
            active_scenarios = session.query(ScenarioWithConfig).filter(ScenarioWithConfig.is_active == True).all()
            print(f"✓ Active scenarios: {len(active_scenarios)}")
            
            # List all scenarios
            all_scenarios = session.query(ScenarioWithConfig).all()
            print("\nAll scenarios in database:")
            for scenario in all_scenarios:
                print(f"  - ID: {scenario.id}, Title: {scenario.title}, Active: {scenario.is_active}")
            
        # Test service function
        print("\nTesting get_available_scenarios service function...")
        scenarios = get_available_scenarios()
        print(f"✓ Service returned {len(scenarios)} scenarios")
        
        for scenario in scenarios:
            print(f"  - {scenario['title']} (ID: {scenario['id']})")
            
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_scenarios()
