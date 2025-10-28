import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class SevkiyatFisiSayfasi extends StatelessWidget {
  final SiparisModel siparis;

  const SevkiyatFisiSayfasi({super.key, required this.siparis});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sevkiyat Fişi Önizleme'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Renkler.anaMavi, Renkler.kahveTon.withOpacity(.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(format, siparis),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: "SevkiyatFisi_${siparis.musteri.firmaAdi ?? ''}.pdf",
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PDF OLUŞTURMA MANTIĞI
// -----------------------------------------------------------------------------

Future<Uint8List> _generatePdf(
  PdfPageFormat format,
  SiparisModel siparis,
) async {
  // Fontları yükle
  final baseFontData = await rootBundle.load(
    'assets/fonts/NotoSans-Regular.ttf',
  );
  final boldFontData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final baseFont = pw.Font.ttf(baseFontData);
  final boldFont = pw.Font.ttf(boldFontData);

  // 💡 YENİ: Logo görselini yükle
  final ByteData logoBytes = await rootBundle.load(
    'assets/images/capri_logo.png',
  );
  final Uint8List logoPng = logoBytes.buffer.asUint8List();

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
  );

  final tarihFormatter = DateFormat('dd.MM.yyyy');
  final toplamUrunAdedi = siparis.urunler.fold<int>(
    0,
    (sum, u) => sum + u.adet,
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 40,
        marginRight: 40,
        marginTop: 40,
        marginBottom: 40,
      ),

      footer: (context) {
        return pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "Capri Stok Takip Sistemi",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
            pw.Text(
              "Sayfa ${context.pageNumber} / ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        );
      },

      build: (context) => [
        // 1. Başlık ve Şirket Bilgileri (Logo ile güncellendi)
        _buildHeader(siparis, tarihFormatter, logoPng),
        pw.SizedBox(height: 20),

        // 2. Müşteri Bilgileri
        _buildMusteriBilgileri(siparis),
        pw.SizedBox(height: 20),

        // 3. Ürünler Tablosu
        _buildUrunTablosu(urunler: siparis.urunler),

        pw.SizedBox(height: 10),

        // 4. Toplamlar
        _buildTotals(toplamUrunAdedi),

        pw.SizedBox(height: 20),

        // 5. Notlar
        if (siparis.aciklama != null && siparis.aciklama!.isNotEmpty)
          _buildNotes(siparis),

        pw.Spacer(),

        // 6. İmza Alanları
        _buildImzaAlanlari(),
      ],
    ),
  );

  return pdf.save();
}

// --- PDF İçin Yardımcı Widget'lar ---

// 💡 GÜNCELLENDİ: LogoPng parametresi eklendi
pw.Widget _buildHeader(
  SiparisModel siparis,
  DateFormat formatter,
  Uint8List logoPng,
) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // 💡 YENİ: Logo burada gösteriliyor
          pw.Image(pw.MemoryImage(logoPng), width: 100, height: 50),
          // pw.Text(
          //   "[Şirket Ünvanınız]",
          //   style: const pw.TextStyle(fontSize: 10),
          // ),
          // pw.Text(
          //   "[Adresiniz, Kayseri]",
          //   style: const pw.TextStyle(fontSize: 10),
          // ),
          // pw.Text(
          //   "[Telefon & Vergi Bilgileriniz]",
          //   style: const pw.TextStyle(fontSize: 10),
          // ),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            "SEVK İRSALİYESİ",
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 18,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 10),
          // 💡 KALDIRILDI: Sipariş No satırı
          pw.Text("Belge Tarihi: ${formatter.format(DateTime.now())}"),
          if (siparis.islemeTarihi != null)
            pw.Text("Sevk Tarihi: ${formatter.format(siparis.islemeTarihi!)}"),
        ],
      ),
    ],
  );
}

pw.Widget _buildMusteriBilgileri(SiparisModel siparis) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400),
    children: [
      pw.TableRow(
        children: [
          _cellPad("Firma Adı:", bold: true, width: 100),
          _cellPad(siparis.musteri.firmaAdi ?? ''),
        ],
      ),
      pw.TableRow(
        children: [
          _cellPad("Yetkili:", bold: true),
          _cellPad(siparis.musteri.yetkili ?? ''),
        ],
      ),
      pw.TableRow(
        children: [
          _cellPad("Telefon:", bold: true),
          _cellPad(siparis.musteri.telefon ?? ''),
        ],
      ),
      pw.TableRow(
        children: [
          _cellPad("Adres:", bold: true),
          _cellPad(siparis.musteri.adres ?? ''),
        ],
      ),
    ],
  );
}

pw.Widget _buildUrunTablosu({required List<SiparisUrunModel> urunler}) {
  final rows = <pw.TableRow>[];

  // Başlık Satırı
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

  // Ürün Satırları
  for (var i = 0; i < urunler.length; i++) {
    final u = urunler[i];
    rows.add(
      pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          _cellPad("${i + 1}", align: pw.Alignment.center),
          _cellPad(u.urunAdi ?? ''),
          _cellPad(u.renk ?? ""),
          _cellPad("${u.adet}", align: pw.Alignment.center),
          _cellPad(""), // Açıklama için boş hücre
        ],
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(),
    columnWidths: {
      0: const pw.FixedColumnWidth(30), // NO
      1: const pw.FlexColumnWidth(3.5), // MODEL
      2: const pw.FlexColumnWidth(2), // RENK
      3: const pw.FixedColumnWidth(50), // ADET
      4: const pw.FlexColumnWidth(2.5), // AÇIKLAMA
    },
    children: rows,
  );
}

pw.Widget _buildTotals(int toplamAdet) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Container(
        width: 200,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Toplam Adet:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '$toplamAdet',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildNotes(SiparisModel siparis) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('NOTLAR:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text(siparis.aciklama!, style: const pw.TextStyle(fontSize: 10)),
      ],
    ),
  );
}

pw.Widget _buildImzaAlanlari() {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
    children: [
      pw.Column(
        children: [
          pw.Text("Teslim Eden"),
          pw.SizedBox(height: 40),
          pw.Container(width: 150, height: 1, color: PdfColors.black),
          pw.Text(
            "İmza",
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ],
      ),
      pw.Column(
        children: [
          pw.Text("Teslim Alan"),
          pw.SizedBox(height: 40),
          pw.Container(width: 150, height: 1, color: PdfColors.black),
          pw.Text(
            "İmza",
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
          ),
        ],
      ),
    ],
  );
}

pw.Widget _headerCell(String text) => pw.Padding(
  padding: const pw.EdgeInsets.all(4),
  child: pw.Text(
    text,
    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    textAlign: pw.TextAlign.center,
  ),
);

pw.Widget _cellPad(
  String text, {
  pw.Alignment align = pw.Alignment.centerLeft,
  bool bold = false,
  double? width,
}) {
  return pw.Container(
    width: width,
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      textAlign: (align == pw.Alignment.center)
          ? pw.TextAlign.center
          : pw.TextAlign.left,
      style: bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null,
    ),
  );
}
