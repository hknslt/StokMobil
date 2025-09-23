import 'package:capri/core/Color/Colors.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/utils/siparis_Pdf_Yazdir.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/services/fiyat_listesi_service.dart';

class SiparisDetaySayfasi extends StatefulWidget {
  final SiparisModel siparis;
  const SiparisDetaySayfasi({super.key, required this.siparis});

  @override
  State<SiparisDetaySayfasi> createState() => _SiparisDetaySayfasiState();
}

class _SiparisDetaySayfasiState extends State<SiparisDetaySayfasi> {
  final urunServis = UrunService();
  final siparisServis = SiparisService();

  late final List<int> _urunIdleri;
  late Future<Map<int, int>> _stokHaritasiFut;

  double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  @override
  void initState() {
    super.initState();
    _urunIdleri = widget.siparis.urunler
        .map((e) => int.tryParse(e.id) ?? -1)
        .where((e) => e >= 0)
        .toList();
    _stokHaritasiFut = urunServis.getStocksByNumericIds(_urunIdleri);
  }

  Future<void> _yenileStokHaritasi() async {
    final m = await urunServis.getStocksByNumericIds(_urunIdleri);
    if (!mounted) return;
    setState(() {
      _stokHaritasiFut = Future.value(m);
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

      await _yenileStokHaritasi();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("İşlem başarısız: $e")));
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

    final bool stokKontrollu =
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

            FutureBuilder<Map<int, int>>(
              future: _stokHaritasiFut,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final stokHaritasi = snap.data ?? {};

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ürünler",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...s.urunler.map((u) {
                          final id = int.tryParse(u.id) ?? -1;
                          final stok = stokHaritasi[id] ?? 0;
                          final stokYeterli = stok >= u.adet;

                          final double netSatirToplam = u.toplamFiyat;
                          final double brutSatirToplam = _round2(
                            netSatirToplam * (1 + kdvOrani / 100),
                          );

                          final Color satirRenk = stokKontrollu
                              ? (stokYeterli ? Colors.green : Colors.red)
                              : Colors.grey;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: satirRenk,
                              child: Text(
                                "${u.adet}x",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              "${u.urunAdi}${(u.renk ?? '').isNotEmpty ? " | ${u.renk}" : ""}",
                              style: TextStyle(
                                color: satirRenk,
                                fontWeight: stokKontrollu && !stokYeterli
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              "Stok: $stok  •  Net ₺${netSatirToplam.toStringAsFixed(2)}  |  "
                              "KDV %${kdvOrani.toStringAsFixed(2)} ",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            trailing: Text(
                              "₺${brutSatirToplam.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
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
