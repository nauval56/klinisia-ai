"""Generator PDF laporan ringkasan Klinisia (hand-rolled, tanpa dependensi berat).

Sengaja tanpa reportlab/weasyprint agar ringan dan mudah diinstal. Konten
disusun dari daftar "blok" (dict) sehingga hasil PDF rapi dan enak dipandang:

- judul halaman + judul bagian tampil tebal berwarna navy dengan garis
  pemisah;
- baris "label: nilai" disejajarkan pada kolom tetap (titik dua tidak lagi
  bergeser-tebak seperti saat menulis spasi manual);
- tabel laporan klasifikasi memakai posisi kolom tetap, kepala berlatar biru
  muda, dan baris zebra berselang-seling;
- analisis teks tampil sebagai butir bernomor dengan indentasi rapi;
- halaman A4 berlipat otomatis (page break) dengan footer + nomor halaman
  di setiap halaman.
"""
from __future__ import annotations

import textwrap
from datetime import datetime

# --- Geometri halaman A4 (satuan point) ---
PAGE_W, PAGE_H = 595, 842
MARGIN_L = 50
CONTENT_R = PAGE_W - 50  # batas kanan teks (545)
TOP_Y = 762              # posisi awal konten halaman pertama
BOTTOM_Y = 66            # batas bawah konten (di atas footer)
FOOTER_Y = 36
VALUE_X = 175            # kolom nilai pada baris label/nilai
ITEM_X = 78              # teks butir setelah nomor urut

# Warna (RGB 0..1) selaras dengan tema web Klinisia.
_NAVY = "0.027 0.325 0.780"   # navy  #0753C7
_INK = "0.067 0.094 0.153"    # ink   #111827
_MUTED = "0.412 0.451 0.525"  # muted #697386
_RULE = "0.906 0.922 0.953"   # line  #E7EBF3
_HEAD_BG = "0.918 0.945 1.0"  # paleBlue #EAF1FF
_ZEBRA = "0.973 0.980 0.996"  # #F8FAFE


def _esc(text: str) -> str:
    """Escape karakter khusus untuk string PDF (tanda kurung & backslash)."""
    return (
        str(text)
        .replace("\\", r"\\")
        .replace("(", r"\(")
        .replace(")", r"\)")
    )


def _txt(text) -> str:
    """Siapkan teks: rapikan karakter tipografi lalu escape untuk PDF."""
    s = str(text)
    # Ganti karakter non-ASCII yang mungkin muncul (kutip, elipsis, dll.)
    # agar aman di-encode latin-1 dan tidak menjadi kotak/karakter aneh.
    for src, dst in {
        "\u2018": "'",
        "\u2019": "'",
        "\u201c": '"',
        "\u201d": '"',
        "\u2013": "-",
        "\u2014": "-",
        "\u2026": "...",
        "\u2192": "->",
        "\u2022": "-",
        "\u00b7": "-",
        "\u00a0": " ",
    }.items():
        s = s.replace(src, dst)
    return _esc(s.encode("latin-1", errors="replace").decode("latin-1"))


def _wrap(text: str, size: float, width: float) -> list[str]:
    """Bungkus teks sesuai lebar kolom (perkiraan lebar Helvetica 0.5em)."""
    chars = max(8, int(width / (size * 0.5)))
    return textwrap.wrap(str(text), width=chars) or [""]


