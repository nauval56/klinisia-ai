"""Layanan model Klinisia AI.

Tanggung jawab:
1. Memuat `klinisia_model.joblib` (berisi TfidfVectorizer, label, nama algoritma).
2. Mencari estimator SVM yang sudah dilatih. Bila file TIDAK memuat estimator
   (kasus file yang diberikan user), backend melatih classifier pendamping
   `klinisia_svm_classifier.joblib` dari dataset ulasan + vectorizer tersebut,
   lalu menyimpannya agar cukup dilatih satu kali.
3. Menyediakan inferensi + penjelasan kontribusi token (untuk kartu explainability).
"""
from __future__ import annotations

import threading
from collections import deque
from datetime import datetime
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd
import sklearn
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.svm import SVC

from . import config, preprocessing


def label_sentimen(score: Any) -> str | None:
    """Labeling 2 kelas sesuai notebook: 1-3 -> Negatif, 4-5 -> Positif."""
    try:
        s = int(float(score))
    except (TypeError, ValueError):
        return None
    if s in (1, 2, 3):
        return "Negatif"
    if s in (4, 5):
        return "Positif"
    return None


def normalize_labels(values: Any) -> list[str | None]:
    """Normalisasi kolom label apa pun dari CSV user → 'Negatif'/'Positif'.

    Dikenali (menyesuaikan mayoritas isi kolom, otomatis):
    - teks  : negatif/negative, positif/positive (tak peduli huruf besar)
    - biner : 0/1  → 0 = Negatif, 1 = Positif
    - skor  : 1-5  → aturan sama dengan `label_sentimen` (1-3 Negatif,
              4-5 Positif)

    Mengembalikan daftar sepanjang `values`; `None` bila tak dikenali
    (baris itu akan diabaikan dari perhitungan laporan/agreement).
    """
    items = list(values)
    nums: list[int] = []
    for v in items:
        try:
            nums.append(int(float(v)))
        except (TypeError, ValueError):
            continue
    # Skema numerik dipakai bila hampir semua nilai berupa angka.
    threshold = max(1, int(0.8 * len(items))) if items else 1
    use_binary = len(nums) >= threshold and set(nums) <= {0, 1}
    use_score = (
        len(nums) >= threshold
        and not use_binary
        and set(nums) <= {1, 2, 3, 4, 5}
    )
    text_map = {
        "negatif": "Negatif",
        "negative": "Negatif",
        "positif": "Positif",
        "positive": "Positif",
    }
    out: list[str | None] = []
    for v in items:
        s = "" if v is None else str(v).strip().lower()
        if s in ("", "nan", "none", "null"):
            out.append(None)
            continue
        if s in text_map:
            out.append(text_map[s])
            continue
        try:
            n = int(float(s))
        except ValueError:
            out.append(None)
            continue
        if use_binary:
            out.append("Positif" if n == 1 else "Negatif")
        elif use_score:
            out.append(label_sentimen(n))
        else:
            out.append(None)
    return out


def _find_estimator(obj: Any, depth: int = 0) -> Any | None:
    """Cari objek estimator (punya method predict) di dalam payload joblib."""
    if depth > 3:
        return None
    if hasattr(obj, "predict") and hasattr(obj, "decision_function"):
        return obj
    if isinstance(obj, dict):
        for value in obj.values():
            found = _find_estimator(value, depth + 1)
            if found is not None:
                return found
    if isinstance(obj, (list, tuple)):
        for value in obj:
            found = _find_estimator(value, depth + 1)
            if found is not None:
                return found
    return None


def _coef_vector(estimator: Any) -> np.ndarray | None:
    """Ambil bobot SVM sebagai vektor 1D (coef_ bisa berupa matriks sparse)."""
    coef = getattr(estimator, "coef_", None)
    if coef is None:
        return None
    if hasattr(coef, "toarray"):
        coef = coef.toarray()
    arr = np.asarray(coef, dtype=float).ravel()
    return arr if arr.size else None


