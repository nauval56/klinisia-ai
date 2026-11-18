// Test alur UI satu-halaman Klinisia (dari ujung ke ujung) — 3 State Flow.
//
// Alur yang diuji (input bar melayang + stream chat):
//   1. Home (Kondisi 1) HANYA hero + status model + preset — teks ulasan
//      default kosong, kartu hasil/laporan BELUM muncul; `↑` kosong -> validasi.
//   2. Analisis teks (Kondisi 2): bubble user + Kartu Hasil Analisis
//      (prediksi, probabilitas, XAI dari top_contributions backend).
//   3. Lampirkan file via `+` lalu kirim `↑` (Kondisi 3) -> chip lampiran di
//      stream + Ringkasan Dataset (statistik file, banner validasi label
//      acuan, tabel laporan klasifikasi, tombol ekspor) + visualisasi & insight.
//
// Dua lapisan di-fake agar test deterministik dan tetap lulus walau
// backend tidak sedang berjalan:
//   1. FilePicker  -> langsung mengembalikan isi CSV uji (tanpa dialog OS).
//   2. HTTP        -> HttpOverrides memalsukan semua respons backend.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_klinisia/main.dart';

/// Isi CSV uji — sama dengan file uji backend (6 baris, kolom `ulasan` +
/// `score`) supaya angka ringkasannya konsisten.
const String _csvUji =
    'ulasan;score\n'
    '"Aplikasi sangat membantu dan mudah dipakai";5\n'
    '"Aplikasi error terus susah booking";1\n'
    '"Pendaftaran online cepat dan praktis";5\n'
    '"Kuota booking selalu habis padahal sudah daftar";2\n'
    '"Tampilan aplikasi jelek dan membingungkan";1\n'
    '"Fitur notifikasi membantu sekali";4\n';

