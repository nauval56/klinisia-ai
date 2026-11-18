"""Diagnostik: pipeline preprocessing mana yang paling cocok dengan kosakata
TfidfVectorizer di klinisia_model.joblib (termasuk pertanyaan: perlu stemming?).

Jalankan:  python scripts/diagnose_vocab.py
"""
from __future__ import annotations

import sys
import warnings
from collections import Counter
from pathlib import Path

warnings.filterwarnings("ignore")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import joblib
import pandas as pd

from app import config, preprocessing

try:
    from Sastrawi.Stemmer.StemmerFactory import StemmerFactory

    STEMMER = StemmerFactory().create_stemmer()
except Exception:  # pragma: no cover
    STEMMER = None

vocab: set[str] = set(joblib.load(config.MODEL_PATH)["vectorizer"].vocabulary_)
stopwords = preprocessing.STOPWORDS

df = pd.read_csv(config.DATASET_PATH, usecols=["content", "score"]).dropna(subset=["content"])
sample = df["content"].astype(str).head(800).tolist()


def basic_clean(text: str) -> str:
    """Bersih tanpa stopword removal (tahap 1-4 pipeline)."""
    t = preprocessing.remove_url(text)
    t = preprocessing.remove_usernames(t)
    t = preprocessing.remove_html(t)
    t = preprocessing.remove_emoji(t)
    t = preprocessing.remove_symbols(t)
    t = preprocessing.remove_numbers(t)
    t = preprocessing.case_folding(t)
    t = preprocessing.normalisasi_kata(t)
    return " ".join(t.split())


def coverage(tokens: list[str]) -> tuple[float, float]:
    """(cakupan kemunculan token, rasio unik token dalam kosakata)."""
    if not tokens:
        return 0.0, 0.0
    hit = sum(1 for t in tokens if t in vocab)
    uniq = set(tokens)
    uniq_hit = sum(1 for t in uniq if t in vocab)
    return hit / len(tokens), uniq_hit / len(uniq)


variants: dict[str, list[str]] = {}

# A: pipeline backend saat ini (ada stopword removal, tanpa stemming)
variants["A. backend saat ini (stopword-, tanpa stemming)"] = [
    tok for t in sample for tok in preprocessing.preprocess(t).split()
]

# B: tanpa stopword removal, tanpa stemming
b_tokens = [tok for t in sample for tok in basic_clean(t).split()]
variants["B. tanpa stopword removal, tanpa stemming"] = b_tokens

# C: tanpa stopword removal + stemming
if STEMMER:
    joined = " ".join(b_tokens)
    variants["C. tanpa stopword removal + stemming (Sastrawi)"] = STEMMER.stem(joined).split()

# D: stopword removal + stemming
if STEMMER:
    joined = " ".join(variants["A. backend saat ini (stopword-, tanpa stemming)"])
    variants["D. stopword removal + stemming (Sastrawi)"] = STEMMER.stem(joined).split()

print(f"Kosakata model : {len(vocab)} token | sampel teks: {len(sample)} ulasan\n")
print(f"{'VARIAN PIPELINE':52s} {'CAKUPAN':>9s} {'UNIK':>8s}")
for name, tokens in variants.items():
    occ, uniq = coverage(tokens)
    print(f"{name:52s} {occ*100:8.1f}% {uniq*100:7.1f}%")

# Apakah kosakata berisi stopword? (bila ya, training TIDAK pakai stopword removal)
sw_in_vocab = sorted(vocab & stopwords)
print(f"\nStopword di dalam kosakata : {len(sw_in_vocab)} dari {len(stopwords)} "
      f"({len(sw_in_vocab)/len(stopwords)*100:.1f}%)")
print("  contoh:", ", ".join(sw_in_vocab[:25]))

# Apakah kosakata berbentuk hasil stemming (kata dasar) atau bentuk berimbuhan?
imbuhan = ("me", "mem", "men", "pen", "pem", "ber", "ter", "per", "di", "ke", "se")
bentuk_imbuhan = [w for w in vocab if w.startswith(imbuhan) and len(w) > 5]
print(f"\nKata berawalan imbuhan (meN-/ber-/per-/...) di kosakata: {len(bentuk_imbuhan)}")
print("  contoh:", ", ".join(sorted(bentuk_imbuhan)[:20]))

# Frekuensi kata bentuk berimbuhan pada teks ASLI (bila tinggi tapi tak ada di
# kosakata -> kemungkinan besar training memakai stemming)
Counter(" ".join(sample).lower().split())
raw_forms = ["pelayanan", "pembayaran", "pendaftaran", "mendaftar", "melayani", "melakukan"]
print("\nKehadiran kata berimbuhan pada ulasan ASLI vs kosakata:")
for w in raw_forms:
    appears = sum(1 for t in sample if w in t.lower())
    print(f"  {w:14s} muncul di {appears:3d} ulasan | di kosakata: {'YA' if w in vocab else 'tidak'}")
