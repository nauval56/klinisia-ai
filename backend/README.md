# Backend Klinisia AI — Analisis Sentimen Ulasan Play Store (SVM Linear + TF-IDF)

Backend REST API untuk aplikasi **Klinisia**. Memakai model AI yang Anda berikan
(`klinisia_model.joblib`) sebagai sumber vectorizer TF-IDF dan label kelas, dilengkapi
classifier **SVM (SVC kernel linear)** yang dilatih otomatis dari dataset ulasan
Play Store Anda.

---

## 1. Catatan penting tentang file model

`klinisia_model.joblib` yang diberikan berisi:

| Kunci        | Isi                                                        |
|--------------|------------------------------------------------------------|
| `vectorizer` | `TfidfVectorizer` (1.434 fitur, unigram, L2 norm, use_idf) |
| `labels`     | `['Negatif', 'Positif']`                                   |
| `model`      | string `'SVM'` (nama algoritma)                            |
| `sklearn_version` | `1.6.1`                                               |

File ini **belum memuat estimator SVM yang sudah dilatih** (bobot `coef_`/`support_vectors_` tidak ada),
sehingga tidak bisa langsung dipakai prediksi. Backend menanganinya otomatis:

1. Cek estimator di dalam file → bila ada, langsung dipakai.
2. Kalau tidak ada → muat file pendamping `models/klinisia_svm_classifier.joblib`.
3. Kalau file pendamping belum ada / tidak kompatibel → **latih otomatis** dari
   `data/hasil_scraper_ulasan_app_klinisia.csv` memakai vectorizer dari file Anda,
   lalu simpan sebagai file pendamping (cukup sekali latih).

Pelatihan memakai pipeline yang sama persis dengan notebook Anda:
preprocessing → vectorizer dari file → `SVC(kernel='linear')` → evaluasi
`train_test_split(80:20, stratify, random_state=42)`.

**Temuan stemming:** diagnosis `scripts/diagnose_vocab.py` membuktikan vectorizer
Anda dilatih pada teks yang **sudah di-stemming** — kosakata berisi kata dasar
(`layanan`, `daftar`, `bayar`) tetapi TIDAK berisi bentuk berimbuhan
(`pelayanan`, `pendaftaran`), padahal kata itu muncul di ulasan asli.

| Pipeline | Cakupan token ke kosakata |
|---|---|
| Tanpa stemming | 68,0% |
| **Dengan stemming Sastrawi (dipakai)** | **92,4%** |

Karena itu backend **mengaktifkan stemming Sastrawi** sebagai tahap terakhir
(nonaktifkan dengan `KLINISIA_STEMMING=0`).

Hasil akhir pada data uji (dengan stemming):

- **Akurasi 87,1%**, F1-weighted **0,878**, macro-F1 0,81
- **Negatif**: precision 0,62 / **recall 0,81** / F1 0,70 (78 dari 96 keluhan tertangkap)
- **Positif**: precision 0,95 / recall 0,88 / F1 0,92
- Confusion matrix: `[[78, 18], [48, 369]]` (label: `['Negatif', 'Positif']`)

> Parameter `C=1.0`, `class_weight='balanced'` dipilih dari eksperimen
> `scripts/experiment_params.py` (memakai macro-F1 & recall Negatif sebagai
> kriteria, agar keluhan pengguna tidak banyak yang lolos).

---

## 2. Struktur folder

```
backend/
├── app/
│   ├── main.py            # Aplikasi FastAPI, CORS, lifespan (muat model)
│   ├── config.py          # Path & hyperparameter
│   ├── preprocessing.py   # Rantai preprocessing replikasi notebook
│   ├── model_service.py   # Muat/latih model, inferensi, bobot, riwayat
│   ├── schemas.py         # Skema Pydantic
│   └── routers/
│       ├── predict.py     # /api/analyze, /analyze/batch, /analyze/csv, /history
│       ├── model.py       # /api/model, /model/weights, /dataset/summary
│       └── report.py      # /api/report/csv, /report/csv/recent, /report/csv/upload, /report/pdf
├── models/
│   ├── klinisia_model.joblib           # file model yang Anda berikan
│   └── klinisia_svm_classifier.joblib  # classifier pendamping (otomatis)
├── data/
│   ├── hasil_scraper_ulasan_app_klinisia.csv  # dataset ulasan
│   ├── kamus_tidak_baku.csv                   # kamus normalisasi (notebook)
│   └── stopwords_id.txt                       # 758 stopwords Indonesia (NLTK)
├── scripts/
│   ├── train_model.py       # latih ulang classifier (--force)
│   ├── experiment_params.py # eksperimen hyperparameter SVM
│   └── smoke_test.py        # uji seluruh endpoint
├── requirements.txt
├── run.py / run.bat
└── README.md
```

