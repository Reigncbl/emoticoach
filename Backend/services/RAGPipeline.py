# backend/services/rag_service.py
import os
import numpy as np
from huggingface_hub import InferenceClient
from groq import Groq
from dotenv import load_dotenv

load_dotenv()
GROQ_API_KEY = os.getenv("api_key")
HF_API_KEY = os.getenv("HF_API_KEY")
HF_MODEL = "BAAI/bge-m3"

class SimpleRAG:
    def __init__(self):
        self.client = Groq(api_key=GROQ_API_KEY)
        self.model = os.getenv("model")
        self.hf_client = InferenceClient(token=HF_API_KEY)
        self.documents = []

    def _embed(self, text):
        try:
            # Get embedding as numpy array
            embedding = np.array(self.hf_client.feature_extraction(text, model=HF_MODEL)).flatten()
            # Format for PostgreSQL vector storage
            return embedding.tolist()
        except Exception as e:
            print(f"Embedding error: {e}")
            return np.zeros(384).tolist()

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