class _Canvas:
    """Penyusun operasi gambar per halaman dengan page-break otomatis."""

    def __init__(self, title: str):
        self.title = title
        self.pages: list[list[str]] = [[]]
        self.y = TOP_Y
        # Halaman pertama: judul besar + garis pemisah navy.
        self._put(self._text(16, _NAVY, MARGIN_L, TOP_Y, title, bold=True))
        self._put(f"0.8 w {_NAVY} RG {MARGIN_L} {TOP_Y - 10} m "
                  f"{CONTENT_R} {TOP_Y - 10} l S")
        self.y = TOP_Y - 34

    # --- Dasar ---
    def _put(self, op: str) -> None:
        self.pages[-1].append(op)

    @staticmethod
    def _text(size: float, color: str, x: float, y: float, text: str,
              bold: bool = False, italic: bool = False) -> str:
        font = "/F2" if bold else ("/F3" if italic else "/F1")
        # Warna di-set di luar BT...ET agar selalu sah menurut spesifikasi.
        return (f"{color} rg BT {font} {size} Tf {x:g} {y:g} Td "
                f"({_txt(text)}) Tj ET")

    def new_page(self) -> None:
        """Mulai halaman baru dengan kepala halaman lanjutan."""
        self.pages.append([])
        judul = self.title if len(self.title) <= 70 else self.title[:67] + "..."
        self._put(self._text(9, _MUTED, MARGIN_L, TOP_Y, judul))
        self._put(f"0.5 w {_RULE} RG {MARGIN_L} {TOP_Y - 6} m "
                  f"{CONTENT_R} {TOP_Y - 6} l S")
        self.y = TOP_Y - 24

    def need(self, height: float) -> None:
        """Pindah halaman bila sisa ruang vertikal tidak cukup."""
        if self.y - height < BOTTOM_Y:
            self.new_page()

    # --- Blok konten ---
    def heading(self, text: str) -> None:
        """Judul bagian: tebal navy + garis pemisah tipis."""
        self.need(34)
        self.y -= 2
        self._put(self._text(11, _NAVY, MARGIN_L, self.y, text, bold=True))
        self.y -= 5
        self._put(f"0.6 w {_RULE} RG {MARGIN_L} {self.y} m "
                  f"{CONTENT_R} {self.y} l S")
        self.y -= 13

    def kv(self, label: str, value: str) -> None:
        """Baris label: nilai — label tebal di kolom kiri, nilai rata kolom."""
        parts = _wrap(value, 10, CONTENT_R - VALUE_X)
        self.need(14 * len(parts))
        for i, part in enumerate(parts):
            if i == 0:
                self._put(self._text(10, _INK, MARGIN_L, self.y, label,
                                     bold=True))
            self._put(self._text(10, _INK, VALUE_X, self.y, part))
            self.y -= 14

    def text(self, value: str, size: float = 10, color: str = _INK,
             indent: float = 0) -> None:
        """Paragraf biasa (dibungkus otomatis agar tidak keluar halaman)."""
        parts = _wrap(value, size, CONTENT_R - MARGIN_L - indent)
        self.need((size + 4) * len(parts))
        for part in parts:
            self._put(self._text(size, color, MARGIN_L + indent, self.y, part))
            self.y -= size + 4

    def item(self, index: int, value: str) -> None:
        """Butir bernomor: nomor di kiri, teks hasil rapi di sebelahnya."""
        parts = _wrap(value, 9.5, CONTENT_R - ITEM_X)
        self.need(13 * len(parts))
        for i, part in enumerate(parts):
            if i == 0:
                self._put(self._text(9.5, _MUTED, MARGIN_L, self.y,
                                     f"{index}."))
            self._put(self._text(9.5, _INK, ITEM_X, self.y, part))
            self.y -= 13

    def table(self, header: list[str], rows: list[list[str]]) -> None:
        """Tabel dengan posisi kolom tetap + kepala berlatar + zebra."""
        # Posisi kolom kiri tetap agar angka sejajar di semua baris.
        xs = [MARGIN_L, 215, 315, 415, 505]
        head_h, row_h, gap = 16, 14, 10
        total = head_h + row_h * len(rows) + gap
        # Usahakan tabel mulai pada ruang lega; bila sangat panjang,
        # potong per baris dan ulangi kepala kolom di halaman berikutnya.
        self.need(min(total, 200))

        def head(top: float) -> None:
            w = CONTENT_R - (MARGIN_L - 4)
            self._put(f"{_HEAD_BG} rg {MARGIN_L - 4} {top - head_h:g} "
                      f"{w:g} {head_h} re f")
            for x, h in zip(xs, header):
                self._put(self._text(9, _NAVY, x, top - head_h + 4.5, h,
                                     bold=True))

        head(self.y)
        self.y -= head_h
        for i, row in enumerate(rows):
            if self.y - row_h < BOTTOM_Y:
                self.new_page()
                head(self.y)
                self.y -= head_h
            if i % 2 == 1:  # zebra selang-seling seperti tampilan web
                w = CONTENT_R - (MARGIN_L - 4)
                self._put(f"{_ZEBRA} rg {MARGIN_L - 4} {self.y - row_h:g} "
                          f"{w:g} {row_h} re f")
            for x, cell in zip(xs, row):
                self._put(self._text(9, _INK, x, self.y - row_h + 4.5, cell))
            self.y -= row_h
        self.y -= gap

    def spacer(self, height: float) -> None:
        self.need(height)
        self.y -= height

    def finish(self, footer: str, stamp: str) -> list[bytes]:
        """Tutup setiap halaman dengan identitas + nomor halaman."""
        total = len(self.pages)
        streams: list[bytes] = []
        for i, ops in enumerate(self.pages, start=1):
            ops.append(self._text(8, _MUTED, MARGIN_L, FOOTER_Y,
                                  f"{footer} - dibuat {stamp}", italic=True))
            no = f"Halaman {i} dari {total}"
            ops.append(self._text(8, _MUTED, CONTENT_R - len(no) * 4, FOOTER_Y,
                                  no, italic=True))
            streams.append("\n".join(ops).encode("latin-1", errors="replace"))
        return streams


