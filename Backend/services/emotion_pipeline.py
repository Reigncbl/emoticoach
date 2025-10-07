import os
import time
import requests
from typing import Dict, List, Tuple, Optional
from groq import Groq
from dotenv import load_dotenv
from huggingface_hub import InferenceClient

load_dotenv()

# Import cache for emotion analysis caching
try:
    from services.cache import MessageCache
    CACHE_AVAILABLE = True
except ImportError:
    CACHE_AVAILABLE = False
    print("Warning: Cache not available for emotion analysis")

HF_MODEL = "j-hartmann/emotion-english-distilroberta-base"

class EmotionEmbedder:
    """A class to generate emotion embeddings for text using a pre-trained model with translation support."""
    
    def __init__(self, model_name: str = HF_MODEL, cache_dir: Optional[str] = None):
        """Initialize the emotion embedder with a pre-trained model and translation capability.
        
        Args:
            model_name: Name of the pre-trained model to use
            cache_dir: Directory to cache the model files (optional)
        """
        self.model_name = model_name
        
        # HF Inference API setup with new syntax
        self.hf_client = InferenceClient(
            provider="hf-inference",
            api_key=os.environ.get("HF_TOKEN")
        )
        
        if not os.environ.get("HF_TOKEN"):
            raise ValueError("HF_TOKEN not found in environment variables")

        # The labels must be in the correct order as expected by the model's output.
        # For "j-hartmann/emotion-english-distilroberta-base", this is the order.
        self.labels = {
            0: 'anger', 1: 'disgust', 2: 'fear', 3: 'joy', 4: 'neutral', 5: 'sadness', 6: 'surprise'
        }
        self.label_names = list(self.labels.values())
        print(f"Emotion analysis configured for Hugging Face model: {self.model_name}")
        
        # Initialize Groq client for translation
        self.groq_client = None
        self.groq_model = None
        groq_api_key = os.getenv("api_key")  # Using your existing env variable
        groq_model_name = os.getenv("model")  # Using your existing env variable
        
        if groq_api_key and groq_model_name:
            try:
                self.groq_client = Groq(api_key=groq_api_key)
                self.groq_model = groq_model_name
                print("Groq client initialized for translation support")
            except Exception as e:
                print(f"Warning: Could not initialize Groq client: {e}")
                print("Translation will be skipped for non-English text")

    def _translate_text(self, text: str) -> str:
        """Translate text to English if needed using Groq."""
        if not self.groq_client or not self.groq_model:
            return text
        
        # Simple heuristic to check if text might be non-English
        # You can make this more sophisticated
        if text.isascii() and len([word for word in text.split() if word.isalpha()]) > 0:
            # Likely English, return as is
            return text
        
        try:
            translate_prompt = f"""Translate this text to English. Preserve the emotional tone and meaning exactly. If already in English, return it unchanged. Output ONLY the translated text, no explanations.

Text: {text}"""
            
            response = self.groq_client.chat.completions.create(
                messages=[
                    {"role": "system", "content": "You are a precise translator. Output only the translated text, preserving emotional nuance."},
                    {"role": "user", "content": translate_prompt}
                ],
                model=self.groq_model,
                temperature=0,
                max_tokens=150
            )
            translated = response.choices[0].message.content.strip()
            # Remove common prefixes that LLM might add
            prefixes = ["Translation:", "English:", "Translated:", "Output:"]
            for prefix in prefixes:
                if translated.startswith(prefix):
                    translated = translated[len(prefix):].strip()
            return translated if translated else text
        except Exception as e:
            print(f"Translation error: {e}")
            return text

    def get_embedding(self, text: str, translate_if_needed: bool = True) -> List[float]:
        """Generate emotion embedding for the input text.
        
        Args:
            text: Input text to analyze
            translate_if_needed: Whether to translate non-English text
            
        Returns:
            List of emotion probabilities corresponding to different emotions
        """
        # Check cache first
        if CACHE_AVAILABLE:
            cached_emotion = MessageCache.get_cached_emotion_analysis(text)
            if cached_emotion and 'vector' in cached_emotion:
                print(f"✅ Cache hit for emotion embedding")
                return cached_emotion['vector']
        
        processed_text = text
        if translate_if_needed:
            processed_text = self._translate_text(text)
        
        try:
            # Use the new client syntax for text classification
            api_response = self.hf_client.text_classification(
                text=processed_text,
                model=self.model_name
            )
            
            # The API returns a list of dicts. We need to process them.
            scores_dict = {item['label'].lower(): item['score'] for item in api_response}
            
            # Reorder scores to match self.label_names
            embedding = [scores_dict.get(label, 0.0) for label in self.label_names]
            
            # Apply a small penalty to neutral class to reduce bias
            if 'neutral' in self.label_names:
                neutral_idx = self.label_names.index('neutral')
                embedding[neutral_idx] = max(0, embedding[neutral_idx] - 0.1) # Reduce confidence slightly
            
            # Cache the result
            if CACHE_AVAILABLE:
                emotion_data = {
                    'vector': embedding,
                    'labels': {label: score for label, score in zip(self.label_names, embedding)},
                    'top': self.label_names[embedding.index(max(embedding))]
                }
                MessageCache.cache_emotion_analysis(text, emotion_data)
                print(f"💾 Cached emotion embedding")
            
            return embedding
        except Exception as e:
            print(f"Emotion embedding error: {e}")
            return [0.0] * len(self.label_names)

    def get_emotion_scores(self, text: str, translate_if_needed: bool = True) -> Dict[str, float]:
        """Get emotion scores with their labels.
        
        Args:
            text: Input text to analyze
            translate_if_needed: Whether to translate non-English text
            
        Returns:
            Dictionary mapping emotion labels to their probabilities
        """
        embedding = self.get_embedding(text, translate_if_needed)
        return {label: score for label, score in zip(self.label_names, embedding)}

    def get_dominant_emotion(self, text: str, translate_if_needed: bool = True) -> Tuple[str, float]:
        """Get the most probable emotion for the input text.
        
        Args:
            text: Input text to analyze
            translate_if_needed: Whether to translate non-English text
            
        Returns:
            Tuple of (emotion_label, probability_score)
        """
        scores = self.get_emotion_scores(text, translate_if_needed)
        if not scores:
            return ("neutral", 1.0)
        dominant_emotion = max(scores.items(), key=lambda x: x[1])
        return dominant_emotion

    def analyze_text_full(self, text: str, translate_if_needed: bool = True) -> Dict:
        """Get complete emotion analysis for text, using LLM fallback for dominant emotion if needed."""
        # Check cache first for complete analysis
        if CACHE_AVAILABLE:
            cached_emotion = MessageCache.get_cached_emotion_analysis(text)
            if cached_emotion and 'vector' in cached_emotion and 'labels' in cached_emotion:
                print(f"✅ Cache hit for full emotion analysis")
                return {
                    "original_text": text,
                    "processed_text": cached_emotion.get("processed_text"),
                    "embedding": cached_emotion['vector'],
                    "emotion_scores": cached_emotion['labels'],
                    "dominant_emotion": cached_emotion['top'],
                    "dominant_score": cached_emotion['labels'].get(cached_emotion['top'], 0.0)
                }
        
        processed_text = text
        if translate_if_needed:
            processed_text = self._translate_text(text)

        embedding = self.get_embedding(processed_text, translate_if_needed=False)  # Already processed
        scores = {label: score for label, score in zip(self.label_names, embedding)}
        
        # Use get_final_emotion for robust dominant emotion (LLM fallback)
        dominant_emotion = self.get_final_emotion(processed_text)
        dominant_score = scores.get(dominant_emotion, 0.0)

        result = {
            "original_text": text,
            "processed_text": processed_text if processed_text != text else None,
            "embedding": embedding,
            "emotion_scores": scores,
            "dominant_emotion": dominant_emotion,
            "dominant_score": dominant_score
        }
        
        # Cache the complete analysis
        if CACHE_AVAILABLE:
            cache_data = {
                'vector': embedding,
                'labels': scores,
                'top': dominant_emotion,
                'processed_text': processed_text if processed_text != text else None
            }
            MessageCache.cache_emotion_analysis(text, cache_data)
            print(f"💾 Cached full emotion analysis")
        
        return result

    def get_final_emotion(self, text: str, threshold: float = 0.6) -> str:
        """
        Get final single-label emotion.
        Uses classifier by default, but calls LLM if confidence < threshold.
        """
        scores = self.get_emotion_scores(text, translate_if_needed=False)
        if not scores:
            return "neutral"
        dominant_emotion, dominant_score = max(scores.items(), key=lambda x: x[1])
        
        # If confident enough, return classifier result
        if dominant_score >= threshold:
            return dominant_emotion

        # Otherwise, double-check with LLM
        if not self.groq_client or not self.groq_model:
            print("Warning: Groq not available, falling back to classifier output")
            return dominant_emotion

        check_prompt = f"""
        You are an emotion classification checker.
        You must ONLY answer with one of these 7 labels:
        [joy, sadness, anger, fear, surprise, disgust, neutral].

        Message: "{text}"
        Classifier Prediction: {dominant_emotion}

        If the classifier prediction matches the true emotion, repeat it.
        If it is wrong, replace it with the correct one.
        Answer with ONLY the label.
        """
        
        try:
            response = self.groq_client.chat.completions.create(
                messages=[{"role": "user", "content": check_prompt}],
                model=self.groq_model,
                temperature=0,
                max_tokens=10
            )
            llm_label = response.choices[0].message.content.strip().lower()
            # Ensure the label is valid
            if llm_label in self.label_names:
                return llm_label
            else:
                print(f"LLM returned invalid label '{llm_label}', falling back to classifier.")
                return dominant_emotion
        except Exception as e:
            print(f"LLM check failed: {e}, falling back to classifier")
            return dominant_emotion


