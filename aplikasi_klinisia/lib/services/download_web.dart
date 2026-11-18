/// Unduh lampiran untuk web: unduh byte via HTTP lalu simpan lewat
/// Blob + `<a download>`.
///
/// Pendekatan ini tidak membuka jendela popup sehingga tidak diblokir
/// browser, dan error backend (mis. "Belum ada unggahan CSV") ikut
/// terbaca karena respon dibaca dulu sebelum unduhan dipicu.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart';

Future<void> downloadAttachment(String url, {String fallbackName = 'unduhan'}) async {
  final http.Response res;
  try {
    res = await http.get(Uri.parse(url));
  } catch (_) {
    throw Exception(
        'Backend Klinisia tidak terjangkau — jalankan backend terlebih dahulu.');
  }
  if (res.statusCode >= 400) {
    throw Exception(_detail(res) ?? 'Gagal mengunduh (status ${res.statusCode}).');
  }

  final filename = _filename(res.headers['content-disposition']) ?? fallbackName;
  // Simpan byte sebagai Blob, lalu picu unduhan lewat anchor tersembunyi.
  final blob = Blob(
    <JSUint8Array>[res.bodyBytes.toJS].toJS,
    BlobPropertyBag(type: _mimeType(res.headers['content-type'])),
  );
  final objectUrl = URL.createObjectURL(blob);
  final anchor = document.createElement('a') as HTMLAnchorElement
    ..href = objectUrl
    ..download = filename
    ..style.display = 'none';
  document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(objectUrl);
}

/// Pesan `detail` dari body error JSON backend (bila ada).
String? _detail(http.Response res) {
  try {
    final decoded = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    if (decoded is Map && decoded['detail'] is String) {
      return decoded['detail'] as String;
    }
  } catch (_) {
    // Bukan JSON — biarkan null.
  }
  return null;
}

/// Nama file dari header `Content-Disposition` (mendukung `filename*=`).
String? _filename(String? disposition) {
  if (disposition == null || disposition.isEmpty) return null;
  final star = RegExp(r"filename\*=UTF-8''([^;]+)").firstMatch(disposition);
  if (star != null) return Uri.decodeComponent(star.group(1)!);
  final plain = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
  return plain?.group(1);
}

/// MIME type untuk Blob dari header `Content-Type`.
String _mimeType(String? contentType) =>
    (contentType == null || contentType.isEmpty)
        ? 'application/octet-stream'
        : contentType.split(';').first.trim();
