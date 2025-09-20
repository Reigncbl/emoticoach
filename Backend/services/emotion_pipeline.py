import os
from huggingface_hub import InferenceClient
from typing import Dict, List, Tuple, Optional
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

class EmotionEmbedder:
    """A class to generate emotion embeddings for text using a pre-trained model with translation support."""
    
    def __init__(self, model_name: str = "j-hartmann/emotion-english-distilroberta-base", cache_dir: Optional[str] = None):
        """Initialize the emotion embedder with a pre-trained model and translation capability.
        
        Args:
            model_name: Name of the pre-trained model to use
            cache_dir: Directory to cache the model files (optional, not used with inference)
        """
        self.model_name = model_name
        self.cache_dir = cache_dir  # Keep for compatibility, but not used
        
        print(f"Initializing Hugging Face Inference client for {self.model_name}...")
        self.client = InferenceClient(model=model_name)
        self.labels = {0: 'anger', 1: 'disgust', 2: 'fear', 3: 'joy', 4: 'neutral', 5: 'sadness', 6: 'surprise'}
        print("Hugging Face Inference client initialized successfully!")
        
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


    def _get_translation_prompt(self, tagalog_text: str) -> str:
        """Creates a translation prompt for Tagalog to English."""
        return f"""You are a professional translator specializing in emotional and culturally-aware translations from Tagalog to English. Your goal is to not just translate the words, but to convey the true meaning and feeling of the original text.

Here are a few examples to guide you:

Example 1:
Tagalog Text: "Kumusta na kayo? Matagal na tayong hindi nagkikita! Miss na miss ko na kayo."
Correct English Translation: "Hey there, how's it going? It's been forever since we saw each other! I miss you guys so, so much."
(Note: The translation uses casual language like "Hey there" and "forever" to match the friendly, emotional tone of the original.)

Example 2:
Tagalog Text: "Grabe! Ang init dito sa Pinas!"
Correct English Translation: "Whoa, it's so incredibly hot here in the Philippines!"
(Note: "Grabe" is a difficult word to translate directly. "Whoa" or "Wow" captures the exclamatory and emotional tone.)

Now, please provide only the translation for the following text. Do not add any extra commentary or explanations.

Tagalog Text: {tagalog_text}

English Translation:"""

    def _clean_translation_output(self, text: str) -> str:
        """Clean translation output from LLM."""
        if not text:
            return ""
        text = text.strip().strip('"\'')
        
        # Remove common prefixes that the model might add
        prefixes_to_remove = [
            'english translation:', 'translation:', 'english:', 'translated:',
            'the english translation is:', 'in english:'
        ]
        
        text_lower = text.lower()
        for prefix in prefixes_to_remove:
            if text_lower.startswith(prefix):
                text = text[len(prefix):].strip()
                break
                
        return text

    def _translate_text(self, text: str) -> str:
        """Always translate text to English using Groq, regardless of language."""
        if not self.groq_client or not self.groq_model:
            print("Warning: Translation not available, using original text")
            return text
        try:
            prompt = self._get_translation_prompt(text)
            response = self.groq_client.chat.completions.create(
                messages=[{"role": "user", "content": prompt}],
                model=self.groq_model,
                temperature=0.2,
                max_tokens=200
            )
            translated = self._clean_translation_output(response.choices[0].message.content)
            print(f"Translated: '{text}' -> '{translated}'")
            return translated if translated else text
        except Exception as e:
            print(f"Translation error: {e}, using original text")
            return text

    def get_embedding(self, text: str, translate_if_needed: bool = True) -> List[float]:
        """Generate emotion embedding for the input text.
        
        Args:
            text: Input text to analyze
            translate_if_needed: Whether to translate non-English text
            
        Returns:
            List of emotion probabilities corresponding to different emotions
        """
        # Translate if needed and translation is available
        processed_text = text
        if translate_if_needed:
            processed_text = self._translate_text(text)
        
        # Use Hugging Face Inference
        result = self.client.text_classification(processed_text, top_k=7)
        
        # Create dict from label to score
        scores_dict = {item['label']: item['score'] for item in result}
        
        # Apply a small penalty to neutral class to reduce bias
        if 'neutral' in scores_dict:
            scores_dict['neutral'] = max(0, scores_dict['neutral'] - 0.1)  # Reduce by 0.1 since it's probability
        
        # Renormalize
        total = sum(scores_dict.values())
        if total > 0:
            scores_dict = {k: v / total for k, v in scores_dict.items()}
        
        # Return in order
        return [scores_dict.get(label, 0.0) for label in self.labels.values()]

    def get_emotion_scores(self, text: str, translate_if_needed: bool = True) -> Dict[str, float]:
        """Get emotion scores with their labels.
        
        Args:
            text: Input text to analyze
            translate_if_needed: Whether to translate non-English text
            
        Returns:
            Dictionary mapping emotion labels to their probabilities
        """
        embedding = self.get_embedding(text, translate_if_needed)
        return {label: score for label, score in zip(self.labels.values(), embedding)}

    def get_dominant_emotion(self, text: str, translate_if_needed: bool = True) -> Tuple[str, float]:
        """Get the most probable emotion for the input text.
        
        Args:
            text: Input text to analyze
            translate_if_needed: Whether to translate non-English text
            
        Returns:
            Tuple of (emotion_label, probability_score)
        """
        scores = self.get_emotion_scores(text, translate_if_needed)
        dominant_emotion = max(scores.items(), key=lambda x: x[1])
        return dominant_emotion

    def analyze_text_full(self, text: str, translate_if_needed: bool = True) -> Dict:
        """Get complete emotion analysis for text, using LLM fallback for dominant emotion if needed."""
        processed_text = text
        if translate_if_needed:
            processed_text = self._translate_text(text)

        embedding = self.get_embedding(text, translate_if_needed=False)  # Already processed
        scores = {label: score for label, score in zip(self.labels.values(), embedding)}
        # Use get_final_emotion for robust dominant emotion (LLM fallback)
        dominant_emotion = self.get_final_emotion(text)
        dominant_score = scores.get(dominant_emotion, 0.0)

        return {
            "original_text": text,
            "processed_text": processed_text if processed_text != text else None,
            "embedding": embedding,
            "emotion_scores": scores,
            "dominant_emotion": dominant_emotion,
            "dominant_score": dominant_score
        }

    def get_final_emotion(self, text: str, threshold: float = 0.6) -> str:
        """
        Get final single-label emotion.
        Uses classifier by default, but calls LLM if confidence < threshold.
        """
        scores = self.get_emotion_scores(text, translate_if_needed=False)
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
            return llm_label
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
        
        return {
            "pipeline_success": True,
            "original_text": analysis["original_text"],
            "processed_text": analysis["processed_text"],
            "emotion_scores": analysis["emotion_scores"],
            "dominant_emotion": analysis["dominant_emotion"],
            "dominant_score": analysis["dominant_score"],
            "embedding": analysis["embedding"],
            "user_context": user_name,
            "analysis_method": "classifier_with_llm_fallback"
        }
        
    except Exception as e:
        return {
            "pipeline_success": False,
            "error": str(e),
            "user_context": user_name
        }

