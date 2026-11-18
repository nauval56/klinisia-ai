"""Smoke test endpoint backend Klinisia AI.

Prasyarat: server berjalan (python run.py) di http://127.0.0.1:8000
Jalankan  : python scripts/smoke_test.py [base_url]
"""
from __future__ import annotations

import io
import sys
from pathlib import Path

import httpx

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8000"

PASS = 0
FAIL = 0


def check(name: str, ok: bool, detail: str = "") -> None:
    global PASS, FAIL
    tag = "OK  " if ok else "GAGAL"
    if ok:
        PASS += 1
    else:
        FAIL += 1
    print(f"[{tag}] {name}" + (f" -> {detail}" if detail else ""))


def main() -> None:
    client = httpx.Client(base_url=BASE, timeout=60)

    # 1. root & health
    r = client.get("/")
    check("GET /", r.status_code == 200 and r.json().get("model_ready") is True,
          str(r.json().get("model_ready")))

    r = client.get("/api/health")
    body = r.json()
    check("GET /api/health", r.status_code == 200 and body["status"] == "ok",
          f"akurasi={body.get('accuracy')}")

    # 2. info model
    r = client.get("/api/model")
    m = r.json()
    check("GET /api/model", r.status_code == 200 and m["ready"],
          f"sumber={m['classifier_source']}, vocab={m['vectorizer']['vocab_size']}, "
          f"akurasi={(m['metrics'] or {}).get('accuracy')}")

    # 2b. laporan klasifikasi (tabel P/R/F1/support di website)
    rep = (m.get("metrics") or {}).get("report") or []
    labels_rep = [str(row.get("label")) for row in rep]
    check("GET /api/model -> metrics.report (5 baris)",
          len(rep) == 5 and labels_rep[-3:] == ["Accuracy", "Macro avg", "Weighted avg"],
          f"baris={labels_rep}")

    # 3. analisis tunggal
    r = client.post("/api/analyze", json={"text": "Pelayanan sangat cepat dan dokter ramah."})
    a = r.json()
    check("POST /api/analyze (positif)", r.status_code == 200 and a["label"] == "Positif",
          f"label={a.get('label')} conf={a.get('confidence_pct')}% margin={a.get('margin')}")

    r = client.post("/api/analyze", json={"text": "Antrean sangat lama dan pelayanan lambat."})
    b = r.json()
    check("POST /api/analyze (negatif)", r.status_code == 200 and b["label"] == "Negatif",
          f"label={b.get('label')} conf={b.get('confidence_pct')}%")

    check("penjelasan token", bool(b.get("explanation")) and b.get("top_contributions") is not None,
          (b.get("explanation") or "")[:80])

    # 4. batch
    r = client.post("/api/analyze/batch", json={"texts": [
        "Aplikasi error terus tidak bisa daftar, kecewa",
        "Terima kasih aplikasi sangat membantu pendaftaran online",
        "Fitur booking mudah dipakai dan pendaftaran cepat selesai",
        "Aplikasi lemot dan kuota booking selalu habis",
    ]})
    bat = r.json()
    check("POST /api/analyze/batch", r.status_code == 200 and bat["summary"]["total"] == 4,
          str(bat.get("summary")))

    # 5. bobot & prediktor
    r = client.get("/api/model/weights?limit=5")
    w = r.json()
    check("GET /api/model/weights",
          r.status_code == 200 and len(w["positive"]) == 5 and len(w["negative"]) == 5,
          f"pos={[x['word'] for x in w['positive'][:3]]} neg={[x['word'] for x in w['negative'][:3]]}")

    r = client.get("/api/model/predict-token", params={"text": "aplikasi lemot dan booking susah"})
    check("GET /api/model/predict-token", r.status_code == 200 and r.json()["contributions"],
          f"kontribusi={len(r.json()['contributions'])}")

    # 6. ringkasan dataset
    r = client.get("/api/dataset/summary")
    d = r.json()
    check("GET /api/dataset/summary", r.status_code == 200 and d.get("available"),
          f"total={d.get('total_reviews')} label={d.get('label_counts')}")

    # 7. upload CSV
    csv_bytes = (
        "ulasan;score\n"
        '"Aplikasi sangat membantu, pendaftaran online mudah";5\n'
        '"Aplikasi error terus dan susah booking";1\n'
        '"Fitur booking sering gagal setelah update";2\n'
        '"Fitur booking mudah dipakai dan pendaftaran cepat";5\n'
        '"Kuota booking habis terus padahal sudah daftar";3\n'
        '"Terima kasih sudah membantu pendaftaran online";4\n'
    ).encode("utf-8")
    r = client.post(
        "/api/analyze/csv",
        files={"file": ("sample_ulasan.csv", io.BytesIO(csv_bytes), "text/csv")},
        data={"text_column": "ulasan"},
    )
    c = r.json() if r.status_code == 200 else {}
    if r.status_code != 200:
        print("       detail:", r.status_code, r.text[:400])
    check("POST /api/analyze/csv", r.status_code == 200 and c.get("rows_processed") == 6,
          f"kolom={c.get('column_used')} ringkasan={c.get('summary')} "
          f"akurasi_vs_label={(c.get('agreement') or {}).get('accuracy_pct')}%")

    # 7b. laporan klasifikasi khusus file unggahan (sinkron dg file)
    up_rep = c.get("upload_report") or {}
    up_rows = up_rep.get("rows") or []
    up_labels = [str(x.get("label")) for x in up_rows]
    check("POST /api/analyze/csv -> upload_report (berlabel, 5 baris)",
          up_rep.get("labeled") is True
          and len(up_rows) == 5
          and up_labels[-3:] == ["Accuracy", "Macro avg", "Weighted avg"]
          # Akurasi laporan = akurasi vs label pada file yang sama.
          and up_rep.get("accuracy") == (c.get("agreement") or {}).get("accuracy_vs_label"),
          f"baris={up_labels} akurasi={up_rep.get('accuracy')}")

    # 7c. pelaporan anggaran waktu analisis (default 5 menit / 300 detik):
    # file kecil pasti selesai -> tidak ada baris yang tertinggal.
    check("POST /api/analyze/csv -> anggaran waktu (selesai sebelum batas)",
          c.get("time_limit_exceeded") is False
          and c.get("rows_not_processed") == 0
          and c.get("warning") is None
          and (c.get("time_budget_seconds") or 0) > 0,
          f"budget={c.get('time_budget_seconds')}s "
          f"terlewat={c.get('rows_not_processed')} "
          f"lewat={c.get('time_limit_exceeded')}")

    # upload CSV tanpa kolom eksplisit (auto-detect + dataset asli, 20 baris)
    sample = Path(__file__).resolve().parent.parent / "data" / "hasil_scraper_ulasan_app_klinisia.csv"
    if sample.exists():
        head = sample.read_bytes().split(b"\n")
        mini = b"\n".join(head[:21])
        r = client.post(
            "/api/analyze/csv",
            files={"file": ("dataset_mini.csv", io.BytesIO(mini), "text/csv")},
            data={"limit": "20"},
        )
        c2 = r.json() if r.status_code == 200 else {}
        if r.status_code != 200:
            print("       detail:", r.status_code, r.text[:400])
        check("POST /api/analyze/csv (auto-detect kolom)", r.status_code == 200,
              f"kolom={c2.get('column_used')} diproses={c2.get('rows_processed')}")

    # 7c. CSV TANPA kolom label (satu kolom teks murni) -> upload_report
    # tetap ada (hanya prediksi); sekaligus menguji parser CSV satu kolom.
    plain = (
        "ulasan\n"
        '"Aplikasi sangat membantu dan mudah dipakai"\n'
        '"Aplikasi error terus dan susah booking"\n'
    ).encode("utf-8")
    r = client.post(
        "/api/analyze/csv",
        files={"file": ("tanpa_label.csv", io.BytesIO(plain), "text/csv")},
        data={"text_column": "ulasan"},
    )
    c3 = r.json() if r.status_code == 200 else {}
    rep3 = c3.get("upload_report") or {}
    rows3 = rep3.get("rows") or []
    check("POST /api/analyze/csv tanpa label -> upload_report (prediksi saja)",
          r.status_code == 200
          and rep3.get("labeled") is False
          and rep3.get("accuracy") is None
          and len(rows3) == 2
          and all(x.get("precision") is None for x in rows3)
          and sum(int(x.get("support") or 0) for x in rows3) == c3.get("rows_processed"),
          f"labeled={rep3.get('labeled')} support={[x.get('support') for x in rows3]}")

    # 7d. CSV dengan kolom label BINER 0/1 (format umum hasil ekspor)
    # -> dinormalisasi jadi Negatif/Positif, laporan berlabel tetap terbentuk.
    biner = (
        "ulasan;label\n"
        '"Aplikasi sangat membantu dan mudah dipakai";1\n'
        '"Aplikasi error terus dan susah booking";0\n'
        '"Fitur booking sering gagal setelah update";0\n'
        '"Fitur booking mudah dipakai dan pendaftaran cepat";1\n'
    ).encode("utf-8")
    r = client.post(
        "/api/analyze/csv",
        files={"file": ("label_biner.csv", io.BytesIO(biner), "text/csv")},
        data={"text_column": "ulasan"},
    )
    c4 = r.json() if r.status_code == 200 else {}
    rep4 = c4.get("upload_report") or {}
    check("POST /api/analyze/csv label biner 0/1 -> upload_report berlabel",
          r.status_code == 200
          and rep4.get("labeled") is True
          and rep4.get("accuracy") is not None
          and len(rep4.get("rows") or []) == 5,
          f"labeled={rep4.get('labeled')} akurasi={rep4.get('accuracy')} "
          f"agreement={(c4.get('agreement') or {}).get('accuracy_pct')}%")

    # 8. riwayat
    r = client.get("/api/history")
    h = r.json()
    check("GET /api/history", r.status_code == 200 and h["count"] > 0, f"count={h['count']}")

    # 9. ekspor CSV dari riwayat
    r = client.get("/api/report/csv/recent")
    check("GET /api/report/csv/recent",
          r.status_code == 200 and r.headers.get("content-type", "").startswith("text/csv"),
          f"panjang={len(r.text)} karakter, disposition={r.headers.get('content-disposition')}")

    # 10. ekspor CSV dari payload
    r = client.post("/api/report/csv", json={"results": [
        {"text": "layanan cepat", "label": "Positif", "confidence_pct": 95.0, "margin": 1.8},
        {"text": "antrean lama", "label": "Negatif", "confidence_pct": 91.0, "margin": -1.6},
    ], "filename": "laporan_uji"})
    check("POST /api/report/csv", r.status_code == 200 and "laporan_uji.csv" in
          r.headers.get("content-disposition", ""), f"baris={r.text.count(chr(10))}")

    # 10b. ekspor CSV dari hasil unggahan terakhir
    r = client.get("/api/report/csv/upload")
    check("GET /api/report/csv/upload",
          r.status_code == 200 and r.headers.get("content-type", "").startswith("text/csv")
          and r.headers.get("content-disposition", "").startswith("attachment"),
          f"panjang={len(r.text)} karakter, disposition={r.headers.get('content-disposition')}")

    # 10c. ekspor ringkasan PDF
    r = client.get("/api/report/pdf")
    is_pdf = r.content[:5] == b"%PDF-"
    check("GET /api/report/pdf",
          r.status_code == 200 and is_pdf
          and r.headers.get("content-type", "").startswith("application/pdf"),
          f"status={r.status_code}, awal={r.content[:8]!r}, panjang={len(r.content)} byte")

    # 11. validasi input
    r = client.post("/api/analyze", json={"text": ""})
    check("POST /api/analyze tolak teks kosong", r.status_code == 422, f"status={r.status_code}")

    # 12. docs
    r = client.get("/docs")
    check("GET /docs (Swagger UI)", r.status_code == 200)

    print(f"\n=== RINGKASAN: {PASS} berhasil, {FAIL} gagal ===")
    if FAIL:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
