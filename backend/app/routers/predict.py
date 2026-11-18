"""Endpoint inferensi sentimen: teks tunggal, batch, CSV, dan riwayat."""
from __future__ import annotations

import io
import time
from typing import Optional

import pandas as pd
from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from .. import config, schemas
from ..model_service import build_upload_report, label_sentimen, normalize_labels, service

router = APIRouter(prefix="/api", tags=["inferensi"])

TEXT_CANDIDATES = [
    "content",
    "text",
    "ulasan",
    "review",
    "komentar",
    "comment",
    "stopword_removal",
    "clean",
    "cleaning",
]

LABEL_COLUMNS = ["sentiment", "sentimen", "label"]


def _require_ready() -> None:
    if not service.ready:
        service.ensure_loaded()  # serverless: lifespan mungkin tidak dijalankan
    if not service.ready:
        raise HTTPException(status_code=503, detail=service.error or "Model belum siap.")


def _clamp(value: int, low: int, high: int) -> int:
    return max(low, min(value, high))


@router.post("/analyze", summary="Analisis sentimen satu ulasan")
def analyze(req: schemas.AnalyzeRequest) -> dict:
    _require_ready()
    result = service.analyze(req.text, top_k=req.top_k)
    service.push_history(
        {
            "type": "teks",
            "text": req.text,
            "label": result["label"],
            "confidence": result["confidence"],
            "confidence_pct": result["confidence_pct"],
            "margin": result["margin"],
            "explanation": result["explanation"],
        }
    )
    return result


@router.post("/analyze/batch", summary="Analisis sentimen banyak ulasan")
def analyze_batch(req: schemas.BatchRequest) -> dict:
    _require_ready()
    if len(req.texts) > config.MAX_BATCH_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"Maksimal {config.MAX_BATCH_SIZE} teks per request batch.",
        )
    results = service.analyze_many(req.texts, top_k=req.top_k)
    positif = sum(1 for r in results if r["is_positive"])
    negatif = len(results) - positif
    total = len(results)
    summary = {
        "total": total,
        "positif": positif,
        "negatif": negatif,
        "ratio_positif_pct": round(positif / total * 100, 1),
        "ratio_negatif_pct": round(negatif / total * 100, 1),
        "avg_confidence": round(sum(r["confidence"] for r in results) / total, 4),
    }
    service.push_history({"type": "batch", "total": total, "summary": summary})
    return {"results": results, "summary": summary}


def _pick_text_column(df: pd.DataFrame, requested: Optional[str]) -> str:
    columns = {c.lower(): c for c in df.columns}
    if requested:
        if requested.lower() not in columns:
            raise HTTPException(
                status_code=400,
                detail=f"Kolom '{requested}' tidak ada di CSV. Kolom tersedia: {list(df.columns)}",
            )
        return columns[requested.lower()]
    for name in TEXT_CANDIDATES:
        if name in columns:
            return columns[name]
    # fallback: kolom objek pertama yang berisi teks cukup panjang
    for col in df.columns:
        if df[col].dtype == object:
            sample = df[col].dropna().astype(str).head(20)
            if not sample.empty and sample.str.len().mean() > 10:
                return col
    raise HTTPException(
        status_code=400,
        detail="Tidak menemukan kolom teks. Tentukan parameter text_column. "
        f"Kolom tersedia: {list(df.columns)}",
    )


def _is_zip(raw: bytes) -> bool:
    """Deteksi file berbasis ZIP (magic `PK`) — ciri file .xlsx modern."""
    return raw[:4] == b"PK\x03\x04"


def _is_old_xls(raw: bytes) -> bool:
    """Deteksi format .xls jadul (OLE2 compound file) yang TIDAK didukung."""
    return raw[:8] == b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"


def _read_table_smart(raw: bytes, filename: str, requested: Optional[str]) -> pd.DataFrame:
    """Baca file unggahan: CSV (auto-separator) ATAU Excel .xlsx.

    .xlsx dibaca lewat `pd.read_excel` (dependensi openpyxl). Format .xls
    jadul ditolak dengan pesan jelas agar user menyimpan ulang ke .xlsx/.csv.
    """
    name = (filename or "").lower()
    if _is_old_xls(raw) and not name.endswith(".csv"):
        raise HTTPException(
            status_code=400,
            detail="Format .xls (Excel lama) tidak didukung. "
            "Buka file lalu 'Save As' -> pilih .xlsx atau .csv, lalu unggah ulang.",
        )
    if name.endswith((".xlsx", ".xlsm")) or (_is_zip(raw) and not name.endswith(".csv")):
        try:
            df = pd.read_excel(io.BytesIO(raw), engine="openpyxl")
        except ImportError as exc:  # pragma: no cover - openpyxl wajib di requirements
            raise HTTPException(
                status_code=400,
                detail="Dukungan file Excel (openpyxl) belum terpasang di server.",
            ) from exc
        except Exception as exc:
            raise HTTPException(
                status_code=400,
                detail=f"Gagal membaca file Excel: {exc}",
            ) from exc
        if df.empty:
            raise HTTPException(status_code=400, detail="File Excel tidak berisi baris data.")
        return df
    return _read_csv_smart(raw, requested)


