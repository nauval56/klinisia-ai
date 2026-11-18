"""Preprocessing teks ulasan — replikasi persis pipeline di notebook training.

Urutan (sesuai notebook `analisis_sentimen_ulasan_aplikasi_klinisia_...py`):
    1. Hapus URL, username (@...), HTML, emoji, simbol, angka   -> cleaning
    2. Case folding (lowercase)
    3. Normalisasi kata tidak baku -> kata baku (kamus eksternal)
    4. Tokenisasi (split spasi)
    5. Hapus stopwords Bahasa Indonesia (daftar NLTK)
    6. Hapus kata-kata tertentu (daftar `hapus_kata`)
    7. Perbaikan kata (kamus kecil: app -> aplikasi, pisan -> bagus, ...)
    8. Stemming ke kata dasar (Sastrawi) - TANPA langkah ini cakupan token
       terhadap kosakata model hanya ~68%; dengan stemming ~92%
       (lihat scripts/diagnose_vocab.py)
"""
from __future__ import annotations

import re
from pathlib import Path

from . import config

# ---------------------------------------------------------------- regex
_URL_RE = re.compile(r"https?://\S+|www\.\S+")
_HTML_RE = re.compile(r"<.*?>")
_USERNAME_RE = re.compile(r"@\w+")
_EMOJI_RE = re.compile(
    "["
    "\U0001F600-\U0001F64F"
    "\U0001F300-\U0001F5FF"
    "\U0001F680-\U0001F6FF"
    "\U0001F700-\U0001F77F"
    "\U0001F780-\U0001F7FF"
    "\U0001F800-\U0001F8FF"
    "\U0001FA00-\U0001FA6F"
    "\U0001FA70-\U0001FAFF"
    "\U00002702-\U000027B0"
    "\U000024C2-\U0001F251"
    "]+",
    flags=re.UNICODE,
)
_SYMBOL_RE = re.compile(r"[^a-zA-Z0-9\s]")
_NUMBER_RE = re.compile(r"\d")

# Daftar kata yang dibuang (diambil dari variabel `hapus_kata` di notebook)
HAPUS_KATA = [
    "ya", "tok", "deh", "wok", "we", "the", "loh", "sih", "up", "pas", "kak", "ai", "swt",
    "abang", "mbak", "idf", "roy", "not", "nih", "cs", "y", "gue", "a", "bu", "mas", "bpk",
    "dek", "allah", "fery", "fer", "omon", "wo", "lo", "kau", "sok", "ku", "tuh", "gua",
    "om", "ded", "gus", "mu", "you", "vid", "thank", "lu", "tau", "al", "si", "densu",
    "tolong", "no", "h", "n", "aah", "kah", "nge", "ter", "ber", "i", "mih", "jis",
]

# Kamus kecil `kamus_tidak_baku` dari notebook (tahap perbaikan_kata)
KAMUS_PERBAIKI = {
    "app": "aplikasi",
    "apps": "aplikasi",
    "apk": "aplikasi",
    "score": "rating",
    "hp": "handphone",
    "pisan": "bagus",
}


def _load_kamus(path: Path) -> dict[str, str]:
    """Muat kamus kata tidak baku -> kata baku (CSV hasil unduhan notebook)."""
    fallback = dict(KAMUS_PERBAIKI)
    if not path.exists():
        return fallback
    kamus: dict[str, str] = {}
    try:
        import csv

        with path.open("r", encoding="utf-8", errors="ignore", newline="") as fh:
            sample = fh.read(4096)
            fh.seek(0)
            delimiter = ";" if sample.count(";") >= sample.count(",") else ","
            reader = csv.DictReader(fh, delimiter=delimiter)
            headers = {h.lower().strip(): h for h in (reader.fieldnames or [])}
            col_baku = next((headers[k] for k in headers if "baku" in k and "tidak" not in k), None)
            col_tidak = next((headers[k] for k in headers if "tidak" in k), None)
            if col_baku and col_tidak:
                for row in reader:
                    k = str(row.get(col_tidak, "")).strip().lower()
                    v = str(row.get(col_baku, "")).strip().lower()
                    if k and v and k != v:
                        kamus[k] = v
    except Exception:  # pragma: no cover - kamus gagal dimuat tidak boleh menjatuhkan API
        return fallback
    kamus.update({k: v.lower() for k, v in KAMUS_PERBAIKI.items()})
    return kamus or fallback


