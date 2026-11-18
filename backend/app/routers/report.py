"""Endpoint ekspor laporan (CSV & PDF) untuk dashboard Klinisia."""
from __future__ import annotations

import csv
import io
import re
from datetime import datetime

import pandas as pd
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse

from .. import schemas
from ..model_service import service
from ..pdf_builder import build_summary_pdf

router = APIRouter(prefix="/api/report", tags=["laporan"])

CSV_HEADER = ["No", "Ulasan", "Sentimen", "Confidence (%)", "Margin", "Penjelasan"]


def _safe_filename(name: str | None) -> str:
    base = (name or "laporan_sentimen_klinisia").strip()
    base = re.sub(r"[^\w\-]+", "_", base)
    return (base or "laporan_sentimen_klinisia") + ".csv"


def _rows_table(rows: list[dict]) -> dict[str, list]:
    """Kolom tabel laporan (dipakai CSV & XLSX agar isinya sama persis)."""
    return {
        "No": list(range(1, len(rows) + 1)),
        "Ulasan": [r.get("text", "") for r in rows],
        "Sentimen": [r.get("label", "") for r in rows],
        "Confidence (%)": [r.get("confidence_pct", "") for r in rows],
        "Margin": [r.get("margin", "") for r in rows],
        "Penjelasan": [r.get("explanation", "") for r in rows],
    }


def _build_xlsx(rows: list[dict]) -> bytes:
    """Hasil analisis sebagai file Excel (.xlsx) — mengikuti unggahan user."""
    buf = io.BytesIO()
    pd.DataFrame(_rows_table(rows)).to_excel(buf, index=False, engine="openpyxl")
    return buf.getvalue()


def _build_csv(rows: list[dict]) -> io.StringIO:
    buffer = io.StringIO(newline="")
    writer = csv.writer(buffer)
    writer.writerow(CSV_HEADER)
    for i, row in enumerate(rows, start=1):
        writer.writerow(
            [
                i,
                row.get("text", ""),
                row.get("label", ""),
                row.get("confidence_pct", ""),
                row.get("margin", ""),
                row.get("explanation", ""),
            ]
        )
    return buffer


def _stream(buffer: io.StringIO, filename: str) -> StreamingResponse:
    data = "\ufeff" + buffer.getvalue()  # BOM agar aman dibuka Excel
    return StreamingResponse(
        iter([data]),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Access-Control-Expose-Headers": "Content-Disposition",
        },
    )


def _stream_bytes(data: bytes, filename: str, media_type: str) -> StreamingResponse:
    """Streaming file biner (mis. .xlsx) sebagai lampiran unduhan."""
    return StreamingResponse(
        iter([data]),
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Access-Control-Expose-Headers": "Content-Disposition",
        },
    )


def _fmt_num(v, digit: int = 3) -> str:
    """Format angka P/R/F1 untuk PDF: 3 desimal, '-' bila kosong."""
    return f"{float(v):.{digit}f}" if isinstance(v, (int, float)) else "-"


def _report_row(row: dict) -> list[str]:
    """Satu baris tabel laporan klasifikasi: kelas, P, R, F1, support."""
    supp = row.get("support")
    return [
        str(row.get("label", "-")),
        _fmt_num(row.get("precision")),
        _fmt_num(row.get("recall")),
        _fmt_num(row.get("f1_score")),
        str(supp) if isinstance(supp, int) else "-",
    ]


@router.post("/csv", summary="Ekspor hasil analisis ke file CSV")
def export_csv(req: schemas.ReportRequest) -> StreamingResponse:
    rows = [r.model_dump() for r in req.results]
    return _stream(_build_csv(rows), _safe_filename(req.filename))


@router.get("/csv/recent", summary="Ekspor riwayat analisis terakhir ke CSV")
def export_history_csv() -> StreamingResponse:
    history = [h for h in service.get_history() if h.get("type") == "teks"]
    if not history:
        raise HTTPException(
            status_code=404,
            detail="Belum ada riwayat analisis teks. Lakukan POST /api/analyze terlebih dahulu.",
        )
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return _stream(_build_csv(history), f"riwayat_sentimen_{stamp}.csv")


