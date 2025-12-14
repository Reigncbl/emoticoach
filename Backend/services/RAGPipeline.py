# backend/services/rag_service.py
import os
import re
import time
import numpy as np
import requests
from groq import Groq
from dotenv import load_dotenv
from .emotion_pipeline import EmotionEmbedder
from huggingface_hub import InferenceClient

load_dotenv()
GROQ_API_KEY = os.getenv("api_key")

# Profanity filter - list of curse words to filter out
CURSE_WORDS = [
    # English curse words
    'fuck', 'fucking', 'fucked', 'fucker', 'fck', 'fuk', 'f*ck', 'f**k',
    'shit', 'shitty', 'bullshit', 'sh*t', 's**t',
    'damn', 'damned', 'dammit', 'goddamn',
    'ass', 'asshole', 'a**hole', 'a$$',
    'bitch', 'b*tch', 'b**ch',
    'bastard', 'dick', 'cock', 'cunt', 'whore', 'slut',
    'crap', 'piss', 'pissed',
    # Filipino curse words
    'putang', 'puta', 'punyeta', 'gago', 'gaga', 'tangina', 'taena', 'tanga',
    'bobo', 'boba', 'ulol', 'leche', 'lintik', 'hinayupak', 'hayop',
    'pakyu', 'pakyu', 'p*ta', 'tang ina', 'tanginamo', 'pucha', 'pakshet',
    'bwisit', 'siraulo', 'inutil', 'ungas', 'gunggong', 'peste',
    # Common abbreviations/variations
    'wtf', 'stfu', 'gtfo', 'ffs',
]

def filter_profanity(text: str) -> str:
    """Filter out curse words from the generated text."""
    if not text:
        return text
    
    filtered_text = text
    for curse in CURSE_WORDS:
        # Create pattern that matches the word with word boundaries (case insensitive)
        pattern = re.compile(r'\b' + re.escape(curse) + r'\b', re.IGNORECASE)
        filtered_text = pattern.sub('', filtered_text)
    
    # Clean up extra spaces that might result from removal
    filtered_text = re.sub(r'\s+', ' ', filtered_text).strip()
    
    # If the entire message was filtered out, return a safe fallback
    if not filtered_text:
        return "I understand how you feel."
    
    return filtered_text
HF_API_KEY = os.getenv("HF_API_KEY")
HF_MODEL = "BAAI/bge-m3"  # Specific embedding model for RAG
HF_RERANKER_MODEL = "BAAI/bge-reranker-v2-m3"  # Reranker model
MODEL_PATH = os.path.join(r"Backend\AIModel", "bge-m3")
EMBEDDING_DIM = 1024 # BGE-M3 embedding dimension

# Weight for combining semantic and emotional similarity
EMOTION_WEIGHT = 0.3  # Adjust this to control the importance of emotional similarity

