#!/usr/bin/env python3
"""Test API endpoints directly"""
import requests
import json

# Test different ports
ports = [8000, 8001]
base_urls = [f"http://localhost:{port}" for port in ports]

def test_endpoints():
    for base_url in base_urls:
        print(f"\nTesting {base_url}...")
        
        try:
            # Test root endpoint
            response = requests.get(f"{base_url}/", timeout=5)
            print(f"✓ Root endpoint: {response.status_code} - {response.json()}")
            
            # Test scenarios list endpoint
            response = requests.get(f"{base_url}/scenarios/list", timeout=5)
            print(f"Scenarios list: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                print(f"✓ Scenarios endpoint successful!")
                print(f"Success: {data.get('success')}")
                scenarios = data.get('scenarios', [])
                print(f"Number of scenarios: {len(scenarios)}")
                
                if scenarios:
                    print("First 3 scenarios:")
                    for i, scenario in enumerate(scenarios[:3]):
                        print(f"  {i+1}. {scenario.get('title')} (ID: {scenario.get('id')})")
                        print(f"     Category: {scenario.get('category')}, Difficulty: {scenario.get('difficulty')}")
            else:
                print(f"✗ Scenarios endpoint failed: {response.text}")
                
        except requests.exceptions.RequestException as e:
            print(f"✗ Connection failed: {e}")

if __name__ == "__main__":
    test_endpoints()
