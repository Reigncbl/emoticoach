# backend/services/rag_service.py
import os
import time
import numpy as np
from sentence_transformers import SentenceTransformer
from groq import Groq
from dotenv import load_dotenv
from .emotion_pipeline import EmotionEmbedder

load_dotenv()
GROQ_API_KEY = os.getenv("api_key")
HF_API_KEY = os.getenv("HF_API_KEY")
HF_MODEL = "BAAI/bge-m3"  # Specific embedding model for RAG
MODEL_PATH = os.path.join(r"Backend\AIModel", "bge-m3")

# Weight for combining semantic and emotional similarity
EMOTION_WEIGHT = 0.3  # Adjust this to control the importance of emotional similarity

class SimpleRAG:
    def __init__(self):
        self.client = Groq(api_key=GROQ_API_KEY)
        self.model = os.getenv("model")
        self.documents = []
        self.max_retries = 3
        self.base_delay = 1  # Initial delay in seconds
        
        # Check for HF token
        if not HF_API_KEY:
            raise ValueError("HF_API_KEY not found in environment variables")
        
        print(f"Initializing BGE-M3 embedding model...")
        
        # Create directory if it doesn't exist
        os.makedirs(MODEL_PATH, exist_ok=True)
        
        # Initialize the SentenceTransformer model with token
        self.encoder = SentenceTransformer(
            HF_MODEL, 
            cache_folder=MODEL_PATH,
            token=HF_API_KEY
        )
        print(f"Model loaded and cached in {MODEL_PATH}")
        
        # Initialize emotion embedder
        self.emotion_embedder = EmotionEmbedder()

    def _embed(self, text):
        """
        Get semantic embedding only for database storage.
        Returns numpy array that can be converted to list for pgvector.
        """
        try:
            # Get semantic embeddings using SentenceTransformer
            semantic_embedding = self.encoder.encode(text, convert_to_numpy=True)
            return semantic_embedding
        except Exception as e:
            print(f"Embedding error: {e}")
            # Return zero vector as fallback
            return np.zeros(self.encoder.get_sentence_embedding_dimension())

    def _embed_with_emotion(self, text):
        """
        Get both semantic and emotion embeddings for RAG similarity calculations.
        Returns dictionary with both embeddings.
        """
        try:
            # Get semantic embeddings using SentenceTransformer
            semantic_embedding = self.encoder.encode(text, convert_to_numpy=True)
            
            # Get emotion embeddings
            emotion_embedding = self.emotion_embedder.get_embedding(text)
            
            return {
                "semantic": semantic_embedding.tolist(),
                "emotion": emotion_embedding
            }
        except Exception as e:
            print(f"Embedding error: {e}")
            # Return zero vectors as fallback
            return {
                "semantic": np.zeros(self.encoder.get_sentence_embedding_dimension()).tolist(),
                "emotion": [0] * 7  # 7 emotion classes
            }

    def get_emotion_data(self, text):
        """
        Get emotion data for database storage.
        Returns dict with vector, labels, and top emotion.
        """
        try:
            # Use the comprehensive analysis method
            analysis = self.emotion_embedder.analyze_text_full(text, translate_if_needed=True)
            
            return {
                "vector": analysis["embedding"],
                "labels": analysis["emotion_scores"],
                "top": analysis["dominant_emotion"],
                "original_text": analysis["original_text"],
                "processed_text": analysis.get("processed_text")  # Will be None if no translation
            }
        except Exception as e:
            print(f"Emotion embedding error: {e}")
            return {
                "vector": [0.0] * 7,
                "labels": {
                    "joy": 0.0, "sadness": 0.0, "anger": 0.0,
                    "fear": 0.0, "surprise": 0.0, "disgust": 0.0,
                    "neutral": 1.0
                },
                "top": "neutral",
                "original_text": text,
                "processed_text": None
            }

    def _calculate_similarity(self, query_embedding, doc_embedding):
        # Calculate semantic similarity
        semantic_sim = float(np.dot(query_embedding["semantic"], doc_embedding["semantic"]) / 
                           (np.linalg.norm(query_embedding["semantic"]) * np.linalg.norm(doc_embedding["semantic"])))
        
        # Calculate emotion similarity
        emotion_sim = float(np.dot(query_embedding["emotion"], doc_embedding["emotion"]) /
                          (np.linalg.norm(query_embedding["emotion"]) * np.linalg.norm(doc_embedding["emotion"])))
        
        # Combine similarities with weighting
        return (1 - EMOTION_WEIGHT) * semantic_sim + EMOTION_WEIGHT * emotion_sim

    def add_document(self, text, metadata=None):
        self.documents.append({
            "content": text,
            "embedding": self._embed_with_emotion(text),  # Use the full embedding for RAG
            "metadata": metadata or {}
        })

    def search(self, query, top_k=3):
        query_embedding = self._embed_with_emotion(query)
        results = [
            {
                "content": doc["content"],
                "score": self._calculate_similarity(query_embedding, doc["embedding"]),
                "metadata": doc["metadata"]
            }
            for doc in self.documents
        ]
        return sorted(results, key=lambda x: x["score"], reverse=True)[:top_k]

    def generate_response(self, query):
        context = "\n".join([doc["content"] for doc in self.search(query)])
        prompt = f"Context:\n{context}\n\nQuestion: {query}\nAnswer based on context."
        try:
            resp = self.client.chat.completions.create(model=self.model, messages=[
                {"role": "system", "content": "You are a helpful emotional AI coach."},
                {"role": "user", "content": prompt}
            ], temperature=0.7, max_tokens=500)
            return resp.choices[0].message.content
        except Exception as e:
            return f"Error: {e}"

# singleton RAG instance
rag = SimpleRAG()