def interpretation(metadata: Dict) -> str:
    """
    Generate an interpretation explaining why the dominant emotion was chosen based on the analysis metadata.
    
    Args:
        metadata: Dictionary containing the emotion analysis results from analyze_emotion.
        
    Returns:
        A string description explaining the dominant emotion.
    """
    if not metadata.get("pipeline_success", False):
        return "Analysis failed, cannot provide interpretation."
    
    dominant_emotion = metadata.get("dominant_emotion", "unknown")
    dominant_score = metadata.get("dominant_score", 0.0)
    original_text = metadata.get("original_text", "")
    emotion_scores = metadata.get("emotion_scores", {})
    
    pipeline = get_pipeline()
    if not pipeline.groq_client or not pipeline.groq_model:
        return f"The dominant emotion is '{dominant_emotion}' with a confidence score of {dominant_score:.2f}. (LLM not available for detailed interpretation.)"
    
    # Optimized prompt for the LLM to generate an interpretation
    prompt = f"""
    You are an expert emotion analyst. Given the following analysis of the text: "{original_text}", explain in 2-3 empathetic sentences why the dominant emotion was identified.

    Dominant Emotion: {dominant_emotion} (Confidence: {dominant_score:.2f})
    All Emotion Scores: {emotion_scores}

    Focus on the most relevant words or phrases in the text that support this emotion. Make your explanation clear, simple, and supportive, as if speaking to the person who wrote the text.
    """
    
    try:
        response = pipeline.groq_client.chat.completions.create(
            messages=[{"role": "user", "content": prompt}],
            model=pipeline.groq_model,
            temperature=0.3,
            max_tokens=150
        )
        interpretation_text = response.choices[0].message.content.strip()
        return interpretation_text
    except Exception as e:
        print(f"Interpretation generation failed: {e}")
        return f"The dominant emotion is '{dominant_emotion}' with a confidence score of {dominant_score:.2f}. (Error generating detailed interpretation.)"
 