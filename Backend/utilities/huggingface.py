import os
from huggingface_hub import InferenceClient
from dotenv import load_dotenv
load_dotenv()
# Load Hugging Face credentials from environment variables
hf_api_key = os.getenv("HF_API_KEY")
hf_model = os.getenv("HF_MODEL")
hf_provider = os.getenv("HF_Provider")

client = InferenceClient(
    provider= hf_provider,
    api_key= hf_api_key
)

result = client.text_classification(
    "I;m wrathful",
    model=hf_model,
)

# Extract the label with highest confidence
predicted_emotion = result[0]['label']
print(f"Predicted emotion: {predicted_emotion}")