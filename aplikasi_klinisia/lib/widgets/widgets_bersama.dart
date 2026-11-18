// Widget & warna bersama untuk tiga halaman aplikasi Klinisia:
// 1) main.dart (halaman pertama), 2) Halaman Ringkasan Dataset,
// 3) Halaman Hasil Sentimen. Karena dipakai lintas-file, kelas dan
// konstanta di sini bersifat publik (tanpa underscore).
import 'package:flutter/material.dart';
const Color navy = Color(0xFF0753C7);
const Color blue = Color(0xFF0B57D0);
const Color paleBlue = Color(0xFFEAF1FF);
const Color pageBg = Color(0xFFF7F8FD);
const Color green = Color(0xFF00B982);
const Color red = Color(0xFFD90D12);
const Color ink = Color(0xFF111827);
const Color muted = Color(0xFF697386);
const Color line = Color(0xFFE7EBF3);

/// Layar HP = sisi terpendek < 560 logical pixel (portrait ATAU
/// landscape). Dipakai agar header/tombol membesar nyaman disentuh
/// jari, sementara desktop tetap tampil ringkas seperti semula.
bool layarHp(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  final pendek = s.width < s.height ? s.width : s.height;
  return pendek < 560;
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? badge;
  final IconData? icon;
  const SectionHeading(this.title, {this.badge, this.icon, super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: navy),
              const SizedBox(width: 4),
            ] else ...[
              Container(width: 4, height: 4, decoration: const BoxDecoration(color: navy, shape: BoxShape.circle)),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 9.5, color: ink, fontWeight: FontWeight.w700)),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(color: paleBlue, borderRadius: BorderRadius.circular(4)),
                child: Text(badge!, style: const TextStyle(fontSize: 6, color: Color(0xFF5C6680))),
              ),
          ],
        ),
      );
}

class TinyBadge extends StatelessWidget {
  final String text;
  const TinyBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF1F4FA), borderRadius: BorderRadius.circular(3)),
        child: Text(text, style: const TextStyle(fontSize: 5.7, color: Color(0xFF657087))),
      );
}

class WeightRow extends StatelessWidget {
  final String word, value;
  final double progress;
  final Color color;
  const WeightRow({required this.word, required this.value, required this.progress, required this.color, super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Text(word, style: const TextStyle(fontSize: 6.5, color: Color(0xFF4B5563))),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 6.5, color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2.5,
              backgroundColor: const Color(0xFFEDF0F5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      );
}

/// Header halaman hasil: tombol kembali + judul.
/// Di HP area sentuh & teks diperbesar agar nyaman disentuh jari.
class PageHeader extends StatelessWidget {
  final String title;
  const PageHeader({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    final hp = layarHp(context);
    return Container(
      height: hp ? 46 : 35,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: line, width: .7)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            child: Padding(
              // Area sentuh tombol kembali: 44px di HP (standar mobile).
              padding: EdgeInsets.all(hp ? 14 : 4),
              child: Icon(Icons.arrow_back, size: hp ? 18 : 11, color: ink),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: hp ? 13 : 9,
                    fontWeight: FontWeight.w800,
                    color: ink)),
          ),
          const Icon(Icons.smart_toy_outlined, size: 9, color: navy),
          const SizedBox(width: 3),
          const Text('Klinisia AI',
              style: TextStyle(fontSize: 6, color: muted)),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    final hp = layarHp(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: hp ? 10 : 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line, width: .7)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medical_services_outlined,
                  size: hp ? 9 : 7, color: navy),
              const SizedBox(width: 4),
              Text('Klinisia AI · Analisis Sentimen Ulasan Play Store',
                  style: TextStyle(
                      fontSize: hp ? 8.5 : 5.8,
                      color: const Color(0xFF657087))),
            ],
          ),
          const SizedBox(height: 4),
          Text('SVM Linear + TF-IDF · Klasifikasi Positif/Negatif · v1.2',
              style: TextStyle(
                  fontSize: hp ? 8 : 5.5, color: const Color(0xFF9AA2B1))),
        ],
      ),
    );
  }
}