# Global instance for backward compatibility
_emotion_pipeline = None

def get_pipeline() -> EmotionEmbedder:
    """Get or create the global emotion pipeline instance."""
    global _emotion_pipeline
    if _emotion_pipeline is None:
        _emotion_pipeline = EmotionEmbedder()
    return _emotion_pipeline

def interpretation(emotion_data, dominant_emotion: str = None) -> str:
    """
    Provide human-readable interpretation of emotion analysis results using Groq LLM.
    
    Args:
        emotion_data: Either a dictionary of emotion scores OR full emotion analysis result
        dominant_emotion: The dominant emotion (optional, will be calculated if not provided)
        
    Returns:
        Human-readable interpretation string
    """
    # Handle different input formats
    if isinstance(emotion_data, dict):
        if "emotion_scores" in emotion_data:
            # Full analysis result from analyze_emotion
            emotion_scores = emotion_data["emotion_scores"]
            dominant_emotion = emotion_data.get("dominant_emotion", dominant_emotion)
        elif "pipeline_success" in emotion_data:
            # Full pipeline result
            if emotion_data.get("pipeline_success"):
                emotion_scores = emotion_data["emotion_scores"]
                dominant_emotion = emotion_data.get("dominant_emotion", dominant_emotion)
            else:
                return f"Unable to analyze emotions: {emotion_data.get('error', 'Unknown error')}"
        else:
            # Assume it's just emotion scores
            emotion_scores = emotion_data
    else:
        return "Unable to analyze emotions from the provided data."
    
    if not emotion_scores:
        return "Unable to analyze emotions from the provided text."
    
    if not dominant_emotion:
        dominant_emotion = max(emotion_scores.items(), key=lambda x: x[1])[0]
    
    dominant_score = emotion_scores.get(dominant_emotion, 0.0)
    
    # Determine confidence level
    if dominant_score >= 0.8:
        confidence = "very confident"
    elif dominant_score >= 0.6:
        confidence = "confident"
    elif dominant_score >= 0.4:
        confidence = "somewhat confident"
    else:
        confidence = "uncertain"

    sorted_emotions = sorted(emotion_scores.items(), key=lambda x: x[1], reverse=True)
    secondary_emotions = [emotion for emotion, score in sorted_emotions[1:3] if score > 0.1]

    # Get Groq client from pipeline
    from services.emotion_pipeline import get_pipeline
    pipeline = get_pipeline()
    groq_client = getattr(pipeline, "groq_client", None)
    groq_model = getattr(pipeline, "groq_model", None)
    
    # Extract text and context information
    text = emotion_data.get("original_text") if isinstance(emotion_data, dict) and "original_text" in emotion_data else None
    user_context = emotion_data.get("user_context") if isinstance(emotion_data, dict) else None
    analysis_method = emotion_data.get("analysis_method") if isinstance(emotion_data, dict) else None
    processed_text = emotion_data.get("processed_text") if isinstance(emotion_data, dict) else None
    
    # Build context information
    context_lines = []
    if user_context:
        context_lines.append(f"User: {user_context}")
    if analysis_method:
        context_lines.append(f"Analysis method: {analysis_method}")
    if processed_text and processed_text != text:
        context_lines.append(f"Processed text: {processed_text}")
    if secondary_emotions:
        secondary_str = ', '.join([f"{e} ({emotion_scores[e]:.2f})" for e in secondary_emotions])
        context_lines.append(f"Secondary emotions: {secondary_str}")
    
    context_str = "\n".join(context_lines) if context_lines else "No additional context"
    
    # Use Groq LLM to generate interpretation
    if groq_client and groq_model and text:
        prompt = f"""You are an emotion analysis interpreter. Provide a brief, natural explanation of the emotion detected in the text.

Text: "{text}"
Dominant Emotion: {dominant_emotion}
Confidence Score: {dominant_score:.2f} ({confidence})
{context_str}

Generate a concise interpretation that explains:
1. Why this emotion was detected in the text
2. What specific words or phrases contribute to this emotion
3. The overall emotional tone

Format your response as: "[Your explanation here]"
Keep it brief and insightful (2-3 sentences max).
"""
        
        try:
            response = groq_client.chat.completions.create(
                messages=[{"role": "user", "content": prompt}],
                model=groq_model,
                temperature=0.3,
                max_tokens=150
            )
            interpretation_text = response.choices[0].message.content.strip()
            if interpretation_text:
                # Add secondary emotions if present
                if secondary_emotions:
                    interpretation_text += f" Secondary emotions detected: {', '.join(secondary_emotions)}."
                return interpretation_text
        except Exception as e:
            print(f"Groq interpretation error: {e}")
    
    # Fallback if Groq is unavailable or fails
    fallback = ""
    if text:
        fallback = f"The text '{text}' shows emotional patterns consistent with {dominant_emotion}."
    else:
        fallback = f"Emotional patterns consistent with {dominant_emotion}."
    if secondary_emotions:
        fallback += f" Secondary emotions: {', '.join(secondary_emotions)}."
    return fallback

def analyze_emotion(text: str, user_name: str = None) -> Dict:
    """
    Analyze emotion using the complete pipeline with LLM fallback.
    
    Args:
        text: Text to analyze
        user_name: Optional user name for context
        
    Returns:
        Dictionary with analysis results
    """
    try:
        pipeline = get_pipeline()
        
        # Use the full analysis method which includes get_final_emotion
        analysis = pipeline.analyze_text_full(text, translate_if_needed=True)
        
        # Add interpretation
        interpretation_text = interpretation(
            analysis["emotion_scores"], 
            analysis["dominant_emotion"]
        )
        
        return {
            "pipeline_success": True,
            "original_text": analysis["original_text"],
            "processed_text": analysis["processed_text"],
            "emotion_scores": analysis["emotion_scores"],
            "dominant_emotion": analysis["dominant_emotion"],
            "dominant_score": analysis["dominant_score"],
            "embedding": analysis["embedding"],
            "interpretation": interpretation_text,
            "user_context": user_name,
            "analysis_method": "classifier_with_llm_fallback"
        }
        
    except Exception as e:
        return {
            "pipeline_success": False,
            "error": str(e),
            "user_context": user_name
        }