def build_report(
    metrics: dict[str, Any] | None, labels: list[str]
) -> list[dict[str, Any]] | None:
    """Susun tabel laporan klasifikasi dari metrics yang tersimpan.

    Baris tabel (sesuai output `classification_report` sklearn):
    tiap kelas (precision/recall/F1/support), Accuracy, Macro avg,
    dan Weighted avg — semua dari hasil data uji pelatihan classifier.

    Mengembalikan `None` bila metrics tidak memuat `per_class`
    (mis. estimator berasal dari file eksternal tanpa metrik lengkap).
    """
    if not metrics:
        return None
    per_class = metrics.get("per_class") or {}
    rows: list[dict[str, Any]] = []
    for cls in labels:
        c = per_class.get(cls)
        if not isinstance(c, dict):
            continue
        rows.append(
            {
                "label": cls,
                "precision": c.get("precision"),
                "recall": c.get("recall"),
                "f1_score": c.get("f1_score"),
                "support": c.get("support"),
            }
        )
    if not rows:
        return None

    def _col(key: str) -> list[float]:
        return [float(r[key]) for r in rows if isinstance(r.get(key), (int, float))]

    accuracy = metrics.get("accuracy")
    total = int(
        metrics.get("test_size")
        or sum(int(r["support"] or 0) for r in rows)
    )
    macro = {
        key: round(sum(vals) / len(vals), 4) if vals else None
        for key in ("precision", "recall", "f1_score")
        for vals in [_col(key)]
    }
    rows.append(
        {
            "label": "Accuracy",
            "precision": accuracy,
            "recall": accuracy,
            "f1_score": accuracy,
            "support": total,
        }
    )
    rows.append({"label": "Macro avg", **macro, "support": total})
    rows.append(
        {
            "label": "Weighted avg",
            "precision": metrics.get("precision"),
            "recall": metrics.get("recall"),
            "f1_score": metrics.get("f1_score"),
            "support": total,
        }
    )
    return rows


def build_upload_report(
    pred_labels: list[str],
    truth_labels: list[str] | None,
    labels: list[str],
) -> dict[str, Any] | None:
    """Susun laporan klasifikasi untuk file yang diunggah user.

    Format baris IDENTIK dengan `build_report` (per kelas + Accuracy +
    Macro avg + Weighted avg) sehingga UI cukup satu widget tabel.

    - Dengan label acuan (kolom score/Sentiment/label pada file):
      memakai `classification_report` sklearn — prediksi model DIBANDINGKAN
      dengan label di file user (bukan akurasi pelatihan).
    - Tanpa label acuan: hanya baris per kelas berisi jumlah prediksi
      (support); precision/recall/F1 diisi `None` karena tidak bisa dihitung.

    Mengembalikan `None` bila tidak ada baris sama sekali.
    """
    if not pred_labels:
        return None
    valid = set(labels)

    # Kasus tanpa label: distribusi prediksi per kelas saja.
    if truth_labels is None:
        rows = [
            {
                "label": cls,
                "precision": None,
                "recall": None,
                "f1_score": None,
                "support": sum(1 for p in pred_labels if p == cls),
            }
            for cls in labels
        ]
        return {"labeled": False, "accuracy": None, "rows": rows}

    # Kasus berlabel: hanya pasangan (label file, prediksi) yang valid.
    pairs = [
        (t, p)
        for t, p in zip(truth_labels, pred_labels)
        if t in valid and p in valid
    ]
    if not pairs:
        return None
    y_true = [t for t, _ in pairs]
    y_pred = [p for _, p in pairs]
    rep = classification_report(
        y_true, y_pred, labels=labels, output_dict=True, zero_division=0
    )

    def _row(name: str, src: dict[str, Any]) -> dict[str, Any]:
        return {
            "label": name,
            "precision": round(float(src["precision"]), 4),
            "recall": round(float(src["recall"]), 4),
            "f1_score": round(float(src["f1-score"]), 4),
            "support": int(src["support"]),
        }

    rows = [_row(cls, rep[cls]) for cls in labels if cls in rep]
    accuracy = round(float(rep["accuracy"]), 4)
    total = len(pairs)
    rows.append(
        {
            "label": "Accuracy",
            "precision": accuracy,
            "recall": accuracy,
            "f1_score": accuracy,
            "support": total,
        }
    )
    rows.append(_row("Macro avg", rep["macro avg"]))
    rows.append(_row("Weighted avg", rep["weighted avg"]))
    return {"labeled": True, "accuracy": accuracy, "rows": rows}


