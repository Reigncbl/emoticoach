# ==============================
# 📘 Polarity Switching Visualization Script
# ==============================

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# === 1. Load your Excel file ===
# (make sure the .xlsx file is in the same folder as your notebook)
df = pd.read_excel(r"C:\Users\John Carlo\emoticoach\emoticoach\Backend\Evaluations\results\tone_mapping_f1_20251007_131841.xlsx")

# === 2. Clean and standardize polarity columns ===
polarity_cols = ['original_polarity', 'expected_polarity', 'response_polarity']
for col in polarity_cols:
    df[col] = df[col].astype(str).str.lower().str.strip()

# === 3. Create helper columns for switching ===
# Whether a polarity change is expected
df['switch_expected'] = df.apply(lambda x: x['original_polarity'] != x['expected_polarity'], axis=1)

# Whether the model actually changed polarity
df['switch_done'] = df.apply(lambda x: x['original_polarity'] != x['response_polarity'], axis=1)

# Whether the model switched correctly
df['switch_correct'] = df['switch_expected'] == df['switch_done']

# === 4. Compute summary metrics ===
switch_summary = (
    df.groupby('switch_expected')['switch_correct']
    .mean()
    .reset_index()
)
switch_summary['switch_expected'] = switch_summary['switch_expected'].map({
    True: 'Switch Expected',
    False: 'No Switch Expected'
})

print("\n=== 🔍 Polarity Switching Summary ===")
print(switch_summary)

# === 5. Visualization 1: Overall polarity switching performance ===
plt.figure(figsize=(6,5))
sns.barplot(
    x='switch_expected',
    y='switch_correct',
    data=switch_summary,
    palette='viridis'
)
plt.title("Model Accuracy on Polarity Switching")
plt.ylabel("Accuracy (Proportion Correct)")
plt.xlabel("Condition")
plt.ylim(0, 1)
plt.tight_layout()
plt.show()

# === 6. Visualization 2: Polarity switching accuracy per emotion ===
if 'original_emotion' in df.columns:
    emo_switch = (
        df.groupby(['original_emotion', 'switch_expected'])['switch_correct']
        .mean()
        .reset_index()
    )

    emo_switch['switch_expected'] = emo_switch['switch_expected'].map({
        True: 'Switch Expected',
        False: 'No Switch Expected'
    })

    plt.figure(figsize=(10,5))
    sns.barplot(
        x='original_emotion',
        y='switch_correct',
        hue='switch_expected',
        data=emo_switch,
        palette='coolwarm'
    )
    plt.title("Polarity Switching Accuracy per Emotion")
    plt.ylabel("Accuracy")
    plt.xlabel("Original Emotion")
    plt.ylim(0, 1)
    plt.legend(title="Switch Expected?")
    plt.tight_layout()
    plt.show()

# === 7. Visualization 3: Polarity switching accuracy per expected tone ===
if 'expected_tone' in df.columns:
    tone_switch = (
        df.groupby(['expected_tone', 'switch_expected'])['switch_correct']
        .mean()
        .reset_index()
    )

    tone_switch['switch_expected'] = tone_switch['switch_expected'].map({
        True: 'Switch Expected',
        False: 'No Switch Expected'
    })

    plt.figure(figsize=(10,5))
    sns.barplot(
        x='expected_tone',
        y='switch_correct',
        hue='switch_expected',
        data=tone_switch,
        palette='mako'
    )
    plt.title("Polarity Switching Accuracy per Expected Tone")
    plt.ylabel("Accuracy")
    plt.xlabel("Expected Tone")
    plt.ylim(0, 1)
    plt.legend(title="Switch Expected?")
    plt.tight_layout()
    plt.show()

# === 8. Optional: Save processed dataset ===
df.to_excel("tone_mapping_with_switch_analysis.xlsx", index=False)
print("\n✅ Analysis complete! Results saved as tone_mapping_with_switch_analysis.xlsx")
