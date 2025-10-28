import 'package:flutter/material.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/sevkiyat_service.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

class UretimdeOlanlarWidget extends StatefulWidget {
  const UretimdeOlanlarWidget({super.key});

  @override
  State<UretimdeOlanlarWidget> createState() => _UretimdeOlanlarWidgetState();
}

class _UretimdeOlanlarWidgetState extends State<UretimdeOlanlarWidget> {
  final siparisServis = SiparisService();
  final urunServis = UrunService();
  final sevkiyatServis = SevkiyatService();

  // 💡 FİLTRELEME GÜNCELLENDİ: Artık sadece durumu 'uretimde' olanları kontrol ediyoruz.
  bool _sadeceUretimdeOlanlar(SiparisModel s) {
    return s.durum == SiparisDurumu.uretimde;
  }

  // Bu fonksiyon, bu widget'ta doğrudan kullanılmadığı için olduğu gibi kalabilir.
  // Muhtemelen başka bir widget'tan çağrılıyordur.
  Future<void> _onayla(SiparisModel siparis) async {
    bool devamEt = true;
    if (siparis.islemeTarihi != null &&
        siparis.islemeTarihi!.isAfter(DateTime.now())) {
      devamEt =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Erken Onaylama Uyarısı"),
              content: Text(
                "Sipariş işleme tarihiniz: ${DateFormat('dd.MM.yyyy').format(siparis.islemeTarihi!)}\n\n"
                "Bu siparişi şimdi onaylamak istediğinize emin misiniz?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Hayır"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Evet"),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!devamEt) return;

    try {
      final ok = await siparisServis.onayla(siparis.docId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? "Onaylandı: Stok yeterli → Sevkiyat onayı bekliyor"
                : "Onaylandı: Stok yetersiz → Üretime aktarıldı",
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("İşlem başarısız: $e")));
      }
    }
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

        // 💡 FİLTRELEME GÜNCELLENDİ: Sadece 'uretimde' olanlar alınıyor.
        final uretimdekiSiparisler = tumSiparisler
            .where((s) => _sadeceUretimdeOlanlar(s))
            .toList();

        // 💡 DEĞİŞKEN ADI GÜNCELLENDİ
        if (uretimdekiSiparisler.isEmpty) return const SizedBox();

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
                    "Üretimde Olanlar", // 💡 Başlık daha uygun hale getirildi.
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                // 💡 Liste artık 'uretimdekiSiparisler' değişkenini kullanıyor.
                ...uretimdekiSiparisler.map((siparis) {
                  final musteriAdi =
                      siparis.musteri.firmaAdi?.trim().isNotEmpty == true
                      ? siparis.musteri.firmaAdi!.trim()
                      : (siparis.musteri.yetkili ?? "-");

                  // Stok kontrol mantığı aynı kalıyor, çünkü üretimdeki bir ürünün stoğunun
                  // sonradan gelip gelmediğini görmek faydalı olabilir.
                  bool siparisStokYeterli() {
                    for (final su in siparis.urunler) {
                      final stok = urunler.firstWhereOrNull(
                        (u) => u.id.toString() == su.id,
                      );
                      final adet = stok?.adet ?? 0;
                      if (adet < su.adet) return false;
                    }
                    return true;
                  }

                  final yeter = siparisStokYeterli();
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
                            Row(
                              children: [
                                Text("Ürün Sayısı: ${siparis.urunler.length}"),
                                const SizedBox(width: 8),
                                Text(
                                  yeter ? "Stok Var" : "Stok Yetersiz",
                                  style: TextStyle(
                                    color: yeter ? Colors.green : Colors.red,
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
                              final stok = urunler.firstWhereOrNull(
                                (u) => u.id.toString() == su.id,
                              );
                              final stokAdet = stok?.adet ?? 0;
                              final stokYeterli = stokAdet >= su.adet;
                              final Color renk = stokYeterli
                                  ? Colors.green
                                  : Colors.red;

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
                                  "Stok: $stokAdet | "
                                  "${su.renk.isNotEmpty ? ' ${su.renk}' : ''}",
                                ),
                                trailing: stok == null
                                    ? const Icon(
                                        Icons.warning,
                                        color: Colors.grey,
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
                }),
              ],
            );
          },
        );
      },
    );
  }
}
