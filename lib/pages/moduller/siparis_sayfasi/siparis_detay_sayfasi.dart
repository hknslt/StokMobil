import 'package:capri/core/Color/Colors.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/utils/teklif_pdf_yazdir.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/utils/siparis_Pdf_Yazdir.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/urun_yonetimi/urun_service.dart';
import 'package:capri/services/urun_yonetimi/fiyat_listesi_service.dart';

class SiparisDetaySayfasi extends StatefulWidget {
  final SiparisModel siparis;
  const SiparisDetaySayfasi({super.key, required this.siparis});

  @override
  State<SiparisDetaySayfasi> createState() => _SiparisDetaySayfasiState();
}

class _SiparisDetaySayfasiState extends State<SiparisDetaySayfasi> {
  final urunServis = UrunService();
  final siparisServis = SiparisService();

  late Future<Map<int, StokDetay>> _stokAnalizFut;

  double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  @override
  void initState() {
    super.initState();
    _stokAnalizFut = urunServis.analizEtStokDurumu(widget.siparis.urunler);
  }

  Future<void> _yenileStokDurumu() async {
    final m = await urunServis.analizEtStokDurumu(widget.siparis.urunler);
    if (!mounted) return;
    setState(() {
      _stokAnalizFut = Future.value(m);
    });
  }

  Future<void> siparisiOnayla() async {
    bool devamEt = true;

    if (widget.siparis.islemeTarihi != null &&
        widget.siparis.islemeTarihi!.isAfter(DateTime.now())) {
      devamEt =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Erken Onaylama Uyarısı"),
              content: Text(
                "Sipariş işleme tarihiniz: ${DateFormat('dd.MM.yyyy').format(widget.siparis.islemeTarihi!)}\n\n"
                "Bu siparişi şimdi onaylamak istediğinize emin misiniz?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Hayır"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Evet"),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!devamEt) return;

    if (widget.siparis.docId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sipariş docId yok.")));
      return;
    }

    try {
      final ok = await siparisServis.onaylaVeStokAyir(widget.siparis.docId!);

      if (!mounted) return;
      setState(() {
        widget.siparis.durum = ok
            ? SiparisDurumu.sevkiyat
            : SiparisDurumu.uretimde;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? "Sipariş onaylandı. Stok var ✅"
                : "Sipariş onaylandı. Stok yetersiz → Üretimde ⚠️",
          ),
        ),
      );

      await _yenileStokDurumu(); // GÜNCELLENDİ
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  Future<void> siparisiReddet() async {
    try {
      if (widget.siparis.docId == null) {
        throw "Bu siparişin docId'si yok.";
      }
      await siparisServis.guncelleDurum(
        widget.siparis.docId!,
        SiparisDurumu.reddedildi,
      );
      if (!mounted) return;
      setState(() {
        widget.siparis.durum = SiparisDurumu.reddedildi;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Sipariş reddedildi.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reddetme başarısız: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.siparis;
    final musteri = s.musteri;
    final tarihStr = DateFormat('dd.MM.yyyy – HH:mm').format(s.tarih);

    final double kdvOrani = s.kdvOrani ?? FiyatListesiService.instance.aktifKdv;

    final double netToplam = s.netTutar ?? s.toplamTutar;
    final double kdvTutar = s.kdvTutar ?? _round2(netToplam * kdvOrani / 100);
    final double brutToplam = s.brutTutar ?? _round2(netToplam + kdvTutar);

    final bool renklendirmeAktif =
        s.durum == SiparisDurumu.beklemede || s.durum == SiparisDurumu.uretimde;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sipariş Detayı"),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: () => teklifPdfYazdir(s),
            tooltip: "Teklif Fişi Yazdır",
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => siparisPdfYazdir(s),
            tooltip: "PDF olarak yazdır",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Müşteri & Sipariş Bilgileri
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      musteri.firmaAdi?.isNotEmpty == true
                          ? musteri.firmaAdi!
                          : (musteri.yetkili ?? ""),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (musteri.telefon != null)
                      Text("Telefon: ${musteri.telefon}"),
                    if (musteri.adres != null) Text("Adres: ${musteri.adres}"),
                    const SizedBox(height: 8),
                    Text("Sipariş Tarihi: $tarihStr"),
                    if (s.islemeTarihi != null)
                      Text(
                        "İşleme Tarihi: ${DateFormat('dd.MM.yyyy').format(s.islemeTarihi!)}",
                      ),
                    if (s.aciklama != null && s.aciklama!.trim().isNotEmpty)
                      Text("Açıklama: ${s.aciklama}"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text("Durum: "),
                        SiparisDurumEtiketi(durum: s.durum),
                      ],
                    ),
                    if ((s.fiyatListesiAd ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "Fiyat Listesi: ${s.fiyatListesiAd} • KDV %${kdvOrani.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            FutureBuilder<Map<int, StokDetay>>(
              future: _stokAnalizFut,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                }
                
                final analizSonucu = snap.data ?? {};

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Ürünler", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        
                        ...s.urunler.map((u) {
                          final id = int.tryParse(u.id) ?? -1;
                          final detay = analizSonucu[id];
                          
                          // Varsayılan Renkler (Renklendirme pasifse veya veri yoksa)
                          Color bgRenk = Colors.transparent;
                          Color borderRenk = Colors.grey.shade300;
                          
                          if (renklendirmeAktif && detay != null) {
                            switch (detay.durum) {
                              case StokDurumu.yeterli:
                                bgRenk = const Color(0xFFE8F5E9); // Açık Yeşil
                                borderRenk = const Color(0xFF4CAF50); // Koyu Yeşil
                                break;
                              case StokDurumu.kritik:
                                bgRenk = const Color(0xFFFFFDE7); // Açık Sarı
                                borderRenk = const Color(0xFFFFC107); // Koyu Sarı
                                break;
                              case StokDurumu.yetersiz:
                                bgRenk = const Color(0xFFFFEBEE); // Açık Kırmızı
                                borderRenk = const Color(0xFFF44336); // Koyu Kırmızı
                                break;
                            }
                          }

                          final double netSatir = u.toplamFiyat;
                          final double brutSatir = _round2(netSatir * (1 + kdvOrani / 100));

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: bgRenk,
                              border: Border.all(color: borderRenk, width: renklendirmeAktif ? 1.5 : 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Sol taraf: Adet Balonu
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: renklendirmeAktif ? borderRenk : Colors.grey,
                                  child: Text(
                                    "${u.adet}",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Orta: Ürün Bilgisi ve Stok Durumu
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${u.urunAdi}${(u.renk ?? '').isNotEmpty ? " | ${u.renk}" : ""}",
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      if (renklendirmeAktif && detay != null)
                                        Text(
                                          "Stok: ${detay.mevcutStok}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: detay.durum == StokDurumu.yetersiz ? Colors.red : Colors.black54,
                                          ),
                                        )
                                      else
                                        Text("Birim: ₺${u.birimFiyat}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),

                                // Sağ: Fiyat
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text("₺${netSatir.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text("Brüt: ₺${brutSatir.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Net Toplam: ₺${netToplam.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "KDV (%${kdvOrani.toStringAsFixed(2)}): ₺${kdvTutar.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Genel Toplam (Brüt): ₺${brutToplam.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (s.durum == SiparisDurumu.beklemede)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: siparisiOnayla,
                    icon: const Icon(Icons.check),
                    label: const Text("Onayla"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: siparisiReddet,
                    icon: const Icon(Icons.close),
                    label: const Text("Reddet"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
