// Smoke test sederhana untuk aplikasi Klinisia AI (UI satu halaman).
//
// Catatan: aplikasi memanggil backend saat startup. Pada environment test
// bawaan flutter_test semua request HTTP dijawab 400, sehingga aplikasi
// menampilkan status offline dengan gagah — test ini hanya memastikan UI
// utama tetap terbangun tanpa angka contoh bawaan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aplikasi_klinisia/main.dart';

void main() {
  testWidgets('dashboard Klinisia terbangun dan menampilkan judul hero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KlinisiaAiApp());
    // Animasi pulse header berjalan terus-menerus, jadi majukan clock
    // dengan pump berjangka (pumpAndSettle tidak akan pernah selesai).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Badge hero + judul aplikasi (header atas & footer).
    expect(
      find.text('AI Healthtech Intelligence • Analisis Sentimen NLP'),
      findsOneWidget,
    );
    expect(find.text('Klinisia AI'), findsOneWidget);

    // Input bar melayang (kapsul teks + `+` lampirkan file + `↑` kirim).
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // Belum ada data — section hasil & dataset BELUM muncul sama sekali,
    // sehingga tampilan awal fokus ke input (tanpa angka contoh bawaan).
    expect(find.text('HASIL KLASIFIKASI'), findsNothing);
    expect(find.text('Ringkasan Dataset Ulasan'), findsNothing);
    expect(find.text('POSITIF'), findsNothing);
    expect(find.text('Laporan Klasifikasi'), findsNothing);
  });
}
