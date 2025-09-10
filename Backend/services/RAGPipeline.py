import os
from typing import List, Dict, Any
from groq import Groq
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class SimpleRAG:
    """Simple RAG Pipeline using Groq"""
    
    def __init__(self):
        self.client = Groq(api_key=os.getenv("api_key"))
        self.model = os.getenv("model") or "llama3-8b-8192"  # Default model if not specified
        self.documents = []  # Simple in-memory storage
    
    def add_document(self, content: str, metadata: Dict = None):
        """Add document to knowledge base"""
        self.documents.append({
            "content": content,
            "metadata": metadata or {}
        })
    
    def search(self, query: str, top_k: int = 3) -> List[Dict]:
        """Simple keyword search"""
        query_words = query.lower().split()
        results = []
        
        for doc in self.documents:
            content_lower = doc["content"].lower()
            score = sum(1 for word in query_words if word in content_lower)
            
            if score > 0:
                results.append({
                    "content": doc["content"],
                    "score": score,
                    "metadata": doc["metadata"]
                })
        
        # Sort by score and return top results
        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:top_k]
    
    def generate_response(self, query: str) -> str:
        """Generate response using retrieved context"""
        # Get relevant documents
        relevant_docs = self.search(query)
        
        # Build context from documents
        context = "\n".join([doc["content"] for doc in relevant_docs])
        
        # Create prompt for Groq
        prompt = f"""Context: {context}

Question: {query}

Please answer the question based on the provided context. If the context doesn't contain enough information, say so and provide general guidance."""
        
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": "You are a helpful AI assistant."},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7,
                max_tokens=500
            )
            return response.choices[0].message.content
        except Exception as e:
            return f"Error: {str(e)}"

# Create global instance
rag = SimpleRAG()

# Example usage
if __name__ == "__main__":
    # Add some sample documents
    rag.add_document("Emotional intelligence is the ability to understand and manage your emotions.")
    rag.add_document("Mindfulness helps improve emotional awareness and regulation.")
    
    # Ask a question
    answer = rag.generate_response("How can I improve my emotional intelligence?")
    print(answer)
