import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/fiyat_listesi_service.dart';

class SiparisOzetSayfasi extends StatelessWidget {
  final MusteriModel musteri;
  final List<SiparisUrunModel> urunler;
  final DateTime? islemeTarihi;
  final String? siparisAciklama;
  final VoidCallback onBack;

  SiparisOzetSayfasi({
    super.key,
    required this.musteri,
    required this.urunler,
    required this.onBack,
    this.islemeTarihi,
    this.siparisAciklama,
  });

  final NumberFormat _tl = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );
  String _fmt(double v) => _tl.format(v);

  double get _netAraToplam =>
      urunler.fold(0, (sum, u) => sum + u.birimFiyat * u.adet);

  @override
  Widget build(BuildContext context) {
    final svc = FiyatListesiService.instance;
    final aktifListeAd = svc.aktifListeAd;   
    final kdvYuzde = svc.aktifKdv;          

    final kdvTutar = _netAraToplam * (kdvYuzde / 100);
    final genelToplam = _netAraToplam + kdvTutar;

    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          "Sipariş Özeti",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Fiyat Listesi: $aktifListeAd • KDV: %${kdvYuzde.toStringAsFixed(2)}",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha((0.6 * 255).round()),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ExpansionTile(
              leading: Icon(Icons.info, color: Renkler.kahveTon),
              title: const Text(
                "Müşteri & Sipariş Bilgileri",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _bilgiSatiri("Firma", musteri.firmaAdi),
                _bilgiSatiri("Yetkili", musteri.yetkili),
                _bilgiSatiri("Telefon", musteri.telefon),
                _bilgiSatiri("Adres", musteri.adres, maxLines: 2),
                if (islemeTarihi != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    "İşleme Alınma Tarihi",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(DateFormat("dd.MM.yyyy").format(islemeTarihi!)),
                ],
                if ((siparisAciklama ?? "").trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    "Sipariş Açıklaması",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(siparisAciklama!.trim()),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: GridView.builder(
              itemCount: urunler.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final u = urunler[index];
                final satirNet = u.birimFiyat * u.adet;
                return Stack(
                  children: [
                    Card(
                      elevation: 1.2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              u.urunAdi,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              u.renk ?? "",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "Net Birim: ${_fmt(u.birimFiyat)}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Net Toplam: ${_fmt(satirNet)}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Renkler.kahveTon,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          "${u.adet}x",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: const Border(top: BorderSide(color: Colors.grey)),
          ),
          child: Column(
            children: [
              _tutarSatiri("Net (Ara Toplam)", _netAraToplam),
              const SizedBox(height: 4),
              _tutarSatiri("KDV (%${kdvYuzde.toStringAsFixed(2)})", kdvTutar),
              const SizedBox(height: 4),
              _tutarSatiri("Genel Toplam", genelToplam, vurgulu: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text(
                        "Geri",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Renkler.kahveTon,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final siparis = SiparisModel(
                          musteri: musteri,
                          urunler: urunler,
                          islemeTarihi: islemeTarihi,
                          aciklama: siparisAciklama,
                          netTutar: _netAraToplam,
                          kdvOrani: kdvYuzde,
                          kdvTutar: kdvTutar,
                          brutTutar: genelToplam,
                          fiyatListesiAd: aktifListeAd,
                        );

                        await SiparisService().ekle(siparis);
                        if (context.mounted) Navigator.pop(context, true);
                      },
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        "Siparişi Oluştur",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _bilgiSatiri(String baslik, String? deger, {int maxLines = 1}) {
    final val = (deger == null || deger.trim().isEmpty) ? "—" : deger.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$baslik:",
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              val,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tutarSatiri(String etiket, double tutar, {bool vurgulu = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiket,
          style: TextStyle(
            fontWeight: vurgulu ? FontWeight.w700 : FontWeight.w600,
            fontSize: vurgulu ? 16 : 14,
          ),
        ),
        Text(
          _fmt(tutar),
          style: TextStyle(
            color: vurgulu ? Colors.green : null,
            fontWeight: vurgulu ? FontWeight.w800 : FontWeight.w600,
            fontSize: vurgulu ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
