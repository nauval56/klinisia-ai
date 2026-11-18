"""Endpoint info model, bobot fitur SVM, dataset, dan reload."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from ..model_service import service

router = APIRouter(prefix="/api", tags=["model"])


@router.get("/model", summary="Info model, pipeline, dan metrik evaluasi")
def model_info() -> dict:
    service.ensure_loaded()  # serverless: lifespan mungkin tidak dijalankan
    return service.info()


@router.post("/model/reload", summary="Muat ulang model & classifier dari disk")
def reload_model() -> dict:
    try:
        return service.load()
    except Exception as exc:  # pragma: no cover - jalur error diagnostik
        raise HTTPException(status_code=500, detail=f"Gagal memuat model: {exc}") from exc


@router.get("/model/weights", summary="Bobot fitur SVM (prediktor positif & negatif)")
def model_weights(limit: int = Query(6, ge=1, le=50)) -> dict:
    service.ensure_loaded()
    if not service.ready:
        raise HTTPException(status_code=503, detail=service.error or "Model belum siap.")
    return service.weights(limit=limit)


@router.get("/model/predict-token", summary="Bobot yang muncul pada teks tertentu")
def token_weights(text: str = Query(..., min_length=1, max_length=5000)) -> dict:
    service.ensure_loaded()
    if not service.ready:
        raise HTTPException(status_code=503, detail=service.error or "Model belum siap.")
    result = service.analyze(text, top_k=10)
    return {
        "text": result["text"],
        "cleaned_text": result["cleaned_text"],
        "margin": result["margin"],
        "contributions": result["top_contributions"],
    }


@router.get("/dataset/summary", summary="Ringkasan dataset ulasan Play Store")
def dataset_summary(refresh: bool = Query(False, description="Hitung ulang ringkasan")) -> dict:
    return service.dataset_summary(refresh=refresh)