class ModelService:
    def __init__(self) -> None:
        self.payload: dict[str, Any] = {}
        self.vectorizer: Any = None
        self.labels: list[str] = []
        self.algorithm: str = "SVM"
        self.estimator: Any = None
        self.classifier_source: str = "none"
        self.metrics: dict[str, Any] | None = None
        self.training_samples: int | None = None
        self.trained_at: str | None = None
        self.ready: bool = False
        self.error: str | None = None
        self.history: deque[dict[str, Any]] = deque(maxlen=config.HISTORY_MAX_SIZE)
        self._lock = threading.Lock()
        self._dataset_summary: dict[str, Any] | None = None
        # Hasil analisis file CSV terakhir yang diunggah pengguna —
        # dipakai endpoint ekspor /api/report/csv/upload.
        self.last_upload: dict[str, Any] | None = None

    # ------------------------------------------------------------ muat model
    def load(self) -> dict[str, Any]:
        """Muat model + classifier (latih bila perlu). Aman dipanggil ulang."""
        with self._lock:
            if not config.MODEL_PATH.exists():
                self.error = f"File model tidak ditemukan: {config.MODEL_PATH}"
                self.ready = False
                return self.info()

            payload = joblib.load(config.MODEL_PATH)
            if not isinstance(payload, dict):
                raise ValueError(
                    "Format klinisia_model.joblib tidak sesuai (diharapkan dict berisi "
                    "'vectorizer', 'labels', 'model')."
                )

            self.payload = payload
            self.vectorizer = payload.get("vectorizer")
            self.labels = list(payload.get("labels") or ["Negatif", "Positif"])
            algo = payload.get("model")
            if isinstance(algo, list) and algo:
                algo = algo[0]
            self.algorithm = str(algo or "SVM")

            if self.vectorizer is None:
                raise ValueError("File model tidak memuat 'vectorizer'.")

            # 1) estimator dari file itu sendiri (jika ada)
            estimator = _find_estimator(payload)
            if estimator is not None:
                self.estimator = estimator
                self.classifier_source = "file"
                self.metrics = payload.get("metrics")
                self.training_samples = payload.get("training_samples")
                self.trained_at = payload.get("trained_at")
            else:
                # 2) file pendamping, kalau kompatibel
                loaded = self._load_companion()
                if not loaded:
                    # 3) latih dari dataset
                    self._train_companion()

            # Susun tabel laporan klasifikasi dari metrics yang tersimpan
            # (file lama belum memuat "report"; cukup disusun ulang di sini).
            if isinstance(self.metrics, dict) and "report" not in self.metrics:
                report = build_report(self.metrics, self.labels)
                if report is not None:
                    self.metrics["report"] = report

            self.ready = self.estimator is not None
            self.error = None if self.ready else "Classifier tidak tersedia."
            return self.info()

    def ensure_loaded(self) -> bool:
        """Pastikan model termuat sebelum dipakai (lazy-load).

        Dibutuhkan di environment serverless (Vercel dsb.) yang tidak
        menjalankan event lifespan ASGI — sehingga `service.load()` di
        `lifespan` tidak pernah terpanggil dan semua endpoint akan
        menjawab "Model belum siap". Aman dipanggil berulang dari banyak
        request bersamaan (`load()` sendiri sudah di bawah `self._lock`).
        """
        if self.ready:
            return True
        try:
            self.load()
        except Exception as exc:  # jangan bocorkan traceback ke client
            self.error = str(exc)
            self.ready = False
        return self.ready

    def _load_companion(self) -> bool:
        path = config.CLASSIFIER_PATH
        if not path.exists():
            return False
        try:
            blob = joblib.load(path)
            estimator = blob.get("estimator") if isinstance(blob, dict) else blob
            n_features = len(getattr(self.vectorizer, "vocabulary_", {}))
            if estimator is None or not hasattr(estimator, "predict"):
                return False
            coef = _coef_vector(estimator)
            if coef is None or coef.size != n_features:
                return False  # vectorizer berbeda -> perlu latih ulang
            if isinstance(blob, dict) and (
                blob.get("svc_c") != config.SVC_C
                or blob.get("svc_class_weight") != config.SVC_CLASS_WEIGHT
            ):
                return False  # parameter SVM berubah -> perlu latih ulang
            self.estimator = estimator
            self.classifier_source = "companion"
            if isinstance(blob, dict):
                self.metrics = blob.get("metrics")
                self.training_samples = blob.get("training_samples")
                self.trained_at = blob.get("trained_at")
            return True
        except Exception:
            return False

    def _train_companion(self) -> None:
        """Latih SVM linear dari dataset ulasan memakai vectorizer dari file model."""
        if not config.DATASET_PATH.exists():
            raise FileNotFoundError(
                "Classifier belum ada dan dataset tidak ditemukan: " + str(config.DATASET_PATH)
            )

        df = pd.read_csv(config.DATASET_PATH, usecols=lambda c: c in {"content", "score", "at"})
        df = df.dropna(subset=["content"])
        df["label"] = df["score"].apply(label_sentimen)
        df = df[df["label"].notna()]
        df["clean"] = df["content"].map(preprocessing.preprocess)
        df = df[df["clean"].str.strip() != ""]
        if len(df) < 20:
            raise ValueError("Dataset terlalu sedikit untuk melatih classifier.")

        X = self.vectorizer.transform(df["clean"].tolist())
        y = df["label"].astype(str)

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=config.TEST_SIZE, random_state=config.RANDOM_STATE, stratify=y
        )

        estimator = SVC(
            kernel="linear",
            C=config.SVC_C,
            class_weight=config.SVC_CLASS_WEIGHT,
            probability=True,
            random_state=config.RANDOM_STATE,
        )
        estimator.fit(X_train, y_train)

        y_pred = estimator.predict(X_test)
        report = classification_report(y_test, y_pred, output_dict=True, zero_division=0)
        self.metrics = {
            "accuracy": round(float(accuracy_score(y_test, y_pred)), 4),
            "precision": round(float(report["weighted avg"]["precision"]), 4),
            "recall": round(float(report["weighted avg"]["recall"]), 4),
            "f1_score": round(float(report["weighted avg"]["f1-score"]), 4),
            "per_class": {
                cls: {
                    "precision": round(float(report[cls]["precision"]), 4),
                    "recall": round(float(report[cls]["recall"]), 4),
                    "f1_score": round(float(report[cls]["f1-score"]), 4),
                    "support": int(report[cls]["support"]),
                }
                for cls in self.labels
                if cls in report
            },
            "confusion_matrix": confusion_matrix(y_test, y_pred, labels=self.labels).tolist(),
            "test_size": int(len(y_test)),
            "split": f"train_test_split(test_size={config.TEST_SIZE}, random_state={config.RANDOM_STATE}, stratify=y)",
        }
        # Tabel laporan klasifikasi ikut disimpan ke file pendamping
        # sehingga endpoint /api/model langsung menyediakannya.
        self.metrics["report"] = build_report(self.metrics, self.labels)
        self.estimator = estimator
        self.classifier_source = "trained_now"
        self.training_samples = int(len(df))
        self.trained_at = datetime.now().isoformat(timespec="seconds")

        config.CLASSIFIER_PATH.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump(
            {
                "estimator": estimator,
                "metrics": self.metrics,
                "labels": self.labels,
                "vocab_size": len(self.vectorizer.vocabulary_),
                "svc_c": config.SVC_C,
                "svc_class_weight": config.SVC_CLASS_WEIGHT,
                "training_samples": self.training_samples,
                "trained_at": self.trained_at,
                "source_model": str(config.MODEL_PATH.name),
            },
            config.CLASSIFIER_PATH,
        )

    # ------------------------------------------------------------ inferensi
    def analyze(self, text: str, top_k: int = 5) -> dict[str, Any]:
        if not self.ready:
            raise RuntimeError("Model belum siap: " + (self.error or "unknown"))

        cleaned = preprocessing.preprocess(text)
        vector = self.vectorizer.transform([cleaned])
        margin = float(self.estimator.decision_function(vector)[0])
        proba = self.estimator.predict_proba(vector)[0]
        classes = list(self.estimator.classes_)
        idx = int(np.argmax(proba))
        label = str(classes[idx])
        confidence = float(proba[idx])

        contributions = self._contributions(vector, top_k=top_k)
        empty = int(vector.nnz) == 0 or not cleaned.strip()

        return {
            "text": text,
            "cleaned_text": cleaned,
            "label": label,
            "is_positive": label == "Positif",
            "confidence": round(confidence, 4),
            "confidence_pct": round(confidence * 100, 1),
            "margin": round(margin, 4),
            "probabilities": {str(c): round(float(p), 4) for c, p in zip(classes, proba)},
            "top_contributions": contributions,
            "explanation": self._explain(label, contributions, empty),
            "is_empty": empty,
        }

    def analyze_many(self, texts: list[str], top_k: int = 3) -> list[dict[str, Any]]:
        results = [self.analyze(t, top_k=top_k) for t in texts]
        for i, res in enumerate(results):
            res["index"] = i
        return results

    def _contributions(self, vector: Any, top_k: int = 5) -> list[dict[str, Any]]:
        """Kontribusi tiap token terhadap margin SVM: tfidf_value * bobot_fitur."""
        if self.estimator is None:
            return []
        coef = _coef_vector(self.estimator)
        if coef is None:
            return []
        reverse = {i: w for w, i in self.vectorizer.vocabulary_.items()}
        row = vector.tocoo()
        items = [
            {
                "token": reverse.get(int(j), f"#{j}"),
                "weight": round(float(coef[int(j)]), 4),
                "tfidf": round(float(v), 4),
                "contribution": round(float(coef[int(j)] * v), 4),
            }
            for j, v in zip(row.col, row.data)
        ]
        items.sort(key=lambda x: x["contribution"])
        negative = [i for i in items if i["contribution"] < 0][:top_k]
        positive = [i for i in reversed(items) if i["contribution"] > 0][:top_k]
        # gabung: pengaruh terbesar sesuai arah prediksi diurutkan dari paling dominan
        return positive + negative

    @staticmethod
    def _join_id(words: list[str]) -> str:
        if len(words) == 1:
            return words[0]
        return ", ".join(words[:-1]) + ", dan " + words[-1]

    def _explain(self, label: str, contributions: list[dict[str, Any]], empty: bool) -> str:
        if empty:
            return (
                "Teks tidak menghasilkan fitur TF-IDF yang cocok dengan kosakata model "
                "(kemungkinan hanya berisi stopwords/simbol). Prediksi diambil dari bias model."
            )
        if label == "Positif":
            pos = [c for c in contributions if c["contribution"] >= 0.05][:3]
            if not pos:
                return (
                    "Tidak ada token pendukung berbobot positif yang material; "
                    "prediksi ditentukan oleh kombinasi seluruh fitur."
                )
            parts = [f"“{c['token']}” ({c['contribution']:+.2f})" for c in pos]
            return (
                "Token pendukung berbobot tinggi: "
                + self._join_id(parts)
                + " melampaui ambang batas klasifikasi."
            )
        neg = [c for c in contributions if c["contribution"] <= -0.05][:3]
        if not neg:
            return (
                "Tidak ada token keluhan berbobot negatif yang material; "
                "prediksi ditentukan oleh kombinasi seluruh fitur."
            )
        parts = [f"“{c['token']}” ({c['contribution']:+.2f})" for c in neg]
        return "Keluhan spesifik berbobot negatif: " + self._join_id(parts) + "."

    # ------------------------------------------------------------ bobot & info
    def weights(self, limit: int = 6) -> dict[str, Any]:
        coef = _coef_vector(self.estimator) if self.estimator is not None else None
        if coef is None:
            return {"positive": [], "negative": []}
        vocab = self.vectorizer.vocabulary_
        pairs = sorted(
            ((w, float(coef[i])) for w, i in vocab.items()),
            key=lambda x: x[1],
        )
        fmt = lambda p: [
            {"word": w, "weight": round(v, 4), "abs_weight": round(abs(v), 4)} for w, v in p
        ]
        return {
            "positive": fmt(list(reversed(pairs[-limit:]))),
            "negative": fmt(pairs[:limit]),
            "feature_count": int(coef.shape[0]),
        }

    def info(self) -> dict[str, Any]:
        vec = self.vectorizer
        return {
            "ready": self.ready,
            "error": self.error,
            "algorithm": f"SVM ({self.algorithm} - kernel linear)",
            "model_name": self.algorithm,
            "labels": self.labels,
            "classifier_source": self.classifier_source,
            "model_file": str(config.MODEL_PATH),
            "classifier_file": str(config.CLASSIFIER_PATH)
            if config.CLASSIFIER_PATH.exists()
            else None,
            "sklearn_version_in_file": self.payload.get("sklearn_version"),
            "sklearn_version_runtime": sklearn.__version__,
            "vectorizer": {
                "type": type(vec).__name__ if vec is not None else None,
                "vocab_size": len(getattr(vec, "vocabulary_", {}) or {}),
                "ngram_range": getattr(vec, "ngram_range", None),
                "norm": getattr(vec, "norm", None),
                "use_idf": getattr(vec, "use_idf", None),
            },
            "metrics": self.metrics,
            "svc_c": config.SVC_C,
            "svc_class_weight": config.SVC_CLASS_WEIGHT,
            "training_samples": self.training_samples,
            "trained_at": self.trained_at,
            "stemming_enabled": preprocessing.stemming_enabled(),
            "preprocessing_steps": preprocessing.steps(),
            "loaded_at": datetime.now().isoformat(timespec="seconds"),
        }

    # ------------------------------------------------------------ dataset
    def dataset_summary(self, refresh: bool = False) -> dict[str, Any]:
        if self._dataset_summary is not None and not refresh:
            return self._dataset_summary
        if not config.DATASET_PATH.exists():
            return {"available": False, "path": str(config.DATASET_PATH)}

        df = pd.read_csv(config.DATASET_PATH)
        labels = df["score"].apply(label_sentimen) if "score" in df.columns else None
        summary: dict[str, Any] = {
            "available": True,
            "path": str(config.DATASET_PATH.name),
            "total_reviews": int(len(df)),
            "columns": list(df.columns),
        }
        if labels is not None:
            counts = labels.value_counts().to_dict()
            total = int(len(labels))
            summary["label_counts"] = {
                "Negatif": int(counts.get("Negatif", 0)),
                "Positif": int(counts.get("Positif", 0)),
            }
            summary["label_ratio"] = {
                k: round(v / total * 100, 1) for k, v in summary["label_counts"].items()
            }
            summary["avg_rating"] = round(float(df["score"].mean()), 2)
            summary["score_distribution"] = {
                str(int(k)): int(v) for k, v in df["score"].value_counts().sort_index().items()
            }
        if "at" in df.columns:
            try:
                dates = pd.to_datetime(df["at"], errors="coerce").dropna()
                summary["period"] = {
                    "start": dates.min().isoformat(),
                    "end": dates.max().isoformat(),
                }
            except Exception:
                pass
        self._dataset_summary = summary
        return summary

    # ------------------------------------------------------------ riwayat
    def push_history(self, record: dict[str, Any]) -> None:
        self.history.appendleft(record)

    def get_history(self) -> list[dict[str, Any]]:
        return list(self.history)

    def clear_history(self) -> int:
        n = len(self.history)
        self.history.clear()
        return n

    # ------------------------------------------------------ unggahan CSV
    def set_last_upload(self, payload: dict[str, Any]) -> None:
        """Simpan hasil analisis file CSV terakhir (untuk ekspor laporan)."""
        self.last_upload = payload

    def get_last_upload(self) -> dict[str, Any] | None:
        return self.last_upload


service = ModelService()
