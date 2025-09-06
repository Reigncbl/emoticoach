#!/usr/bin/env python3
"""Direct test of scenario endpoint"""
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_scenarios_endpoint():
    print("Testing scenarios/list endpoint directly...")
    
    try:
        response = client.get("/scenarios/list")
        print(f"Status Code: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                scenarios = data.get('scenarios', [])
                print(f"\n✓ Success! Found {len(scenarios)} scenarios")
                for scenario in scenarios[:3]:
                    print(f"  - {scenario.get('title')} (ID: {scenario.get('id')})")
            else:
                print("✗ API returned success=False")
        else:
            print(f"✗ HTTP Error: {response.status_code}")
            
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_scenarios_endpoint()