def _assemble(page_streams: list[bytes]) -> bytes:
    """Susun objek PDF: Catalog, Pages multi-halaman, Page+Contents, font."""
    n = len(page_streams)
    font_base = 3 + 2 * n  # id objek font: F1, F2, F3
    objects: list[bytes | None] = [None] * (2 + 2 * n + 3)

    kids = b" ".join(b"%d 0 R" % (3 + 2 * i) for i in range(n))
    objects[0] = b"<< /Type /Catalog /Pages 2 0 R >>"
    objects[1] = b"<< /Type /Pages /Kids [%s] /Count %d >>" % (kids, n)
    for i, stream in enumerate(page_streams):
        objects[2 + 2 * i] = (
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %d %d] "
            b"/Resources << /Font << /F1 %d 0 R /F2 %d 0 R /F3 %d 0 R >> >> "
            b"/Contents %d 0 R >>"
            % (PAGE_W, PAGE_H, font_base, font_base + 1, font_base + 2,
               4 + 2 * i)
        )
        objects[3 + 2 * i] = (
            b"<< /Length %d >>\nstream\n%s\nendstream" % (len(stream), stream)
        )
    objects[2 + 2 * n] = b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    objects[2 + 2 * n + 1] = (
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>"
    )
    objects[2 + 2 * n + 2] = (
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >>"
    )

    # Susun bytes PDF: header + xref + trailer (id objek = indeks + 1).
    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets: list[int] = []
    for i, obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n%s\nendobj\n" % (i, obj)

    xref_pos = len(out)
    out += b"xref\n0 %d\n" % (len(objects) + 1)
    out += b"0000000000 65535 f \n"
    for off in offsets:
        out += b"%010d 00000 n \n" % off
    out += (
        b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n"
        % (len(objects) + 1, xref_pos)
    )
    return bytes(out)


def build_summary_pdf(
    *,
    title: str,
    blocks: list[dict],
    footer: str = "Klinisia AI - Analisis Sentimen Ulasan Play Store",
) -> bytes:
    """Susun PDF berhalaman dari daftar blok konten.

    Parameter
    ---------
    title  : judul halaman pertama (halaman lanjutan memakai judul kecil).
    blocks : daftar blok konten. Jenis yang didukung:
             {"kind": "heading", "text": str}        judul bagian
             {"kind": "kv", "label", "value": str}   baris label: nilai
             {"kind": "text", "text": str}           paragraf biasa
             {"kind": "item", "index": int, "text"}  butir bernomor
             {"kind": "table", "header": [...],      tabel kolom tetap
              "rows": [[str, ...], ...]}
             {"kind": "spacer", "height": float}     jarak antar bagian
    footer : teks kaki halaman.

    Mengembalikan bytes isi file PDF (A4, bisa lebih dari satu halaman).
    """
    stamp = datetime.now().strftime("%d/%m/%Y %H:%M")
    canvas = _Canvas(title)

    for block in blocks:
        kind = block.get("kind")
        if kind == "heading":
            canvas.heading(str(block.get("text", "")))
        elif kind == "kv":
            canvas.kv(str(block.get("label", "")), str(block.get("value", "")))
        elif kind == "text":
            canvas.text(str(block.get("text", "")))
        elif kind == "item":
            canvas.item(int(block.get("index", 0)),
                        str(block.get("text", "")))
        elif kind == "table":
            header = [str(h) for h in (block.get("header") or [])]
            rows = [[str(c) for c in row]
                    for row in (block.get("rows") or [])]
            canvas.table(header, rows)
        elif kind == "spacer":
            canvas.spacer(float(block.get("height", 6)))

    return _assemble(canvas.finish(footer, stamp))
