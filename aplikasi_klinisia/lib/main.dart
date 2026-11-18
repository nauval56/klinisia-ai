import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import 'services/api_service.dart';
import 'services/download_service.dart';

void main() {
  runApp(const KlinisiaAiApp());
}

/// Definisi Palet Warna Material 3 persis seperti pada Tailwind Config HTML
class AppColors {
  // Light Mode Tokens
  static const Color primary = Color(0xFF004AC6);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF2563EB);
  static const Color onPrimaryContainer = Color(0xFFEEEFFF);
  static const Color primaryFixed = Color(0xFFDBE1FF);
  static const Color primaryFixedDim = Color(0xFFB4C5FF);
  static const Color onPrimaryFixed = Color(0xFF00174B);
  static const Color onPrimaryFixedVariant = Color(0xFF003EA8);

  static const Color secondary = Color(0xFF00668A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF40C2FD);
  static const Color onSecondaryContainer = Color(0xFF004D6A);
  static const Color secondaryFixed = Color(0xFFC4E7FF);
  static const Color secondaryFixedDim = Color(0xFF7BD0FF);

  static const Color tertiary = Color(0xFF006242);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF007D55);
  static const Color onTertiaryContainer = Color(0xFFBDFFDB);
  static const Color tertiaryFixed = Color(0xFF6FFBBE);
  static const Color tertiaryFixedDim = Color(0xFF4EDEA3);
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF005236);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color surface = Color(0xFFF8F9FF);
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF434655);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color surfaceVariant = Color(0xFFD3E4FE);
  static const Color outline = Color(0xFF737686);
  static const Color outlineVariant = Color(0xFFC3C6D7);
}

class KlinisiaAiApp extends StatefulWidget {
  const KlinisiaAiApp({super.key});

  @override
  State<KlinisiaAiApp> createState() => _KlinisiaAiAppState();
}

