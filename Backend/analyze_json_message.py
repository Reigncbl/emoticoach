import json
import sys
import os

# Add the parent directory to the Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.emotion_pipeline import get_pipeline, analyze_emotion

def analyze_message_from_json(file_path):
    """Analyze messages from a JSON file using the emotion pipeline"""
    try:
        # Read the JSON file
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        print(f"Analyzing messages from: {file_path}")
        print("=" * 60)
        
        messages = data.get('messages', [])
        if not messages:
            print("No messages found in the file.")
            return
        
        # Analyze each message
        for i, message in enumerate(messages, 1):
            text = message.get('text', '')
            sender = message.get('from', 'Unknown')
            date = message.get('date', 'Unknown date')
            
            print(f"\nMessage {i}:")
            print(f"From: {sender}")
            print(f"Date: {date}")
            print(f"Text: \"{text}\"")
            print("-" * 40)
            
            if text.strip():
                # Analyze the message using emotion pipeline
                result = analyze_emotion(text)
                
                if result.get("pipeline_success", False):
                    print(f"🌐 Language: {result['language_detected']}")
                    print(f"🔤 English: {result['english_text']}")
                    print(f"😊 Emotion: {result['emotion']} {result['emoji']} ({result['confidence']:.1%})")
                    
                    # Print the structured analysis from RAG
                    analysis = result.get('analysis', {})
                    coaching = analysis.get('coaching', {})
                    analysis_data = analysis.get('analysis', {})
                    
                    print("\n--- EmotiCoach Analysis ---")
                    print(f"🔍 Primary Emotion: {analysis_data.get('primary_emotion', 'N/A')}")
                    print(f"🔍 Secondary Emotion: {analysis_data.get('secondary_emotion', 'N/A')}")
                    print(f"📝 Interpretation: {analysis_data.get('interpretation', 'N/A')}")
                    print(f"🏷️ Keywords: {analysis_data.get('keywords', [])}")
                    print(f"💬 Empathetic Statement: {coaching.get('empathetic_statement', 'N/A')}")
                    print("✅ Suggestions:")
                    for suggestion in coaching.get('suggestions', []):
                        print(f"  - {suggestion}")
                    print(f"🗣️ Suggested Response: {coaching.get('suggested_response', 'N/A')}")
                    
                    if result.get('saved_to_file'):
                        print(f"💾 Saved analysis to: {result['saved_to_file']}")
                    
                    print("---------------------------")
                else:
                    print(f"❌ Error: {result.get('error', 'Unknown error')}")
            else:
                print("⚠️ Empty message - skipping analysis")
            
            print("\n" + "=" * 60)
        
    except FileNotFoundError:
        print(f"Error: File not found - {file_path}")
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in file - {file_path}")
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    # Path to the JSON file
    json_file_path = "saved_messages/7633614792_reign.json"
    
    # Check if file exists
    if os.path.exists(json_file_path):
        analyze_message_from_json(json_file_path)
    else:
        print(f"File not found: {json_file_path}")
        print("Please make sure the file exists in the saved_messages directory.")
