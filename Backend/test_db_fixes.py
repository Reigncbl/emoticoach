#!/usr/bin/env python3
"""Test database connection and scenario endpoints after fixes"""
import sys
import os
import asyncio
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.scenario import get_available_scenarios, start_conversation

async def test_database_fixes():
    print("Testing database connection fixes...")
    
    try:
        print("\n1. Testing get_available_scenarios()...")
        scenarios = get_available_scenarios()
        print(f"✓ Successfully retrieved {len(scenarios)} scenarios")
        
        if scenarios:
            first_scenario = scenarios[0]
            print(f"First scenario: {first_scenario['title']} (ID: {first_scenario['id']})")
            
            print(f"\n2. Testing start_conversation() with scenario ID {first_scenario['id']}...")
            result = await start_conversation(first_scenario['id'])
            
            if result.success:
                print("✓ Successfully started conversation")
                print(f"  Character: {result.character_name}")
                print(f"  First message: {result.first_message[:50]}...")
            else:
                print(f"✗ Failed to start conversation: {result.error}")
        else:
            print("✗ No scenarios found")
            
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_database_fixes())
