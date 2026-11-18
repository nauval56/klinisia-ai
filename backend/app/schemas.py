"""Skema request/response Pydantic untuk API Klinisia AI."""
from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, Field


class AnalyzeRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000, description="Ulasan pengguna aplikasi (teks bebas)")
    top_k: int = Field(5, ge=1, le=10, description="Jumlah token kontribusi teratas")


class BatchRequest(BaseModel):
    texts: list[str] = Field(..., min_length=1, description="Daftar ulasan yang akan dianalisis")
    top_k: int = Field(3, ge=1, le=10)


class ReportRow(BaseModel):
    text: str
    label: str
    confidence: Optional[float] = None
    margin: Optional[float] = None
    explanation: Optional[str] = None


class ReportRequest(BaseModel):
    results: list[ReportRow] = Field(..., min_length=1, description="Hasil analisis untuk diekspor")
    filename: Optional[str] = Field(None, description="Nama file CSV tanpa ekstensi")


class TokenContribution(BaseModel):
    token: str
    weight: float
    tfidf: float
    contribution: float


class AnalyzeResponse(BaseModel):
    text: str
    cleaned_text: str
    label: str
    is_positive: bool
    confidence: float
    confidence_pct: float
    margin: float
    probabilities: dict[str, float]
    top_contributions: list[dict[str, Any]]
    explanation: str
    is_empty: bool


class BatchSummary(BaseModel):
    total: int
    positif: int
    negatif: int
    ratio_positif_pct: float
    ratio_negatif_pct: float
    avg_confidence: float


__all__ = [
    "AnalyzeRequest",
    "BatchRequest",
    "ReportRow",
    "ReportRequest",
    "TokenContribution",
    "AnalyzeResponse",
    "BatchSummary",
]