# Tone mapping for response policy
RESPONSE_POLICY = {
    "anger": "Calm",
    "sadness": "Encouraging",
    "fear": "Reassuring",
    "disgust": "Understanding",
    "joy": "Supportive",
    "neutral": "Reflective",
    "surprise": "Supportive"  # Add if needed for completeness
}

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

        print(f"Initializing RAG with Hugging Face Inference API for {HF_MODEL}...")

        self.hf_client = InferenceClient(model=HF_MODEL, token=HF_API_KEY)
        
        # Initialize reranker client
        print(f"Initializing Reranker with {HF_RERANKER_MODEL}...")
        self.reranker_client = InferenceClient(model=HF_RERANKER_MODEL, token=HF_API_KEY)

        # Initialize emotion embedder
        self.emotion_embedder = EmotionEmbedder()

    def get_response_tone(self, query):
        """
        Detect dominant emotion and map to response tone.
        """
        emotion_data = self.emotion_embedder.analyze_text_full(query)
        dominant_emotion = emotion_data.get("dominant_emotion", "neutral").lower()
        return RESPONSE_POLICY.get(dominant_emotion, "Supportive")

    def _embed(self, text):
        """
        Get semantic embedding only for database storage using HF Inference API.
        Returns numpy array that can be converted to list for pgvector.
        """
        try:
            # Get semantic embeddings using HF Inference API
            embedding = self.hf_client.feature_extraction(text)
            # The output is a list of embeddings, for a single text input, we take the first.
            # It might be nested, so we flatten it if necessary.
            embedding = np.array(embedding).flatten()
            return embedding
        except Exception as e:
            print(f"Embedding error: {e}")
            # Return zero vector as fallback
            return np.zeros(EMBEDDING_DIM)

    def _embed_with_emotion(self, text):
        """
        Get both semantic and emotion embeddings for RAG similarity calculations.
        Returns dictionary with both embeddings.
        """
        try:
            # Get semantic embeddings using SentenceTransformer
            semantic_embedding = self._embed(text)
            
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
                "semantic": np.zeros(EMBEDDING_DIM).tolist(),
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

    def _rerank(self, query, documents, top_k=3):
        """
        Rerank documents using the BGE reranker model.
        
        Args:
            query: The user query string
            documents: List of document dictionaries with content and scores
            top_k: Number of top documents to return after reranking
            
        Returns:
            List of reranked documents with updated scores
        """
        if not documents:
            return []
        
        try:
            # Prepare input for the reranker
            # The reranker expects pairs of [query, document] texts
            pairs = [[query, doc["content"]] for doc in documents]
            
            # Get reranking scores from the model
            # The reranker returns relevance scores for each query-document pair
            scores = self.reranker_client.sentence_similarity(
                query,
                [doc["content"] for doc in documents]
            )
            
            # Update documents with reranker scores
            for i, doc in enumerate(documents):
                doc["rerank_score"] = float(scores[i]) if isinstance(scores, (list, np.ndarray)) else float(scores)
                # Combine original similarity score with rerank score (weighted average)
                doc["combined_score"] = 0.4 * doc["score"] + 0.6 * doc["rerank_score"]
            
            # Sort by combined score and return top_k
            reranked = sorted(documents, key=lambda x: x["combined_score"], reverse=True)[:top_k]
            
            return reranked
            
        except Exception as e:
            print(f"Reranking error: {e}, falling back to original scores")
            # Fall back to original ranking if reranking fails
            return documents[:top_k]

    def search(self, query, top_k=3, use_reranker=True, initial_k=10):
        """
        Search for relevant documents with optional reranking.
        
        Args:
            query: The user query string
            top_k: Number of final results to return
            use_reranker: Whether to use the reranker (default True)
            initial_k: Number of candidates to retrieve before reranking (default 10)
            
        Returns:
            List of top_k most relevant documents
        """
        # Get initial candidates using embedding similarity
        query_embedding = self._embed_with_emotion(query)
        results = [
            {
                "content": doc["content"],
                "score": self._calculate_similarity(query_embedding, doc["embedding"]),
                "metadata": doc["metadata"]
            }
            for doc in self.documents
        ]
        
        # Sort and get initial candidates
        initial_results = sorted(results, key=lambda x: x["score"], reverse=True)[:initial_k]
        
        # Apply reranking if enabled
        if use_reranker and len(initial_results) > 0:
            return self._rerank(query, initial_results, top_k)
        else:
            return initial_results[:top_k]

    def generate_response(self, query, user_messages=None, top_k=3, use_reranker=True, 
                          latest_message=None, conversation_context=None, length_instruction=None):
        """
        Generate a response based on the query and context.
        
        Args:
            query: The full prompt/query (used for RAG search and fallback)
            user_messages: List of user's previous messages for style matching
            top_k: Number of documents to retrieve
            use_reranker: Whether to use reranking
            latest_message: The ACTUAL latest message text to reply to (priority)
            conversation_context: Previous conversation for context
            length_instruction: Interpretation layer instruction for response length/style
        """
        # Use the enhanced search with reranker
        search_results = self.search(query, top_k=top_k, use_reranker=use_reranker)
        
        # Extract content from search results
        rag_context = "\n".join([doc["content"] for doc in search_results])
        
        style_examples = ""
        if user_messages:
            # Limit to last 3 messages for style
            style_examples = "\nUser style examples:\n" + "\n".join(user_messages[-3:])

        # Determine what to reply to - prioritize explicit latest_message
        message_to_reply = latest_message if latest_message else query
        
        # Get the mapped response tone based on the message to reply to
        response_tone = self.get_response_tone(message_to_reply)

        # Build prompt with clear structure
        prompt_parts = []
        
        if style_examples:
            prompt_parts.append(style_examples)
        
        if conversation_context:
            prompt_parts.append(f"\nConversation history:\n{conversation_context}")
        
        if rag_context:
            prompt_parts.append(f"\nRelevant knowledge:\n{rag_context}")
        
        # The LATEST MESSAGE is clearly marked and placed LAST for emphasis
        prompt_parts.append(f"\n\nTheir message: \"{message_to_reply}\"")
        
        prompt = "\n".join(prompt_parts)
        
        # Build a more human, emotionally-aware system prompt
        tone_instructions = {
            "Calm and reassuring": "Be gentle and soothing. Acknowledge their feelings without being preachy.",
            "Encouraging and supportive": "Be warm and uplifting. Show you care without overdoing it.",
            "Friendly and casual": "Be chill and relatable. Keep it light and fun.",
            "Curious and engaged": "Show genuine interest. Ask follow-ups naturally.",
            "Warm and affirming": "Celebrate with them! Share their excitement authentically."
        }
        
        tone_guide = tone_instructions.get(response_tone, "Be natural and conversational.")
        
        # Build length/style guidance from interpretation layer + set dynamic token limits
        length_guide = ""
        max_tokens = 60  # Default: short casual reply
        
        if length_instruction:
            if "detailed" in length_instruction.lower() or "code" in length_instruction.lower():
                length_guide = "This is a task/request - give a helpful, complete answer."
                max_tokens = 500  # Allow longer for tasks
            elif "2-4 sentences" in length_instruction.lower():
                length_guide = "Answer their question in 2-3 sentences. Be clear but concise."
                max_tokens = 100  # Medium for questions
            else:
                length_guide = "Reply in 1 sentence max. Keep it super short."
                max_tokens = 50  # Short for casual
        
        try:
            resp = self.client.chat.completions.create(model=self.model, messages=[
                {"role": "system", "content": (
                    f"You're texting a close friend. {tone_guide}\n"
                    f"{length_guide}\n\n"
                    "RULES:\n"
                    "- Sound like a real person, not a bot or therapist\n"
                    "- Use casual language, contractions, maybe even 'haha' or 'lol' if appropriate\n"
                    "- React genuinely - be empathetic but not fake\n"
                    "- Match their vibe (Tagalog/English/Taglish)\n"
                    "- NO names, NO quotes around reply, NO prefixes like 'Reply:'\n"
                    "- NEVER use curse words, profanity, or vulgar language\n"
                    "- Just output the message text directly"
                )},
                {"role": "user", "content": prompt}
            ], temperature=0.85, max_tokens=max_tokens)

            content = (resp.choices[0].message.content or "").strip()
            
            # Clean up common formatting issues
            # Remove quotes if the entire response is wrapped in them
            if content.startswith('"') and content.endswith('"'):
                content = content[1:-1].strip()
            if content.startswith("'") and content.endswith("'"):
                content = content[1:-1].strip()
            
            # Remove common prefixes
            prefixes_to_remove = [
                "Reply:", "reply:", "Response:", "response:", 
                "Here's a reply:", "Here is a reply:",
                "Suggested reply:", "My reply:",
            ]
            for prefix in prefixes_to_remove:
                if content.startswith(prefix):
                    content = content[len(prefix):].strip()
            
            # Apply profanity filter to remove any curse words
            content = filter_profanity(content)
            
            if not content:
                return "Okay lang."

            return content
        except Exception as e:
            return f"Error: {e}"

# singleton RAG instance
rag = SimpleRAG()