def _read_csv_smart(raw: bytes, requested: Optional[str]) -> pd.DataFrame:
    """Baca CSV unggahan dengan deteksi pemisah yang lebih stabil.

    `sep=None` bisa salah menebak pada CSV minim kolom (mis. satu kolom
    teks tanpa pemisah justru terpecah oleh huruf yang sering muncul).
    Strategi: coba deteksi otomatis dulu; bila kolom teks tidak bisa
    dipilih dari hasilnya, ulangi dengan pemisah koma lalu titik-koma.
    """
    attempts = (None, ",", ";", "\t")
    frames: list[pd.DataFrame] = []
    for sep in attempts:
        try:
            try:
                df = pd.read_csv(io.BytesIO(raw), encoding="utf-8-sig", sep=sep, engine="python")
            except UnicodeDecodeError:
                df = pd.read_csv(io.BytesIO(raw), encoding="latin-1", sep=sep, engine="python")
        except Exception:
            continue  # coba pemisah berikutnya
        if df.empty:
            continue
        frames.append(df)
        # Pakai hasil ini bila kolom teks sudah bisa dipilih.
        try:
            _pick_text_column(df, requested)
            return df
        except HTTPException:
            continue
    if frames:
        # Kembalikan hasil terakhir agar pesan error kolom tetap informatif.
        return frames[-1]
    raise HTTPException(
        status_code=400,
        detail="Gagal membaca CSV (format tidak dikenali).",
    )


