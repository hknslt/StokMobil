import 'package:flutter/material.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/siparis_yonetimi/sevkiyat_service.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';
import 'package:capri/services/urun_yonetimi/urun_service.dart';
import 'package:intl/intl.dart';

class UretimdeOlanlarWidget extends StatefulWidget {
  const UretimdeOlanlarWidget({super.key});

  @override
  State<UretimdeOlanlarWidget> createState() => _UretimdeOlanlarWidgetState();
}

class _UretimdeOlanlarWidgetState extends State<UretimdeOlanlarWidget> {
  final siparisServis = SiparisService();
  final sevkiyatServis = SevkiyatService();
  // UrunService instance olarak aşağıda kullanılacak

  // Sadece durumu 'uretimde' olanları filtrele
  bool _sadeceUretimdeOlanlar(SiparisModel s) {
    return s.durum == SiparisDurumu.uretimde;
  }

  @override
  Widget build(BuildContext context) {
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

        // Sadece 'uretimde' olanlar
        final uretimdekiSiparisler = tumSiparisler
            .where((s) => _sadeceUretimdeOlanlar(s))
            .toList();

        if (uretimdekiSiparisler.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Üretimde Olanlar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ...uretimdekiSiparisler.map((siparis) {
              final musteriAdi =
                  siparis.musteri.firmaAdi?.trim().isNotEmpty == true
                  ? siparis.musteri.firmaAdi!.trim()
                  : (siparis.musteri.yetkili ?? "-");

              // --- YENİ KISIM: FutureBuilder ile Stok Analizi ---
              return FutureBuilder<Map<int, StokDetay>>(
                future: UrunService().analizEtStokDurumu(siparis.urunler),
                builder: (context, snapshot) {
                  final analizSonucu = snapshot.data ?? {};

                  // Genel Durum Kontrolü:
                  // Sadece KIRMIZI (Yetersiz) varsa "Yetersiz" deriz.
                  // SARI (Kritik) varsa "Var" deriz (rengi farklı olur).
                  bool genelStokYeterli = true;
                  if (snapshot.hasData) {
                    genelStokYeterli = !analizSonucu.values.any(
                      (d) => d.durum == StokDurumu.yetersiz,
                    );
                  }

                  final bool kritikUrunVar = analizSonucu.values.any(
                    (d) => d.durum == StokDurumu.kritik,
                  );

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

                            // --- YENİ EKLENDİ: AÇIKLAMA ALANI ---
                            if (siparis.aciklama != null &&
                                siparis.aciklama!.trim().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(
                                  top: 6,
                                  bottom: 6,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFF8E1,
                                  ), // Açık sarı (Amber 50)
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFFE082),
                                  ), // Amber 200
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.note_alt_outlined,
                                      size: 16,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        siparis.aciklama!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // -------------------------------------
                            Row(
                              children: [
                                Text("Ürün Sayısı: ${siparis.urunler.length}"),
                                const SizedBox(width: 8),
                                // Analiz Yükleniyor mu?
                                snapshot.connectionState ==
                                        ConnectionState.waiting
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        genelStokYeterli
                                            ? "Stok Var"
                                            : "Stok Yetersiz",
                                        style: TextStyle(
                                          color: genelStokYeterli
                                              ? (kritikUrunVar
                                                    ? Colors.orange
                                                    : Colors.green)
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ],
                            ),
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
                            children: siparis.urunler.map((su) {
                              final id = int.tryParse(su.id) ?? -1;
                              final detay = analizSonucu[id];

                              // Renk Mantığı
                              Color renk = Colors.grey;
                              if (detay != null) {
                                switch (detay.durum) {
                                  case StokDurumu.yeterli:
                                    renk = Colors.green;
                                    break;
                                  case StokDurumu.kritik:
                                    renk = Colors.orangeAccent; // SARI
                                    break;
                                  case StokDurumu.yetersiz:
                                    renk = Colors.red;
                                    break;
                                }
                              }

                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: renk,
                                  child: Text(
                                    "${su.adet}x",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  su.urunAdi,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: renk,
                                  ),
                                ),
                                subtitle: Text(
                                  "Stok: ${detay?.mevcutStok ?? '...'}"
                                  "${su.renk != null && su.renk!.isNotEmpty ? ' | ${su.renk}' : ''}"
                                  " | ₺${su.birimFiyat.toStringAsFixed(2)}",
                                ),
                                trailing:
                                    detay == null &&
                                        snapshot.connectionState ==
                                            ConnectionState.waiting
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : null,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}
