// lib/pages/moduller/uretim_sayfasi/uretim_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:collection/collection.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';

/// Ürün + renk + müşteri bazlı tek bir ihtiyaç kartı
class _EksikIstek {
  final int urunId;
  final String urunAdi;
  final String renk;   // her yerde '' ile normalize edeceğiz
  final String musteriId;
  final String musteriAdi;
  final int adet;

  const _EksikIstek({
    required this.urunId,
    required this.urunAdi,
    required this.renk,
    required this.musteriId,
    required this.musteriAdi,
    required this.adet,
  });

  _EksikIstek copyWith({int? adet}) => _EksikIstek(
        urunId: urunId,
        urunAdi: urunAdi,
        renk: renk,
        musteriId: musteriId,
        musteriAdi: musteriAdi,
        adet: adet ?? this.adet,
      );
}

class UretimSayfasi extends StatefulWidget {
  const UretimSayfasi({super.key});

  @override
  State<UretimSayfasi> createState() => _UretimSayfasiState();
}

class _UretimSayfasiState extends State<UretimSayfasi> {
  final siparisServis = SiparisService();
  final urunServis = UrunService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Üretim"), backgroundColor: Renkler.kahveTon),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<SiparisModel>>(
          stream: siparisServis.dinle(sadeceDurum: SiparisDurumu.uretimde),
          builder: (context, sipSnap) {
            if (sipSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (sipSnap.hasError) {
              return Center(child: Text('Hata: ${sipSnap.error}'));
            }
            final uretimde = (sipSnap.data ?? []).toList()
              ..sort((a, b) => a.tarih.compareTo(b.tarih)); // FIFO

            return StreamBuilder<List<Urun>>(
              stream: urunServis.dinle(),
              builder: (context, urunSnap) {
                if (urunSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (urunSnap.hasError) {
                  return Center(child: Text('Hata: ${urunSnap.error}'));
                }
                final tumUrunler = urunSnap.data ?? [];

                // Anlık stok: ürünId -> adet
                final stokMap = <int, int>{for (final u in tumUrunler) u.id: u.adet};

                // ---- EKSİK HARİTASI (ürün+renk+müşteri) ----
                final tempStok = Map<int, int>.from(stokMap);
                final Map<String, _EksikIstek> eksikHarita = {};

                for (final sip in uretimde) {
                  final musteriAdi = (sip.musteri.firmaAdi?.trim().isNotEmpty == true)
                      ? sip.musteri.firmaAdi!.trim()
                      : (sip.musteri.yetkili ?? 'Müşteri');
                  final musteriId = sip.musteri.id;

                  for (final su in sip.urunler) {
                    final id = int.tryParse(su.id);
                    if (id == null) continue;

                    final varolan = tempStok[id] ?? 0;
                    if (varolan >= su.adet) {
                      tempStok[id] = varolan - su.adet;
                    } else {
                      final eksik = su.adet - varolan;
                      tempStok[id] = 0;

                      final renkSafe = (su.renk ?? '').trim();
                      final key = '$id|$musteriId|$renkSafe';

                      final cur = eksikHarita[key];
                      if (cur == null) {
                        eksikHarita[key] = _EksikIstek(
                          urunId: id,
                          urunAdi: su.urunAdi,
                          renk: renkSafe,
                          musteriId: musteriId,
                          musteriAdi: musteriAdi,
                          adet: eksik,
                        );
                      } else {
                        eksikHarita[key] = cur.copyWith(adet: cur.adet + eksik);
                      }
                    }
                  }
                }

                final eksikListe = eksikHarita.values.toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "İstek Listesi",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (eksikListe.isEmpty)
                      const Text("Şu anda bekleyen istek yok.")
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96), // FAB çakışmasın
                          itemCount: eksikListe.length,
                          itemBuilder: (context, index) {
                            final istek = eksikListe[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  "${istek.urunAdi} | ${istek.renk.isEmpty ? '-' : istek.renk}",
                                ),
                                subtitle: Text(
                                  "Firma: ${istek.musteriAdi}  •  İstenen Adet: ${istek.adet}",
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  tooltip: "İstek Karşılandı",
                                  onPressed: () => _istekTamamla(istek, tumUrunler),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),

      floatingActionButton: Builder(
        builder: (ctx) => FloatingActionButton.extended(
          onPressed: () => _stokEkleDialog(ctx),
          tooltip: "Stok Ekle",
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Yeni Stok",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Renkler.kahveTon,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ---- Dialog: Stok Ekle ----
  Future<void> _stokEkleDialog(BuildContext pageContext) async {
    final urunler = await urunServis.onceGetir();
    final TextEditingController adetController = TextEditingController();
    Urun? secilen;

    await showDialog(
      context: pageContext,
      builder: (dialogCtx) {
        final nav = Navigator.of(dialogCtx); // await'ten önce yakala
        return AlertDialog(
          title: const Text("Stok Ekle"),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TypeAheadField<Urun>(
                  suggestionsCallback: (p) => urunler
                      .where((u) => u.urunAdi.toLowerCase().contains(p.toLowerCase()))
                      .toList(),
                  itemBuilder: (_, u) => ListTile(
                    title: Text(u.urunAdi),
                    subtitle: Text("Renk: ${u.renk}  |  Stok: ${u.adet}"),
                  ),
                  onSelected: (u) => secilen = u,
                  builder: (context, controller, focusNode) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Ürün Ara",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: adetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Eklenecek Adet",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => nav.pop(),
              child: const Text("İptal", style: TextStyle(color: Renkler.kahveTon)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
              onPressed: () async {
                final ek = int.tryParse(adetController.text.trim()) ?? 0;
                if (secilen != null && ek > 0 && secilen!.docId != null) {
                  await urunServis.adetArtir(secilen!.docId!, ek);
                }
                nav.pop(); // diyalogu kapat
              },
              child: const Text("Ekle", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// TAMAMLA:
  ///  - Diyalog hemen kapanır, loader gösterilir (UI takılmaz)
  ///  - Sadece bu MÜŞTERİ + bu ÜRÜN(+renk) içeren 'üretimde' siparişler FIFO
  ///  - Önce yerel stokla UYGUNLUK ÖN KONTROLÜ yapılır (hız!)
  ///  - Gerçekten tamamlanabilen siparişlere tek tek transaction uygulanır
  Future<void> _istekTamamla(_EksikIstek istek, List<Urun> tumUrunler) async {
    final TextEditingController uretimAdetController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        final nav = Navigator.of(dialogCtx);
        return AlertDialog(
          title: Text("${istek.urunAdi} Üretimi"),
          content: TextField(
            controller: uretimAdetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Üretilen Adet"),
          ),
          actions: [
            TextButton(
              child: const Text("İptal"),
              onPressed: () => nav.pop(),
            ),
            ElevatedButton(
              child: const Text("Tamamla"),
              onPressed: () async {
                final uretilen = int.tryParse(uretimAdetController.text.trim()) ?? 0;
                if (uretilen <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Geçerli bir adet girin.")),
                  );
                  return;
                }

                // Diyalog hemen kapansın, loader açılsın
                nav.pop();
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  // 1) Ürün dokümanı
                  final urun = tumUrunler.firstWhereOrNull((u) => u.id == istek.urunId);
                  if (urun == null || urun.docId == null) {
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ürün bulunamadı. Listeyi yenileyin.")),
                      );
                    }
                    return;
                  }

                  // 2) Stoğa ekle
                  await urunServis.adetArtir(urun.docId!, uretilen);

                  // 3) Aday siparişleri topla (sadece bu firma + bu ürün(+renk) içerenler)
                  final tumUretimde = await siparisServis.getirByDurumOnce(SiparisDurumu.uretimde);
                  final adaylar = tumUretimde
                      .where((s) => s.musteri.id == istek.musteriId)
                      .where((s) => s.urunler.any((su) {
                            final id = int.tryParse(su.id);
                            final renkSafe = (su.renk ?? '').trim();
                            return id == istek.urunId && renkSafe == istek.renk;
                          }))
                      .toList()
                    ..sort((a, b) => a.tarih.compareTo(b.tarih)); // FIFO

                  if (adaylar.isEmpty) {
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pop(); // loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Uygun sipariş bulunamadı.")),
                      );
                    }
                    return;
                  }

                  // 4) Bu adaylarda geçen TÜM ürün id'lerini çıkar → stok snapshot
                  final idKumesi = {
                    for (final s in adaylar)
                      ...s.urunler
                          .map((su) => int.tryParse(su.id))
                          .whereNotNull()
                  }.toList();
                  final stokSnapshot = await urunServis.getStocksByNumericIds(idKumesi);
                  final localStok = Map<int, int>.from(stokSnapshot);

                  // 5) Ön kontrol: hangi siparişler TAMAMEN karşılanabilir?
                  final tamamlanacaklar = <SiparisModel>[];
                  for (final s in adaylar) {
                    // siparişin tüm ihtiyaçlarını test et
                    bool yeter = true;
                    for (final su in s.urunler) {
                      final id = int.tryParse(su.id);
                      if (id == null) continue;
                      final varolan = localStok[id] ?? 0;
                      if (varolan < su.adet) {
                        yeter = false;
                        break;
                      }
                    }
                    if (yeter) {
                      // yerel stoktan düş (rezerv et)
                      for (final su in s.urunler) {
                        final id = int.tryParse(su.id);
                        if (id == null) continue;
                        localStok[id] = (localStok[id] ?? 0) - su.adet;
                      }
                      tamamlanacaklar.add(s);
                    }
                  }

                  // 6) Gerçek uygulama (transaction): sadece ön kontrolden geçenler
                  for (final s in tamamlanacaklar) {
                    final istekMap = <int, int>{};
                    for (final su in s.urunler) {
                      final id = int.tryParse(su.id);
                      if (id != null) {
                        istekMap[id] = (istekMap[id] ?? 0) + su.adet;
                      }
                    }
                    final ok = await urunServis.decrementStocksIfSufficient(istekMap);
                    if (ok && s.docId != null) {
                      await siparisServis.durumGuncelle(s.docId!, SiparisDurumu.sevkiyat);
                    }
                  }

                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // loader
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("İstek tamamlandı.")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // loader
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("İşlem başarısız: $e")),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    ); 
  }
}
