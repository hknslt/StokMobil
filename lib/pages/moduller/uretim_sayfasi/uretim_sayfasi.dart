// lib/pages/moduller/uretim_sayfasi/uretim_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:collection/collection.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';

/// Ürün + renk + SİPARİŞ bazlı tek bir ihtiyaç kartı
class _EksikIstek {
  final String siparisDocId;
  final DateTime siparisTarihi;
  final String musteriAdi;

  final int urunId;
  final String urunAdi;
  final String renk; // normalize: '' olabilir
  final int toplamIstenen; // o siparişte bu ürün için toplam
  final int eksikAdet; // o siparişte bu ürün için eksik

  final String aciklama; // kartta gösterilecek açıklama

  const _EksikIstek({
    required this.siparisDocId,
    required this.siparisTarihi,
    required this.musteriAdi,
    required this.urunId,
    required this.urunAdi,
    required this.renk,
    required this.toplamIstenen,
    required this.eksikAdet,
    required this.aciklama,
  });

  _EksikIstek copyWith({int? eksikAdet}) => _EksikIstek(
    siparisDocId: siparisDocId,
    siparisTarihi: siparisTarihi,
    musteriAdi: musteriAdi,
    urunId: urunId,
    urunAdi: urunAdi,
    renk: renk,
    toplamIstenen: toplamIstenen,
    eksikAdet: eksikAdet ?? this.eksikAdet,
    aciklama: aciklama,
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
      appBar: AppBar(
        title: const Text("Üretim"),
        backgroundColor: Renkler.kahveTon,
      ),
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

                // Mevcut stok: ürünId -> adet
                final stokMap = <int, int>{
                  for (final u in tumUrunler) u.id: u.adet,
                };

                // ---- EKSİK LİSTESİ (SİPARİŞ BAZLI) ----
                // FIFO mantığıyla, siparişleri sırayla dolaşıp, her kalemde stoktan düş.
                // Stok yetmezse o sipariş + ürün(+renk) için EKSİK kaydı oluşur.
                final tempStok = Map<int, int>.from(stokMap);
                final List<_EksikIstek> eksikListe = [];

                for (final sip in uretimde) {
                  final musteriAdi =
                      (sip.musteri.firmaAdi?.trim().isNotEmpty == true)
                      ? sip.musteri.firmaAdi!.trim()
                      : (sip.musteri.yetkili ?? 'Müşteri');

                  for (final su in sip.urunler) {
                    final id = int.tryParse(su.id);
                    if (id == null) continue;

                    final varolan = tempStok[id] ?? 0;
                    if (varolan >= su.adet) {
                      // stok yeterli: yerel stoktan düş ve devam
                      tempStok[id] = varolan - su.adet;
                    } else {
                      final eksik = su.adet - varolan;
                      tempStok[id] = 0;

                      final renkSafe = (su.renk ?? '').trim();
                      final aciklama =
                          "Sipariş Tarihi: ${_fmtDate(sip.tarih)} • Toplam: ${su.adet} • Eksik: $eksik • Acıklama: ${sip.aciklama} ";

                      eksikListe.add(
                        _EksikIstek(
                          siparisDocId:
                              sip.docId ?? '', // stream’de her zaman dolu
                          siparisTarihi: sip.tarih,
                          musteriAdi: musteriAdi,
                          urunId: id,
                          urunAdi: su.urunAdi,
                          renk: renkSafe,
                          toplamIstenen: su.adet,
                          eksikAdet: eksik,
                          aciklama: aciklama,
                        ),
                      );
                    }
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "İstek Listesi",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (eksikListe.isEmpty)
                      const Text("Şu anda bekleyen istek yok.")
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: eksikListe.length,
                          itemBuilder: (context, index) {
                            final istek = eksikListe[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  "${istek.urunAdi} | ${istek.renk.isEmpty ? '-' : istek.renk}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Firma: ${istek.musteriAdi}"),
                                    const SizedBox(height: 4),
                                    Text(
                                      istek.aciklama,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: FilledButton.icon(
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text("Ekle"),
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.all(
                                      Renkler.kahveTon,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _istekTamamla(istek, tumUrunler),
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
          label: const Text(
            "Yeni Stok",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Renkler.kahveTon,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  // ---- Dialog: Stok Ekle (firma/sipariş belirtilmeden -> FIFO dağıt) ----
  Future<void> _stokEkleDialog(BuildContext pageContext) async {
    final urunler = await urunServis.onceGetir();
    final TextEditingController adetController = TextEditingController();
    Urun? secilen;

    await showDialog(
      context: pageContext,
      builder: (dialogCtx) {
        final nav = Navigator.of(dialogCtx);
        return AlertDialog(
          title: const Text("Stok Ekle"),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TypeAheadField<Urun>(
                  suggestionsCallback: (p) => urunler
                      .where(
                        (u) =>
                            u.urunAdi.toLowerCase().contains(p.toLowerCase()),
                      )
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
              child: const Text(
                "İptal",
                style: TextStyle(color: Renkler.kahveTon),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Renkler.kahveTon,
              ),
              onPressed: () async {
                final ek = int.tryParse(adetController.text.trim()) ?? 0;
                if (secilen != null && ek > 0 && secilen!.docId != null) {
                  // 1) Stoğa ekle
                  await urunServis.adetArtir(secilen!.docId!, ek);
                  // 2) Firma belirtilmediği için FIFO dağıt
                  final kac = await siparisServis
                      .allocateFIFOAcrossProduction();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Stok eklendi.$kac sipariş sevkiyata geçti.",
                        ),
                      ),
                    );
                  }
                }
                nav.pop();
              },
              child: const Text("Ekle", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// İSTEK KARTINDAN TAMAMLA:
  /// 1) Üretilen adedi stoğa ekler.
  /// 2) Önce SADECE bu siparişi sevkiyata geçirmeyi dener.
  ///    - Başarırsa: kalan stokla FIFO dağıtımı yapar.
  ///    - Başaramazsa: başka siparişlere dokunmaz (stok sizde kalır).
  Future<void> _istekTamamla(_EksikIstek istek, List<Urun> tumUrunler) async {
    final TextEditingController uretimAdetController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        final nav = Navigator.of(dialogCtx);
        return AlertDialog(
          title: Text("${istek.urunAdi} Üretimi (${istek.musteriAdi})"),
          content: TextField(
            controller: uretimAdetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Üretilen Adet (Eksik: ${istek.eksikAdet})",
            ),
          ),
          actions: [
            TextButton(child: const Text("İptal"), onPressed: () => nav.pop()),
            ElevatedButton(
              child: const Text("Tamamla"),
              onPressed: () async {
                final uretilen =
                    int.tryParse(uretimAdetController.text.trim()) ?? 0;
                if (uretilen <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Geçerli bir adet girin.")),
                  );
                  return;
                }

                nav.pop(); // input diyalogu
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  // 1) İlgili ürün dokümanı
                  final urun = tumUrunler.firstWhereOrNull(
                    (u) => u.id == istek.urunId,
                  );
                  if (urun == null || urun.docId == null) {
                    if (mounted) {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pop(); // loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Ürün bulunamadı. Listeyi yenileyin."),
                        ),
                      );
                    }
                    return;
                  }

                  // 2) Stoğa ekle
                  await urunServis.adetArtir(urun.docId!, uretilen);

                  // 3) SADECE BU SİPARİŞİ tamamlamayı dene
                  final ok = await siparisServis.sevkiyataGecir(
                    istek.siparisDocId,
                  );

                  if (ok) {
                    // 4) Kalan stok varsa FIFO ile dağıt
                    final kac = await siparisServis
                        .allocateFIFOAcrossProduction();
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Sipariş sevkiyata geçti. Ek olarak $kac sipariş daha sevkiyata geçti.",
                          ),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Bu siparişin diğer ürünleri eksik, üretimde kalmaya devam ediyor.",
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
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