/// Respons backend yang dipalsukan, dipetakan per "METODE /path".
final Map<String, Map<String, dynamic>> _routes = {
  'GET /api/health': {'status': 'ok', 'model_ready': true, 'accuracy': 0.8674},
  'GET /api/model': {
    'ready': true,
    'algorithm': 'SVM (SVC - kernel linear)',
    'model_name': 'SVC',
    'training_samples': 2562,
    'trained_at': '2026-11-16T06:55:19',
    'classifier_source': 'trained_now',
    'sklearn_version_runtime': '1.6.1',
    'vectorizer': {
      'type': 'TfidfVectorizer',
      'vocab_size': 1446,
      'ngram_range': [1, 1],
    },
    'preprocessing_steps': ['Case folding', 'Normalisasi', 'Stopword removal'],
    'metrics': {
      'accuracy': 0.8674,
      'precision': 0.8797,
      'recall': 0.8674,
      'f1_score': 0.8739,
      'test_size': 513,
      'split': 'train_test_split(test_size=0.2, random_state=42, stratify=y)',
    },
  },
  'GET /api/model/weights': {
    'feature_count': 1446,
    'positive': [
      {'word': 'membantu', 'weight': 1.12, 'abs_weight': 1.12},
      {'word': 'mudah', 'weight': 0.98, 'abs_weight': 0.98},
      {'word': 'cepat', 'weight': 0.91, 'abs_weight': 0.91},
      {'word': 'praktis', 'weight': 0.87, 'abs_weight': 0.87},
      {'word': 'bagus', 'weight': 0.8, 'abs_weight': 0.8},
      {'word': 'keren', 'weight': 0.75, 'abs_weight': 0.75},
    ],
    'negative': [
      {'word': 'error', 'weight': -1.24, 'abs_weight': 1.24},
      {'word': 'lemot', 'weight': -1.1, 'abs_weight': 1.1},
      {'word': 'susah', 'weight': -1.02, 'abs_weight': 1.02},
      {'word': 'habis', 'weight': -0.95, 'abs_weight': 0.95},
      {'word': 'jelek', 'weight': -0.88, 'abs_weight': 0.88},
      {'word': 'gagal', 'weight': -0.83, 'abs_weight': 0.83},
    ],
  },
  // Dipakai section Hasil Analisis + XAI (bentuk asli /api/analyze).
  'POST /api/analyze': {
    'text':
        'Aplikasi sangat membantu, pendaftaran online jadi mudah dan cepat.',
    'cleaned_text': 'aplikasi sangat membantu pendaftaran online mudah cepat',
    'label': 'Positif',
    'is_positive': true,
    'confidence': 0.997,
    'confidence_pct': 99.7,
    'margin': 0.99,
    'probabilities': {'Negatif': 0.003, 'Positif': 0.997},
    'top_contributions': [
      {
        'token': 'membantu',
        'weight': 1.12,
        'tfidf': 0.41,
        'contribution': 0.46,
      },
      {'token': 'mudah', 'weight': 0.87, 'tfidf': 0.38, 'contribution': 0.33},
      {'token': 'cepat', 'weight': 0.64, 'tfidf': 0.31, 'contribution': 0.2},
      {'token': 'error', 'weight': -1.05, 'tfidf': 0.22, 'contribution': -0.23},
    ],
    'explanation':
        'Kata "membantu", "mudah", dan "cepat" mendorong prediksi Positif.',
    'is_empty': false,
  },
  // Respons /api/analyze/csv — sama persis dengan bentuk backend sungguhan.
  'POST /api/analyze/csv': {
    'filename': 'uji_ulasan_klinisia.csv',
    'column_used': 'ulasan',
    'columns': ['ulasan', 'score'],
    'rows_total_in_file': 6,
    'rows_processed': 6,
    'rows_not_processed': 0,
    'time_limit_exceeded': false,
    'time_budget_seconds': 300,
    'elapsed_seconds': 0.4,
    'warning': null,
    'summary': {
      'total': 6,
      'positif': 4,
      'negatif': 2,
      'ratio_positif_pct': 66.7,
      'ratio_negatif_pct': 33.3,
      'avg_confidence': 0.8871,
    },
    'agreement': {
      'labeled_rows': 6,
      'accuracy_vs_label': 0.8333,
      'accuracy_pct': 83.3,
      'note': 'Label acuan dari kolom label pada CSV.',
    },
    // Laporan klasifikasi FILE INI (prediksi vs label score di file):
    // 6 baris berlabel, 5 prediksi benar -> akurasi 0.8333.
    'upload_report': {
      'labeled': true,
      'accuracy': 0.8333,
      'rows': [
        {
          'label': 'Negatif',
          'precision': 1.0,
          'recall': 0.6667,
          'f1_score': 0.8,
          'support': 3,
        },
        {
          'label': 'Positif',
          'precision': 0.75,
          'recall': 1.0,
          'f1_score': 0.8571,
          'support': 3,
        },
        {
          'label': 'Accuracy',
          'precision': 0.8333,
          'recall': 0.8333,
          'f1_score': 0.8333,
          'support': 6,
        },
        {
          'label': 'Macro avg',
          'precision': 0.875,
          'recall': 0.8333,
          'f1_score': 0.8286,
          'support': 6,
        },
        {
          'label': 'Weighted avg',
          'precision': 0.875,
          'recall': 0.8333,
          'f1_score': 0.8286,
          'support': 6,
        },
      ],
    },
    // Hasil per baris — semua berasal dari file unggahan user.
    'results': [
      {
        'text': 'Aplikasi sangat membantu dan mudah dipakai',
        'label': 'Positif',
        'is_positive': true,
        'confidence': 0.99,
      },
      {
        'text': 'Aplikasi error terus susah booking',
        'label': 'Negatif',
        'is_positive': false,
        'confidence': 0.97,
      },
      {
        'text': 'Pendaftaran online cepat dan praktis',
        'label': 'Positif',
        'is_positive': true,
        'confidence': 0.96,
      },
      {
        'text': 'Kuota booking selalu habis padahal sudah daftar',
        'label': 'Negatif',
        'is_positive': false,
        'confidence': 0.94,
      },
      {
        'text': 'Tampilan aplikasi jelek dan membingungkan',
        'label': 'Negatif',
        'is_positive': false,
        'confidence': 0.93,
      },
      {
        'text': 'Fitur notifikasi membantu sekali',
        'label': 'Positif',
        'is_positive': true,
        'confidence': 0.92,
      },
    ],
  },
};

