import urllib.request
import json

def test_api():
    try:
        # Test scenarios list
        print("Testing /scenarios/list...")
        with urllib.request.urlopen('http://localhost:8000/scenarios/list') as response:
            data = response.read().decode('utf-8')
            print(f"Status: {response.getcode()}")
            print(f"Response: {data}")
            
        # Test scenarios start with ID 1
        print("\nTesting /scenarios/start/1...")
        with urllib.request.urlopen('http://localhost:8000/scenarios/start/1') as response:
            data = response.read().decode('utf-8')
            print(f"Status: {response.getcode()}")
            print(f"Response: {data}")
            
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_api()
