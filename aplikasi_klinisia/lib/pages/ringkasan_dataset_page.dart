// Halaman Ringkasan Dataset â€” DIBUKA hanya setelah user mengunggah CSV
// miliknya sendiri (tidak ada dataset bawaan yang tampil lebih dulu).
// Berisi: statistik dataset, distribusi sentimen (donut), bobot fitur
// SVM, laporan klasifikasi dari file unggahan, sampel klasifikasi,
// dan tombol unduh laporan (CSV/PDF).
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/download_service.dart';
import '../widgets/widgets_bersama.dart';

/// Statistik dataset — hanya menampilkan file unggahan user
/// (tanpa dataset bawaan apa pun).
class _DatasetSection extends StatelessWidget {
  /// Ringkasan file CSV yang diunggah user (wajib).
  final Map<String, dynamic> upload;

  const _DatasetSection({required this.upload});

  static String _fmt(num? v) {
    if (v == null) return '-';
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final up = upload;
    final summary = (up['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final agreement = (up['agreement'] as Map?)?.cast<String, dynamic>();
    final rows = (up['rows_processed'] as num?)?.toInt() ?? 0;
    final positif = (summary['positif'] as num?) ?? 0;
    final negatif = (summary['negatif'] as num?) ?? 0;
    final ratioPos = summary['ratio_positif_pct'] ?? '-';
    final ratioNeg = summary['ratio_negatif_pct'] ?? '-';
    final avg = (summary['avg_confidence'] as num?)?.toDouble();

    // F1-Score rata-rata tertimbang dari laporan klasifikasi FILE INI
    // (baris "Weighted avg" pada `upload_report`) — tampil sebagai kartu
    // "F1 Score" (fallback "Rata-rata Confidence" bila file tanpa label).
    final rep = (up['upload_report'] as Map?)?.cast<String, dynamic>();
    final repRows = ((rep?['rows'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    Map<String, dynamic>? weighted;
    if (rep?['labeled'] == true) {
      for (final r in repRows) {
        if (r['label'] == 'Weighted avg') {
          weighted = r;
          break;
        }
      }
    }
    final f1 = (weighted?['f1_score'] as num?)?.toDouble();
    // Jumlah baris berlabel = support baris Weighted avg (fallback agreement).
    final labeledRows =
        (weighted?['support'] as num?)?.toInt() ??
        (agreement?['labeled_rows'] as num?)?.toInt();

    return Column(
      children: [
        const SectionHeading(
          'Statistik Dataset',
          icon: Icons.upload_file_outlined,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                size: 9,
                color: navy,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${up['filename'] ?? 'unggahan.csv'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 6.5,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5FBF2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_fmt(rows)} Baris',
                  style: const TextStyle(fontSize: 6, color: Color(0xFF008B65)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Total Baris Diunggah',
                value: _fmt(rows),
                sub: 'kolom teks: ${up['column_used'] ?? '-'}',
                color: navy,
                subBg: paleBlue,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _MetricCard(
                title: 'Sentimen Positif',
                value: _fmt(positif),
                sub: '$ratioPos% Proporsi',
                color: const Color(0xFF00875F),
                subBg: const Color(0xFFE7FBF3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Sentimen Negatif',
                value: _fmt(negatif),
                sub: '$ratioNeg% Proporsi',
                color: red,
                subBg: const Color(0xFFFFE9E9),
              ),
            ),
            const SizedBox(width: 6),
            // Kartu F1 Score — F1 weighted avg DARI FILE UNGGAHAN USER
            // (upload_report); file tanpa label jatuh ke "Rata-rata
            // Confidence".
            Expanded(
              child: _MetricCard(
                title: f1 != null ? 'F1 Score' : 'Rata-rata Confidence',
                value: f1 != null
                    ? '${(f1 * 100).toStringAsFixed(1)}%'
                    : avg == null
                    ? '-'
                    : '${(avg * 100).toStringAsFixed(1)}%',
                sub: f1 != null
                    ? '${labeledRows ?? '-'} baris berlabel'
                    : 'tanpa kolom label',
                color: navy,
                subBg: paleBlue,
              ),
            ),
          ],
        ),
        // Peringatan bila analisis berhenti pada batas waktu 5 menit:
        // jumlah data TIDAK dipotong lebih dulu — hanya waktunya yang
        // dibatasi, sehingga user tahu berapa baris yang sempat selesai.
        if (up['time_limit_exceeded'] == true) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF5C518), width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 9,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    up['warning'] as String? ??
                        'Analisis dihentikan pada batas waktu.',
                    style: const TextStyle(
                      fontSize: 6,
                      height: 1.4,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value, sub;
  final Color color, subBg;
  const _MetricCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
    required this.subBg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 6.5, color: muted)),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            height: 1,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: subBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(sub, style: TextStyle(fontSize: 5.7, color: color)),
        ),
      ],
    ),
  );
}

/// Distribusi polaritas — dihitung dari ringkasan file unggahan user
/// (tanpa fallback ke dataset bawaan).
class _PolarityCard extends StatelessWidget {
  /// Ringkasan unggah CSV (wajib).
  final Map<String, dynamic> upload;

  const _PolarityCard({required this.upload});

  @override
  Widget build(BuildContext context) {
    final s = (upload['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final total = (s['total'] as num?)?.toInt() ?? 0;
    final positif = (s['positif'] as num?) ?? 0;
    final negatif = (s['negatif'] as num?) ?? 0;
    final ratioPos = '${s['ratio_positif_pct'] ?? '-'}';
    final ratioNeg = '${s['ratio_negatif_pct'] ?? '-'}';
    final posFraction = total > 0 ? positif / total : 0.0;
    final negFraction = total > 0 ? negatif / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Distribusi Polaritas',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TinyBadge(total > 0 ? 'N=$total' : 'N=-'),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(72, 72),
                    painter: _DonutPainter(
                      posFraction: posFraction,
                      negFraction: negFraction,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        total > 0 ? '$total' : '-',
                        style: const TextStyle(
                          fontSize: 11,
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'TOTAL DATA',
                        style: TextStyle(fontSize: 5.5, color: muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 11),
          const Divider(height: 1, color: line),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _LegendBox(
                  color: green,
                  title: 'Positif: ${positif.toInt()}',
                  value: '$ratioPos%',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LegendBox(
                  color: red,
                  title: 'Negatif: ${negatif.toInt()}',
                  value: '$ratioNeg%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double posFraction;
  final double negFraction;

  const _DonutPainter({required this.posFraction, required this.negFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.butt;
    p.color = red;
    canvas.drawArc(
      rect.deflate(4),
      -1.5708,
      3.14159 * 2 * negFraction,
      false,
      p,
    );
    p.color = green;
    canvas.drawArc(
      rect.deflate(4),
      -1.5708 + 3.14159 * 2 * negFraction,
      3.14159 * 2 * posFraction,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.posFraction != posFraction ||
      oldDelegate.negFraction != negFraction;
}

class _LegendBox extends StatelessWidget {
  final Color color;
  final String title, value;
  const _LegendBox({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: color == green ? const Color(0xFFEAFBF4) : const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 5.7,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  fontSize: 6.5,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WeightCard extends StatefulWidget {
  const _WeightCard();

  @override
  State<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<_WeightCard> {
  Map<String, dynamic>? _weights;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiService.weights(limit: 6)
        .then((w) {
          if (mounted) setState(() => _weights = w);
        })
        .catchError((e) {
          if (mounted) setState(() => _error = e.toString());
        });
  }

  List<Map<String, dynamic>> _list(dynamic key) =>
      ((_weights?[key] as List?) ?? [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();

  @override
  Widget build(BuildContext context) {
    final positive = _list('positive').take(4).toList();
    final negative = _list('negative').take(4).toList();
    final maxAbs = [...positive, ...negative]
        .map((e) => (e['abs_weight'] as num?)?.toDouble() ?? 0)
        .fold<double>(0, (a, b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bobot Fitur SVM (w)',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TinyBadge(
                _error != null
                    ? 'Offline'
                    : _weights == null
                    ? 'Memuat...'
                    : 'TF-IDF · ${_weights!['feature_count'] ?? '-'} fitur',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              'Gagal memuat bobot: $_error',
              style: const TextStyle(fontSize: 6.5, color: red),
            )
          else if (_weights == null)
            const LinearProgressIndicator(minHeight: 2, color: navy)
          else ...[
            const Text(
              '↗ PREDIKTOR POSITIF (+)',
              style: TextStyle(
                fontSize: 6,
                color: green,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            for (final w in positive) ...[
              WeightRow(
                word: '“${w['word']}”',
                value: '+${(w['weight'] as num).toStringAsFixed(2)}',
                progress: maxAbs > 0
                    ? ((w['abs_weight'] as num) / maxAbs).clamp(0, 1).toDouble()
                    : 0,
                color: green,
              ),
              const SizedBox(height: 7),
            ],
            const SizedBox(height: 5),
            const Text(
              '↘ PREDIKTOR NEGATIF (-)',
              style: TextStyle(
                fontSize: 6,
                color: red,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            for (final w in negative) ...[
              WeightRow(
                word: '“${w['word']}”',
                value: (w['weight'] as num).toStringAsFixed(2),
                progress: maxAbs > 0
                    ? ((w['abs_weight'] as num) / maxAbs).clamp(0, 1).toDouble()
                    : 0,
                color: red,
              ),
              const SizedBox(height: 7),
            ],
          ],
        ],
      ),
    );
  }
}

/// Tabel laporan klasifikasi: baris Kelas/Precision/Recall/F1-Score/
/// Support + Accuracy/Macro avg/Weighted avg. Nilai `null` ditampilkan "-".
///
/// Tata letak dirapikan agar enak dipandang:
/// - kepala kolom berlatar biru muda bersudut membulat;
/// - baris tiap kelas berselang-seling (zebra) dengan titik warna kelas
///   (merah = Negatif, hijau = Positif);
/// - baris Accuracy/Macro/Weighted dikelompokkan di kotak terpisah
///   berlatar khas agar tidak tercampur dengan baris per kelas.
class _ReportTable extends StatelessWidget {
  /// Baris laporan: {label, precision, recall, f1_score, support}.
  final List<Map<String, dynamic>> rows;

  const _ReportTable({required this.rows});

  /// Format angka P/R/F1: 3 desimal, "-" bila kosong.
  static String _num(dynamic v) => v is num ? v.toStringAsFixed(3) : '-';

  /// Format support: bilangan bulat, "-" bila kosong.
  static String _supp(dynamic v) => v is num ? v.toInt().toString() : '-';

  /// Gaya teks kepala kolom (biru navy di atas latar biru muda).
  static const TextStyle _headStyle = TextStyle(
    fontSize: 6,
    color: navy,
    fontWeight: FontWeight.w700,
  );

  /// Satu baris tabel: kepala kolom / baris kelas / baris ringkasan.
  static Widget _row(
    String label,
    dynamic precision,
    dynamic recall,
    dynamic f1,
    dynamic support, {
    bool header = false,
    bool summary = false,
    bool alt = false,
    bool last = false,
  }) {
    // Warna label mengikuti sentimen: merah = Negatif, hijau = Positif.
    final Color labelColor = label == 'Negatif'
        ? red
        : label == 'Positif'
        ? green
        : ink;
    // Titik warna hanya untuk baris kelas sentimen.
    final bool isSentiment = label == 'Negatif' || label == 'Positif';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        // Latar: kepala biru muda, baris kelas zebra, baris ringkasan
        // transparan (mewarisi latar kotak ringkasan).
        color: header
            ? paleBlue
            : summary
            ? null
            : alt
            ? const Color(0xFFF8FAFE)
            : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: header ? const Radius.circular(7) : Radius.zero,
          topRight: header ? const Radius.circular(7) : Radius.zero,
          bottomLeft: last ? const Radius.circular(7) : Radius.zero,
          bottomRight: last ? const Radius.circular(7) : Radius.zero,
        ),
      ),
      child: Row(
        children: [
          // Kolom kelas — titik warna membedakan Positif/Negatif.
          Expanded(
            flex: 5,
            child: header
                ? Text(label, style: _headStyle)
                : Row(
                    children: [
                      if (isSentiment) ...[
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: labelColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 6.5,
                            color: labelColor,
                            fontWeight: summary
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          // Kolom Precision/Recall/F1 — rata kanan.
          for (final v in [precision, recall, f1])
            Expanded(
              flex: 3,
              child: Text(
                header ? v.toString() : _num(v),
                textAlign: TextAlign.right,
                style: header
                    ? _headStyle
                    : TextStyle(
                        fontSize: 6.5,
                        color: ink,
                        fontWeight: summary ? FontWeight.w700 : FontWeight.w500,
                      ),
              ),
            ),
          // Kolom Support — rata kanan, warna lebih lembut.
          Expanded(
            flex: 2,
            child: Text(
              header ? support.toString() : _supp(support),
              textAlign: TextAlign.right,
              style: header
                  ? _headStyle
                  : TextStyle(
                      fontSize: 6.5,
                      color: summary ? ink : muted,
                      fontWeight: summary ? FontWeight.w700 : FontWeight.w600,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pisahkan baris per kelas dan baris ringkasan (Accuracy dst.).
    final kelas = <Map<String, dynamic>>[];
    final ringkasan = <Map<String, dynamic>>[];
    for (final r in rows) {
      final l = (r['label'] ?? '-').toString();
      if (l == 'Accuracy' || l == 'Macro avg' || l == 'Weighted avg') {
        ringkasan.add(r);
      } else {
        kelas.add(r);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kepala kolom tabel.
        _row(
          'KELAS',
          'PRECISION',
          'RECALL',
          'F1-SCORE',
          'SUPPORT',
          header: true,
        ),
        // Baris tiap kelas — zebra selang-seling.
        for (var i = 0; i < kelas.length; i++)
          _row(
            (kelas[i]['label'] ?? '-').toString(),
            kelas[i]['precision'],
            kelas[i]['recall'],
            kelas[i]['f1_score'],
            kelas[i]['support'],
            alt: i.isOdd,
          ),
        if (ringkasan.isNotEmpty) ...[
          const SizedBox(height: 5),
          // Baris ringkasan dikelompokkan dalam kotak berlatar khas.
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F5FB),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: line, width: 0.7),
            ),
            child: Column(
              children: [
                for (var i = 0; i < ringkasan.length; i++)
                  _row(
                    (ringkasan[i]['label'] ?? '-').toString(),
                    ringkasan[i]['precision'],
                    ringkasan[i]['recall'],
                    ringkasan[i]['f1_score'],
                    ringkasan[i]['support'],
                    summary: true,
                    last: i == ringkasan.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Kartu Laporan Klasifikasi — tabel Precision/Recall/F1-Score/Support
/// per kelas + Accuracy, Macro avg, dan Weighted avg DARI FILE YANG
/// BARU DIUNGGAH USER (`upload_report` pada respons /api/analyze/csv),
/// yaitu prediksi model dibandingkan dengan label acuan di file itu.
///
/// File berlabel: baris per kelas + Accuracy/Macro/Weighted.
/// File tanpa label: hanya baris per kelas berisi Support (P/R/F1 "-").
/// Kartu disembunyikan bila respons tidak menyertakan laporan.
class _ReportCard extends StatelessWidget {
  /// Hasil unggah CSV user (wajib).
  final Map<String, dynamic> upload;

  const _ReportCard({required this.upload});

  @override
  Widget build(BuildContext context) {
    final rep = (upload['upload_report'] as Map?)?.cast<String, dynamic>();
    final labeled = rep?['labeled'] == true;
    final rows = ((rep?['rows'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    // Bila file unggahan tidak menyertakan laporan, kartu tidak tampil.
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Laporan Klasifikasi',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TinyBadge(labeled ? 'File unggahan' : 'Tanpa label'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            labeled
                ? 'Precision, Recall, F1-Score, dan Support tiap kelas '
                      'dihitung dari prediksi model vs label acuan pada file '
                      'yang Anda unggah.'
                : 'File ini tidak memiliki kolom label — hanya Support '
                      '(jumlah prediksi tiap kelas) yang bisa ditampilkan.',
            style: const TextStyle(fontSize: 6, color: muted, height: 1.5),
          ),
          const SizedBox(height: 7),
          _ReportTable(rows: rows),
          const SizedBox(height: 6),
          Text(
            labeled
                ? 'Support = jumlah baris tiap kelas di file unggahan; '
                      'Accuracy/Macro/Weighted memakai seluruh baris berlabel.'
                : 'Unggah file berlabel (mis. kolom Sentiment/label) untuk '
                      'melihat Precision, Recall, dan F1-Score.',
            style: const TextStyle(fontSize: 6, color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Sampel hasil klasifikasi — menampilkan baris dari file unggahan user
/// (bukan teks contoh bawaan).
class _SamplesSection extends StatelessWidget {
  /// Daftar baris hasil analisis unggahan user ({text, label,
  /// is_positive, confidence, ...}); diambil dari respons /api/analyze/csv.
  final List<Map<String, dynamic>> samples;

  const _SamplesSection({required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return Column(
        children: [
          const SectionHeading('Sampel Klasifikasi Ulasan'),
          const Text(
            'Tidak ada baris untuk ditampilkan sebagai sampel.',
            style: TextStyle(fontSize: 6.5, color: muted),
          ),
        ],
      );
    }
    return Column(
      children: [
        SectionHeading(
          'Sampel Klasifikasi Ulasan',
          badge: '${samples.length} baris pertama',
        ),
        for (var i = 0; i < samples.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SampleCard(
              item: _Sample(
                'CSV-${(i + 1).toString().padLeft(3, '0')}',
                '${samples[i]['text'] ?? ''}',
                samples[i]['is_positive'] == true,
                (((samples[i]['confidence'] as num?) ?? 0) * 100)
                    .toStringAsFixed(1),
              ),
            ),
          ),
      ],
    );
  }
}

class _Sample {
  final String id, text, confidence;
  final bool positive;
  const _Sample(this.id, this.text, this.positive, this.confidence);
}

class _SampleCard extends StatelessWidget {
  final _Sample item;
  const _SampleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.positive ? const Color(0xFF00A876) : red;
    final bg = item.positive
        ? const Color(0xFFE7FBF2)
        : const Color(0xFFFFE9E9);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                item.id,
                style: const TextStyle(fontSize: 5.8, color: muted),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.positive ? Icons.check_circle : Icons.cancel,
                      size: 6,
                      color: color,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.positive ? 'Positif' : 'Negatif',
                      style: TextStyle(
                        fontSize: 5.8,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.text,
            style: const TextStyle(
              fontSize: 6.5,
              height: 1.4,
              color: Color(0xFF424958),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Text(
                'Confidence: ${item.confidence}',
                style: const TextStyle(fontSize: 5.7, color: muted),
              ),
              const Spacer(),
              const Icon(Icons.visibility_outlined, size: 8, color: navy),
              const SizedBox(width: 3),
              const Text('Uji', style: TextStyle(fontSize: 6, color: navy)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Halaman Ringkasan Dataset — DIBUKA hanya setelah user mengunggah CSV
/// miliknya sendiri (tidak ada dataset bawaan yang tampil lebih dulu).
///
/// Menampilkan empat bagian sesuai permintaan: statistik dataset,
/// distribusi sentimen, grafik fitur SVM, dan sampel hasil klasifikasi —
/// semuanya dari file unggahan user. Halaman ini adalah SATU-SATUNYA
/// tampilan dataset aktif — tidak pernah tampil bersamaan dengan
/// Halaman Hasil Sentimen.
class DatasetSummaryPage extends StatelessWidget {
  /// Hasil unggah CSV user (wajib — tidak ada fallback data internal).
  final Map<String, dynamic> upload;

  const DatasetSummaryPage({super.key, required this.upload});

  @override
  Widget build(BuildContext context) {
    final samples = ((upload['samples'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: 'Ringkasan Dataset'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1) Statistik dataset dari file unggahan user
                    _DatasetSection(upload: upload),
                    const SizedBox(height: 12),
                    // 2) Distribusi sentimen unggahan user
                    _PolarityCard(upload: upload),
                    const SizedBox(height: 12),
                    // 3) Grafik fitur SVM
                    const _WeightCard(),
                    const SizedBox(height: 12),
                    // 4) Laporan klasifikasi — P/R/F1/support per kelas dari
                    //    prediksi model vs label pada FILE UNGGAHAN USER
                    _ReportCard(upload: upload),
                    const SizedBox(height: 13),
                    // 5) Sampel hasil klasifikasi baris unggahan user
                    _SamplesSection(samples: samples),
                    const SizedBox(height: 13),
                    // 6) Unduh laporan hasil analisis file unggahan
                    const _ExportButtons(),
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

/// Tombol unduh laporan di bawah Halaman Ringkasan Dataset:
/// - CSV  → seluruh baris hasil analisis file yang baru diunggah user
///          (GET /api/report/csv/upload).
/// - PDF  → ringkasan model + hasil unggahan + riwayat (GET /api/report/pdf).
class _ExportButtons extends StatefulWidget {
  const _ExportButtons();

  @override
  State<_ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<_ExportButtons> {
  bool _busy = false;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: navy,
          content: Text(msg, style: const TextStyle(fontSize: 9)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _open(String url, String label, String fallbackName) async {
    setState(() => _busy = true);
    try {
      // Web: fetch + blob + anchor download (tanpa popup). Non-web:
      // url_launcher. Keduanya lewat satu jembatan di download_service.
      await downloadAttachment(url, fallbackName: fallbackName);
      if (!mounted) return;
      _snack('Unduhan $label dimulai — periksa folder unduhan browser.');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _snack('Gagal mengunduh $label: $msg');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hp = layarHp(context);
    // Tinggi tombol unduh: 48px di HP agar nyaman disentuh jari.
    final tinggi = hp ? 48.0 : 32.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading(
          'Unduh Laporan Hasil',
          icon: Icons.download_outlined,
        ),
        InkWell(
          onTap: _busy
              ? null
              : () => _open(
                  ApiService.csvUploadReportUrl(),
                  'Hasil CSV',
                  'hasil_unggahan_klinisia.csv',
                ),
          child: Container(
            height: tinggi,
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_busy)
                  SizedBox(
                    width: hp ? 13 : 9,
                    height: hp ? 13 : 9,
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.3,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(
                    Icons.download_rounded,
                    size: hp ? 16 : 11,
                    color: Colors.white,
                  ),
                const SizedBox(width: 5),
                Text(
                  'Unduh Hasil Analisis (CSV)',
                  style: TextStyle(
                    fontSize: hp ? 13 : 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: _busy
              ? null
              : () => _open(
                  ApiService.pdfReportUrl,
                  'Ringkasan PDF',
                  'ringkasan_sentimen_klinisia.pdf',
                ),
          child: Container(
            height: tinggi,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  size: hp ? 16 : 11,
                  color: red,
                ),
                const SizedBox(width: 5),
                Text(
                  'Ekspor Ringkasan PDF',
                  style: TextStyle(
                    fontSize: hp ? 13 : 8,
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