class _KlinisiaAiAppState extends State<KlinisiaAiApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klinisia AI - Sentiment Analyzer',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          secondaryContainer: AppColors.secondaryContainer,
          onSecondaryContainer: AppColors.onSecondaryContainer,
          tertiary: AppColors.tertiary,
          onTertiary: AppColors.onTertiary,
          tertiaryContainer: AppColors.tertiaryContainer,
          onTertiaryContainer: AppColors.onTertiaryContainer,
          error: AppColors.error,
          onError: AppColors.onError,
          errorContainer: AppColors.errorContainer,
          onErrorContainer: AppColors.onErrorContainer,
          surface: AppColors.surface,
          onSurface: AppColors.onSurface,
          onSurfaceVariant: AppColors.onSurfaceVariant,
          outline: AppColors.outline,
          outlineVariant: AppColors.outlineVariant,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1524),
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryFixedDim,
          onPrimary: AppColors.onPrimaryFixed,
          primaryContainer: AppColors.primaryContainer,
          onPrimaryContainer: AppColors.onPrimaryContainer,
          secondary: AppColors.secondaryFixedDim,
          onSecondary: const Color(0xFF001E2C),
          secondaryContainer: AppColors.secondary,
          onSecondaryContainer: AppColors.secondaryFixed,
          tertiary: AppColors.tertiaryFixedDim,
          onTertiary: AppColors.onTertiaryFixed,
          tertiaryContainer: AppColors.tertiaryContainer,
          onTertiaryContainer: AppColors.onTertiaryContainer,
          error: const Color(0xFFFFB4AB),
          errorContainer: AppColors.onErrorContainer,
          onErrorContainer: AppColors.errorContainer,
          surface: const Color(0xFF0B1524),
          onSurface: const Color(0xFFEAF1FF),
          onSurfaceVariant: const Color(0xFFC3C6D7),
          outlineVariant: const Color(0xFF434655),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: KlinisiaHomePage(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class KlinisiaHomePage extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const KlinisiaHomePage({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<KlinisiaHomePage> createState() => _KlinisiaHomePageState();
}

class _KlinisiaHomePageState extends State<KlinisiaHomePage>
    with SingleTickerProviderStateMixin {
  // Scroll & hero key (kunci section pertama pada hero)
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _heroKey = GlobalKey();

  /// Konteks untuk "kunci" input bar melayang ala Gemini/ChatGPT:
  /// menempelkan widget input ke dalam hero/viewport sehingga bilah
  /// kapsul selalu tampil di bawah layar tanpa halaman terpisah.
  final GlobalKey _floatingAnchorKey = GlobalKey();

  // =========================================================================
  // ALIRAN CHAT 3 KONDISI (ala Gemini/ChatGPT) — satu halaman, tanpa routing.
  //
  //   Kondisi 1 (awal)     : hero + kartu status model + preset. Belum ada
  //                          pesan -> kartu hasil/laporan TIDAK tampil.
  //   Kondisi 2 (teks)     : bubble user + Kartu Hasil Analisis AI + XAI,
  //                          menumpuk ke bawah (riwayat bertambah).
  //   Kondisi 3 (file)     : chip lampiran file + rangkaian laporan dataset
  //                          (unduh, ringkasan KPI, donut, insight, kata
  //                          kunci, spesifikasi & metrik model).
  // =========================================================================
  final List<_ChatMessage> _riwayat = <_ChatMessage>[];

  // Input & Sentiment State
  final TextEditingController _reviewController = TextEditingController();
  int _charCount = 0;

  // Lampiran file (Kondisi 3): dipilih via tombol `+`, dianalisis saat `↑`.
  PlatformFile? _lampiran;
  bool _busyPilihFile = false;

  // Status pengiriman pesan (hasil analisis disimpan per-pesan di _riwayat).
  bool _busyAnalisis = false;
  String? _error;

  // Unggah CSV — DATA NYATA dari backend (/api/analyze/csv).
  bool _busyUnggah = false;
  bool _busyEkspor = false;

  // Info model NYATA dari /api/health, /api/model, dan /api/model/weights.
  bool? _online;
  double? _akurasi;
  int? _latencyApi;
  Map<String, dynamic>? _infoModel;
  Map<String, dynamic>? _bobot;

  // Visualisasi Tab State (0: Distribusi, 1: Bobot Fitur)
  int _selectedChartTab = 0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Muat info koneksi & model NYATA dari backend (tanpa memblokir UI).
    _muatInfoModel();

    _reviewController.addListener(() {
      setState(() {
        _charCount = _reviewController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _reviewController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  /// Isi preset contoh lalu langsung analisis (Kondisi 2).
  void _loadSample(String text) {
    _reviewController.text = text;
    _kirim();
  }

  /// Bersihkan input, lampiran, dan pesan error (riwayat chat tetap ada).
  void _resetForm() {
    _reviewController.clear();
    setState(() {
      _lampiran = null;
      _error = null;
    });
  }

  /// Gulir halus sehingga pesan terbaru (bubble + kartu hasil) langsung
  /// terlihat tepat di bawah header fixed — BUKAN lompat ke paling bawah
  /// halaman (yang justru menampilkan footer, bukan hasil analisis).
  ///
  /// Tunggu 2 frame agar tinggi konten baru (kartu hasil / laporan
  /// dataset) terhitung dulu; ulangi sekali bila konten masih bertambah.
  void _gulirKePesan(_ChatMessage pesan, {bool paksa = false}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      void lompat() {
        final ctx = pesan.key.currentContext;
        if (ctx == null) return;
        final box = ctx.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return;
        final pos = _scrollController.position;
        // dy = posisi global atas pesan di layar saat ini. Tambahkan ke
        // pixels lalu kurangi `targetY` agar bubble sejajar `targetY`
        // (di bawah header fixed 64px) — hasil langsung terlihat.
        const double targetY = 96;
        final dy = box.localToGlobal(Offset.zero).dy;
        final target = (pos.pixels + dy - targetY).clamp(
          pos.minScrollExtent,
          pos.maxScrollExtent,
        );
        if ((target - pos.pixels).abs() < 1) return;
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }

      lompat();
      if (paksa) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) lompat();
        });
      }
    });
  }

  /// Pilih file dataset (Kondisi 3): HANYA menyimpan lampiran.
  /// Analisis dijalankan saat user menekan tombol kirim `↑`.
  ///
  /// `FileType.any` dipakai agar file dari Google Drive/storage eksternal
  /// tetap bisa DIPILIH (filter MIME bawaan Android sering membuat file
  /// .csv/.xlsx dari Drive tidak bisa ditekan). Validasi ekstensi &
  /// ukuran dilakukan manual di sini dengan pesan yang jelas.
  static const List<String> _formatDataset = ['csv', 'tsv', 'xlsx'];
  static const int _maksUnggahanBytes = 4400 * 1024; // batas Vercel 4,5 MB

  Future<void> _pilihFile() async {
    if (_busyPilihFile) return;
    setState(() {
      _busyPilihFile = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // jangan filter MIME — semua file terlihat
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      final ekstensi = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      if (!_formatDataset.contains(ekstensi)) {
        setState(
          () => _error =
              'File "${file.name}" tidak didukung.\n'
              'Format yang bisa dianalisis: .CSV, .TSV, dan .XLSX.',
        );
        return;
      }
      if (file.bytes != null && file.bytes!.length > _maksUnggahanBytes) {
        final mb = (file.bytes!.length / (1024 * 1024)).toStringAsFixed(1);
        setState(
          () => _error =
              'File "${file.name}" berukuran $mb MB — melebihi batas '
              'unggah 4,5 MB.\n'
              'Kurangi jumlah baris atau hapus kolom yang tidak perlu, '
              'lalu unggah ulang.',
        );
        return;
      }
      if (file.bytes == null) {
        setState(
          () => _error = 'File "${file.name}" tidak terbaca. Coba pilih ulang.',
        );
        return;
      }
      if (!mounted) return;
      setState(() => _lampiran = file);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memilih file: $e');
    } finally {
      if (mounted) setState(() => _busyPilihFile = false);
    }
  }

  /// Tambahkan pesan ke riwayat chat lalu tampilkan langsung hasilnya
  /// (gulir ke pesan ini, bukan ke bawah halaman).
  void _tambahPesan(_ChatMessage pesan) {
    setState(() => _riwayat.add(pesan));
    _gulirKePesan(pesan);
    // Bila tinggi konten masih bertambah (animasi chart/laporan),
    // gulir ulang ke pesan yang sama setelah frame berikutnya.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _gulirKePesan(pesan, paksa: true);
    });
  }

  /// Panduan format CSV (tombol di baris status file).
  void _tampilkanPanduanCsv() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Format CSV: satu kolom teks ulasan (content / review / ulasan). '
          'Kolom score atau label (opsional) dipakai agar prediksi bisa '
          'dibandingkan dengan label acuan.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  /// Kirim pesan sesuai 3 State Flow (trigger tombol `↑`):
  ///   - ada file terlampir  -> Kondisi 3 (analisis dataset)
  ///   - hanya teks          -> Kondisi 2 (analisis teks)
  ///   - keduanya kosong     -> Kondisi 1 (validasi, tanpa panggilan API)
  Future<void> _kirim() async {
    FocusScope.of(context).unfocus();

    // ---- Kondisi 3: ada lampiran file -> analisis dataset (pelabelan
    // biner 1-3 Negatif / 4-5 Positif + prediksi SVM seluruh baris).
    if (_lampiran != null) {
      await _analisisDataset(_lampiran!);
      return;
    }

    // ---- Kondisi 2: hanya teks.
    final text = _reviewController.text.trim();
    if (text.isEmpty) {
      setState(
        () => _error = 'Tulis ulasan atau lampirkan file terlebih dahulu.',
      );
      return;
    }
    await _analisisTeks(text);
  }

  /// Kondisi 2: analisis SATU ulasan teks ke backend (/api/analyze).
  Future<void> _analisisTeks(String text) async {
    setState(() {
      _busyAnalisis = true;
      _error = null;
    });
    final sw = Stopwatch()..start();
    try {
      final res = await ApiService.analyze(text);
      sw.stop();
      if (!mounted) return;
      setState(() => _busyAnalisis = false);
      // Tambahkan pesan + kartu hasil & XAI ke stream chat, lalu gulir.
      _tambahPesan(
        _ChatMessage.teks(
          teksUser: text,
          hasil: res,
          latencyMs: sw.elapsedMilliseconds,
        ),
      );
    } catch (e) {
      sw.stop();
      if (!mounted) return;
      setState(() {
        _busyAnalisis = false;
        _error = e.toString();
      });
    }
  }

  /// Kondisi 3: analisis file lampiran ke backend (/api/analyze/csv) —
  /// pelabelan biner otomatis dari kolom rating (1–3 Negatif, 4–5 Positif)
  /// + prediksi SVM seluruh baris. Lampiran dibuang setelah analisis.
  Future<void> _analisisDataset(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      setState(
        () => _error = 'File "${file.name}" tidak terbaca. Coba pilih ulang.',
      );
      return;
    }

    setState(() {
      _busyUnggah = true;
      _error = null;
    });
    try {
      final res = await ApiService.analyzeCsv(
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(() {
        _busyUnggah = false;
        _lampiran = null; // lampiran sudah "terkirim" -> chip di stream
      });
      // Chip lampiran + rangkaian laporan dataset di stream chat.
      _tambahPesan(_ChatMessage.dataset(namaFile: file.name, unggahan: res));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyUnggah = false;
        _error = e.toString();
      });
    }
  }

  /// Muat info koneksi & model NYATA dari backend sekali saat awal load.
  Future<void> _muatInfoModel() async {
    final sw = Stopwatch()..start();
    try {
      final h = await ApiService.health();
      sw.stop();
      if (!mounted) return;
      setState(() {
        _online = h['model_ready'] == true;
        _akurasi = (h['accuracy'] as num?)?.toDouble();
        _latencyApi = sw.elapsedMilliseconds;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _online = false); // backend belum dijalankan
      return;
    }
    try {
      final m = await ApiService.modelInfo();
      if (mounted) setState(() => _infoModel = m);
    } catch (_) {
      // biarkan null — section model menampilkan '—'
    }
    try {
      final b = await ApiService.weights(limit: 6);
      if (mounted) setState(() => _bobot = b);
    } catch (_) {
      // biarkan null — section kata kunci menampilkan status menunggu
    }
  }

  /// Catatan keyakinan mengikuti tingkat confidence backend.
  String _catatanKeyakinan(double pct) => pct >= 85
      ? 'Sangat Yakin'
      : pct >= 70
      ? 'Yakin'
      : 'Cukup Yakin';

  /// Format angka dengan pemisah ribuan titik (id-ID).
  String _fmt(num? v) {
    if (v == null) return '—';
    final s = v.toInt().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Teks sub-metrik akurasi: rasio pembagian data dari backend.
  String get _teksHoldout {
    final m = _infoModel?['metrics'];
    if (m is Map && m['test_size'] != null) {
      return 'Hold-out 80:20 · uji ${m['test_size']} baris';
    }
    return 'Menunggu backend…';
  }

  /// Teks tag F1 dari metrik backend ('—' bila backend belum terhubung).
  String get _teksF1 {
    final m = _infoModel?['metrics'];
    if (m is Map && m['f1_score'] is num) {
      return 'F1-Score ${((m['f1_score'] as num) * 100).toStringAsFixed(1)}%';
    }
    return 'F1-Score —';
  }

  /// Jumlah fitur TF-IDF (vocab) dari info model; '—' bila belum termuat.
  String get _vocabTeks {
    final v = _infoModel?['vectorizer'];
    if (v is Map && v['vocab_size'] is num) {
      return '${_fmt(v['vocab_size'] as num)} fitur';
    }
    return '—';
  }

  /// Susun teks ulasan sebagai span; token berpengaruh dari model
  /// di-highlight bila kata itu benar-benar muncul di teks.
  List<InlineSpan> _transkripSpans(
    String teks,
    Set<String> tokenPenting, {
    required bool positif,
  }) {
    final spans = <InlineSpan>[];
    final Color bg = positif
        ? AppColors.tertiaryFixed
        : AppColors.errorContainer;
    final Color fg = positif
        ? AppColors.onTertiaryFixed
        : AppColors.onErrorContainer;
    final re = RegExp(r'\S+');
    var last = 0;
    for (final m in re.allMatches(teks)) {
      if (m.start > last) {
        spans.add(TextSpan(text: teks.substring(last, m.start)));
      }
      final kata = m.group(0)!;
      final bersih = kata.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      if (tokenPenting.contains(bersih)) {
        spans.add(_highlightSpan(kata, bg, fg));
      } else {
        spans.add(TextSpan(text: kata));
      }
      last = m.end;
    }
    if (last < teks.length) spans.add(TextSpan(text: teks.substring(last)));
    if (spans.isEmpty) spans.add(const TextSpan(text: '—'));
    return spans;
  }

  /// Ekspor lampiran (CSV/PDF) dari backend dengan status sibuk.
  Future<void> _ekspor(String url, String namaFallback) async {
    setState(() => _busyEkspor = true);
    try {
      await downloadAttachment(url, fallbackName: namaFallback);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyEkspor = false);
    }
  }

  // Helper warna adaptif Light/Dark sesuai struktur permukaan HTML
  Color get _bgSurface =>
      widget.isDark ? const Color(0xFF0B1524) : AppColors.surface;
  Color get _surfaceLowest => widget.isDark
      ? const Color(0xFF132238)
      : AppColors.surfaceContainerLowest;
  Color get _surfaceLow =>
      widget.isDark ? const Color(0xFF101D30) : AppColors.surfaceContainerLow;
  Color get _surfaceContainer =>
      widget.isDark ? const Color(0xFF182A44) : AppColors.surfaceContainer;
  Color get _surfaceContainerHighest => widget.isDark
      ? const Color(0xFF264063)
      : AppColors.surfaceContainerHighest;
  Color get _textPrimary =>
      widget.isDark ? const Color(0xFFEAF1FF) : AppColors.onSurface;
  Color get _textVariant =>
      widget.isDark ? const Color(0xFFAEC0DC) : AppColors.onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgSurface,
      // StackFit.expand: Stack selalu setinggi viewport — content scroll
      // bebas lebih pendek/lebih tinggi dari layar, bar melayang & header
      // fixed tetap menempel di tepi atas/bawah (bukan ikut tinggi konten).
      body: Stack(
        fit: StackFit.expand,
        children: [
          // =========================================================================
          // STREAM CHAT (satu halaman, tanpa routing):
          //   Kondisi 1 (awal) : hero + kartu status model + preset.
          //   Kondisi 2 (teks) : bubble user + Kartu Hasil Analisis AI + XAI.
          //   Kondisi 3 (file) : chip lampiran + rangkaian laporan dataset.
          // Hero hanya tampil selama riwayat kosong; hasil menumpuk ke bawah
          // dan selalu menggulir halus ke pesan terbaru (auto-scroll).
          // =========================================================================
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              top: 84,
              bottom: 148, // ruang untuk input bar melayang di bawah
              left: 16,
              right: 16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768), // max-w-3xl
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kondisi 1 (awal): hero ringkas + kartu status model —
                    // tampil HANYA selama belum ada pesan chat, tanpa
                    // section lain supaya halaman awal lapang & bersih.
                    if (_riwayat.isEmpty) _buildHeroSection(),

                    // Stream pesan chat: bubble user + kartu hasil/laporan
                    // sesuai kondisi yang dikirim (auto-scroll ke bawah).
                    for (final pesan in _riwayat) ...[
                      _buildPesan(pesan),
                      const SizedBox(height: 28),
                    ],

                    // Footer baru tampil setelah pesan pertama — halaman
                    // awal tetap ringkas & bersih.
                    if (_riwayat.isNotEmpty) ...[
                      const SizedBox(height: 48),
                      _buildFooterSection(),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // FIXED TOP HEADER
          Positioned(top: 0, left: 0, right: 0, child: _buildFixedHeader()),

          // FIXED BOTTOM FLOATING INPUT BAR (selalu tampil di semua state)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFloatingInputBar(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TOP HEADER
  // ===========================================================================
  Widget _buildFixedHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _bgSurface.withValues(alpha: 0.90),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 768),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo & Title — dibatasi lebarnya agar wrap di layar HP.
                  Expanded(
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuC8iSUYt-skubrOl_UFyPL5PHVobF-NH-7Utaw_7_SVwrNktyfF_WWsKwZf75sgdS08nxgEhnFmbQYoJ22Z-uOnH7LJ0gwvJs026BDNSy1fNFLulXI8-vrAo68_eiELdzXWgpK3PNRJl_0EQUQclJxRToaPNwb-boKAEEJiNNTAo2xquSCfb031Z4BQXuadDKJhVjTgnkl4KyJTvqUhza0Gd0Vlo1FBukf8LRjY4aM2qjDwMGFiW4QSIg',
                            height: 32,
                            width: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Container(
                              height: 32,
                              width: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.local_hospital,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Klinisia AI',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: _textPrimary,
                                ),
                              ),
                              Row(
                                children: [
                                  FadeTransition(
                                    opacity: _pulseController,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _online == null
                                            ? AppColors.secondary
                                            : _online!
                                            ? AppColors.tertiary
                                            : AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _online == null
                                          ? 'SVM Linear · Memuat…'
                                          : _online!
                                          ? 'SVM Linear · Online${_akurasi != null ? ' (${(_akurasi! * 100).toStringAsFixed(1)}%)' : ''}'
                                          : 'SVM Linear · Offline',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                        color: _textVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Theme Toggle & User Avatar
                  Row(
                    children: [
                      InkWell(
                        onTap: widget.onToggleTheme,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isDark ? Icons.light_mode : Icons.dark_mode,
                            size: 20,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.onPrimary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: HERO (#hero)
  // ===========================================================================

  /// Judul section: ikon + teks yang dibatasi lebarnya (Expanded) sehingga
  /// wrap otomatis di layar sempit dan tidak pernah overflow horizontal.
  Widget _sectionTitle(
    IconData icon,
    String title, {
    Color color = AppColors.primary,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Container(
      key: _heroKey,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'AI Healthtech Intelligence • Analisis Sentimen NLP',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.onPrimaryFixedVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Headline
          RichText(
            text: TextSpan(
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                height: 1.28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.56,
                color: _textPrimary,
              ),
              children: [
                const TextSpan(text: 'Klinisia '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondaryContainer],
                    ).createShader(bounds),
                    child: Text(
                      'Sentiment Analyzer',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        height: 1.28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle — satu kalimat singkat agar tidak menumpuk.
          Text(
            'Klasifikasi sentimen ulasan pengguna dengan SVM Linear '
            'berbasis fitur TF-IDF.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.57,
              color: _textVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Kartu Status Model SVM — ringkas, tanpa tombol CTA ganda
          // (input bar melayang di bawah selalu tersedia).
          // Tech Diagnostic Hero Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status row — indikator koneksi backend yang sesungguhnya.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          FadeTransition(
                            opacity: _pulseController,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _online == null
                                    ? AppColors.secondary
                                    : _online!
                                    ? AppColors.tertiary
                                    : AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _online == null
                                  ? 'Model Status: Memuat…'
                                  : _online!
                                  ? 'Model Status: Online'
                                  : 'Model Status: Offline',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _latencyApi == null ? 'API — ms' : 'API $_latencyApi ms',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: _textVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Akurasi model aktif — ringkas, tanpa grafik dekoratif.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Model Accuracy',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _akurasi != null
                              ? '${(_akurasi! * 100).toStringAsFixed(1)}%'
                              : '—',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? AppColors.primaryFixedDim
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _teksHoldout,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: widget.isDark
                                  ? AppColors.tertiaryFixedDim
                                  : AppColors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tags ringkas
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _codeTag(
                      'SVM Linear',
                      _surfaceContainerHighest,
                      _textPrimary,
                    ),
                    _codeTag(
                      'TF-IDF Unigram',
                      _surfaceContainerHighest,
                      _textPrimary,
                    ),
                    _codeTag(
                      _teksF1,
                      AppColors.tertiaryFixed,
                      AppColors.onTertiaryFixed,
                      bold: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeTag(String text, Color bg, Color fg, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: fg,
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: INPUT ULASAN (#input-section)
  // ===========================================================================
  /// ==========================================================================
  /// INPUT BAR MELAYANG ALA GEMINI/CHATGPT (selalu tampil di bawah layar).
  ///
  /// Berisi kapsul teks + tombol `+` (lampirkan file) + tombol `↑` (kirim
  /// sesuai 3 State Flow). Preset contoh cepat tampil di sini — kartu
  /// Hasil/Laporan TIDAK tampil sebelum user menekan `↑`.
  /// ==========================================================================
  Widget _buildFloatingInputBar() {
    final bool sibuk = _busyAnalisis || _busyUnggah || _busyPilihFile;
    return Container(
      key: _floatingAnchorKey,
      decoration: BoxDecoration(
        color: _bgSurface.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Preset contoh cepat (hanya saat riwayat masih kosong).
                  if (_riwayat.isEmpty) ...[
                    _presetRow(),
                    const SizedBox(height: 10),
                  ],

                  // Error analisis/unggahan — tampil hanya bila ada pesan.
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.onErrorContainer,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _error = null),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Chip lampiran file (dipilih via `+`, dianalisis saat `↑`).
                  if (_lampiran != null) ...[
                    _chipLampiran(_lampiran!),
                    const SizedBox(height: 10),
                  ],

                  // Kapsul input ala Gemini.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceLowest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.outlineVariant.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // '+' Lampirkan dataset (.csv/.xlsx) — hanya memilih
                        // file; analisis berjalan saat tombol `↑` ditekan.
                        InkWell(
                          onTap: sibuk ? null : _pilihFile,
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            width: 38,
                            height: 38,
                            child: _busyPilihFile
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : Icon(
                                    Icons.add,
                                    size: 24,
                                    color: _textVariant,
                                  ),
                          ),
                        ),

                        // Text Field
                        Expanded(
                          child: TextField(
                            controller: _reviewController,
                            maxLength: 500,
                            onSubmitted: (_) => _kirim(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _textPrimary,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: 'Tulis ulasan pengguna atau tanyakan analisis...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: _textVariant.withValues(alpha: 0.7),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),

                        // Clear Button
                        InkWell(
                          onTap: _resetForm,
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: _textVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Send / Analyze Arrow Button `↑` — trigger 3 State Flow:
                        // ada file -> Kondisi 3; hanya teks -> Kondisi 2.
                        InkWell(
                          onTap: sibuk ? null : _kirim,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: sibuk
                                ? const Padding(
                                    padding: EdgeInsets.all(11),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onPrimary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward,
                                    color: AppColors.onPrimary,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Panduan format file (micro-guide).
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: _tampilkanPanduanCsv,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.upload_file,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _lampiran == null
                                  ? 'Tekan + untuk lampirkan dataset (.CSV / .XLSX), atau tulis teks — lalu ↑ untuk menganalisis.'
                                  : 'Tekan ↑ untuk menganalisis seluruh baris file terlampir.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _textVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Deret preset contoh cepat (hanya Kondisi 1 — belum ada pesan).
  Widget _presetRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Preset Contoh Cepat:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textVariant,
                ),
              ),
            ),
            Text(
              '$_charCount/500',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: _textVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _presetChip(
                dotColor: AppColors.tertiaryContainer,
                label: 'Dokter cepat & obat tepat',
                badgeText: 'Positif',
                badgeBg: AppColors.tertiaryFixed,
                badgeFg: AppColors.onTertiaryFixed,
                onTap: () => _loadSample(
                  'Layanan dokter cepat & obat sampai tepat waktu! Sangat memuaskan.',
                ),
              ),
              const SizedBox(width: 8),
              _presetChip(
                dotColor: AppColors.secondary,
                label: 'Perlu update jadwal',
                // Model hanya punya 2 kelas (Positif/Negatif),
                // jadi chip contoh ini tanpa label kelas.
                onTap: () => _loadSample(
                  'Aplikasi lumayan, tapi perlu update jadwal praktek dokter spesialis.',
                ),
              ),
              const SizedBox(width: 8),
              _presetChip(
                dotColor: AppColors.error,
                label: 'Gagal login & resep hilang',
                badgeText: 'Negatif',
                badgeBg: AppColors.errorContainer,
                badgeFg: AppColors.onErrorContainer,
                onTap: () => _loadSample(
                  'Sering gagal login dan resep digital hilang saat dibuka, tolong perbaiki.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Chip lampiran file di bar input — menunggu dikirim via `↑`.
  Widget _chipLampiran(PlatformFile file) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primaryFixedDim),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.attach_file, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _lampiran = null),
            borderRadius: BorderRadius.circular(999),
            child: const Icon(Icons.close, size: 16, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _presetChip({
    required Color dotColor,
    required String label,
    String? badgeText,
    Color? badgeBg,
    Color? badgeFg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            if (badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg ?? _surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeFg ?? _textVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PESAN CHAT (riwayat 3 State Flow)
  //
  //   Kondisi 2 (teks) : bubble user + Kartu Hasil Analisis AI + kartu XAI.
  //   Kondisi 3 (file) : chip lampiran + tombol unduh + Ringkasan Dataset
  //                      (KPI) + Donut Chart + Insight + Kata Kunci.
  //   Kondisi 1 (awal) : hero + kartu status model + preset (riwayat kosong).
  // =========================================================================
  Widget _buildPesan(_ChatMessage pesan) {
    return Column(
      key: pesan.key, // key stabil per-pesan untuk auto-scroll ke hasil
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Bubbl e user (kanan) ------------------------------------------
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: pesan.teksUser != null
                ? Text(
                    pesan.teksUser!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_file,
                        size: 18,
                        color: AppColors.onPrimary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'File terlampir: ${pesan.namaFile}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // ---- Hasil dari backend (kartu AI / laporan dataset) ---------------
        if (pesan.teksUser != null && pesan.hasil != null) ...[
          _buildHasilSection(pesan.hasil!, latencyMs: pesan.latencyMs),
          const SizedBox(height: 28),
          _buildXaiSection(pesan.hasil!),
        ],

        if (pesan.unggahan != null) ...[
          _buildDatasetSection(pesan.unggahan!),
          const SizedBox(height: 28),
          _buildVisualisasiSection(pesan.unggahan!),
          const SizedBox(height: 28),
          _buildInsightSection(pesan.unggahan!),
          const SizedBox(height: 28),
          _buildKeywordsSection(),
        ],
      ],
    );
  }

  // ===========================================================================
  // SECTION 3: HASIL ANALISIS AI (#hasil-section) — per-pesan (Kondisi 2)
  // ===========================================================================
  Widget _buildHasilSection(Map<String, dynamic> hasil, {int? latencyMs}) {
    // Warna & label mengikuti hasil NYATA dari model (2 kelas:
    // Positif / Negatif) dari respons backend untuk pesan ini.
    final String? tipe = (hasil['label'] as String?)?.toLowerCase();
    final bool adaHasil = tipe != null && tipe.isNotEmpty;

    Color bannerBg = _surfaceContainer;
    Color iconWrapBg = AppColors.primary;
    Color iconFg = AppColors.onPrimary;
    Color accentText = AppColors.primary;
    IconData sentimentIcon = Icons.pending_outlined;
    String labelUpper = 'BELUM ADA';
    double mainPct = 0;
    String confidenceNote = '-';

    // Probabilitas & confidence dihitung dari respons pesan ini
    // (angka NYATA dari backend, bukan state global).
    final double posScore =
        ((hasil['probabilities']?['Positif'] as num?)?.toDouble() ?? 0) * 100;
    final double negScore =
        ((hasil['probabilities']?['Negatif'] as num?)?.toDouble() ?? 0) * 100;

    if (adaHasil && tipe == 'negatif') {
      bannerBg = AppColors.errorContainer.withValues(alpha: 0.7);
      iconWrapBg = AppColors.error;
      iconFg = AppColors.onError;
      accentText = AppColors.error;
      sentimentIcon = Icons.sentiment_very_dissatisfied;
      labelUpper = 'NEGATIF';
      mainPct = negScore;
      confidenceNote = _catatanKeyakinan(mainPct);
    } else if (adaHasil) {
      bannerBg = AppColors.tertiaryFixed.withValues(alpha: 0.6);
      iconWrapBg = AppColors.tertiaryContainer;
      iconFg = AppColors.onTertiaryContainer;
      accentText = AppColors.tertiary;
      sentimentIcon = Icons.sentiment_satisfied;
      labelUpper = 'POSITIF';
      mainPct = posScore;
      confidenceNote = _catatanKeyakinan(mainPct);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _sectionTitle(
                Icons.verified,
                'Hasil Analisis AI',
                color: AppColors.tertiary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _surfaceContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                latencyMs != null ? 'Inferensi $latencyMs ms' : '—',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: _textVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Main Result Card — angka dari respons backend (/api/analyze).
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Class Indicator Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bannerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: iconWrapBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(sentimentIcon, color: iconFg, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'HASIL KLASIFIKASI',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                    color: accentText,
                                  ),
                                ),
                                // Skala turun bila lebar sempit (HP).
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    labelUpper,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: tipe == 'positif'
                                          ? AppColors.onTertiaryFixed
                                          : accentText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${mainPct.toStringAsFixed(1)}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: tipe == 'positif'
                                ? AppColors.onTertiaryFixed
                                : accentText,
                          ),
                        ),
                        Text(
                          confidenceNote,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: accentText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Probability Bars
              Text(
                'Distribusi Probabilitas Kelas',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _probRow('Positif', posScore, AppColors.tertiaryContainer),
              const SizedBox(height: 12),
              _probRow('Negatif', negScore, AppColors.error),
              const SizedBox(height: 16),

              // Contextual Metadata Grid
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _metaCol(
                      'Latency',
                      latencyMs == null ? '—' : '$latencyMs ms',
                    ),
                    _metaCol('Fitur TF-IDF', _vocabTeks),
                    _metaCol('Model', 'SVM Linear'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _probRow(String label, double value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 10,
            width: double.infinity,
            color: _surfaceContainer,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (value / 100).clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaCol(String title, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 4: EXPLAINABLE AI (XAI) (#xai-section) — per-pesan (Kondisi 2)
  // ===========================================================================
  Widget _buildXaiSection(Map<String, dynamic> hasil) {
    final List<InlineSpan> transcriptSpans;
    final List<Widget> chips;
    final InlineSpan rationaleSpan;
    {
      final bool positif = hasil['label'] == 'Positif';
      final String teks = ((hasil['text'] as String?) ?? '').trim();
      final kontribusi = (hasil['top_contributions'] as List?) ?? const [];
      final tokenPenting = <String>{
        for (final c in kontribusi)
          if (c is Map) (c['token'] as String? ?? '').toLowerCase(),
      }..remove('');

      transcriptSpans = _transkripSpans(teks, tokenPenting, positif: positif);

      // Chip kontribusi — tanda +/− mengikuti bobot fitur sesungguhnya.
      Widget chipDari(dynamic c) {
        final double nilai = ((c['contribution'] as num?) ?? 0).toDouble();
        final bool naik = nilai >= 0;
        return _xaiChip(
          naik ? Icons.check_circle : Icons.warning,
          '"${c['token']}" (${naik ? '+' : ''}${nilai.toStringAsFixed(2)})',
          naik ? AppColors.tertiaryFixed : AppColors.errorContainer,
          naik ? AppColors.onTertiaryFixed : AppColors.onErrorContainer,
        );
      }

      chips = [
        for (final c in kontribusi.take(5))
          if (c is Map) chipDari(c),
      ];

      final String alasan =
          (hasil['explanation'] as String?) ?? 'Tidak ada rincian tambahan.';
      rationaleSpan = TextSpan(
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.4,
          color: _textPrimary,
        ),
        children: [
          const TextSpan(text: 'Model mengklasifikasikan ulasan ini sebagai '),
          TextSpan(
            text: positif ? 'Positif' : 'Negatif',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: positif ? AppColors.primary : AppColors.error,
            ),
          ),
          const TextSpan(text: '. '),
          TextSpan(text: alasan),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.visibility, 'Explainable AI (XAI)'),
        const SizedBox(height: 4),
        Text(
          'Kontribusi fitur TF-IDF terhadap margin klasifikasi SVM pada pesan ini:',
          style: GoogleFonts.inter(fontSize: 13, color: _textVariant),
        ),
        const SizedBox(height: 12),

        // XAI Card — selalu berisi hasil pesan ini (Kondisi 2).
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Teks Ulasan & Token Berpengaruh:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.6,
                      color: _textPrimary,
                    ),
                    children: transcriptSpans,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Top Kata Kunci Berpengaruh:',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
              const SizedBox(height: 16),

              // Clinical Rationale Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: RichText(text: rationaleSpan)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  WidgetSpan _highlightSpan(String text, Color bg, Color fg) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }

  Widget _xaiChip(IconData icon, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 5: RINGKASAN DATASET (#dataset-section) — per-pesan (Kondisi 3)
  // ===========================================================================
  Widget _buildDatasetSection(Map<String, dynamic> u) {
    final summary = (u['summary'] as Map?)?.cast<String, dynamic>();
    final report = (u['upload_report'] as Map?)?.cast<String, dynamic>();
    final agreement = (u['agreement'] as Map?)?.cast<String, dynamic>();
    final warning = u['warning'] as String?;
    final namaFile = (u['filename'] as String?) ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tombol unduh — DI ATAS seluruh laporan (sesuai desain).
        _tombolEkspor(
          label: 'Unduh Hasil Analisis (.CSV)',
          url: ApiService.csvUploadReportUrl,
          fallback: 'hasil_unggahan.csv',
          icon: Icons.table_chart_outlined,
        ),
        const SizedBox(height: 16),

        _sectionTitle(Icons.dataset, 'Ringkasan Dataset Ulasan'),
        const SizedBox(height: 4),
        Text(
          'File "$namaFile" · kolom ${u['column_used']} · '
          '${_fmt(summary?['total'])} baris dianalisis.',
          style: GoogleFonts.inter(fontSize: 13, color: _textVariant),
        ),
        const SizedBox(height: 12),

        // 2-Col Stat Grid — angka nyata dari file unggahan.
        // Rasio sel fleksibel: layar sempit (HP) mendapat sel lebih tinggi
        // agar isi kartu tidak overflow vertikal.
        LayoutBuilder(
          builder: (context, c) => GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: c.maxWidth < 480 ? 1.0 : 1.22,
            children: [
              _datasetStatCard(
                icon: Icons.forum,
                iconBg: AppColors.primaryContainer,
                iconFg: AppColors.onPrimaryContainer,
                title: 'Total Baris',
                value: _fmt(summary?['total']),
                valueColor: _textPrimary,
                subtitle: 'Dari file unggahan',
                subtitleColor: AppColors.primary,
              ),
              _datasetStatCard(
                icon: Icons.thumb_up,
                iconBg: AppColors.tertiaryContainer,
                iconFg: AppColors.onTertiaryContainer,
                title: 'Positif',
                value: _fmt(summary?['positif']),
                valueColor: AppColors.tertiary,
                subtitle: '${_persen(summary?['ratio_positif_pct'])} Proporsi',
                subtitleColor: AppColors.tertiary,
              ),
              _datasetStatCard(
                icon: Icons.thumb_down,
                iconBg: AppColors.error,
                iconFg: AppColors.onError,
                title: 'Negatif',
                value: _fmt(summary?['negatif']),
                valueColor: AppColors.error,
                subtitle: '${_persen(summary?['ratio_negatif_pct'])} Proporsi',
                subtitleColor: AppColors.error,
              ),
              _datasetStatCard(
                icon: Icons.speed,
                iconBg: AppColors.secondary,
                iconFg: AppColors.onSecondary,
                title: 'Rata-rata Confidence',
                value: _persen(summary?['avg_confidence'], dariNolSatu: true),
                valueColor: AppColors.secondary,
                subtitle: 'Model SVM Linear',
                subtitleColor: AppColors.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Banner peringatan (kuning) — mis. batas waktu analisis tercapai.
        if (warning != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6D8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEFD98A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber,
                  size: 18,
                  color: Color(0xFF9A7B00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    warning,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.45,
                      color: const Color(0xFF6B5300),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Kesepakatan dengan label acuan (bila file punya kolom label).
        if (agreement != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixed.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 18,
                  color: AppColors.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prediksi model vs label acuan file: '
                    '${_persen(agreement['accuracy_pct'] as num?)} cocok '
                    'pada ${_fmt(agreement['labeled_rows'] as num?)} baris berlabel.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onTertiaryFixed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Tabel Laporan Klasifikasi — baris persis dari `upload_report`.
        if (report != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Laporan Klasifikasi',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                report['labeled'] == true
                    ? 'vs label acuan file'
                    : 'tanpa label acuan',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                _laporanBaris(null, kepala: true),
                const SizedBox(height: 6),
                const Divider(height: 1, color: AppColors.outlineVariant),
                const SizedBox(height: 6),
                for (final r in (report['rows'] as List?) ?? const [])
                  if (r is Map) ...[
                    _laporanBaris(r, kepala: false),
                    const SizedBox(height: 6),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Tombol ekspor PDF — file diunduh langsung dari backend
        // (tombol CSV utama sudah ada di bagian atas laporan).
        _tombolEkspor(
          label: 'Laporan (PDF)',
          url: ApiService.pdfReportUrl,
          fallback: 'laporan_klasifikasi.pdf',
          icon: Icons.picture_as_pdf_outlined,
        ),
        const SizedBox(height: 12),

        // Footer Info Banner — panduan format CSV (selalu tampil).
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Format CSV: satu kolom teks ulasan (content / review / '
                  'ulasan). Kolom score atau label opsional agar prediksi '
                  'bisa dibandingkan dengan label acuan.',
                  style: GoogleFonts.inter(fontSize: 13, color: _textVariant),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Satu baris pada tabel laporan klasifikasi (5 kolom).
  /// precision/recall/F1 tampil sebagai persen; `null` -> '—'.
  Widget _laporanBaris(dynamic baris, {required bool kepala}) {
    Widget sel(String teks, {bool kiri = false, bool tebal = false}) =>
        Expanded(
          child: Text(
            teks,
            textAlign: kiri ? TextAlign.left : TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: tebal ? FontWeight.w700 : FontWeight.w600,
              color: kepala ? _textVariant : _textPrimary,
            ),
          ),
        );

    if (kepala) {
      return Row(
        children: [
          sel('Kelas', kiri: true),
          sel('Precision'),
          sel('Recall'),
          sel('F1'),
          sel('Support'),
        ],
      );
    }

    final map = (baris as Map).cast<String, dynamic>();
    final bool tebal = map['label'] == 'Accuracy';

    String angka(String kunci) {
      final v = map[kunci];
      if (v == null) return '—';
      if (kunci == 'support') return _fmt(v as num);
      return '${((v as num) * 100).toStringAsFixed(1)}%';
    }

    return Row(
      children: [
        sel('${map['label'] ?? '—'}', kiri: true, tebal: tebal),
        sel(angka('precision'), tebal: tebal),
        sel(angka('recall'), tebal: tebal),
        sel(angka('f1_score'), tebal: tebal),
        sel(angka('support'), tebal: tebal),
      ],
    );
  }

  /// Tombol unduh ekspor dari backend (CSV/PDF) dengan status sibuk.
  Widget _tombolEkspor({
    required String label,
    required String url,
    required String fallback,
    required IconData icon,
  }) {
    return InkWell(
      onTap: _busyEkspor ? null : () => _ekspor(url, fallback),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryFixedDim),
        ),
        child: _busyEkspor
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Format persen 1 desimal; [dariNolSatu] mengonversi 0..1 -> persen.
  String _persen(num? v, {bool dariNolSatu = false}) {
    if (v == null) return '—';
    final x = dariNolSatu ? v * 100 : v;
    return '${x.toStringAsFixed(1)}%';
  }

  Widget _datasetStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String title,
    required String value,
    required Color valueColor,
    required String subtitle,
    required Color subtitleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconFg),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textVariant,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 6: VISUALISASI DATA (#visualisasi-section)
  // ===========================================================================
  Widget _buildVisualisasiSection(Map<String, dynamic> u) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.analytics, 'Visualisasi Data Interaktif'),
        const SizedBox(height: 12),

        // Segmented Tab Switcher
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _chartTabBtn('Distribusi', 0),
              _chartTabBtn('Bobot Fitur', 1),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Chart Display Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _selectedChartTab == 0
                ? _buildDonutChartView(u)
                : _buildBobotFiturView(),
          ),
        ),
      ],
    );
  }

  Widget _chartTabBtn(String label, int index) {
    final bool isActive = _selectedChartTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedChartTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? _surfaceLowest : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? AppColors.primary : _textVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonutChartView(Map<String, dynamic> u) {
    final summary = (u['summary'] as Map?)?.cast<String, dynamic>();
    if (summary == null) {
      // Empty state — belum ada file yang diunggah.
      return Column(
        key: const ValueKey('donut'),
        children: [
          const SizedBox(height: 12),
          Icon(Icons.donut_small_outlined, size: 36, color: _textVariant),
          const SizedBox(height: 10),
          Text(
            'Belum ada data untuk ditampilkan',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Unggah dataset CSV — distribusi Positif/Negatif dari file '
            'Anda akan tampil di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: _textVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    final total = (summary['total'] as num?) ?? 0;
    final positif = (summary['positif'] as num?) ?? 0;
    final negatif = (summary['negatif'] as num?) ?? 0;
    final rasioPos = total == 0 ? 0.0 : positif / total;
    final rasioNeg = total == 0 ? 0.0 : negatif / total;

    return Column(
      key: const ValueKey('donut'),
      children: [
        SizedBox(
          width: 192,
          height: 192,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(192, 192),
                painter: _DonutChartPainter(
                  positifRasio: rasioPos.toDouble(),
                  negatifRasio: rasioNeg.toDouble(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fmt(total),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  Text(
                    'Baris',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _textVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Wrap — legend turun baris otomatis di layar sempit (HP).
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            _legendItem(
              AppColors.tertiaryContainer,
              'Positif (${_persen(summary['ratio_positif_pct'] as num?)})',
            ),
            _legendItem(
              AppColors.error,
              'Negatif (${_persen(summary['ratio_negatif_pct'] as num?)})',
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  /// Tab "Bobot Fitur": kata dengan bobot SVM terbesar untuk tiap kelas,
  /// diambil langsung dari /api/model/weights (data nyata, bukan mockup).
  Widget _buildBobotFiturView() {
    final bobot = _bobot;
    if (bobot == null) {
      return Column(
        key: const ValueKey('bobot'),
        children: [
          const SizedBox(height: 12),
          Icon(Icons.bar_chart, size: 36, color: _textVariant),
          const SizedBox(height: 10),
          Text(
            'Bobot fitur belum dimuat',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jalankan backend Klinisia — daftar kata paling berpengaruh '
            'terhadap keputusan model akan tampil di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: _textVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    final positif = ((bobot['positive'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    final negatif = ((bobot['negative'] as List?) ?? const [])
        .whereType<Map>()
        .toList();

    // Skala bar relatif terhadap bobot absolut terbesar.
    double maxAbs = 0;
    for (final w in [...positif, ...negatif]) {
      final a = ((w['abs_weight'] as num?) ?? 0).toDouble();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs <= 0) maxAbs = 1;

    Widget baris(Map w, {required bool kelasPositif}) {
      final kata = (w['word'] as String?) ?? '—';
      final nilai = ((w['weight'] as num?) ?? 0).toDouble();
      final abs = ((w['abs_weight'] as num?) ?? nilai.abs()).toDouble();
      return _serviceBar(
        kata,
        (abs / maxAbs).clamp(0.0, 1.0),
        kelasPositif ? AppColors.tertiaryContainer : AppColors.error,
        kelasPositif ? AppColors.tertiary : AppColors.error,
        '${nilai > 0 ? '+' : ''}${nilai.toStringAsFixed(3)}',
      );
    }

    List<Widget> deret(List<Map> daftar, {required bool kelasPositif}) => [
      for (var i = 0; i < daftar.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        baris(daftar[i], kelasPositif: kelasPositif),
      ],
    ];

    return Column(
      key: const ValueKey('bobot'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kata pendorong kelas Positif',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.tertiary,
          ),
        ),
        const SizedBox(height: 16),
        ...deret(positif, kelasPositif: true),
        const SizedBox(height: 20),
        Text(
          'Kata pendorong kelas Negatif',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: 16),
        ...deret(negatif, kelasPositif: false),
        const SizedBox(height: 14),
        Text(
          'Sumber: bobot fitur SVM Linear dari /api/model/weights.',
          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: _textVariant),
        ),
      ],
    );
  }

  /// Bar horizontal: [factor] 0..1 menentukan panjang bar.
  Widget _serviceBar(
    String title,
    double factor,
    Color barColor,
    Color textColor,
    String nilai,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              nilai,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 12,
            width: double.infinity,
            color: _surfaceContainer,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SECTION 7: AI INSIGHT & REKOMENDASI (#insight-section)
  // ===========================================================================
  Widget _buildInsightSection(Map<String, dynamic> u) {
    final summary = (u['summary'] as Map?)?.cast<String, dynamic>();
    final agreement = (u['agreement'] as Map?)?.cast<String, dynamic>();
    final m = _infoModel?['metrics'];
    final metrik = m is Map ? m.cast<String, dynamic>() : null;

    // Kata dengan bobot terbesar dari /api/model/weights.
    String? kataPertama(List? l) {
      if (l == null || l.isEmpty || l.first is! Map) return null;
      final w = (l.first as Map)['word'];
      return w is String && w.isNotEmpty ? w : null;
    }

    final kataPos = kataPertama((_bobot?['positive'] as List?) ?? const []);
    final kataNeg = kataPertama((_bobot?['negative'] as List?) ?? const []);

    final cards = <Widget>[];

    if (summary != null) {
      cards.add(
        _insightCard(
          bg: AppColors.tertiaryFixed.withValues(alpha: 0.3),
          iconBg: AppColors.tertiaryContainer,
          iconFg: AppColors.onTertiaryContainer,
          icon: Icons.verified_user,
          tag: 'DISTRIBUSI KLASIFIKASI FILE UNGGAHAN',
          tagColor: AppColors.tertiary,
          body: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
            children: [
              const TextSpan(text: 'Dari '),
              TextSpan(
                text: '${_fmt(summary['total'])} baris',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' ulasan yang dianalisis, '),
              TextSpan(
                text:
                    '${_persen(summary['ratio_positif_pct'] as num?)} terklasifikasi Positif',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    ' dan ${_persen(summary['ratio_negatif_pct'] as num?)} Negatif '
                    '(rata-rata confidence ${_persen(summary['avg_confidence'] as num?, dariNolSatu: true)}).',
              ),
            ],
          ),
        ),
      );
    }

    if (agreement != null) {
      cards.add(
        _insightCard(
          bg: AppColors.primaryFixed.withValues(alpha: 0.3),
          iconBg: AppColors.primaryContainer,
          iconFg: AppColors.onPrimaryContainer,
          icon: Icons.fact_check,
          tag: 'VALIDASI TERHADAP LABEL ACUAN',
          tagColor: AppColors.primary,
          body: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
            children: [
              const TextSpan(
                text: 'Prediksi model cocok dengan label acuan pada ',
              ),
              TextSpan(
                text:
                    '${_fmt(agreement['labeled_rows'] as num?)} baris berlabel',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    ' (${_persen(agreement['accuracy_pct'] as num?)}). ${agreement['note'] ?? ''}',
              ),
            ],
          ),
        ),
      );
    }

    if (metrik != null) {
      final latih = (_infoModel?['training_samples'] as num?)?.toInt();
      cards.add(
        _insightCard(
          bg: AppColors.secondaryFixed.withValues(alpha: 0.35),
          iconBg: AppColors.secondaryContainer,
          iconFg: AppColors.onSecondaryContainer,
          icon: Icons.smart_toy,
          tag: 'MODEL SVM YANG AKTIF',
          tagColor: AppColors.secondary,
          body: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
            children: [
              const TextSpan(text: 'Model terlatih mencapai akurasi hold-out '),
              TextSpan(
                text: _persen(metrik['accuracy'] as num?),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text:
                    ' dengan F1-weighted ${_persen(metrik['f1_score'] as num?)} '
                    'pada ${_fmt(metrik['test_size'] as num?)} baris uji',
              ),
              if (latih != null) TextSpan(text: ' dari $latih sampel latih'),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      );
    }

    if (kataPos != null && kataNeg != null) {
      cards.add(
        _insightCard(
          bg: AppColors.errorContainer.withValues(alpha: 0.4),
          iconBg: AppColors.error,
          iconFg: AppColors.onError,
          icon: Icons.priority_high,
          tag: 'KATA PENDORONG UTAMA MODEL',
          tagColor: AppColors.error,
          body: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
            children: [
              const TextSpan(text: 'Kontributor positif terkuat: '),
              TextSpan(
                text: '"$kataPos"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ', sedangkan penarik ke kelas Negatif terkuat: ',
              ),
              TextSpan(
                text: '"$kataNeg"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' berdasarkan bobot fitur SVM.'),
            ],
          ),
        ),
      );
    }

    if (cards.isEmpty) {
      cards.add(
        _insightCard(
          bg: _surfaceContainer,
          iconBg: AppColors.primaryContainer,
          iconFg: AppColors.onPrimaryContainer,
          icon: Icons.info_outline,
          tag: 'MENUNGGU DATA',
          tagColor: AppColors.primary,
          body: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: _textPrimary),
            children: const [
              TextSpan(
                text:
                    'Jalankan backend Klinisia dan unggah file CSV — ringkasan '
                    'klasifikasi, validasi label, serta kata pendorong model '
                    'akan muncul otomatis di sini.',
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.auto_awesome, 'Insight Otomatisasi AI Klinisia'),
        const SizedBox(height: 4),
        Text(
          'Ringkasan otomatis dari file unggahan, metrik model, dan bobot fitur SVM.',
          style: GoogleFonts.inter(fontSize: 13, color: _textVariant),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }

  Widget _insightCard({
    required Color bg,
    required Color iconBg,
    required Color iconFg,
    required IconData icon,
    required String tag,
    required Color tagColor,
    required InlineSpan body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: iconFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: tagColor,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(text: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 8: TOP KEYWORDS (#keywords-section)
  // ===========================================================================
  Widget _buildKeywordsSection() {
    final bobot = _bobot;
    final positif = ((bobot?['positive'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    final negatif = ((bobot?['negative'] as List?) ?? const [])
        .whereType<Map>()
        .toList();

    List<Widget> pills(List<Map> daftar, {required bool kelasPositif}) => [
      for (var i = 0; i < daftar.length; i++)
        _ngramPill(
          '#${i + 1} ${daftar[i]['word'] ?? '—'}',
          '(${((daftar[i]['weight'] as num?) ?? 0).toStringAsFixed(3)})',
          kelasPositif
              ? (i < 3 ? AppColors.tertiaryFixed : AppColors.tertiaryFixedDim)
              : (i < 3
                    ? AppColors.errorContainer
                    : AppColors.errorContainer.withValues(alpha: 0.7)),
          kelasPositif ? AppColors.onTertiaryFixed : AppColors.onErrorContainer,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.spellcheck, 'Analisis Kata Kunci Teratas'),
        const SizedBox(height: 4),
        Text(
          'Kata dengan bobot fitur SVM tertinggi — semakin besar bobot, '
          'semakin menentukan keputusan klasifikasi.',
          style: GoogleFonts.inter(fontSize: 13, color: _textVariant),
        ),
        const SizedBox(height: 12),

        if (bobot == null || (positif.isEmpty && negatif.isEmpty))
          // Empty state — bobot belum termuat.
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_off_outlined, size: 36, color: _textVariant),
                const SizedBox(height: 10),
                Text(
                  'Bobot fitur belum dimuat',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nyalakan backend Klinisia — kata pendorong Positif & Negatif '
                  'akan tampil di sini.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: _textVariant,
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Positive Keywords Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.thumb_up,
                            size: 20,
                            color: AppColors.tertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'TOP KATA POSITIF',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${positif.length} Fitur Teratas',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: _textVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pills(positif, kelasPositif: true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Negative Keywords Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.thumb_down,
                            size: 20,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'TOP KATA NEGATIF',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${negatif.length} Fitur Teratas',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: _textVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: pills(negatif, kelasPositif: false),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _ngramPill(String word, String count, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
          children: [
            TextSpan(text: '$word '),
            TextSpan(
              text: count,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 10: FOOTER
  // ===========================================================================
  Widget _buildFooterSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida/ALJJyrCRjy7xvm3kT_QgnwXYBeFHAI4S52xxSD2o_ns8CzLenM87LJJA8wTd486OJDdxfyhQ84MfLOrjM-u-xhdQgyOTM-BgAarubS4ehu2mGxuHt9ogtGoUaNbEp0i5A6xaf0vLd_Newyt5YuRu1ol72m43Ynx2aKayN8x86oSllEyyxVgqWl7A-asmR51_4vLufYhahJHUpw-eXTAGltBPd8xNBYlCDK6amzC8oFe6K2xBiQ',
                  height: 40,
                  width: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    height: 40,
                    width: 40,
                    color: AppColors.primary,
                    child: const Icon(
                      Icons.local_hospital,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Klinisia AI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    Text(
                      'Healthcare Sentiment Intelligence',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _textVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Text(
              'Aplikasi analisis sentimen ulasan pengguna Klinisia — klasifikasi '
              'otomatis menjadi sentimen Positif & Negatif secara real-time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _textVariant),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              _codeTag('Python 3.11', _surfaceContainer, _textPrimary),
              _codeTag('FastAPI', _surfaceContainer, _textPrimary),
              _codeTag('Flutter Dart', _surfaceContainer, _textPrimary),
              _codeTag('Scikit-learn 1.6', _surfaceContainer, _textPrimary),
              _codeTag(
                'SVM Linear + TF-IDF',
                AppColors.primaryFixed,
                AppColors.onPrimaryFixedVariant,
                bold: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Klasifikasi Sentimen Ulasan • Dibangun dengan Machine Learning',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hak Cipta © 2025 Klinisia AI. All rights reserved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // (Bottom nav lama DIHAPUS — diganti input bar melayang `_buildFloatingInputBar`.)
  // ===========================================================================
}

// =============================================================================
// MODEL SATU PESAN CHAT (riwayat 3 State Flow)
//
//   teks()     -> Kondisi 2: bubble teks + hasil analisis + XAI.
//   dataset()  -> Kondisi 3: chip lampiran + laporan dataset lengkap.
// =============================================================================
class _ChatMessage {
  _ChatMessage.teks({
    required this.teksUser,
    required this.hasil,
    required this.latencyMs,
  }) : unggahan = null,
       namaFile = null;

  _ChatMessage.dataset({required this.namaFile, required this.unggahan})
    : teksUser = null,
      hasil = null,
      latencyMs = null;

  /// Teks yang dikirim user (null untuk pesan lampiran file).
  final String? teksUser;

  /// Respons /api/analyze untuk pesan teks (label, probabilities, XAI).
  final Map<String, dynamic>? hasil;

  /// Respons /api/analyze/csv untuk pesan file (summary, upload_report,
  /// agreement, export URL) — semua angka dari backend.
  final Map<String, dynamic>? unggahan;

  /// Nama file lampiran (Kondisi 3).
  final String? namaFile;

  /// Waktu tunggu respons teks dalam milidetik.
  final int? latencyMs;

  /// Penanda unik untuk GlobalKey per-pesan (auto-scroll ke hasil).
  static int _counter = 0;
  final int id = _counter++;

  /// Key widget pesan — dipakai `_gulirKePesan` untuk menemukan posisi
  /// bubble + kartu hasil di dalam stream chat.
  final GlobalKey key = GlobalKey(debugLabel: 'pesan');
}

// =============================================================================
// CUSTOM PAINTER 1: DONUT CHART (Positif vs Negatif — rasio data unggahan)
// =============================================================================
class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.positifRasio, required this.negatifRasio});

  /// Rasio kelas (0..1) dari data unggahan — tanpa angka hardcoded.
  final double positifRasio;
  final double negatifRasio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 18;
    const strokeWidth = 26.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const startAngle = -math.pi / 2;
    final posSweep = 2 * math.pi * positifRasio.clamp(0.0, 1.0);
    final negSweep = 2 * math.pi * negatifRasio.clamp(0.0, 1.0);

    // Positif
    paint.color = AppColors.tertiaryContainer;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      posSweep,
      false,
      paint,
    );

    // Negatif
    paint.color = AppColors.error;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + posSweep,
      negSweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.positifRasio != positifRasio ||
      oldDelegate.negatifRasio != negatifRasio;
}
