// lib/utils/pdf/stok_pdf.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:capri/core/models/urun_model.dart';

Future<void> stokPdfYazdir(List<Urun> urunler) async {
  // Türkçe karakterler
  final baseFontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final baseFont = pw.Font.ttf(baseFontData);
  final boldFont = pw.Font.ttf(boldFontData);

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
  );

  // Özetler
  final toplamCesit = urunler.length;                 // kaç çeşit ürün
  final toplamAdet  = urunler.fold<int>(0, (s, u) => s + (u.adet));
  final stoktaOlanCesit = urunler.where((u) => u.adet > 0).length;
  final sifirStokCesit  = urunler.where((u) => u.adet == 0).length;

  // Satırları sayfalara böl (başlık hariç her sayfada ~30 satır güzel durur)
  const rowsPerPage = 30;
  List<List<Urun>> chunked = [];
  for (var i = 0; i < urunler.length; i += rowsPerPage) {
    chunked.add(urunler.sublist(
      i,
      (i + rowsPerPage > urunler.length) ? urunler.length : i + rowsPerPage,
    ));
  }
  if (chunked.isEmpty) chunked = [[]];

  final nowStr = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      footer: (ctx) {
        final isLast = ctx.pageNumber == ctx.pagesCount;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (isLast) ...[
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Özet", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Toplam Çeşit: $toplamCesit"),
                        pw.Text("Toplam Adet: $toplamAdet"),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("Stokta Olan Çeşit: $stoktaOlanCesit"),
                        pw.Text("Sıfır Stok Çeşit: $sifirStokCesit"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Sayfa ${ctx.pageNumber}/${ctx.pagesCount}",
                style: const pw.TextStyle(color: PdfColors.grey700),
              ),
            ),
          ],
        );
      },
      build: (ctx) {
        final widgets = <pw.Widget>[
          // Başlık
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                "STOK LİSTESİ",
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text("Tarih: $nowStr"),
            ],
          ),
          pw.SizedBox(height: 10),
        ];

        int globalIndexOffset = 0;
        for (var pi = 0; pi < chunked.length; pi++) {
          final pageRows = chunked[pi];
          widgets.add(_stokTablosu(pageRows, globalIndexOffset));
          globalIndexOffset += pageRows.length;

          if (pi != chunked.length - 1) {
            widgets.add(pw.SizedBox(height: 10));
          }
        }
        return widgets;
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (_) async => pdf.save());
}

pw.Widget _stokTablosu(List<Urun> urunler, int startIndex) {
  final rows = <pw.TableRow>[];

  // Başlık
  rows.add(
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
      children: [
        _headerCell("NO"),
        _headerCell("ÜRÜN KODU"),
        _headerCell("MODEL"),
        _headerCell("RENK"),
        _headerCell("ADET"),
      ],
    ),
  );

  // Satırlar
  for (var i = 0; i < urunler.length; i++) {
    final u = urunler[i];
    rows.add(
      pw.TableRow(
        children: [
          _cellPad("${startIndex + i + 1}"),
          _cellPad(u.urunKodu),
          _cellPad(u.urunAdi),
          _cellPad((u.renk).toString()),
          _cellPad("${u.adet}"),
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {
      0: const pw.FixedColumnWidth(26), // NO
      1: const pw.FlexColumnWidth(2),   // ÜRÜN KODU
      2: const pw.FlexColumnWidth(3),   // MODEL
      3: const pw.FlexColumnWidth(2),   // RENK
      4: const pw.FixedColumnWidth(40), // ADET
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