---

## 3. Menjalankan

```bash
cd backend
pip install -r requirements.txt
python run.py                # atau: run.bat  /  uvicorn app.main:app --port 8000
```

- Swagger UI:  <http://localhost:8000/docs>
- ReDoc:       <http://localhost:8000/redoc>
- Health:      <http://localhost:8000/api/health>

Jalankan tes endpoint (server harus hidup):

```bash
python scripts/smoke_test.py
```

---

## 4. Daftar Endpoint

| Method | Path                        | Fungsi |
|--------|-----------------------------|--------|
| GET    | `/`                         | Banner API & daftar endpoint |
| GET    | `/api/health`               | Status kesehatan + model |
| POST   | `/api/analyze`              | Analisis 1 teks ulasan |
| POST   | `/api/analyze/batch`        | Analisis banyak teks + ringkasan distribusi |
| POST   | `/api/analyze/csv`          | Unggah CSV → analisis per baris + perbandingan label |
| GET    | `/api/model`                | Info model, pipeline, metrik evaluasi + laporan klasifikasi |
| POST   | `/api/model/reload`         | Muat ulang model dari disk |
| GET    | `/api/model/weights`        | Bobot fitur SVM (prediktor positif/negatif) |
| GET    | `/api/model/predict-token`  | Kontribusi token pada teks tertentu |
| GET    | `/api/dataset/summary`      | Ringkasan dataset ulasan Play Store |
| GET    | `/api/history`              | Riwayat analisis terakhir (50 di memori) |
| DELETE | `/api/history`              | Bersihkan riwayat |
| POST   | `/api/report/csv`           | Ekspor hasil analisis → file CSV |
| GET    | `/api/report/csv/recent`    | Ekspor riwayat → file CSV |
| GET    | `/api/report/csv/upload`    | Ekspor hasil unggahan CSV terakhir → file CSV |
| GET    | `/api/report/pdf`           | Unduh ringkasan (model + dataset + unggahan + riwayat) → file PDF |

### 4.1 Analisis satu ulasan

```http
POST /api/analyze
Content-Type: application/json

{ "text": "Pelayanan sangat cepat dan dokter ramah.", "top_k": 5 }
```

Respon:

```json
{
  "text": "Pelayanan sangat cepat dan dokter ramah.",
  "cleaned_text": "pelayanan cepat dokter ramah",
  "label": "Positif",
  "is_positive": true,
  "confidence": 0.9930,
  "confidence_pct": 99.3,
  "margin": 2.4884,
  "probabilities": { "Negatif": 0.007, "Positif": 0.993 },
  "top_contributions": [
    { "token": "ramah", "weight": 1.3669, "tfidf": 0.5867, "contribution": 0.8019 },
    { "token": "cepat", "weight": 1.3954, "tfidf": 0.4919, "contribution": 0.6864 }
  ],
  "explanation": "Token pendukung berbobot tinggi: “ramah” (+0.80), dan “cepat” (+0.69) melampaui ambang batas klasifikasi.",
  "is_empty": false
}
```

`margin` = `w·x + b` (hyperplane SVM); positif → **Positif**, negatif → **Negatif**.
`explanation` siap ditampilkan pada kartu *Penjelasan Model* di Halaman Hasil Sentimen Flutter (di bawah daftar fitur kata `top_contributions`).

### 4.2 Batch

```http
POST /api/analyze/batch
{ "texts": ["Antrean lama...", "Dokter ramah..."] }
```

Respon: `{ "results": [...], "summary": { "total", "positif", "negatif", "ratio_positif_pct", "ratio_negatif_pct", "avg_confidence" } }`
(maksimal 200 teks per request).

### 4.3 Unggah CSV

```http
POST /api/analyze/csv
multipart/form-data
  file         : dataset.csv
  text_column  : (opsional — otomatis deteksi: content/text/ulasan/review/...)
  limit        : (opsional — kosong = SELURUH baris file dianalisis)
```

Pemisah `,` maupun `;` didukung, termasuk CSV berisi **satu kolom teks
murni** (parser otomatis mencoba deteksi pemisah lalu fallback koma/titik-koma).
Bila CSV punya kolom `score`, respons menyertakan
`agreement.accuracy_vs_label` (perbandingan prediksi dengan label aturan
1–3 Negatif, 4–5 Positif). Kolom label `Sentiment`/`sentimen`/`label` juga dikenali.

