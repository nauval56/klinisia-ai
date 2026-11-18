# aplikasi_klinisia

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Menjalankan di HP Android fisik

HP dan komputer harus terhubung ke jaringan Wi-Fi yang sama. Backend harus
menerima koneksi dari jaringan, bukan hanya dari `localhost`. Dari folder
`backend`, jalankan:

```powershell
$env:KLINISIA_HOST = "0.0.0.0"
python run.py
```

Cari alamat IPv4 komputer dengan `ipconfig`, lalu jalankan aplikasi dari folder
Flutter dengan alamat tersebut:

```powershell
flutter run -d <ID-PERANGKAT> --dart-define=KLINISIA_API=http://<IP-LAN-PC>:8000
```

Ganti `<ID-PERANGKAT>` dan `<IP-LAN-PC>` sesuai perangkat dan alamat IPv4
komputer. Jika diminta oleh Windows Firewall, izinkan koneksi masuk untuk
backend pada jaringan privat. HTTP tanpa enkripsi hanya diizinkan untuk build
debug; gunakan HTTPS untuk deployment.
