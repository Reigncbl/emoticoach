#!/usr/bin/env python3
"""Test the fixed scenario start endpoint"""
import requests
import json
import time

def test_scenario_start():
    print("Testing the fixed /scenarios/start/1 endpoint...")
    
    # Wait a moment for server to start
    time.sleep(2)
    
    try:
        # Test scenario start endpoint
        response = requests.get("http://127.0.0.1:8000/scenarios/start/1", timeout=10)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print("✓ Success! Response:")
            print(json.dumps(data, indent=2))
        else:
            print(f"✗ Error {response.status_code}:")
            print(response.text)
            
    except requests.exceptions.ConnectionError:
        print("✗ Connection failed - backend might not be running")
    except Exception as e:
        print(f"✗ Error: {e}")

if __name__ == "__main__":
    test_scenario_start()
