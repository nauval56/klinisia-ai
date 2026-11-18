/// Jembatan unduh lampiran antar-platform untuk Klinisia.
///
/// Kondisional: web memakai `download_web.dart` (fetch → blob → anchor),
/// platform lain memakai `download_stub.dart` (url_launcher).
library;

import 'download_stub.dart'
    if (dart.library.js_interop) 'download_web.dart' as impl;

/// Unduh [url] sebagai lampiran dengan nama [fallbackName] bila backend
/// tidak mengirim header `Content-Disposition`.
///
/// Melempar [Exception] berisi pesan siap ditampilkan ke pengguna bila
/// unduhan gagal (backend mati, belum ada unggahan, dst.).
Future<void> downloadAttachment(String url, {String fallbackName = 'unduhan'}) =>
    impl.downloadAttachment(url, fallbackName: fallbackName);
