
import 'package:capri/core/Color/Colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/core/models/siparis_model.dart';

class SiparisGecmisDetaySayfasi extends StatelessWidget {
  final String siparisId;
  const SiparisGecmisDetaySayfasi({super.key, required this.siparisId});

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  String _musteriAdi(dynamic m) {
    try {
      final ad = (m as dynamic).ad as String?;
      if (ad != null && ad.isNotEmpty) return ad;
    } catch (_) {}
    try {
      final firma = (m as dynamic).firmaAdi as String?;
      if (firma != null && firma.isNotEmpty) return firma;
    } catch (_) {}
    try {
      final isim = (m as dynamic).isimSoyisim as String?;
      if (isim != null && isim.isNotEmpty) return isim;
    } catch (_) {}
    return '-';
  }
  double _netToplam(SiparisModel s) => (s.netTutar ?? s.toplamTutar);
  double _kdvOrani(SiparisModel s) => (s.kdvOrani ?? 0.0);
  double _kdvTutar(SiparisModel s) =>
      (s.kdvTutar ?? (_netToplam(s) * _kdvOrani(s) / 100));
  double _brutToplam(SiparisModel s) =>
      (s.brutTutar ?? (_netToplam(s) + _kdvTutar(s)));

  @override
  Widget build(BuildContext context) {
    final svc = SiparisService();
    final tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sipariş Detayı'),
        backgroundColor: Renkler.kahveTon,
      ),
      body: StreamBuilder<SiparisModel?>(
        stream: svc.tekDinle(siparisId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          final s = snap.data;
          if (s == null) {
            return const Center(child: Text('Sipariş bulunamadı.'));
          }

          final musteriAd = _musteriAdi(s.musteri);
          final net = _netToplam(s);
          final kdvOran = _kdvOrani(s);
          final kdv = _kdvTutar(s);
          final brut = _brutToplam(s);

          return Column(
            children: [

              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                musteriAd,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                s.durum.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: -6,
                          children: [
                            Chip(
                              label: Text('Oluşturuldu: ${_fmt(s.tarih)}'),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text('İşlem/Tamamlandı: ${_fmt(s.islemeTarihi)}'),
                              visualDensity: VisualDensity.compact,
                            ),
                            if ((s.aciklama ?? '').isNotEmpty)
                              Chip(
                                label: Text('Not: ${s.aciklama}'),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _finSatir("Net (KDV hariç)", tl.format(net)),
                              _finDivider(),
                              _finSatir(
                                "KDV (${kdvOran.toStringAsFixed(2)}%)",
                                tl.format(kdv),
                              ),
                              _finDivider(),
                              _finSatir(
                                "Brüt (KDV dahil)",
                                tl.format(brut),
                                vurgulu: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: ListView.separated(
                  itemCount: s.urunler.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final u = s.urunler[i];
                    dynamic d = u;
                    String urunAdi = '';
                    String? urunKodu;
                    String? renk;
                    int adet = 0;
                    double birim = 0, netSatir = 0;

                    try {
                      urunAdi = (d.urunAdi as String?) ?? '';
                    } catch (_) {}
                    try {
                      urunKodu = d.urunKodu as String?;
                    } catch (_) {}
                    try {
                      renk = d.renk as String?;
                    } catch (_) {}
                    try {
                      adet = (d.adet as int?) ?? 0;
                    } catch (_) {}
                    try {
                      birim = (d.birimFiyat as double?) ?? 0;
                    } catch (_) {}
                    try {
                      netSatir = (d.toplamFiyat as double?) ?? (adet * birim);
                    } catch (_) {
                      netSatir = adet * birim;
                    }

                    final kdvSatir = netSatir * kdvOran / 100;
                    final brutSatir = netSatir + kdvSatir;

                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(
                          urunAdi,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text([
                              if ((urunKodu ?? '').isNotEmpty) 'Kod: $urunKodu',
                              if ((renk ?? '').isNotEmpty) 'Renk: $renk',
                              'Adet: $adet',
                              'Birim: ${tl.format(birim)}',
                            ].join(' • ')),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _miniTag("Brüt", tl.format(brutSatir), highlight: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _finDivider() => const Divider(height: 0, thickness: 1, color: Color(0x11000000));

  Widget _finSatir(String baslik, String deger, {bool vurgulu = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              baslik,
              style: TextStyle(
                fontSize: 15,
                fontWeight: vurgulu ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            deger,
            style: TextStyle(
              fontSize: vurgulu ? 17 : 15,
              fontWeight: vurgulu ? FontWeight.w800 : FontWeight.w700,
              color: vurgulu ? Colors.green[800] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String label, String value, {String? trailing, bool highlight = false}) {
    final bg = highlight ? Colors.green.shade50 : Colors.grey.shade100;
    final fg = highlight ? Colors.green.shade800 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: highlight ? Colors.green.shade200 : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label: ",
              style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(trailing, style: TextStyle(color: fg)),
          ],
        ],
      ),
    );
  }
}
