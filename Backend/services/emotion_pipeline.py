import os
import json
import re
import sys
from typing import Dict, Any, List
from datetime import datetime
from dotenv import load_dotenv

# Add the parent directory to the Python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Import existing services
from services.translation import translate_texts, get_translation_prompt, clean_llm_output
from services.RAGPipeline import SimpleRAG
from groq import Groq
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch
import torch.nn.functional as F

# Load environment variables
load_dotenv()

class EmotionPipeline:
    """Complete emotion analysis pipeline: Translation → Classification → RAG Analysis"""
    
    def __init__(self):
        # Initialize Groq client for translation
        self.groq_client = Groq(api_key=os.getenv("api_key"))
        self.groq_model = os.getenv("model") or "llama3-8b-8192"
        
        # Initialize emotion classifier
        model_name = "j-hartmann/emotion-english-distilroberta-base"
        self.emotion_tokenizer = AutoTokenizer.from_pretrained(model_name)
        self.emotion_model = AutoModelForSequenceClassification.from_pretrained(model_name)
        
        # Define emotion labels with emojis
        self.emotion_emojis = {
            "anger": "🤬",
            "disgust": "🤢", 
            "fear": "😨",
            "joy": "😀",
            "neutral": "😐",
            "sadness": "😭",
            "surprise": "😲"
        }
        
        # Initialize RAG for insights and suggestions
        self.rag = SimpleRAG()
        self._setup_rag_knowledge()
    
    def classify_emotion(self, text: str) -> Dict[str, Any]:
        """Classify emotion using the loaded model"""
        try:
            inputs = self.emotion_tokenizer(text, return_tensors="pt", truncation=True, padding=True, max_length=512)
            with torch.no_grad():
                outputs = self.emotion_model(**inputs)
                probs = F.softmax(outputs.logits, dim=1).squeeze()
            
            top_idx = probs.argmax().item()
            emotion = self.emotion_model.config.id2label[top_idx].lower()
            confidence = float(probs[top_idx])
            
            return {
                "emotion": emotion,
                "confidence": confidence,
                "emoji": self.emotion_emojis.get(emotion, "😐")
            }
        except Exception as e:
            print(f"Classification failed: {e}")
            return {
                "emotion": "neutral",
                "confidence": 0.5,
                "emoji": "😐"
            }
        
    def _setup_rag_knowledge(self):
        """Add emotion coaching knowledge to RAG"""
        coaching_knowledge = [
            # Anger management 🤬
            "Anger 🤬 is a normal emotion that signals when something is wrong. To manage anger: take deep breaths, count to 10, identify the trigger, express feelings calmly, and take a break if needed. Channel anger constructively by addressing the root cause.",
            
            # Joy enhancement 😀
            "Joy 😀 is a positive emotion that should be celebrated and shared. To enhance joy: practice gratitude, share good moments with others, engage in activities you love, and savor positive experiences. Joy strengthens relationships and improves wellbeing.",
            
            # Sadness support 😭
            "Sadness 😭 is a natural response to loss or disappointment. To cope with sadness: acknowledge your feelings, reach out for support, engage in self-care, and give yourself time to process emotions. Sadness helps us process difficult experiences.",
            
            # Fear management 😨
            "Fear 😨 can be protective but shouldn't control your life. To manage fear: identify what you're afraid of, challenge negative thoughts, practice relaxation techniques, and take small steps forward. Face fears gradually with support.",
            
            # Surprise handling 😲
            "Surprise 😲 can be positive or negative. To handle surprise: take a moment to process what happened, assess the situation calmly, and adapt your response accordingly. Surprise keeps us alert and helps us learn.",
            
            # Disgust processing 🤢
            "Disgust 🤢 helps us avoid harmful things. To process disgust: identify what triggered the feeling, determine if it's justified, and take appropriate action to address or avoid the trigger. Disgust protects us from threats.",
            
            # Neutral state 😐
            "Neutral 😐 emotions indicate balance and calm. In neutral states: maintain mindfulness, stay present, and be open to experiencing other emotions as they arise. Neutral is a peaceful baseline state.",
            
            # General emotional intelligence
            "Emotional intelligence involves recognizing, understanding, and managing emotions effectively. The seven core emotions are: anger 🤬, joy 😀, sadness 😭, fear 😨, surprise 😲, disgust 🤢, and neutral 😐. Practice self-awareness, empathy, and healthy emotional expression.",
            
            # Communication tips
            "When expressing emotions: use 'I' statements, be specific about feelings, choose appropriate timing, and listen actively to others' responses. Each emotion serves a purpose in communication.",
            
            # Stress management
            "Stress management techniques include: deep breathing, regular exercise, adequate sleep, healthy eating, time management, and seeking support when needed. Recognize which emotions accompany your stress."
        ]
        
        for knowledge in coaching_knowledge:
            self.rag.add_document(knowledge, {"type": "emotion_coaching"})
    
    
    
    def translate_if_needed(self, text: str, detected_emotion: str = "neutral") -> str:
        """Translate text if it's in Tagalog"""
        language = self.detect_language(text)
        
        if language == "tagalog":
            try:
                prompt = get_translation_prompt(text, detected_emotion)
                response = self.groq_client.chat.completions.create(
                    messages=[{"role": "user", "content": prompt}],
                    model=self.groq_model,
                    temperature=0.3,
                    max_tokens=200
                )
                translated = clean_llm_output(response.choices[0].message.content)
                return translated if translated else text
            except Exception as e:
                print(f"Translation failed: {e}")
                return text
        
        return text
    
    def save_message_to_json(self, complete_analysis: Dict[str, Any]) -> str:
        """Save complete message analysis to JSON file in saved_messages directory"""
        try:
            # Create saved_messages directory if it doesn't exist
            save_dir = "saved_messages"
            os.makedirs(save_dir, exist_ok=True)
            
            # Generate filename based on timestamp and emotion
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            emotion = complete_analysis.get("emotion", "unknown")
            filename = f"{save_dir}/message_{timestamp}_{emotion}.json"
            
            # Save complete analysis to JSON file
            with open(filename, "w", encoding="utf-8") as f:
                json.dump(complete_analysis, f, indent=2, ensure_ascii=False)
            
            return filename
            
        except Exception as e:
            print(f"Failed to save message: {e}")
            return None
    
    def create_metadata(self, original_text: str, english_text: str, emotion_result: Dict) -> Dict[str, Any]:
        """Create metadata from analysis results"""
        metadata = {
            "original_text": original_text,
            "english_text": english_text,
            "emotion": emotion_result["emotion"],
            "confidence": emotion_result["confidence"],
            "emoji": emotion_result["emoji"],
            "language_detected": self.detect_language(original_text),
            "timestamp": datetime.now().isoformat(),
            "processing_pipeline": "translation->classification->rag"
        }
        
        return metadata
    
    def get_rag_insights(self, metadata: Dict[str, Any], message_history: List[Dict[str, Any]], user_name: str = None) -> Dict[str, Any]:
        """Get emotion insights, tone analysis, and suggestions from RAG using few-shot prompting."""
        emotion = metadata["emotion"]
        confidence = metadata["confidence"]
        emoji = metadata.get("emoji", self.emotion_emojis.get(emotion, "😐"))
        text = metadata["english_text"]
        
        # Prepare message history for the prompt
        history_summary = "No recent messages."
        if message_history:
            recent_emotions = [msg.get("emotion", "unknown") for msg in message_history[-5:]]
            history_summary = f"Recent emotional patterns: {', '.join(recent_emotions)}"

        # Determine user context for personalized coaching
        user_context = ""
        if user_name:
            user_context = f"You are providing personalized coaching for {user_name}. "

        # Few-shot prompt optimized for Taglish/Filipino context with flexible user support
        prompt = f"""You are EmotiCoach, an expert AI emotional wellness coach specializing in Filipino culture and Taglish communication. {user_context}Your goal is to provide culturally sensitive, empathetic, and actionable advice. Always respond in valid JSON format.

### Example 1 (English):
**User Message:** "I'm so angry at my boss! He's always undermining me."
**Emotion:** anger 🤬 (98.1% confidence)
**History:** "Recent emotional patterns: sadness, anger, sadness"
**Your JSON Response:**
```json
{{
  "analysis": {{
    "primary_emotion": "Anger",
    "interpretation": "The user is feeling intense anger and frustration, likely due to a perceived injustice or lack of respect at work. The recurring pattern of sadness and anger suggests an ongoing issue that is causing significant distress.",
    "keywords": ["angry", "boss", "undermining"]
  }},
  "coaching": {{
    "empathetic_statement": "It sounds incredibly frustrating to feel undermined by your boss, especially when it's a recurring issue. Your feelings are completely valid.",
    "suggestions": [
      "Take deep breaths to calm your immediate anger before reacting",
      "Document specific examples of the undermining behavior",
      "Consider having a calm, professional conversation with your boss about the impact",
      "Focus on what you can control - your excellent work and professional responses"
    ],
    "suggested_response": "I'm feeling really frustrated about this situation at work. I need some time to think before I respond."
  }}
}}

### User's Current Situation:
**User Message:** "{text}"
**Emotion:** {emotion} {emoji} ({confidence:.1%} confidence)
**History:** "{history_summary}"

**Your JSON Response:**
"""
        
        # Get RAG response
        rag_response_str = self.rag.generate_response(prompt)
        
        # Parse the JSON response
        try:
            # Clean the response to extract only the JSON part
            json_match = re.search(r'```json\n({.*?})\n```', rag_response_str, re.DOTALL)
            if json_match:
                json_str = json_match.group(1)
                parsed_response = json.loads(json_str)
            else:
                # Fallback if the ```json ``` block is missing
                parsed_response = json.loads(rag_response_str)
            
            return parsed_response

        except (json.JSONDecodeError, TypeError) as e:
            print(f"Failed to parse RAG JSON response: {e}")
            # Return a fallback response
            return {
                "analysis": {
                    "primary_emotion": emotion.capitalize(),
                    "interpretation": "Could not parse the detailed analysis, but the primary emotion is clear."
                },
                "coaching": {
                    "empathetic_statement": f"It seems you're feeling {emotion}. Your feelings are valid.",
                    "suggestions": ["Take a moment to breathe and acknowledge how you feel."],
                    "suggested_response": rag_response_str  # Return the raw string if parsing fails
                }
            }
    
    def load_saved_messages(self) -> List[Dict[str, Any]]:
        """Load all saved messages from saved_messages directory"""
        saved_messages = []
        save_dir = "saved_messages"
        
        if os.path.exists(save_dir):
            for filename in os.listdir(save_dir):
                if filename.endswith('.json'):
                    try:
                        filepath = os.path.join(save_dir, filename)
                        with open(filepath, 'r', encoding='utf-8') as f:
                            message_data = json.load(f)
                            saved_messages.append(message_data)
                    except Exception as e:
                        print(f"Error loading {filename}: {e}")
        
        return saved_messages
    
    def get_message_history_summary(self) -> Dict[str, Any]:
        """Get summary statistics from saved messages"""
        saved_messages = self.load_saved_messages()
        
        if not saved_messages:
            return {"total_messages": 0, "emotion_distribution": {}}
        
        # Count emotions
        emotion_counts = {}
        languages = {}
        
        for msg in saved_messages:
            emotion = msg.get("emotion", "unknown")
            language = msg.get("language_detected", "unknown")
            
            emotion_counts[emotion] = emotion_counts.get(emotion, 0) + 1
            languages[language] = languages.get(language, 0) + 1
        
        return {
            "total_messages": len(saved_messages),
            "emotion_distribution": emotion_counts,
            "language_distribution": languages,
            "most_common_emotion": max(emotion_counts, key=emotion_counts.get) if emotion_counts else None,
            "recent_messages": saved_messages[-5:] if len(saved_messages) >= 5 else saved_messages
        }
    
    def process_message(self, text: str, user_name: str = None) -> Dict[str, Any]:
        """
        Complete pipeline: Input → Translation → Classification → Metadata → RAG Analysis
        """
        try:
            # Step 1: Initial emotion classification (for translation context)
            initial_classification = self.classify_emotion(text)
            
            # Step 2: Translation (if Tagalog)  
            english_text = self.translate_if_needed(text, initial_classification["emotion"])
            
            # Step 3: Final emotion classification on English text
            final_classification = self.classify_emotion(english_text)
            
            # Step 4: Create metadata
            metadata = self.create_metadata(text, english_text, final_classification)
            
            # Step 5: Get message history for RAG context
            message_history = self.load_saved_messages()
            
            # Step 6: RAG analysis for insights and suggestions (with user context)
            rag_insights = self.get_rag_insights(metadata, message_history, user_name)
            
            # Step 7: Combine everything into final output
            result = {
                **metadata,
                "analysis": rag_insights,
                "message_history_summary": self.get_message_history_summary(),
                "pipeline_success": True
            }
            
            # Step 8: Save complete analysis (including suggestions) to JSON
            saved_file = self.save_message_to_json(result)
            if saved_file:
                result["saved_to_file"] = saved_file
            
            return result
            
        except Exception as e:
            return {
                "error": str(e),
                "pipeline_success": False,
                "original_text": text,
                "timestamp": datetime.now().isoformat()
            }

