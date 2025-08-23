import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';

class BugununSiparisleriWidget extends StatefulWidget {
  const BugununSiparisleriWidget({super.key});

  @override
  State<BugununSiparisleriWidget> createState() =>
      _BugununSiparisleriWidgetState();
}

class _BugununSiparisleriWidgetState extends State<BugununSiparisleriWidget> {
  final siparisServis = SiparisService();
  final urunServis = UrunService();

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Bekleyen liste mantığı:
  // - beklemede: sadece islemeTarihi bugün ise göster
  // - uretimde/sevkiyat: tamamlanana kadar (tarihten bağımsız) göster
  bool _isPendingForToday(SiparisModel s, DateTime now) {
    switch (s.durum) {
      case SiparisDurumu.beklemede:
        if (s.islemeTarihi == null) return false;
        return _isSameDay(s.islemeTarihi!, now);
      case SiparisDurumu.uretimde:
      case SiparisDurumu.sevkiyat:
        return true;
      case SiparisDurumu.tamamlandi:
      case SiparisDurumu.reddedildi:
        return false;
    }
  }

  double _safeBrut(SiparisModel s) {
    final net = s.netTutar ?? s.toplamTutar;
    final kdv = s.kdvOrani ?? 0.0;
    return s.brutTutar ?? (net * (1 + kdv / 100));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

    return StreamBuilder<List<SiparisModel>>(
      stream: siparisServis.hepsiDinle(),
      builder: (context, sipSnap) {
        if (sipSnap.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }
        if (sipSnap.hasError) {
          return Text('Hata: ${sipSnap.error}');
        }
        final tumSiparisler = sipSnap.data ?? [];

        // Filtre uygula
        final bugunBekleyen = tumSiparisler
            .where((s) => _isPendingForToday(s, now))
            .toList();

        if (bugunBekleyen.isEmpty) return const SizedBox();

        // Stok kontrolü için ürünleri de dinle
        return StreamBuilder<List<Urun>>(
          stream: urunServis.dinle(),
          builder: (context, urunSnap) {
            final urunler = urunSnap.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "Bugünün Siparişleri (Bekleyenler)",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                ...bugunBekleyen.map((siparis) {
                  final musteriAdi =
                      siparis.musteri.firmaAdi?.trim().isNotEmpty == true
                          ? siparis.musteri.firmaAdi!.trim()
                          : (siparis.musteri.yetkili ?? "-");
                  final brutToplam = _safeBrut(siparis);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                musteriAdi,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            SiparisDurumEtiketi(durum: siparis.durum),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("Yetkili: ${siparis.musteri.yetkili ?? '-'}"),
                            Text("Ürün Sayısı: ${siparis.urunler.length}"),
                            Text("Toplam Tutar (Brüt): ${tl.format(brutToplam)}"),
                            if (siparis.islemeTarihi != null)
                              Text(
                                "İşlem Tarihi: ${DateFormat('dd.MM.yyyy').format(siparis.islemeTarihi!)}",
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: siparis.urunler.map((sipUrun) {
                              final stok = urunler.firstWhereOrNull(
                                (u) => u.id.toString() == sipUrun.id,
                              );
                              final stokYeterli =
                                  stok != null && stok.adet >= sipUrun.adet;

                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      stokYeterli ? Colors.green : Colors.red,
                                  child: Text(
                                    "${sipUrun.adet}x",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  sipUrun.urunAdi,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        stokYeterli ? Colors.green : Colors.red,
                                  ),
                                ),
                                subtitle: Text(
                                  "₺${sipUrun.birimFiyat.toStringAsFixed(2)}"
                                  "${sipUrun.renk.isNotEmpty ? ' | ${sipUrun.renk}' : ''}",
                                ),
                                trailing: stok == null
                                    ? const Icon(Icons.warning, color: Colors.grey)
                                    : Text("Stok: ${stok.adet}"),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),

                          // İstersen burada onayla/reddet aksiyonlarını ekleyebilirsin:
                          // (Sipariş beklemede ise göster; uretimde/sevkiyatta ise gizli tutabilirsiniz)
                          if (siparis.durum == SiparisDurumu.beklemede)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // onaylama akışın
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text("Onayla"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // reddetme akışın
                                  },
                                  icon: const Icon(Icons.close),
                                  label: const Text("Reddet"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}
