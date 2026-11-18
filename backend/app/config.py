"""Konfigurasi pusat backend Klinisia AI."""
from __future__ import annotations

import os
from pathlib import Path

# backend/ (folder induk dari package `app`)
BASE_DIR = Path(__file__).resolve().parent.parent

MODELS_DIR = BASE_DIR / "models"
DATA_DIR = BASE_DIR / "data"

# File model utama yang diberikan (berisi TfidfVectorizer + label + nama algoritma)
MODEL_PATH = Path(os.environ.get("KLINISIA_MODEL_PATH", MODELS_DIR / "klinisia_model.joblib"))

# File pendamping berisi estimator SVM yang sudah dilatih.
# Dibuat otomatis saat startup bila file model utama tidak memuat estimator.
CLASSIFIER_PATH = Path(os.environ.get("KLINISIA_CLASSIFIER_PATH", MODELS_DIR / "klinisia_svm_classifier.joblib"))

# Dataset ulasan Play Store (untuk melatih classifier pendamping & ringkasan dataset)
DATASET_PATH = Path(
    os.environ.get("KLINISIA_DATASET_PATH", DATA_DIR / "hasil_scraper_ulasan_app_klinisia.csv")
)

# Aset preprocessing (dipakai agar inferensi sama persis dengan notebook)
KAMUS_PATH = DATA_DIR / "kamus_tidak_baku.csv"
STOPWORDS_PATH = DATA_DIR / "stopwords_id.txt"

# Stemming Bahasa Indonesia (Sastrawi).
# Diagnosis (scripts/diagnose_vocab.py): kosakata model berisi kata dasar
# ("layanan", "daftar") tetapi TIDAK berisi bentuk berimbuhan ("pelayanan",
# "pendaftaran") -> vectorizer dilatih pada teks hasil stemming.
# Dengan stemming, cakupan token naik 68% -> 92,4%.
STEMMING_ENABLED = os.environ.get("KLINISIA_STEMMING", "1") not in {"0", "false", "False"}

# Batasan praktis
MAX_TEXT_LENGTH = 5000          # karakter per teks
MAX_BATCH_SIZE = 200            # teks per request batch
# Batas baris CSV per unggahan. 0 = TANPA BATAS — seluruh baris file yang
# diunggah user dianalisis berapa pun jumlahnya (mis. 20000 baris ya
# 20000 dianalisis). Ubah ke angka > 0 hanya bila perlu membatasi.
MAX_CSV_ROWS = 0
# Anggaran waktu (detik) untuk menganalisis SATU unggahan CSV.
# Jumlah data tetap mengikuti unggahan user (tanpa batas baris), tetapi
# proses BERHENTI setelah selama ini — baris yang belum sempat dianalisis
# dilaporkan jelas (time_limit_exceeded + rows_not_processed), bukan
# dipotong diam-diam. Default 300 detik = 5 menit; 0 = tanpa batas waktu.
ANALYSIS_TIME_BUDGET = float(os.environ.get("KLINISIA_TIME_BUDGET", "300"))
HISTORY_MAX_SIZE = 50           # riwayat analisis di memori

# Evaluasi ketika melatih classifier pendamping
TEST_SIZE = 0.2
RANDOM_STATE = 42

# Parameter SVM hasil eksperimen (scripts/experiment_params.py) dengan stemming:
# - balanced C=1.0 -> macro-F1 tertinggi & recall Negatif terbaik (0.81)
#   agar keluhan pengguna tidak banyak yang lolos.
SVC_C = float(os.environ.get("KLINISIA_SVC_C", "1.0"))
# "" (kosong) = tanpa class_weight
SVC_CLASS_WEIGHT = os.environ.get("KLINISIA_SVC_CLASS_WEIGHT", "balanced") or None

CORS_ORIGINS = os.environ.get("KLINISIA_CORS_ORIGINS", "*").split(",")

# Server. 0.0.0.0 = bisa diakses dari PC DAN dari HP via IP LAN
# (mis. http://192.168.100.31:8000). Set KLINISIA_HOST=127.0.0.1 bila ingin
# backend hanya bisa diakses dari komputer ini saja.
HOST = os.environ.get("KLINISIA_HOST", "0.0.0.0")
PORT = int(os.environ.get("KLINISIA_PORT", "8000"))