# Global pipeline instance
_pipeline: EmotionPipeline = None

def get_pipeline() -> EmotionPipeline:
    """Get or create pipeline instance"""
    global _pipeline
    if _pipeline is None:
        _pipeline = EmotionPipeline()
    return _pipeline

# Convenience function
def analyze_emotion(text: str, user_name: str = None) -> Dict[str, Any]:
    """Quick function to analyze emotion in text"""
    pipeline = get_pipeline()
    return pipeline.process_message(text, user_name)

# Example usage
if __name__ == "__main__":
    # Test the pipeline
    test_messages = [
        "Galit na galit ako sa nangyari!",  # Tagalog anger
        "I'm so happy today!",             # English joy
        "Nalulungkot ako ngayon...",       # Tagalog sadness
    ]
    
    pipeline = EmotionPipeline()
    
    for message in test_messages:
        print(f"\n{'='*60}")
        print(f"INPUT: {message}")
        print(f"{'='*60}")
        
        result = pipeline.process_message(message)
        
        if result["pipeline_success"]:
            print(f"🌐 Language: {result['language_detected']}")
            print(f"🔤 English: {result['english_text']}")
            print(f"😊 Emotion: {result['emotion']} {result['emoji']} ({result['confidence']:.1%})")
            
            # Print the structured analysis from RAG
            analysis = result.get('analysis', {})
            coaching = analysis.get('coaching', {})
            
            print("\n--- EmotiCoach Analysis ---")
            print(f"� Interpretation: {analysis.get('analysis', {}).get('interpretation', 'N/A')}")
            print(f"💬 Empathetic Statement: {coaching.get('empathetic_statement', 'N/A')}")
            print("✅ Suggestions:")
            for suggestion in coaching.get('suggestions', []):
                print(f"  - {suggestion}")
            print(f"🗣️ Suggested Response: {coaching.get('suggested_response', 'N/A')}")
            print("---------------------------\n")

        else:
            print(f"❌ Error: {result['error']}")
