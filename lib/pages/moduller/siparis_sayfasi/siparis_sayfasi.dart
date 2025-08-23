// lib/pages/moduller/siparis_sayfasi/siparis_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_detay_sayfasi.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_oluşturma/siparis_olustur_sayfasi.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/services/urun_service.dart';
import 'package:capri/services/fiyat_listesi_service.dart'; // 👈 KDV için

class SiparisSayfasi extends StatefulWidget {
  const SiparisSayfasi({super.key});

  @override
  State<SiparisSayfasi> createState() => _SiparisSayfasiState();
}

class _SiparisSayfasiState extends State<SiparisSayfasi> {
  final siparisServis = SiparisService();
  final urunServis = UrunService();
  final fiyatSvc = FiyatListesiService.instance; // 👈 aktif KDV

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

    final istek = <int, int>{};
    for (final su in siparis.urunler) {
      final id = int.tryParse(su.id);
      if (id != null) {
        istek[id] = (istek[id] ?? 0) + su.adet;
      }
    }

    try {
      final ok = await urunServis.decrementStocksIfSufficient(istek);
      if (ok) {
        await siparisServis.guncelleDurum(
          siparis.docId!,
          SiparisDurumu.sevkiyat,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Sipariş onaylandı. Stok Var ✅")),
          );
        }
      } else {
        await siparisServis.guncelleDurum(
          siparis.docId!,
          SiparisDurumu.uretimde,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sipariş onaylandı. Stok Yetersiz ⚠️"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("İşlem başarısız: $e")));
      }
    }
  }

  Future<void> _reddet(SiparisModel siparis) async {
    try {
      await siparisServis.guncelleDurum(
        siparis.docId!,
        SiparisDurumu.reddedildi,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Reddetme başarısız: $e")));
      }
    }
  }

  // --- küçük yardımcılar (aktif KDV & brüt hesap) ---
  double _aktifKdv() => fiyatSvc.aktifKdv; // 🔁 getKdv yerine
  double _brut(double net, double kdvOrani) => net * (1 + kdvOrani / 100);

  @override
  Widget build(BuildContext context) {
    final aktifKdv = _aktifKdv();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sipariş Listesi"),
        backgroundColor: Renkler.kahveTon,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final sonuc = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SiparisOlusturSayfasi()),
          );
          if (sonuc == true && mounted) setState(() {});
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Yeni Sipariş",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Renkler.kahveTon,
      ),

      body: StreamBuilder<List<SiparisModel>>(
        stream: siparisServis.dinle(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          final siparisler = snap.data ?? [];
          if (siparisler.isEmpty) {
            return const Center(
              child: Text("Henüz sipariş yok.", style: TextStyle(fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: siparisler.length,
            itemBuilder: (context, index) {
              final siparis = siparisler[index];
              final musteri = siparis.musteri;
              final tarihStr = DateFormat(
                'dd.MM.yyyy – HH:mm',
              ).format(siparis.tarih);
              final musteriAdi = musteri.firmaAdi?.isNotEmpty == true
                  ? musteri.firmaAdi!
                  : musteri.yetkili ?? "";

              final numericIds = siparis.urunler
                  .map((e) => int.tryParse(e.id))
                  .whereNotNull()
                  .toList();

              // ✅ Kaydedilmiş finansallar varsa onları kullan; yoksa aktif KDV ile hesapla
              final netToplam = (siparis.netTutar ?? siparis.toplamTutar);
              final kdvOrani = (siparis.kdvOrani ?? aktifKdv);
              final brutToplam =
                  (siparis.brutTutar ?? _brut(netToplam, kdvOrani));

              return FutureBuilder<Map<int, int>>(
                future: urunServis.getStocksByNumericIds(numericIds),
                builder: (context, stokSnap) {
                  final stokHaritasi = stokSnap.data ?? {};
                  final stokYeterli = siparis.urunler.every((su) {
                    final id = int.tryParse(su.id);
                    final mevcut = id == null ? 0 : (stokHaritasi[id] ?? 0);
                    return mevcut >= su.adet;
                  });

                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
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
                                IconButton(
                                  icon: const Icon(
                                    Icons.open_in_new,
                                    color: Renkler.kahveTon,
                                  ),
                                  tooltip: "Detay Sayfası",
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SiparisDetaySayfasi(
                                          siparis: siparis,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Tarih: $tarihStr"),
                                Text(
                                  "İşlem Tarih: ${siparis.islemeTarihi != null ? DateFormat('dd.MM.yyyy').format(siparis.islemeTarihi!) : '-'}",
                                ),
                                Row(
                                  children: [
                                    Text(
                                      "Ürün Sayısı: ${siparis.urunler.length}",
                                    ),
                                    const SizedBox(width: 8),
                                    if (siparis.durum ==
                                        SiparisDurumu.beklemede)
                                      Text(
                                        stokYeterli
                                            ? "Stok Var"
                                            : "Stok Yetersiz",
                                        style: TextStyle(
                                          color: stokYeterli
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    else
                                      const SizedBox.shrink(), // Beklemede değilse bu etiketi hiç gösterme
                                  ],
                                ),

                                // 👇 Artık BRÜT toplamı (KDV dahil) ve kullanılan KDV %
                                Text(
                                  "Toplam (Brüt): ₺${brutToplam.toStringAsFixed(2)}  (KDV %${kdvOrani.toStringAsFixed(2)})",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            children: siparis.urunler.map((urun) {
                              final id = int.tryParse(urun.id);
                              final mevcut = id == null
                                  ? 0
                                  : (stokHaritasi[id] ?? 0);
                              final yeterli = mevcut >= urun.adet;

                              final netSatirToplam =
                                  urun.toplamFiyat; // adet * net birim
                              final brutSatirToplam = _brut(
                                netSatirToplam,
                                kdvOrani,
                              );

                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  backgroundColor: yeterli
                                      ? Colors.green
                                      : Colors.red,
                                  child: Text(
                                    "${urun.adet}x",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  urun.urunAdi,
                                  style: TextStyle(
                                    color: yeterli ? Colors.green : Colors.red,
                                    fontWeight: yeterli
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  "Net ₺${netSatirToplam.toStringAsFixed(2)}  |  KDV %${kdvOrani.toStringAsFixed(2)}  |  Brüt ₺${brutSatirToplam.toStringAsFixed(2)}"
                                  "${urun.renk != null && urun.renk!.isNotEmpty ? "  •  ${urun.renk}" : ""}",
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                trailing: Text(
                                  "₺${brutSatirToplam.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: SiparisDurumEtiketi(durum: siparis.durum),
                          ),

                          if (siparis.durum == SiparisDurumu.beklemede) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: () => _onayla(siparis),
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  tooltip: "Onayla",
                                ),
                                IconButton(
                                  onPressed: () => _reddet(siparis),
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  tooltip: "Reddet",
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
