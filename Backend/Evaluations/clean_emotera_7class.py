import pandas as pd

# Path to the TSV file
input_path = "Backend/Evaluations/EMOTERA-All-cleaned.tsv"
output_path = "Backend/Evaluations/EMOTERA-7class-cleaned.tsv"

# The 7 emotion classes to keep
valid_emotions = {"anger", "disgust", "fear", "joy", "sadness", "surprise", "neutral"}

# Load the TSV file
df = pd.read_csv(input_path, sep='\t')

# Find the column containing emotion labels (assume 'Emotion' or similar)
possible_label_cols = [col for col in df.columns if 'emotion' in col.lower() or col.lower() == 'label']
if possible_label_cols:
    label_col = possible_label_cols[0]
else:
    label_col = df.columns[-1]  # fallback: last column


# Map 'Trust' to 'Neutral' (case-insensitive)
df[label_col] = df[label_col].replace({"Trust": "Neutral", "trust": "Neutral"})

# Filter rows to keep only the 7 classes (case-insensitive)
df_cleaned = df[df[label_col].str.lower().isin(valid_emotions)]

# Save the cleaned dataset
df_cleaned.to_csv(output_path, sep='\t', index=False)

print(f"Cleaned dataset saved to {output_path}. Rows before: {len(df)}, after: {len(df_cleaned)}.")