// ---------------------------------------------------------------------------
// Fake HTTP (dart:io HttpClient) — cukup meniru jalur yang dipakai package:http
// ---------------------------------------------------------------------------

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final route = '${method.toUpperCase()} ${url.path}';
    final body = _routes[route] ?? <String, dynamic>{};
    return _FakeRequest(200, utf8.encode(jsonEncode(body)));
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.statusCode, this._bytes);

  // Bukan bagian HttpClientRequest — dipakai internal saat membuat response.
  final int statusCode;
  final List<int> _bytes;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  Encoding encoding = utf8;

  @override
  int contentLength = -1;

  @override
  bool followRedirects = false;

  @override
  bool persistentConnection = false;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => <Cookie>[];

  @override
  void add(List<int> data) {}

  @override
  void write([Object? object = '']) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String sep = '']) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  void writeCharCode(int charCode) {}

  /// Stream badan request dari package:http hanya perlu "ditelan".
  @override
  Future<dynamic> addStream(Stream<List<int>> stream) => stream.drain();

  @override
  Future<HttpClientResponse> close() async => _FakeResponse(statusCode, _bytes);

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(this.statusCode, this._bytes);

  @override
  final int statusCode;
  final List<int> _bytes;

  @override
  int get contentLength => _bytes.length;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  bool get persistentConnection => false;

  @override
  List<Cookie> get cookies => <Cookie>[];

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHeaders implements HttpHeaders {
  final Map<String, List<String>> _map = <String, List<String>>{};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    (_map[name.toLowerCase()] ??= <String>[]).add('$value');
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _map[name.toLowerCase()] = <String>['$value'];
  }

  @override
  String? value(String name) => _map[name.toLowerCase()]?.join(',');

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _map.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// ---------------------------------------------------------------------------
// Fake FilePicker — mengembalikan CSV uji tanpa dialog pemilihan file.
// ---------------------------------------------------------------------------

