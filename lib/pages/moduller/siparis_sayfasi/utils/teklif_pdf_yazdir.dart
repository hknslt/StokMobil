import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:capri/core/models/siparis_model.dart';


// --- Yardımcı Fonksiyonlar ---

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

final _currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
String _tl(double value) => _currencyFormatter.format(value);


Future<void> teklifPdfYazdir(SiparisModel siparis) async {
  final notoReg = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final notoBold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final logoBytes = await rootBundle.load('assets/images/capri_logo_ori.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(notoReg),
      bold: pw.Font.ttf(notoBold),
    ),
  );

  final tarihFormatter = DateFormat('dd.MM.yyyy');
  final teklifTarihi = tarihFormatter.format(
    siparis.islemeTarihi ?? siparis.tarih,
  );

  // Toplamları hesapla
  final globalKdv = siparis.kdvOrani ?? 10.0;

  double araToplam = 0;
  double kdvTutar = 0;

  for (final u in siparis.urunler) {
    final adet = _num(u.adet);
    final birimFiyat = _num(u.birimFiyat);
    final satirNet = adet * birimFiyat;

    final satirKdvOrani = globalKdv;
    final satirKdvTutar = satirNet * (satirKdvOrani / 100);

    araToplam += satirNet;
    kdvTutar += satirKdvTutar;
  }
  final genelToplam = araToplam + kdvTutar;

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(14, 20, 14, 20),

      header: (context) =>
          _buildHeader(context, logoImage, teklifTarihi, siparis),
      footer: (context) => _buildFooter(context, globalKdv),

      build: (context) => [
        _buildUrunlerTablosu(siparis.urunler),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _buildToplamlarTablosu(araToplam, kdvTutar, genelToplam),
        ),
      ],
    ),
  );

  final ad =
      "Teklif_${siparis.musteri.firmaAdi?.replaceAll(' ', '_') ?? 'Musteri'}.pdf";
  await Printing.sharePdf(bytes: await pdf.save(), filename: ad);
}

// --- PDF Parçaları (Build metodları) ---

pw.Widget _buildHeader(
  pw.Context context,
  pw.ImageProvider logoImage,
  String tarih,
  SiparisModel siparis,
) {
  return pw.Column(
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.SizedBox(
            width: 200,
            height: 75,
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'TEKLİF FİŞİ',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Tarih: $tarih'),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      _buildMusteriBilgileri(siparis),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget _buildFooter(pw.Context context, double globalKdv) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        "Birim fiyatlar KDV HARİÇTİR.",
        style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
      ),
      pw.Text(
        "Sayfa ${context.pageNumber} / ${context.pagesCount}",
        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
      ),
    ],
  );
}

pw.Widget _buildMusteriBilgileri(SiparisModel s) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey600),
    columnWidths: const {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)},
    children: [
      pw.TableRow(
        children: [
          _cell("Müşteri: ${s.musteri.firmaAdi ?? s.musteri.yetkili ?? ''}"),
          _cell("Yetkili: ${s.musteri.yetkili ?? ''}"),
        ],
      ),
      pw.TableRow(
        children: [
          _cell("Telefon: ${s.musteri.telefon ?? ''}"),
          _cell("Adres: ${s.musteri.adres ?? ''}"),
        ],
      ),
      pw.TableRow(
        children: [_cell("Açıklama: ${s.aciklama ?? ''}", colSpan: 2)],
      ),
    ],
  );
}

pw.Widget _buildUrunlerTablosu(List<SiparisUrunModel> urunler) {
  return pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    cellStyle: const pw.TextStyle(fontSize: 10),
    cellAlignments: {
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
    },
    columnWidths: {
      0: const pw.FixedColumnWidth(25),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1.5),
      3: const pw.FixedColumnWidth(40),
      4: const pw.FlexColumnWidth(1.5),
      5: const pw.FlexColumnWidth(1.5),
    },
    headers: ["NO", "ÜRÜN/MODEL", "RENK", "ADET", "BİRİM FİYAT", "TUTAR"],
    data: List<List<String>>.generate(urunler.length, (index) {
      final u = urunler[index];
      final adet = _num(u.adet);
      final birimFiyat = _num(u.birimFiyat);
      return [
        '${index + 1}',
        u.urunAdi,
        u.renk ?? '',
        adet.toStringAsFixed(0),
        _tl(birimFiyat),
        _tl(adet * birimFiyat),
      ];
    }),
  );
}

pw.Widget _buildToplamlarTablosu(double ara, double kdv, double genel) {
  return pw.SizedBox(
    width: 250,
    child: pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey600),
      children: [
        _toplamSatir("Ara Toplam", _tl(ara)),
        _toplamSatir("KDV Toplamı", _tl(kdv)),
        _toplamSatir("Genel Toplam", _tl(genel), isBold: true),
      ],
    ),
  );
}

pw.TableRow _toplamSatir(String label, String value, {bool isBold = false}) {
  final style = isBold
      ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
      : const pw.TextStyle();
  return pw.TableRow(
    children: [
      _cell(label, style: style),
      _cell(value, align: pw.Alignment.centerRight, style: style),
    ],
  );
}

pw.Widget _cell(
  String text, {
  pw.Alignment align = pw.Alignment.centerLeft,
  pw.TextStyle? style,
  int colSpan = 1,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(4),
    alignment: align,
    child: pw.Text(text, style: style),
  );
}
