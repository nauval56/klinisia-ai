// Halaman Hasil Sentimen â€” DIBUKA setelah tombol "Analisis" ditekan.
// Hanya menampilkan: teks ulasan user, prediksi Positif/Negatif,
// confidence score, dan fitur kata yang mempengaruhi prediksi.
import 'package:flutter/material.dart';

import '../widgets/widgets_bersama.dart';
/// Halaman Hasil Sentimen — DIBUKA setelah tombol "Analisis" ditekan.
///
/// Hanya menampilkan: teks ulasan, prediksi Positif/Negatif, confidence
/// score, dan fitur kata yang mempengaruhi prediksi (sesuai permintaan).
class SentimentResultPage extends StatelessWidget {
  final Map<String, dynamic> result;
  const SentimentResultPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final positive = result['is_positive'] == true;
    final color = positive ? green : red;
    final bg = positive ? const Color(0xFFE9FBF4) : const Color(0xFFFFECEC);
    final confidence = (result['confidence_pct'] as num?)?.toDouble() ?? 0;
    final explanation = '${result['explanation'] ?? ''}';
    final features = ((result['top_contributions'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final maxAbs = features.fold<double>(0, (a, f) {
      final c = ((f['contribution'] as num?) ?? 0).abs().toDouble();
      return c > a ? c : a;
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Hasil Sentimen'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ------------------------------------------------ teks
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ULASAN YANG DIANALISIS',
                              style: TextStyle(
                                  fontSize: 6,
                                  color: muted,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('"${result['text'] ?? ''}"',
                              style: const TextStyle(
                                  fontSize: 7.5,
                                  height: 1.45,
                                  color: Color(0xFF424958),
                                  fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // -------------------------------------------- prediksi
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text('PREDIKSI MODEL',
                                  style: TextStyle(
                                      fontSize: 6,
                                      color: muted,
                                      fontWeight: FontWeight.w700)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 6),
                                decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  children: [
                                    Icon(
                                        positive
                                            ? Icons.check_circle_outline
                                            : Icons.error_outline,
                                        size: 8,
                                        color: color),
                                    const SizedBox(width: 4),
                                    Text(positive ? 'POSITIF' : 'NEGATIF',
                                        style: TextStyle(
                                            fontSize: 7.5,
                                            color: color,
                                            fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('CONFIDENCE SCORE',
                              style: TextStyle(
                                  fontSize: 6,
                                  color: muted,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('${confidence.toStringAsFixed(1)}%',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  height: 1)),
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (confidence / 100).clamp(0, 1),
                              minHeight: 4,
                              backgroundColor: const Color(0xFFEDF0F5),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                              'Tingkat keyakinan model SVM Linear pada prediksi di atas.',
                              style: TextStyle(
                                  fontSize: 5.8, color: muted, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ----------------------------------------- fitur kata
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                    'Fitur Kata yang Mempengaruhi Prediksi',
                                    style: TextStyle(
                                        fontSize: 8.5,
                                        color: ink,
                                        fontWeight: FontWeight.w600)),
                              ),
                              TinyBadge('${features.length} fitur'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (features.isEmpty)
                            const Text(
                                'Tidak ada fitur kata yang terbaca — teks hanya '
                                'berisi kata umum/stopword sehingga prediksi '
                                'diambil dari bias model.',
                                style: TextStyle(
                                    fontSize: 6.5,
                                    color: muted,
                                    height: 1.4))
                          else ...[
                            const Text('KONTRIBUSI TERHADAP PREDIKSI (tfidf × bobot)',
                                style: TextStyle(
                                    fontSize: 6,
                                    color: muted,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            for (final f in features.take(8)) ...[
                              WeightRow(
                                word: '“${f['token']}”',
                                value: () {
                                  final c =
                                      ((f['contribution'] as num?) ?? 0)
                                          .toDouble();
                                  return '${c >= 0 ? '+' : ''}${c.toStringAsFixed(3)}';
                                }(),
                                progress: maxAbs > 0
                                    ? (((f['contribution'] as num?) ?? 0)
                                            .abs()
                                            .toDouble() /
                                        maxAbs)
                                        .clamp(0, 1)
                                        .toDouble()
                                    : 0,
                                color: ((f['contribution'] as num?) ?? 0) >= 0
                                    ? green
                                    : red,
                              ),
                              const SizedBox(height: 7),
                            ],
                            if (explanation.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF5F8FD),
                                    borderRadius: BorderRadius.circular(7)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.psychology_outlined,
                                            size: 8, color: navy),
                                        SizedBox(width: 4),
                                        Text('Penjelasan Model',
                                            style: TextStyle(
                                                fontSize: 6.5,
                                                color: Color(0xFF3F4B63),
                                                fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(explanation,
                                        style: const TextStyle(
                                            fontSize: 6.2,
                                            height: 1.4,
                                            color: Color(0xFF667085))),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Footer(),
          ],
        ),
      ),
    );
  }
}