@router.post("/analyze/csv", summary="Analisis sentimen dari file CSV (unggahan)")
async def analyze_csv(
    file: UploadFile = File(..., description="File CSV berisi ulasan"),
    text_column: Optional[str] = Form(None, description="Nama kolom teks (otomatis bila kosong)"),
    limit: Optional[int] = Form(
        None, description="Batas baris (kosong = seluruh baris file dianalisis)"
    ),
) -> dict:
    _require_ready()
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="File kosong.")
    df = _read_table_smart(raw, file.filename or "", text_column)
    if df.empty:
        raise HTTPException(status_code=400, detail="File tidak berisi baris data.")

    col = _pick_text_column(df, text_column)
    # Analisis mengikuti jumlah data yang diunggah user (tanpa dipotong):
    # - MAX_CSV_ROWS == 0 (default) -> seluruh baris file dianalisis;
    # - MAX_CSV_ROWS  > 0           -> dibatasi sampai angka tersebut;
    # - limit eksplisit dari client tetap dihormati (untuk kompatibilitas).
    if config.MAX_CSV_ROWS > 0:
        limit = _clamp(limit or config.MAX_CSV_ROWS, 1, config.MAX_CSV_ROWS)
    elif limit is not None and limit < 1:
        limit = None
    work = df.head(limit).copy() if limit else df.copy()
    work = work[work[col].notna()]
    work["teks"] = work[col].astype(str).str.strip()
    work = work[work["teks"] != ""]
    if work.empty:
        raise HTTPException(status_code=400, detail=f"Kolom '{col}' tidak berisi teks ulasan.")

    # Anggaran waktu analisis (default 300 detik / 5 menit): jumlah data
    # tetap mengikuti unggahan user, tetapi proses BERHENTI setelah
    # selama ini — baris yang belum sempat dianalisis dilaporkan jelas
    # (rows_not_processed + time_limit_exceeded), bukan dipotong diam-diam.
    budget = config.ANALYSIS_TIME_BUDGET
    deadline = (time.monotonic() + budget) if budget > 0 else None
    timed_out = False
    t_start = time.monotonic()

    results: list[dict] = []
    for i, (_, row) in enumerate(work.iterrows()):
        if deadline is not None and i > 0 and time.monotonic() >= deadline:
            timed_out = True
            break
        res = service.analyze(row["teks"], top_k=3)
        results.append(
            {
                "index": i,
                "text": res["text"],
                "label": res["label"],
                "is_positive": res["is_positive"],
                "confidence": res["confidence"],
                "confidence_pct": res["confidence_pct"],
                "margin": res["margin"],
                "explanation": res["explanation"],
            }
        )

    total = len(results)
    elapsed = round(time.monotonic() - t_start, 2)
    rows_not_processed = int(len(work)) - total
    # Pemberitahuan bila anggaran waktu habis sebelum seluruh baris selesai.
    warning = (
        f"Analisis dihentikan pada batas waktu {budget:g} detik; "
        f"{rows_not_processed} dari {int(len(work))} baris belum sempat "
        f"dianalisis ({total} baris berhasil dianalisis dalam {elapsed} detik)."
        if timed_out
        else None
    )
    positif = sum(1 for r in results if r["is_positive"])
    negatif = total - positif
    summary = {
        "total": total,
        "positif": positif,
        "negatif": negatif,
        "ratio_positif_pct": round(positif / total * 100, 1),
        "ratio_negatif_pct": round(negatif / total * 100, 1),
        "avg_confidence": round(sum(r["confidence"] for r in results) / total, 4),
    }

    # Bila dataset punya label (score / kolom label), bandingkan dengan prediksi
    agreement = None
    cols_lower = {c.lower(): c for c in df.columns}
    label_col = next((cols_lower[n] for n in LABEL_COLUMNS if n in cols_lower), None)
    score_col = cols_lower.get("score")
    truth = None
    if label_col:
        # Kolom label apa pun: teks (positif/negatif), biner 0/1, atau
        # skor 1-5 — dinormalisasi otomatis oleh normalize_labels.
        truth = normalize_labels(work[label_col].tolist())
    elif score_col:
        truth = work[score_col].apply(label_sentimen).tolist()
    if truth is not None:
        pairs = [(t, r["label"]) for t, r in zip(truth, results) if t in {"Negatif", "Positif"}]
        if pairs:
            correct = sum(1 for t, p in pairs if t == p)
            # Sebut format file SESUNGGUHNYA (.csv/.tsv/.xlsx) — jangan
            # hardcode "CSV" karena user bisa mengunggah Excel.
            ext = (file.filename or "").rsplit(".", 1)[-1].lower()
            ext = ext if ext in {"csv", "tsv", "xlsx"} else "csv"
            agreement = {
                "labeled_rows": len(pairs),
                "accuracy_vs_label": round(correct / len(pairs), 4),
                "accuracy_pct": round(correct / len(pairs) * 100, 1),
                "note": "Label acuan diturunkan dari kolom score (1-3 Negatif, 4-5 Positif)."
                if score_col
                else f"Label acuan dari kolom label pada file .{ext.upper()}.",
            }

    # Laporan klasifikasi khusus file unggahan ini (sinkron dengan file):
    # prediksi model vs label acuan di file bila ada; tanpa label hanya
    # jumlah prediksi per kelas. Format baris = laporan klasifikasi
    # (per kelas + Accuracy + Macro avg + Weighted avg).
    upload_report = build_upload_report(
        pred_labels=[r["label"] for r in results],
        truth_labels=truth,
        labels=service.labels or ["Negatif", "Positif"],
    )

    service.push_history(
        {"type": "csv", "file": file.filename, "column": col, "summary": summary}
    )
    # Simpan hasil lengkap → dasar tombol "Unduh Hasil Analisis (CSV)"
    # di Halaman Ringkasan Dataset Flutter.
    service.set_last_upload(
        {
            "filename": file.filename,
            "column": col,
            "rows_total_in_file": int(len(df)),
            "rows_processed": total,
            "rows_not_processed": rows_not_processed,
            "time_limit_exceeded": timed_out,
            "time_budget_seconds": budget,
            "elapsed_seconds": elapsed,
            "warning": warning,
            "results": results,
            "summary": summary,
            "agreement": agreement,
            "upload_report": upload_report,
        }
    )
    return {
        "filename": file.filename,
        "column_used": col,
        "columns": list(df.columns),
        "rows_total_in_file": int(len(df)),
        "rows_processed": total,
        "rows_not_processed": rows_not_processed,
        "time_limit_exceeded": timed_out,
        "time_budget_seconds": budget,
        "elapsed_seconds": elapsed,
        "warning": warning,
        "results": results,
        "summary": summary,
        "agreement": agreement,
        "upload_report": upload_report,
    }


@router.get("/history", summary="Riwayat analisis terakhir (di memori)")
def history() -> dict:
    items = service.get_history()
    return {"count": len(items), "items": items}


@router.delete("/history", summary="Bersihkan riwayat analisis")
def clear_history() -> dict:
    removed = service.clear_history()
    return {"removed": removed}
