"""Klinisia AI — Backend API analisis sentimen ulasan pengguna aplikasi Klinisia
di Google Play Store (SVM Linear + TF-IDF).

Jalankan dengan:
    uvicorn app.main:app --host 0.0.0.0 --port 8000
atau:
    python run.py
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import __version__, config
from .model_service import service
from .routers import model, predict, report

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger("klinisia")


@asynccontextmanager
async def lifespan(_: FastAPI):
    log.info("Memuat model Klinisia AI ...")
    try:
        info = service.load()
        log.info(
            "Model siap | sumber classifier: %s | akurasi: %s | fitur: %s",
            info.get("classifier_source"),
            (info.get("metrics") or {}).get("accuracy"),
            (info.get("vectorizer") or {}).get("vocab_size"),
        )
    except Exception as exc:  # tetap nyalakan API agar endpoint error bisa dijelaskan
        log.error("Gagal memuat model: %s", exc)
        service.ready = False
        service.error = str(exc)
    yield


app = FastAPI(
    title="Klinisia AI API",
    description=(
        "Backend analisis sentimen ulasan pengguna aplikasi Klinisia di Play Store "
        "dengan SVM Linear Kernel + TF-IDF. "
        "Menggunakan model `klinisia_model.joblib` (vectorizer & label) dilengkapi "
        "classifier SVM pendamping yang dilatih dari dataset ulasan Play Store."
    ),
    version=__version__,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

app.include_router(predict.router)
app.include_router(model.router)
app.include_router(report.router)


@app.get("/", tags=["umum"])
def root() -> dict:
    service.ensure_loaded()  # serverless: lifespan mungkin tidak dijalankan
    return {
        "name": "Klinisia AI API",
        "version": __version__,
        "model_ready": service.ready,
        "docs": "/docs",
        "endpoints": {
            "POST /api/analyze": "Analisis sentimen 1 ulasan",
            "POST /api/analyze/batch": "Analisis banyak ulasan",
            "POST /api/analyze/csv": "Analisis file CSV (unggahan)",
            "GET /api/model": "Info model, pipeline, dan metrik",
            "GET /api/model/weights": "Bobot fitur SVM (prediktor +/-)",
            "GET /api/dataset/summary": "Ringkasan dataset ulasan",
            "GET /api/history": "Riwayat analisis terakhir",
            "POST /api/report/csv": "Ekspor hasil ke CSV",
            "GET /api/report/csv/recent": "Ekspor riwayat ke CSV",
        },
    }


@app.get("/api/health", tags=["umum"])
def health() -> dict:
    service.ensure_loaded()  # serverless: lifespan mungkin tidak dijalankan
    info = service.info()
    return {
        "status": "ok" if service.ready else "degraded",
        "model_ready": service.ready,
        "error": service.error,
        "classifier_source": info.get("classifier_source"),
        "labels": info.get("labels"),
        "accuracy": (info.get("metrics") or {}).get("accuracy"),
    }
