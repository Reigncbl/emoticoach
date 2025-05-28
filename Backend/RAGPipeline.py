from pathlib import Path
import qdrant_client
from llama_index.core import VectorStoreIndex, StorageContext, Settings
from llama_index.embeddings.ollama import OllamaEmbedding 
from llama_index.llms.ollama import Ollama
from llama_index.readers.json import JSONReader
from llama_index.vector_stores.qdrant import QdrantVectorStore


prompt = """
You are Carlo in the metadata, generate the appropriate response to the receiver.
Analyze the metadata provided.
Generate 5 reply suggestions for how the user should respond to the last message based on the context of the data.

For analysis, USE ONE WORD
Use the following format for your response:
[
  {"analysis": "<ANALYSIS>", "suggestion": "<SUGGESTION>"},
  {"analysis": "<ANALYSIS>", "suggestion": "<SUGGESTION>"},
  {"analysis": "<ANALYSIS>", "suggestion": "<SUGGESTION>"},
  {"analysis": "<ANALYSIS>", "suggestion": "<SUGGESTION>"},
  {"analysis": "<ANALYSIS>", "suggestion": "<SUGGESTION>"}
]

RULES:
1. Use only the context provided in the metadata, use its specific behavior.
2. USE THE CONTEXT OF ALL MESSAGES BEFORE GENERATING.
3. Analyze which language the user is using, and reply using that language.
4. You can combine languages, like Tagalog and English if both are present.
5. USE EMOJI IF IT IS PRESENT, IF THERE IS NONE DON'T USE EMOJI.
6. ALWAYS REPLY TO THE LAST MESSAGE.
7. Use the language switching behavior of the data.
"""

async def suggestionGeneration():
    Settings.llm = Ollama(model="gemma3:4b", request_timeout=1000)
    Settings.embed_model = OllamaEmbedding(model_name='nomic-embed-text:latest')

    loader = JSONReader()
    documents = loader.load_data(Path(r'C:\3rd year sec sem\Capstone\Telegram\emoticoach\backend\saved_messages\reign_analysis.json'))

    client = qdrant_client.QdrantClient(path="./qdrant_data")
    vector_store = QdrantVectorStore(client=client, collection_name="analysis")
    storage_context = StorageContext.from_defaults(vector_store=vector_store)

    index = VectorStoreIndex.from_documents(documents, storage_context=storage_context)

    query_engine = index.as_query_engine()
    response = query_engine.query(prompt)
    # Consider parsing response.response if it is a stringified JSON
    return {"suggestions": response.response}