class _FakeFilePicker extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(_csvUji));
    return FilePickerResult(<PlatformFile>[
      PlatformFile(
        name: 'uji_ulasan_klinisia.csv',
        size: bytes.length,
        bytes: bytes,
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------

/// Majukan clock beberapa frame — UI memiliki animasi pulse header yang
/// tidak pernah selesai, sehingga `pumpAndSettle` tidak bisa dipakai.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 6}) async {
  await tester.pump();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Pump aplikasi dengan layar cukup tinggi agar area input terlihat.
Future<void> _pumpApp(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const KlinisiaAiApp());
  await _pumpFrames(tester);
}

/// Gulir agar [finder] berada di **tengah** viewport (y ≈ 800) sebelum tap.
///
/// `tester.ensureVisible` bawaan menarik widget ke paling atas layar
/// (y ≈ widget.height/2) — di balik fixed header 64px, sehingga hit test
/// jatuh ke header dan tap meleset. Alignment 0.5 menghindari tabrakan ini
/// sekaligus menjauhi bottom nav di bawah.
Future<void> _tengahkan(WidgetTester tester, Finder finder) async {
  final element = finder.evaluate().single;
  await Scrollable.ensureVisible(
    element,
    alignment: 0.5,
    duration: Duration.zero,
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
    FilePicker.platform = _FakeFilePicker();
  });

  testWidgets('home hanya berisi input — tanpa data contoh/bawaan', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    // Input tersedia.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Preset Contoh Cepat:'), findsOneWidget);

    // Status koneksi backend NYATA dari /api/health.
    expect(find.text('SVM Linear · Online (86.7%)'), findsOneWidget);
    expect(find.text('Model Status: Online'), findsOneWidget);

    // Belum ada data — section hasil & dataset belum muncul sama sekali,
    // tampilan awal fokus ke input (tanpa angka contoh).
    expect(find.text('HASIL KLASIFIKASI'), findsNothing);
    expect(find.text('Ringkasan Dataset Ulasan'), findsNothing);
    expect(find.text('POSITIF'), findsNothing);
    expect(find.text('Laporan Klasifikasi'), findsNothing);
    expect(find.text('Unduh Hasil Analisis (.CSV)'), findsNothing);

    // Teks ulasan default KOSONG — user wajib mengetik sendiri.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text ?? '', isEmpty);

    // Analisis tanpa teks -> validasi menolak, tidak ada panggilan API.
    await _tengahkan(tester, find.byIcon(Icons.arrow_upward));
    await tester.tap(find.byIcon(Icons.arrow_upward), warnIfMissed: true);
    await _pumpFrames(tester, frames: 2);
    expect(
      find.text('Tulis ulasan atau lampirkan file terlebih dahulu.'),
      findsOneWidget,
    );
  });

  testWidgets('analisis teks menampilkan hasil & XAI dari backend', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _tengahkan(tester, find.byType(TextField));
    await tester.enterText(
      find.byType(TextField),
      'Aplikasi sangat membantu dan cepat.',
    );
    await _tengahkan(tester, find.byIcon(Icons.arrow_upward));
    await tester.tap(find.byIcon(Icons.arrow_upward), warnIfMissed: true);
    // Respons fake + animasi scroll 500 ms ke section Hasil.
    await _pumpFrames(tester);

    // Hasil dari POST /api/analyze (bukan logika kata kunci di klien).
    expect(find.text('HASIL KLASIFIKASI'), findsOneWidget);
    expect(find.text('POSITIF'), findsOneWidget);
    expect(find.text('99.7%'), findsWidgets);
    expect(find.text('Sangat Yakin'), findsOneWidget);
    expect(find.textContaining('Inferensi'), findsOneWidget);
    expect(find.text('Distribusi Probabilitas Kelas'), findsOneWidget);
    expect(find.text('Belum ada hasil analisis'), findsNothing);

    // XAI: token berpengaruh dari top_contributions backend.
    expect(find.text('Explainable AI (XAI)'), findsOneWidget);
    expect(find.text('Teks Ulasan & Token Berpengaruh:'), findsOneWidget);
    expect(find.text('"membantu" (+0.46)'), findsOneWidget);
    expect(find.text('"error" (-0.23)'), findsOneWidget);

    // Section dataset & visualisasi belum muncul (belum ada file unggahan).
    expect(find.text('Ringkasan Dataset Ulasan'), findsNothing);
    expect(find.text('Visualisasi Data Interaktif'), findsNothing);
    expect(find.text('Unduh Hasil Analisis (.CSV)'), findsNothing);
  });

  testWidgets('unggah CSV menampilkan ringkasan, laporan, dan ekspor', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _tengahkan(tester, find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add), warnIfMissed: true);
    // Fake picker — file hanya DILAMPIRKAN (belum dianalisis).
    await _pumpFrames(tester);

    // Chip lampiran tampil di input bar, laporan BELUM muncul.
    expect(find.textContaining('uji_ulasan_klinisia.csv'), findsWidgets);
    expect(find.text('Ringkasan Dataset Ulasan'), findsNothing);

    // Tekan `↑` -> Kondisi 3: analisis seluruh baris file.
    await _tengahkan(tester, find.byIcon(Icons.arrow_upward));
    await tester.tap(find.byIcon(Icons.arrow_upward), warnIfMissed: true);
    // Respons fake + animasi auto-scroll ke pesan dataset.
    await _pumpFrames(tester);

    // Nama file tampil di bubble chat & subtitle ringkasan.
    expect(find.textContaining('uji_ulasan_klinisia.csv'), findsWidgets);

    // Statistik dari file unggahan (bukan data bawaan).
    expect(find.text('Total Baris'), findsOneWidget);
    expect(find.text('Rata-rata Confidence'), findsOneWidget);
    expect(find.text('88.7%'), findsOneWidget);
    expect(find.text('66.7% Proporsi'), findsOneWidget);
    expect(find.text('33.3% Proporsi'), findsOneWidget);

    // Banner validasi terhadap label acuan di file.
    expect(
      find.textContaining('83.3% cocok pada 6 baris berlabel'),
      findsOneWidget,
    );

    // Tabel laporan klasifikasi (upload_report).
    expect(find.text('Laporan Klasifikasi'), findsOneWidget);
    expect(find.text('vs label acuan file'), findsOneWidget);
    expect(find.text('Kelas'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Accuracy'), findsWidgets);
    expect(find.text('Macro avg'), findsOneWidget);
    expect(find.text('Weighted avg'), findsOneWidget);

    // Tombol ekspor hasil unggahan.
    expect(find.text('Unduh Hasil Analisis (.CSV)'), findsOneWidget);
    expect(find.text('Laporan (PDF)'), findsOneWidget);

    // Donut distribusi memakai rasio file unggahan.
    expect(find.text('Positif (66.7%)'), findsOneWidget);
    expect(find.text('Negatif (33.3%)'), findsOneWidget);

    // Kata kunci dari bobot fitur backend (pill RichText).
    expect(
      find.textContaining('#1 membantu', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('#1 error', findRichText: true), findsOneWidget);

    // Tab "Bobot Fitur" menampilkan bobot SVM per kelas.
    await _tengahkan(tester, find.text('Bobot Fitur'));
    await tester.tap(find.text('Bobot Fitur'), warnIfMissed: true);
    await _pumpFrames(tester, frames: 4);
    expect(find.text('Kata pendorong kelas Positif'), findsOneWidget);
    expect(find.text('Kata pendorong kelas Negatif'), findsOneWidget);
  });

  testWidgets(
    'layar HP 360px: awal fokus input, hasil & dataset muncul ke bawah '
    'tanpa overflow',
    (WidgetTester tester) async {
      // Ukuran HP mungil (Android portrait) — mendukung mobile-friendly.
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const KlinisiaAiApp());
      await _pumpFrames(tester);

      // Awal: fokus ke input — section hasil/dataset belum muncul.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('HASIL KLASIFIKASI'), findsNothing);
      expect(find.text('Ringkasan Dataset Ulasan'), findsNothing);

      // Kirim kata -> analisis muncul DI BAWAH input.
      await _tengahkan(tester, find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Aplikasi sangat membantu dan cepat.',
      );
      await _tengahkan(tester, find.byIcon(Icons.arrow_upward));
      await tester.tap(find.byIcon(Icons.arrow_upward), warnIfMissed: true);
      await _pumpFrames(tester);
      expect(find.text('HASIL KLASIFIKASI'), findsOneWidget);
      expect(find.text('Explainable AI (XAI)'), findsOneWidget);

      // Lampirkan dataset (+) lalu kirim (↑) -> laporan muncul DI BAWAH input.
      await _tengahkan(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add), warnIfMissed: true);
      await _pumpFrames(tester, frames: 4);
      await _tengahkan(tester, find.byIcon(Icons.arrow_upward));
      await tester.tap(find.byIcon(Icons.arrow_upward), warnIfMissed: true);
      await _pumpFrames(tester, frames: 10);
      expect(find.text('Ringkasan Dataset Ulasan'), findsOneWidget);
      expect(find.text('Laporan Klasifikasi'), findsOneWidget);
      expect(find.text('Unduh Hasil Analisis (.CSV)'), findsOneWidget);
      expect(find.text('Laporan (PDF)'), findsOneWidget);

      // Tidak ada overflow / exception layout di layar sempit.
      expect(tester.takeException(), isNull);
    },
  );
}