@router.get("/csv/upload", summary="Ekspor hasil analisis unggahan terakhir")
def export_upload_csv(format: str = Query("csv", pattern="^(csv|xlsx)$")) -> StreamingResponse:
    """Ekspor seluruh baris hasil analisis file yang baru diunggah user.

    Dipakai tombol "Unduh Hasil Analisis (.CSV/.XLSX)" — format mengikuti
    file yang diunggah user (xlsx -> file Excel, selain itu -> CSV).
    """
    upload = service.get_last_upload()
    if not upload or not upload.get("results"):
        raise HTTPException(
            status_code=404,
            detail="Belum ada file terunggah. Unggah file lebih dulu (POST /api/analyze/csv).",
        )
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    base = re.sub(
        r"\.(csv|xlsx|tsv|xls)$",
        "",
        str(upload.get("filename") or "hasil_unggahan"),
        flags=re.I,
    )
    rows = upload["results"]
    if format == "xlsx":
        return _stream_bytes(
            _build_xlsx(rows),
            f"hasil_{base}_{stamp}.xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
    return _stream(_build_csv(rows), f"hasil_{base}_{stamp}.csv")


@router.get("/pdf", summary="Unduh ringkasan analisis berformat PDF")
def export_summary_pdf() -> StreamingResponse:
    """Ringkasan dashboard (model + dataset + unggahan + riwayat) dalam satu file PDF."""
    info = service.info()
    dataset = service.dataset_summary()
    history = [h for h in service.get_history() if h.get("type") == "teks"]
    upload = service.get_last_upload()

    if not service.ready:
        service.ensure_loaded()  # serverless: lifespan mungkin tidak dijalankan
    if not service.ready:
        raise HTTPException(
            status_code=503,
            detail=f"Model belum siap: {info.get('error') or 'vectorizer/classifier belum termuat.'}",
        )

    # Konten disusun sebagai BLOK (lihat pdf_builder.build_summary_pdf)
    # agar PDF rapi: judul bagian tampil tebal dengan garis pemisah, baris
    # label/nilai disejajarkan pada kolom tetap, dan tabel memakai posisi
    # kolom tetap + kepala berlatar. Halaman berlipat otomatis.
    blocks: list[dict] = []

    # --- Bagian model ---
    blocks.append({"kind": "heading", "text": "MODEL"})
    blocks.append({"kind": "kv", "label": "Algoritma",
                   "value": str(info.get("algorithm"))})
    blocks.append({"kind": "kv", "label": "Sumber klasifier",
                   "value": str(info.get("classifier_source"))})
    labels = info.get("labels") or []
    blocks.append({"kind": "kv", "label": "Label",
                   "value": ", ".join(labels)})
    metrics = info.get("metrics") or {}
    if metrics:
        acc = metrics.get("accuracy")
        f1 = metrics.get("f1_score")
        if acc is not None:
            blocks.append({"kind": "kv", "label": "Akurasi uji",
                           "value": f"{float(acc) * 100:.2f}%"})
        if f1 is not None:
            blocks.append({"kind": "kv", "label": "F1-score (w)",
                           "value": f"{float(f1):.3f}"})
    vec = info.get("vectorizer") or {}
    if vec.get("vocab_size"):
        blocks.append({"kind": "kv", "label": "Vokabuler TF-IDF",
                       "value": f"{vec['vocab_size']} fitur"})
    if info.get("training_samples"):
        blocks.append({"kind": "kv", "label": "Data latih",
                       "value": str(info["training_samples"])})
    if info.get("stemming_enabled"):
        blocks.append({"kind": "kv", "label": "Preprocessing",
                       "value": "stemming Sastrawi aktif"})

    # --- Bagian laporan klasifikasi (P/R/F1/support per kelas) ---
    # Laporan klasifikasi yang dicetak = FILE UNGGAHAN USER (upload_report),
    # selaras dengan kartu "Laporan Klasifikasi" di website. Bila belum ada
    # unggahan, bagian ini dilewat (ringkasan model tetap di bagian MODEL).
    up_rep0 = (upload or {}).get("upload_report") or {}
    report_rows = up_rep0.get("rows") or []
    if report_rows:
        blocks.append({"kind": "spacer", "height": 4})
        judul = "LAPORAN KLASIFIKASI (file unggahan)"
        if not up_rep0.get("labeled"):
            judul += " - tanpa kolom label"
        blocks.append({"kind": "heading", "text": judul})
        blocks.append(
            {
                "kind": "table",
                "header": ["Kelas", "Precision", "Recall", "F1-Score",
                           "Support"],
                "rows": [_report_row(r) for r in report_rows],
            }
        )

    # --- Bagian dataset ---
    blocks.append({"kind": "spacer", "height": 4})
    blocks.append({"kind": "heading", "text": "DATASET"})
    if dataset.get("available"):
        blocks.append({"kind": "kv", "label": "File",
                       "value": str(dataset.get("path"))})
        blocks.append({"kind": "kv", "label": "Total ulasan",
                       "value": str(dataset.get("total_reviews"))})
        counts = dataset.get("label_counts") or {}
        ratio = dataset.get("label_ratio") or {}
        for key in ("positif", "Positif", "negatif", "Negatif"):
            if key in counts:
                pct = ratio.get(key, ratio.get(key.lower()))
                suffix = f" ({pct}%)" if pct is not None else ""
                blocks.append({"kind": "kv", "label": key,
                               "value": f"{counts[key]}{suffix}"})
    else:
        blocks.append({"kind": "text",
                       "text": "Dataset tidak ditemukan di backend."})

    # --- Bagian hasil unggahan CSV terakhir ---
    if upload:
        blocks.append({"kind": "spacer", "height": 4})
        blocks.append({"kind": "heading",
                       "text": f"HASIL UNGGAHAN ({upload.get('filename')})"})
        blocks.append({"kind": "kv", "label": "Kolom teks",
                       "value": str(upload.get("column"))})
        blocks.append({"kind": "kv", "label": "Baris diproses",
                       "value": str(upload.get("rows_processed"))})
        up_sum = upload.get("summary") or {}
        if up_sum:
            blocks.append(
                {
                    "kind": "kv",
                    "label": "Positif/Negatif",
                    "value": (
                        f"{up_sum.get('positif')} / {up_sum.get('negatif')}"
                        f" ({up_sum.get('ratio_positif_pct')}% / "
                        f"{up_sum.get('ratio_negatif_pct')}%)"
                    ),
                }
            )
        # Kartu "F1 Score" (web) memakai F1 weighted avg DARI FILE INI —
        # samakan di PDF agar konsisten (nilai mengikuti unggahan user).
        up_rep = upload.get("upload_report") or {}
        up_weighted = next(
            (r for r in up_rep.get("rows") or []
             if r.get("label") == "Weighted avg"),
            None,
        )
        up_f1 = up_weighted.get("f1_score") if up_weighted else None
        if up_f1 is not None:
            blocks.append({"kind": "kv", "label": "F1 Score",
                           "value": f"{round(float(up_f1) * 100, 1)}%"})

        # Butir bernomor: teks hasil analisis (dibungkus rapi bila panjang).
        results = upload.get("results") or []
        for i, r in enumerate(results[:15], start=1):
            text = str(r.get("text", ""))[:120]
            label = r.get("label", "-")
            conf = r.get("confidence_pct")
            conf_s = f"{conf}%" if conf is not None else "-"
            blocks.append({"kind": "item", "index": i,
                           "text": f"[{label} {conf_s}] {text}"})
        if len(results) > 15:
            blocks.append({"kind": "text",
                           "text": f"... dan {len(results) - 15} "
                                   "baris lainnya."})

    # --- Bagian riwayat analisis ---
    blocks.append({"kind": "spacer", "height": 4})
    blocks.append({"kind": "heading",
                   "text": f"RIWAYAT ANALISIS ({len(history)} teks)"})
    if history:
        for i, h in enumerate(history[:15], start=1):
            text = str(h.get("text", ""))[:120]
            label = h.get("label", "-")
            conf = h.get("confidence_pct")
            conf_s = f"{conf}%" if conf is not None else "-"
            blocks.append({"kind": "item", "index": i,
                           "text": f"[{label} {conf_s}] {text}"})
        if len(history) > 15:
            blocks.append({"kind": "text",
                           "text": f"... dan {len(history) - 15} "
                                   "analisis lainnya."})
    else:
        blocks.append({"kind": "text",
                       "text": "Belum ada riwayat analisis teks."})

    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    pdf_bytes = build_summary_pdf(
        title="Laporan Ringkasan Sentimen Ulasan Play Store - Klinisia AI",
        blocks=blocks,
    )
    return StreamingResponse(
        iter([pdf_bytes]),
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="ringkasan_sentimen_{stamp}.pdf"',
            "Access-Control-Expose-Headers": "Content-Disposition",
        },
    )
