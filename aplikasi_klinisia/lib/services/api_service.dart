/// Klien REST API untuk backend Klinisia AI (FastAPI).
///
/// Base URL otomatis:
/// - Web (Chrome/Edge)      -> http://localhost:8000
/// - Emulator Android       -> http://10.0.2.2:8000 (loopback ke host PC)
/// - HP Android fisik       -> tentukan IP LAN komputer saat build:
///      flutter run --dart-define=KLINISIA_API=http://[IP-LAN-PC]:8000
library;

import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

/// Error API dengan pesan yang siap ditampilkan ke pengguna.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  ApiService._(); // konstruktor privat: kelas statis, tidak diinstansiasi

  static const String _override = String.fromEnvironment('KLINISIA_API');

  /// Alamat backend Klinisia AI.
  ///
  /// Di web, host diambil dari alamat HALAMAN yang sedang dibuka
  /// (`Uri.base.host`) sehingga otomatis benar di semua perangkat:
  /// - dibuka di PC  (localhost:5173)  -> API di localhost:8000
  /// - dibuka di HP  (192.168.x.x:5173)-> API di 192.168.x.x:8000
  /// Override `--dart-define=KLINISIA_API=...` tetap didahulukan.
  static String get baseUrl {
    final forced = _override.replaceAll(RegExp(r'/+$'), '');
    if (forced.isNotEmpty) return forced;
    if (kIsWeb) {
      final host = Uri.base.host; // host halaman saat ini (PC atau HP)
      return 'http://${host.isEmpty ? 'localhost' : host}:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  static const Duration _timeout = Duration(seconds: 30);

  static String _decode(http.Response res) =>
      utf8.decode(res.bodyBytes, allowMalformed: true);

  /// HTTP GET -> JSON object.
  static Future<Map<String, dynamic>> _get(String path) async {
    final http.Response res;
    try {
      res = await http.get(Uri.parse('$baseUrl$path')).timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Server analisis tidak terjangkau di $baseUrl.\n'
        'Periksa koneksi internet Anda lalu coba lagi.',
      );
    }
    return _jsonOrThrow(res, path);
  }

  /// HTTP POST JSON -> JSON object.
  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Server analisis tidak terjangkau di $baseUrl.\n'
        'Periksa koneksi internet Anda lalu coba lagi.',
      );
    }
    return _jsonOrThrow(res, path);
  }

  static Map<String, dynamic> _jsonOrThrow(http.Response res, String path) {
    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(_decode(res));
      parsed = decoded is Map<String, dynamic> ? decoded : {'data': decoded};
    } catch (_) {
      throw ApiException(
        'Respons tidak valid dari $path (status ${res.statusCode}).',
      );
    }
    if (res.statusCode >= 400) {
      final detail = parsed['detail'];
      throw ApiException(
        detail is String
            ? detail
            : 'Permintaan $path gagal (status ${res.statusCode}).',
        res.statusCode,
      );
    }
    return parsed;
  }

  // ------------------------------------------------------------ endpoints

  static Future<Map<String, dynamic>> health() => _get('/api/health');

  static Future<Map<String, dynamic>> modelInfo() => _get('/api/model');

  static Future<Map<String, dynamic>> weights({int limit = 6}) =>
      _get('/api/model/weights?limit=$limit');

  static Future<Map<String, dynamic>> datasetSummary() =>
      _get('/api/dataset/summary');

  static Future<Map<String, dynamic>> history() => _get('/api/history');

  /// Analisis satu ulasan -> {label, confidence, margin, explanation, ...}
  static Future<Map<String, dynamic>> analyze(String text, {int topK = 5}) =>
      _post('/api/analyze', {'text': text, 'top_k': topK});

  /// Analisis banyak ulasan -> {results: [...], summary: {...}}
  static Future<Map<String, dynamic>> analyzeBatch(
    List<String> texts, {
    int topK = 3,
  }) => _post('/api/analyze/batch', {'texts': texts, 'top_k': topK});

  /// Analisis file CSV (multipart) ke /api/analyze/csv.
  ///
  /// Dipanggil saat user MENEKAN tombol Analisis setelah memilih file —
  /// pemilihan/unggah file sendiri tidak langsung menganalisis.
  /// SELURUH baris file dianalisis (ikut jumlah data user); backend
  /// berhenti sendiri setelah anggaran waktu 5 menit dan mengirim hasil
  /// parsial + peringatan bila belum selesai. Timeout di sini 6 menit —
  /// sedikit di atas anggaran backend agar upload besar dan respons
  /// hasil (bisa belasan MB) masih sempat diterima utuh.
  static Future<Map<String, dynamic>> analyzeCsv({
    required Uint8List bytes,
    required String filename,
    String? textColumn,
  }) async {
    const csvTimeout = Duration(minutes: 6);
    final uri = Uri.parse('$baseUrl/api/analyze/csv');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    if (textColumn != null && textColumn.isNotEmpty) {
      request.fields['text_column'] = textColumn;
    }

    try {
      final streamed = await request.send().timeout(csvTimeout);
      final body = await streamed.stream.toBytes();
      final res = http.Response.bytes(body, streamed.statusCode);

      // Vercel menolak body > 4,5 MB (413 FUNCTION_PAYLOAD_TOO_LARGE)
      // dengan respons teks polos — terjemahkan ke pesan yang jelas.
      if (res.statusCode == 413) {
        final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        throw ApiException(
          'File berukuran $mb MB melebihi batas unggah server 4,5 MB.\n'
          'Kurangi jumlah baris atau hapus kolom yang tidak perlu, '
          'lalu unggah ulang.',
          413,
        );
      }
      return _jsonOrThrow(res, '/api/analyze/csv');
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Analisis melebihi batas waktu 6 menit dan dihentikan.\n'
        'Coba unggah file dengan jumlah baris lebih sedikit.',
      );
    } catch (_) {
      throw ApiException(
        'Gagal mengunggah file ke server.\n'
        'Periksa koneksi internet Anda lalu coba lagi.',
      );
    }
  }

  // -------------------------------------------------------------- ekspor

  /// URL unduhan laporan CSV (riwayat analisis) dari backend.
  static String get csvReportUrl => '$baseUrl/api/report/csv/recent';

  /// URL unduhan hasil analisis file CSV yang baru diunggah user.
  /// Dipakai tombol "Unduh Hasil Analisis (CSV)" di Halaman Ringkasan Dataset.
  static String get csvUploadReportUrl => '$baseUrl/api/report/csv/upload';

  /// URL unduhan ringkasan PDF dari backend.
  static String get pdfReportUrl => '$baseUrl/api/report/pdf';

  /// URL dokumen Swagger UI.
  static String get docsUrl => '$baseUrl/docs';
}
