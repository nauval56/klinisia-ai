/// Unduh lampiran untuk platform non-web (Android/desktop).
///
/// Cukup buka URL — browser/OS menangani unduhan sendiri karena backend
/// selalu mengirim `Content-Disposition: attachment`.
library;

import 'package:url_launcher/url_launcher.dart';

Future<void> downloadAttachment(String url, {String fallbackName = 'unduhan'}) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
  if (!ok) {
    throw Exception('Gagal membuka $url');
  }
}