**Jumlah data mengikuti unggahan** — seluruh baris file dianalisis berapa pun
jumlahnya (20000 baris ya 20000 dianalisis), dengan **anggaran waktu 5 menit**
(`ANALYSIS_TIME_BUDGET` / env `KLINISIA_TIME_BUDGET`, detik; `0` = tanpa batas).
Bila waktu habis sebelum semua baris selesai, proses berhenti dan respons
menyertakan pemberitahuan jelas, bukan pemotongan diam-diam:

```json
"rows_processed": 18420,
"rows_not_processed": 1580,
"time_limit_exceeded": true,
"time_budget_seconds": 300.0,
"elapsed_seconds": 300.04,
"warning": "Analisis dihentikan pada batas waktu 300 detik; 1580 dari 20000 baris belum sempat dianalisis (18420 baris berhasil dianalisis dalam 300.04 detik)."
```

Field yang sama juga tersimpan di unggahan terakhir (`last_upload`) sehingga
tombol unduh CSV/PDF dan Halaman Ringkasan Dataset menampilkan peringatan
serupa. Tanpa batas waktu tercapai, `time_limit_exceeded: false`,
`rows_not_processed: 0`, `warning: null`.

Respons juga memuat **`upload_report`** — laporan klasifikasi khusus file
ini (sinkron dengan unggahan), disusun dari **prediksi model vs label
acuan di file**:

```json
"upload_report": {
  "labeled": true,
  "accuracy": 0.8333,
  "rows": [
    { "label": "Negatif", "precision": 1.0, "recall": 0.6667, "f1_score": 0.8, "support": 3 },
    { "label": "Positif", "precision": 0.75, "recall": 1.0, "f1_score": 0.8571, "support": 3 },
    { "label": "Accuracy", "precision": 0.8333, "recall": 0.8333, "f1_score": 0.8333, "support": 6 },
    { "label": "Macro avg", "precision": 0.875, "recall": 0.8333, "f1_score": 0.8286, "support": 6 },
    { "label": "Weighted avg", "precision": 0.875, "recall": 0.8333, "f1_score": 0.8286, "support": 6 }
  ]
}
```

- **File berlabel** (`labeled: true`): baris per kelas + Accuracy + Macro avg +
  Weighted avg, persis format `metrics.report` (bagian 4.4) tetapi dihitung
  dari file user; `accuracy` di sini = kecocokan prediksi dengan label file
  (bukan akurasi pelatihan).
- **File tanpa label** (`labeled: false`, `accuracy: null`): hanya baris per
  kelas berisi jumlah prediksi (support); precision/recall/F1 `null` karena
  tak bisa dihitung tanpa acuan.

Kartu **F1 Score** di Halaman Ringkasan Dataset menampilkan F1 `Weighted
avg` dari `upload_report` (fallback "Rata-rata Confidence" bila file
tanpa label). Tabel **Laporan Klasifikasi** di website juga memakai
baris `upload_report` — prediksi model vs label acuan pada file user.
PDF ringkasan mencetak angka yang sama: bagian "LAPORAN KLASIFIKASI
(file unggahan)" berisi tabel `upload_report`, dan baris `F1 Score`
pada bagian "HASIL UNGGAHAN" memakai F1 `Weighted avg` file tersebut.

### 4.4 Laporan klasifikasi (tabel Precision/Recall/F1/Support)

`GET /api/model` menyertakan `metrics.report` — tabel evaluasi classifier
disusun dari metrik data uji (bukan angka ketikan):

```json
{
  "metrics": {
    "accuracy": 0.8713,
    "report": [
      { "label": "Negatif",      "precision": 0.619,  "recall": 0.8125, "f1_score": 0.7027, "support": 96 },
      { "label": "Positif",      "precision": 0.9535, "recall": 0.8849, "f1_score": 0.9179, "support": 417 },
      { "label": "Accuracy",     "precision": 0.8713, "recall": 0.8713, "f1_score": 0.8713, "support": 513 },
      { "label": "Macro avg",    "precision": 0.7863, "recall": 0.8487, "f1_score": 0.8103, "support": 513 },
      { "label": "Weighted avg", "precision": 0.8909, "recall": 0.8713, "f1_score": 0.8776, "support": 513 }
    ]
  }
}
```

Baris `Accuracy`/`Macro avg`/`Weighted avg` memakai `support` = total sampel
data uji. Kartu **Laporan Klasifikasi** di website memakai `upload_report`
(bagian 4.3, sesuai file user) — bukan `metrics.report` ini; namun format
keduanya identik sehingga `metrics.report` tetap berguna sebagai acuan
metrik evaluator di API.

