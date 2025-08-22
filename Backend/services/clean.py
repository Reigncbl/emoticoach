# clean_original_dataset.py
import pandas as pd

# Original dataset path
dataset_path = r"C:\Users\John Carlo\Downloads\EMOTERA-All.tsv"
df = pd.read_csv(dataset_path, sep='\t')

# Drop empty/whitespace tweets
df = df[df['tweet'].str.strip() != ""]

# Drop duplicates
df = df.drop_duplicates(subset=['tweet', 'emotion']).reset_index(drop=True)

# Save cleaned file
clean_path = r"C:\Users\John Carlo\Downloads\EMOTERA-All-cleaned.tsv"
df.to_csv(clean_path, sep='\t', index=False)

print(f"Cleaned dataset saved to: {clean_path}")
print(f"Total samples after cleaning: {len(df)}")
