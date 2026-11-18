"""Eksperimen singkat: varian parameter SVM untuk classifier pendamping Klinisia.

Jalankan:  python scripts/experiment_params.py
"""
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import joblib
import pandas as pd
from sklearn.metrics import accuracy_score, classification_report
from sklearn.model_selection import train_test_split
from sklearn.svm import SVC

from app import config, preprocessing

payload = joblib.load(config.MODEL_PATH)
vec = payload["vectorizer"]

df = pd.read_csv(config.DATASET_PATH, usecols=lambda c: c in {"content", "score"})
df = df.dropna(subset=["content"])
df["label"] = df["score"].apply(
    lambda s: "Negatif" if int(s) in (1, 2, 3) else ("Positif" if int(s) in (4, 5) else None)
)
df = df[df["label"].notna()]
df["clean"] = df["content"].map(preprocessing.preprocess)
df = df[df["clean"].str.strip() != ""]

X = vec.transform(df["clean"].tolist())
y = df["label"]
Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
print("jumlah data:", len(df), "| distribusi:", y.value_counts().to_dict())

# koherensi coef_ terhadap decision_function
probe = SVC(kernel="linear", random_state=42).fit(Xtr, ytr)
coef = probe.coef_
coef_arr = coef.toarray() if hasattr(coef, "toarray") else coef.__array__()
import numpy as np

w = np.asarray(coef_arr).ravel()
b = np.asarray(probe.intercept_).ravel()
d1 = np.asarray(Xte @ w + b[0]).ravel()
d2 = np.asarray(probe.decision_function(Xte)).ravel()
print("shape coef_:", coef.shape, "| intercept:", b, "| selisih max:", float(np.max(np.abs(d1 - d2))))
print()

rows = []
for cw in [None, "balanced"]:
    for C in [0.25, 0.5, 1.0, 2.0, 4.0]:
        m = SVC(kernel="linear", C=C, class_weight=cw, random_state=42).fit(Xtr, ytr)
        p = m.predict(Xte)
        rep = classification_report(yte, p, output_dict=True, zero_division=0)
        row = {
            "class_weight": cw,
            "C": C,
            "accuracy": accuracy_score(yte, p),
            "weighted_f1": rep["weighted avg"]["f1-score"],
            "macro_f1": rep["macro avg"]["f1-score"],
            "neg_recall": rep["Negatif"]["recall"],
            "neg_f1": rep["Negatif"]["f1-score"],
            "pos_f1": rep["Positif"]["f1-score"],
        }
        rows.append(row)
        print(
            f"cw={str(cw):9s} C={C:4.2f} acc={row['accuracy']:.4f} "
            f"wF1={row['weighted_f1']:.4f} macroF1={row['macro_f1']:.4f} "
            f"negRecall={row['neg_recall']:.3f} negF1={row['neg_f1']:.3f}"
        )

best = max(rows, key=lambda r: (r["macro_f1"], r["accuracy"]))
print("\nTERBAIK (macro F1):", best)