def _load_stopwords(path: Path) -> set[str]:
    if not path.exists():
        return set()
    return {w.strip().lower() for w in path.read_text(encoding="utf-8").splitlines() if w.strip()}


KAMUS_TIDAK_BAKU: dict[str, str] = _load_kamus(config.KAMUS_PATH)
STOPWORDS: set[str] = _load_stopwords(config.STOPWORDS_PATH)

# ------------------------------------------------------------- stemming
_STEMMER: object | None = None
_STEMMER_CHECKED = False


def _get_stemmer() -> object | None:
    """Stemmer Sastrawi (dibuat sekali, lazy). None bila dinonaktifkan/terpasang."""
    global _STEMMER, _STEMMER_CHECKED
    if not config.STEMMING_ENABLED:
        return None
    if not _STEMMER_CHECKED:
        _STEMMER_CHECKED = True
        try:
            from Sastrawi.Stemmer.StemmerFactory import StemmerFactory

            _STEMMER = StemmerFactory().create_stemmer()
        except Exception:  # pragma: no cover - PySastrawi belum terpasang
            _STEMMER = None
    return _STEMMER


def stemming_enabled() -> bool:
    return config.STEMMING_ENABLED and _get_stemmer() is not None


# ------------------------------------------------------------- tahapan
def remove_url(text: str) -> str:
    return _URL_RE.sub("", text)


def remove_usernames(text: str) -> str:
    return _USERNAME_RE.sub("", text)


def remove_html(text: str) -> str:
    return _HTML_RE.sub("", text)


def remove_emoji(text: str) -> str:
    return _EMOJI_RE.sub("", text)


def remove_symbols(text: str) -> str:
    return _SYMBOL_RE.sub("", text)


def remove_numbers(text: str) -> str:
    return _NUMBER_RE.sub("", text)


def case_folding(text: str) -> str:
    return text.lower()


def normalisasi_kata(text: str) -> str:
    return " ".join(KAMUS_TIDAK_BAKU.get(w, w) for w in text.split())


def remove_stopwords(text: str) -> str:
    return " ".join(w for w in text.split() if w not in STOPWORDS)


def hapus_kata_tertentu(text: str) -> str:
    return " ".join(w for w in text.split() if w not in HAPUS_KATA)


def perbaiki_kata(text: str) -> str:
    return " ".join(KAMUS_PERBAIKI.get(w, w) for w in text.split())


def preprocess(text: str | None) -> str:
    """Jalankan seluruh rantai preprocessing pada satu teks ulasan."""
    if text is None:
        return ""
    if not isinstance(text, str):
        text = str(text)

    # 1) cleaning
    cleaned = remove_url(text)
    cleaned = remove_usernames(cleaned)
    cleaned = remove_html(cleaned)
    cleaned = remove_emoji(cleaned)
    cleaned = remove_symbols(cleaned)
    cleaned = remove_numbers(cleaned)
    # 2) case folding
    cleaned = case_folding(cleaned)
    # 3) normalisasi kata tidak baku
    cleaned = normalisasi_kata(cleaned)
    # 4) tokenisasi (split spasi)
    # 5) hapus stopwords
    cleaned = remove_stopwords(cleaned)
    # 6) hapus kata tertentu
    cleaned = hapus_kata_tertentu(cleaned)
    # 7) perbaikan kata
    cleaned = perbaiki_kata(cleaned)
    # 8) stemming ke kata dasar (Sastrawi) - kunci agar token cocok dengan
    #    kosakata model yang berisi bentuk dasar ("layanan", "daftar")
    stemmer = _get_stemmer()
    if stemmer is not None:
        cleaned = stemmer.stem(cleaned)
    return " ".join(cleaned.split())


def steps() -> list[str]:
    """Daftar langkah preprocessing (dikirim ke frontend lewat /api/model)."""
    daftar = [
        "Hapus URL, username, HTML, emoji, simbol, dan angka",
        "Case folding (lowercase)",
        "Normalisasi kata tidak baku -> kata baku",
        "Tokenisasi (split spasi)",
        "Hapus stopwords Bahasa Indonesia",
        "Hapus kata tertentu (daftar hapus_kata)",
        "Perbaikan kata (app->aplikasi, pisan->bagus, ...)",
    ]
    if stemming_enabled():
        daftar.append("Stemming ke kata dasar (Sastrawi)")
    return daftar