### 4.5 Bobot fitur (kartu "Bobot Fitur SVM")

```http
GET /api/model/weights?limit=6
```

```json
{
  "positive": [ { "word": "mudah", "weight": 2.0065, "abs_weight": 2.0065 }, ... ],
  "negative": [ { "word": "data", "weight": -2.5328, "abs_weight": 2.5328 }, ... ],
  "feature_count": 1434
}
```

### 4.6 Ekspor laporan CSV

```http
POST /api/report/csv
{ "results": [ { "text": "...", "label": "Positif", "confidence_pct": 95.0, "margin": 1.8, "explanation": "..." } ],
  "filename": "laporan_oktober" }
```

Respons berupa file unduhan (`text/csv`, UTF-8 + BOM agar rapi di Excel).

---

## 5. Pipeline preprocessing (identik notebook + stemming)

1. Hapus URL, username (`@...`), HTML, emoji, simbol, angka
2. Case folding (lowercase)
3. Normalisasi kata tidak baku → kata baku (`data/kamus_tidak_baku.csv`)
4. Tokenisasi (split spasi)
5. Hapus stopwords Indonesia (`data/stopwords_id.txt`, 758 kata)
6. Hapus kata tertentu (daftar `hapus_kata`)
7. Perbaikan kata (`app→aplikasi`, `pisan→bagus`, dll.)
8. **Stemming ke kata dasar (Sastrawi)** — wajib agar token cocok dengan
   kosakata model (lihat Temuan stemming di bagian 1)
9. TF-IDF dengan vectorizer dari `klinisia_model.joblib`
10. Klasifikasi SVM linear → label + confidence + kontribusi token

Daftar tahap ini juga dikirim dinamis oleh `GET /api/model` → `preprocessing_steps`
dan `stemming_enabled`, sehingga UI dapat menampilkannya.

---

## 6. Konfigurasi (environment variable, opsional)

| Variabel | Default | Fungsi |
|----------|---------|--------|
| `KLINISIA_MODEL_PATH` | `models/klinisia_model.joblib` | Path file model |
| `KLINISIA_CLASSIFIER_PATH` | `models/klinisia_svm_classifier.joblib` | Path classifier pendamping |
| `KLINISIA_DATASET_PATH` | `data/hasil_scraper_ulasan_app_klinisia.csv` | Dataset pelatihan |
| `KLINISIA_STEMMING` | `1` | `0` untuk mematikan stemming (tidak disarankan) |
| `KLINISIA_SVC_C` | `1.0` | Parameter C SVM |
| `KLINISIA_SVC_CLASS_WEIGHT` | `balanced` | `""` untuk tanpa class_weight |
| `KLINISIA_HOST` | `127.0.0.1` | `0.0.0.0` agar bisa diakses dari HP/emulator |
| `KLINISIA_PORT` | `8000` | Port server |
| `KLINISIA_CORS_ORIGINS` | `*` | Origin yang diizinkan (pisahkan dengan koma) |

Setelah mengubah parameter SVM, latih ulang supaya file pendamping ikut berubah:

```bash
python scripts/train_model.py --force
```

(Classifier otomatis di-latih ulang bila `svc_c`/`svc_class_weight` pada file
pendamping tidak cocok dengan konfigurasi saat ini.)

---

## 7. Contoh pemakaian dari Flutter

Aplikasi Flutter di `../aplikasi_klinisia/` sudah terhubung penuh lewat
`lib/services/api_service.dart` (kode di bawah ini hanya contoh mentah):

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const base = 'http://localhost:8000'; // emulator Android: http://10.0.2.2:8000

Future<Map<String, dynamic>> analisisUlasan(String teks) async {
  final res = await http.post(
    Uri.parse('$base/api/analyze'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'text': teks}),
  );
  return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
}
```

Yang sudah terpasang di aplikasi:

- **Base URL otomatis** — web → `localhost:8000`, emulator Android →
  `10.0.2.2:8000`; override dengan
  `flutter run --dart-define=KLINISIA_API=http://192.168.x.x:8000`
  untuk perangkat fisik.
