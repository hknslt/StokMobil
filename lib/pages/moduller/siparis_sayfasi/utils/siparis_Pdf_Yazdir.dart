import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:capri/core/models/siparis_model.dart';

Future<void> siparisPdfYazdir(SiparisModel siparis) async {
  // Türkçe karakterler için fontları yükle
  final baseFontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final baseFont = pw.Font.ttf(baseFontData);
  final boldFont = pw.Font.ttf(boldFontData);

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
  );

  final tarihFormatter = DateFormat('dd.MM.yyyy');

  // Veriler
  final urunler = siparis.urunler;
  const int firstPageMaxRows = 30;
  final int firstCount = urunler.length <= firstPageMaxRows ? urunler.length : firstPageMaxRows;
  final List remaining = urunler.length > firstCount ? urunler.sublist(firstCount) : const [];

  final toplamUrunAdedi = urunler.fold<int>(0, (sum, u) => sum + u.adet);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),

      // Footer: sadece SON sayfada toplam ve alt bilgiler
      footer: (context) {
        final isLast = context.pageNumber == context.pagesCount;
        if (!isLast) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text("Sayfa ${context.pageNumber}/${context.pagesCount}",
                style: const pw.TextStyle(color: PdfColors.grey700)),
          );
        }
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    _cellPad("TOPLAM"),
                    _cellPad(""),
                    _cellPad(""),
                    _cellPad("$toplamUrunAdedi"),
                    _cellPad(""),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Sevk Tarihi: ${siparis.islemeTarihi != null ? tarihFormatter.format(siparis.islemeTarihi!) : ''}"),
                pw.Text("KDV (%):"), // İstersen burada dinamik KDV yazdır
                pw.Text("Teslim Tarihi:"),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text("Sayfa ${context.pageNumber}/${context.pagesCount}",
                  style: const pw.TextStyle(color: PdfColors.grey700)),
            ),
          ],
        );
      },

      build: (context) => [
        // Başlık (sadece ilk sayfa içeriğinde; MultiPage otomatik kıracak)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "SEVKİYAT FİŞİ",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text("Sevkiyat Tarihi: ${siparis.islemeTarihi != null ? tarihFormatter.format(siparis.islemeTarihi!) : ''}"),
          ],
        ),
        pw.SizedBox(height: 10),

        // Müşteri Bilgileri (ilk sayfada yer alır)
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              children: [
                _cellPad("Firma Adı: ${siparis.musteri.firmaAdi ?? ''}"),
                _cellPad("Yetkili: ${siparis.musteri.yetkili ?? ''}"),
              ],
            ),
            pw.TableRow(
              children: [
                _cellPad("İletişim: ${siparis.musteri.telefon ?? ''}"),
                _cellPad("Teslimat Adresi: ${siparis.musteri.adres ?? ''}"),
              ],
            ),
            pw.TableRow(
              children: [
                _cellPad("Fatura Bilgileri: ${siparis.musteri.firmaAdi ?? ''}"),
                _cellPad("Not: ${siparis.aciklama ?? ''}"),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        // --- İlk sayfanın tablosu (en fazla 30 satır) ---
        _urunTablosu(
          baslikSatiri: true,
          urunler: urunler.take(firstCount).toList(),
        ),

        // --- Kalanlar varsa yeni sayfadan devam et ---
        if (remaining.isNotEmpty) pw.SizedBox(height: 100000), // sayfa sonunu zorlar


        
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
}

// ---------- Yardımcılar ----------

pw.Widget _urunTablosu({
  required bool baslikSatiri,
  required List urunler,
}) {
  final rows = <pw.TableRow>[];

  if (baslikSatiri) {
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _headerCell("NO"),
          _headerCell("MODEL"),
          _headerCell("RENK"),
          _headerCell("ADET"),
          _headerCell("AÇIKLAMA"),
        ],
      ),
    );
  }

  for (var i = 0; i < urunler.length; i++) {
    final u = urunler[i];
    rows.add(
      pw.TableRow(
        children: [
          _cellPad("${i + 1}"),
          _cellPad(u.urunAdi),
          _cellPad(u.renk ?? ""),
          _cellPad("${u.adet}"),
          _cellPad(""),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {
      0: const pw.FixedColumnWidth(24),   // NO
      1: const pw.FlexColumnWidth(3),     // MODEL
      2: const pw.FlexColumnWidth(2),     // RENK
      3: const pw.FixedColumnWidth(40),   // ADET
      4: const pw.FlexColumnWidth(3),     // AÇIKLAMA
    },
    children: rows,
  );
}

pw.Widget _headerCell(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _cellPad(String text) =>
    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(text));
