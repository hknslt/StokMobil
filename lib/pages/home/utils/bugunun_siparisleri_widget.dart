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

  Future<void> _sevkiyataOnayla(SiparisModel siparis) async {
    try {
      final ok = await siparisServis.sevkiyataOnayla(siparis.docId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? "Sevkiyat onayı başarılı. Stok düşüldü."
                : "Stok yetersiz. Üretime devam edilmeli.",
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

  Future<void> _reddet(SiparisModel siparis) async {
    final onay =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Reddetme Onayı"),
            content: Text(
              "Bu siparişi reddetmek istediğinize emin misiniz?"
              "${siparis.durum == SiparisDurumu.sevkiyat ? "\n\nNot: Sipariş sevkiyatta olduğundan daha önce düşülen stoklar iade edilecektir." : ""}",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Vazgeç"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Reddet",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!onay) return;

    try {
      await siparisServis.reddetVeStokIade(siparis.docId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sipariş reddedildi. Gerekliyse stok iade edildi."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Reddetme başarısız: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tl = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );

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
        final bugunBekleyen = tumSiparisler
            .where((s) => _isPendingForToday(s, now))
            .toList();

        if (bugunBekleyen.isEmpty) return const SizedBox();
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
                  final stokKontrollu =
                      siparis.durum == SiparisDurumu.beklemede ||
                      siparis.durum == SiparisDurumu.uretimde;
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
                  final sevkiyatOnayGorunur =
                      (siparis.durum == SiparisDurumu.beklemede ||
                          siparis.durum == SiparisDurumu.uretimde) &&
                      (siparis.sevkiyatHazir == true);

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
                                if (stokKontrollu)
                                  Text(
                                    yeter ? "Stok Var" : "Stok Yetersiz",
                                    style: TextStyle(
                                      color: yeter ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              "Toplam Tutar (Brüt): ${tl.format(brutToplam)}",
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
                              final Color renk = stokKontrollu
                                  ? (stokYeterli ? Colors.green : Colors.red)
                                  : Colors.grey;

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
                                  "Stok: $stokAdet"
                                  "${su.renk.isNotEmpty ? ' | ${su.renk}' : ''}"
                                  " | ₺${su.birimFiyat.toStringAsFixed(2)}",
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

                          if (siparis.durum == SiparisDurumu.beklemede)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _onayla(siparis),
                                  icon: const Icon(Icons.check),
                                  label: const Text("Onayla"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _reddet(siparis),
                                  icon: const Icon(Icons.close),
                                  label: const Text("Reddet"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),

                          if (sevkiyatOnayGorunur)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _sevkiyataOnayla(siparis),
                                    icon: const Icon(Icons.local_shipping),
                                    label: const Text("Sevkiyat Onayı"),
                                  ),
                                ],
                              ),
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
