import os
import torch
from transformers import AutoTokenizer, AutoModelForSequenceClassification
from torch.nn.functional import softmax

model_name = "j-hartmann/emotion-english-distilroberta-base"

# Load model & tokenizer
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(model_name)

# Input text
text = "I like you. I love you"

# Encode input
inputs = tokenizer(text, return_tensors="pt")

# Forward pass (no grad needed)
with torch.no_grad():
    outputs = model(**inputs)
    logits = outputs.logits
    probs = softmax(logits, dim=-1).squeeze()  # probabilities per class

# Convert to list
emotional_embedding = probs.tolist()

# Get labels
labels = model.config.id2label

# Print embedding
print("Emotional embedding vector:", emotional_embedding)
print("\nWith labels:")
for label, score in zip(labels.values(), emotional_embedding):
    print(f"{label}: {score:.4f}")
