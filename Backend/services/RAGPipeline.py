# backend/services/rag_service.py
import os
import time
import numpy as np
from sentence_transformers import SentenceTransformer
from groq import Groq
from dotenv import load_dotenv

load_dotenv()
GROQ_API_KEY = os.getenv("api_key")
HF_API_KEY = os.getenv("HF_API_KEY")
HF_MODEL = "BAAI/bge-m3"  # Specific embedding model for RAG
MODEL_PATH = os.path.join(r"C:\Users\John Carlo\emoticoach\emoticoach\Backend\AIModel", "bge-m3")

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

    def _embed(self, text):
        try:
            # Get embeddings using SentenceTransformer
            embedding = self.encoder.encode(text, convert_to_numpy=True)
            return embedding.tolist()
        except Exception as e:
            print(f"Embedding error: {e}")
            # Return zero vector as fallback
            return np.zeros(self.encoder.get_sentence_embedding_dimension()).tolist()

    def add_document(self, text, metadata=None):
        self.documents.append({"content": text, "embedding": self._embed(text), "metadata": metadata or {}})

    def search(self, query, top_k=3):
        q_vec = self._embed(query)
        results = [
            {"content": doc["content"], "score": float(np.dot(q_vec, doc["embedding"]) / (np.linalg.norm(q_vec)*np.linalg.norm(doc["embedding"]))), "metadata": doc["metadata"]}
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