- **Dua halaman hasil terpisah (satu tampilan aktif)** — home hanya berisi
  input tanpa data contoh/bawaan (teks ulasan default kosong). Tombol
  **Analisis** (setelah user mengetik ulasannya sendiri) membuka *Halaman
  Hasil Sentimen* (prediksi Positif/Negatif + confidence score + fitur kata
  yang mempengaruhi prediksi); analisis file CSV milik user (setelah user
  menekan tombol Analisis) membuka *Halaman
  Ringkasan Dataset* (statistik dataset + kartu **F1 Score** — F1
  weighted avg dari laporan klasifikasi file user (`upload_report`),
  fallback "Rata-rata Confidence" bila file tanpa label — distribusi
  polaritas donut, grafik bobot fitur SVM,
  **tabel Laporan Klasifikasi** — Precision/Recall/F1-Score/Support per
  kelas + Accuracy/Macro/Weighted avg dari `upload_report` (prediksi
  model vs label pada file user) — dan sampel klasifikasi dari baris
  file user).
  Kedua
  halaman tidak pernah tampil bersamaan — semuanya mengambil data langsung
  dari endpoint (bukan hard-coded), dan tidak ada ringkasan dataset bawaan
  yang tampil sebelum user mengunggah CSV sendiri.
- **Input & unggah** — teks ulasan lewat `TextField` (POST `/api/analyze`);
  memilih file CSV lewat `file_picker` hanya MENAHAN file di aplikasi
  (tanpa analisis otomatis). File baru dianalisis saat user menekan
  tombol **Analisis** (POST `/api/analyze/csv`) lalu membuka Halaman
  Ringkasan Dataset berisi ringkasannya.
- **Ekspor** — ada di Halaman Ringkasan Dataset (setelah analisis file
  unggahan): tombol "Unduh Hasil Analisis (CSV)" (`/api/report/csv/upload`,
  seluruh baris hasil unggahan) dan "Ekspor Ringkasan PDF"
  (`/api/report/pdf`); di web file diunduh lewat fetch + blob tanpa
  popup, di platform lain dibuka via `url_launcher`.
- **Status koneksi** — topbar menampilkan indikator Online/Offline hasil
  `GET /api/health`; bila backend mati, UI menampilkan pesan cara menjalankan.

Jangan lupa menambahkan `android:usesCleartextTraffic="true"` (debug) atau memakai
HTTPS bila di-deploy.

> Server default hanya mendengarkan `127.0.0.1` (aman dari akses luar).
> Untuk diakses emulator/perangkat Android, jalankan dengan
> `set KLINISIA_HOST=0.0.0.0` lalu `python run.py`.

---

## 8. Batasan yang perlu diketahui

- Kosakata model tetap **1.434 token** (dari file Anda). Kata di luar kosakata
  (mis. “mahal” bila tidak ada saat vectorizer di-fit) diabaikan oleh TF-IDF sehingga
  tidak memengaruhi prediksi — ini keterbatasan vectorizer, bukan backend.
- Label pelatihan aturan **score 1–3 = Negatif, 4–5 = Positif** (persis notebook),
  sehingga ulasan 3 bintang yang bernada “lumayan” ikut ditandai Negatif.
- Confidence berasal dari Platt scaling internal `SVC(probability=True)`.
- Riwayat disimpan **di memori** (50 entri terakhir, hilang saat server restart).
  Untuk persistensi, ganti ke database (mis. SQLite) pada `model_service.push_history`.


## Deploy ke Vercel (serverless)

Backend FastAPI ini bisa di-deploy langsung ke Vercel (paket Hobby gratis):

\\\ash
npm install -g vercel
vercel login
cd backend
vercel              # pilih "Create new project" — framework terdeteksi FastAPI
vercel --prod       # rilis -> https://<nama-projek>.vercel.app
\\\

Konfigurasi ada di \ercel.json\ (framework \astapi\, \maxDuration: 300\
detik — sama dengan \ANALYSIS_TIME_BUDGET\).

**Catatan penting:**

1. **Lazy-load model** — runtime serverless tidak menjalankan event lifespan
   ASGI, jadi \service.load()\ dipanggil otomatis pada request pertama lewat
   \service.ensure_loaded()\ (di \/api/health\, \/api/model\, dan semua
   endpoint yang butuh model siap).
2. **Batas payload 4,5 MB** (request & response) — file CSV unggahan dan file
   ekspor harus di bawah itu; dataset besar perlu di-upload ke storage
   (Vercel Blob / Supabase) lalu dianalisis dari URL.
3. **CORS** — default \KLINISIA_CORS_ORIGINS="*\" sudah mengizinkan domain
   frontend Vercel.
4. **Frontend Flutter** harus di-build dengan define agar menunjuk API Vercel:
   \\\ash
   flutter build web --release --dart-define=KLINISIA_API=https://<nama-projek>.vercel.app
   \\\
5. \data/\ + \models/\ (±2 MB) ikut ter-bundle — jangan tambahkan file besar
   ke folder itu agar tetap di bawah limit 500 MB.
#   k l i n i s i a - a i  
 #   k l i n i s i a - a i  
 