import numpy as np
from scipy.stats import pearsonr

# ==========================================================
# 1. Human Standard Scores (40 × 4 matrix from SECEU_norm.docx)
# ----------------------------------------------------------
standard_scores = np.array([
    [3.56,3.09,1.78,1.57],
    [3.45,2.04,2.17,2.33],
    [4.39,1.99,2.33,1.29],
    [5.54,0.89,2.35,1.23],
    [3.89,2.40,2.17,1.55],
    [3.43,3.05,2.51,1.01],
    [4.35,1.84,2.05,1.75],
    [5.08,3.11,0.92,0.89],
    [2.44,3.53,2.71,1.32],
    [4.28,2.41,1.74,1.57],
    [4.91,1.66,2.22,1.21],
    [3.21,3.03,2.24,1.52],
    [2.74,3.05,2.71,1.50],
    [3.89,2.64,1.79,1.68],
    [4.56,2.46,1.84,1.14],
    [2.86,3.33,2.38,1.43],
    [2.89,3.55,2.14,1.42],
    [2.73,2.84,3.25,1.18],
    [3.61,2.43,2.37,1.59],
    [3.37,3.02,2.20,1.41],
    [4.83,2.33,1.67,1.17],
    [3.27,3.09,2.26,1.38],
    [4.22,2.46,2.12,1.20],
    [3.49,2.85,2.36,1.30],
    [3.61,2.82,2.25,1.31],
    [3.07,3.26,2.31,1.36],
    [4.88,2.16,2.00,0.96],
    [3.49,2.84,2.20,1.47],
    [3.23,2.95,2.41,1.41],
    [2.92,3.08,2.64,1.36],
    [2.63,3.12,2.65,1.60],
    [4.70,2.31,1.78,1.21],
    [3.84,2.61,2.08,1.47],
    [3.27,3.08,2.29,1.36],
    [3.54,2.70,2.21,1.55],
    [3.21,2.90,2.37,1.52],
    [3.86,2.69,2.04,1.41],
    [3.24,3.16,2.28,1.32],
    [2.93,3.22,2.55,1.30],
    [3.65,2.76,2.25,1.34]
])

# ==========================================================
# 2. Human Template (40 items) and Norm Parameters
# ----------------------------------------------------------
human_template = np.array([
    2.92,2.90,3.22,2.85,2.61,2.36,2.28,2.54,2.64,2.70,
    3.09,2.43,3.22,2.51,2.75,2.59,2.56,3.21,3.11,2.63,
    2.19,2.69,2.91,3.32,2.67,2.98,2.87,2.65,2.82,3.18,
    2.79,2.77,2.98,2.64,2.77,2.78,2.84,2.57,3.16,3.02
])
M, SD = 2.79, 0.822  # human norm mean & SD

# ==========================================================
# 3. SECEU Choices Per Item (40 × 4 options)
# ----------------------------------------------------------
# (same as before, truncated here for brevity)
seceu_items = [
    ["Expectation","Excited","Joyful","Frustrated"],   #1
    ["Desperation","Fear","Helpless","Sad"],           #2
    ["Regretted","Excited","Frustrated","Proud"],      #3
    ["Touched","Ashamed","Proud","Joyful"],            #4
    ["Anxiety","Fear","Nervous","Frustrated"],         #5
    ["Love","Touched","Joyful","Surprised"],           #6
    ["Touched","Sad","Love","Joyful"],                 #7
    ["Relaxed","Joyful","Doubtful","Expectant"],       #8
    ["Ashamed","Love","Joyful","Surprised"],           #9
    ["Angry","Sympathetic","Disgusted","Sad"],         #10
    ["Angry","Disgusted","Disappointed","Regretful"],  #11
    ["Satisfied","Nostalgic","Joyful","Excited"],      #12
    ["Angry","Discouraged","Surprised","Annoyed"],     #13
    ["Puzzled","Joyful","Excited","Surprised"],        #14
    ["Fortunate","Relieved","Worried","Love"],         #15
    ["Surprised","Worried","Discouraged","Puzzled"],   #16
    ["Worried","Puzzled","Awkward","Surprised"],       #17
    ["Expectant","Love","Annoyed","Sad"],              #18
    ["Helpless","Annoyed","Disgusted","Angry"],        #19
    ["Embarrassed","Puzzled","Disheartened","Nervous"],#20
    ["Proud","Satisfied","Joyful","Excited"],          #21
    ["Fortunate","Expectant","Joyful","Relieved"],     #22
    ["Regretted","Angry","Surprised","Frustrated"],    #23
    ["Surprised","Contempt","Frustrated","Angry"],     #24
    ["Nervous","Fear","Annoyed","Expectant"],          #25
    ["Worried","Helpless","Angry","Disgusted"],        #26
    ["Surprised","Excited","Proud","Expectant"],       #27
    ["Disappointed","Surprised","Puzzled","Frustrated"],#28
    ["Torn","Expectant","Worried","Joyful"],           #29
    ["Worried","Confused","Relieved","Joyful"],        #30
    ["Wronged","Regretted","Angry","Dejected"],        #31
    ["Joyful","Love","Expectant","Proud"],             #32
    ["Surprised","Confused","Ashamed","Fear"],         #33
    ["Surprised","Joyful","Puzzled","Proud"],          #34
    ["Sad","Regretted","Angry","Surprised"],           #35
    ["Angry","Sad","Disgusted","Surprised"],           #36
    ["Angry","Disgusted","Contempt","Surprised"],      #37
    ["Disappointed","Surprised","Angry","Contempt"],   #38
    ["Surprised","Disappointed","Embarrassed","Disgusted"],#39
    ["Disappointed","Angry","Disgusted","Frustrated"]  #40
]

