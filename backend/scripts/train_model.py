"""Paksa latih ulang classifier pendamping (SVM) dari dataset ulasan.

Jalankan:  python scripts/train_model.py [--force]
Output   : models/klinisia_svm_classifier.joblib + laporan metrik
"""
from __future__ import annotations

import argparse
import sys
import warnings
from pathlib import Path

warnings.filterwarnings("ignore")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app import config
from app.model_service import service


def main() -> None:
    parser = argparse.ArgumentParser(description="Latih ulang classifier SVM pendamping Klinisia")
    parser.add_argument("--force", action="store_true", help="Hapus classifier lama sebelum latih")
    args = parser.parse_args()

    if args.force and config.CLASSIFIER_PATH.exists():
        config.CLASSIFIER_PATH.unlink()
        print(f"Menghapus {config.CLASSIFIER_PATH.name} lama ...")

    info = service.load()
    if not info["ready"]:
        print("GAGAL:", info["error"])
        raise SystemExit(1)

    m = info["metrics"] or {}
    print("\n=== HASIL PELATIHAN CLASSIFIER PENDAMPING ===")
    print("Sumber classifier :", info["classifier_source"])
    print("File classifier   :", info["classifier_file"])
    print("Jumlah data latih :", info["training_samples"])
    print("Parameter SVM     : kernel=linear, C =", info["svc_c"],
          ", class_weight =", info["svc_class_weight"])
    print("Stemming          :", info["stemming_enabled"])
    print("Akurasi (uji 20%) :", m.get("accuracy"))
    print("Precision (w)     :", m.get("precision"))
    print("Recall (w)        :", m.get("recall"))
    print("F1-Score (w)      :", m.get("f1_score"))
    print("Confusion matrix  :", m.get("confusion_matrix"), f"(label: {info['labels']})")
    print("Per class         :", m.get("per_class"))
    print("\nContoh inferensi:")
    for text in [
        "Pelayanan sangat cepat dan dokter ramah.",
        "Antrean sangat lama dan pelayanan lambat.",
        "Aplikasi error terus tidak bisa daftar, kecewa",
    ]:
        r = service.analyze(text)
        print(f"  [{r['label']:7s}] conf={r['confidence_pct']:5.1f}%  {text}")
        print(f"           -> {r['explanation']}")


if __name__ == "__main__":
    main()
