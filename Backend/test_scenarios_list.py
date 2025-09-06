import urllib.request
import json

def test_scenarios_list():
    try:
        print("Testing scenarios list endpoint...")
        with urllib.request.urlopen('http://localhost:8000/scenarios/list') as response:
            data = response.read().decode('utf-8')
            print(f"Status: {response.getcode()}")
            
            # Parse and pretty print the JSON response
            parsed_data = json.loads(data)
            print("Response:")
            print(json.dumps(parsed_data, indent=2))
            
            # Check if scenarios exist
            scenarios = parsed_data.get('scenarios', [])
            print(f"\nNumber of scenarios found: {len(scenarios)}")
            
            if scenarios:
                print("First scenario details:")
                print(json.dumps(scenarios[0], indent=2))
            else:
                print("No scenarios found in database!")
                
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_scenarios_list()