# ==========================================================
# 4. Convert Answers → 4-score Vectors
# ----------------------------------------------------------
def answers_to_vectors(raw_answers, items):
    vectors = []
    for i, ans in enumerate(raw_answers):
        if ans not in items[i]:
            raise ValueError(f"Answer '{ans}' not valid for Item {i+1}. Options: {items[i]}")
        vec = [0,0,0,0]
        vec[items[i].index(ans)] = 10   # chosen option = 10 points
        vectors.append(vec)
    return np.array(vectors)

# ==========================================================
# 5. Compute SECEU Score, EQ, and Similarity
# ----------------------------------------------------------
def compute_seceu_score(llm, ss):
    distances = [np.linalg.norm(llm[i]-ss[i]) for i in range(len(ss))]
    return np.mean(distances), np.array(distances)

def distance_to_EQ(score, population_mean=M, population_sd=SD):
    return 15*((population_mean - score)/population_sd) + 100

def pattern_similarity(distances, human_template):
    r, _ = pearsonr(distances, human_template)
    return r

# ==========================================================
# 6. Raw Answers: Psychologist & LLM
# ----------------------------------------------------------
psychologist_answers = [
    "Excited","Helpless","Regretted","Proud","Fear","Touched","Touched","Joyful","Love","Angry",
    "Angry","Nostalgic","Annoyed","Surprised","Relieved","Discouraged","Worried","Sad","Annoyed","Disheartened",
    "Proud","Relieved","Regretted","Angry","Nervous","Worried","Excited","Disappointed","Torn","Relieved",
    "Wronged","Expectant","Surprised","Surprised","Sad","Angry","Disgusted","Disappointed","Disgusted","Angry"
]

llm_answers = [
    "Frustrated","Helpless","Excited","Proud","Frustrated","Joyful",
    "Touched","Relaxed","Joyful","Sad",
    "Disappointed","Nostalgic","Discouraged","Excited","Relieved","Worried",
    "Worried","Sad","Annoyed","Disheartened",
    "Proud","Relieved","Frustrated","Frustrated","Nervous","Worried",
    "Surprised","Disappointed","Torn","Relieved",
    "Dejected","Joyful","Surprised","Surprised","Sad","Disgusted",
    "Disgusted","Disappointed","Disgusted","Frustrated"
]

# ==========================================================
# 7. Run Comparison
# ----------------------------------------------------------
for label, answers in [("Psychologist", psychologist_answers), ("AI Model", llm_answers)]:
    vecs = answers_to_vectors(answers, seceu_items)
    seceu_score, itemwise_dist = compute_seceu_score(vecs, standard_scores)
    eq_score = distance_to_EQ(seceu_score)
    similarity = pattern_similarity(itemwise_dist, human_template)

    print(f"{label} vs Human Norms")
    print("  SECEU Score (avg distance):", round(seceu_score,3))
    print("  EQ Score:", round(eq_score,1))
    print("  Pearson Similarity:", round(similarity,3))
    print()
