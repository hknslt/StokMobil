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
import 'package:capri/services/fiyat_listesi_service.dart'; // KDV için

class SiparisSayfasi extends StatefulWidget {
  const SiparisSayfasi({super.key});

  @override
  State<SiparisSayfasi> createState() => _SiparisSayfasiState();
}

class _SiparisSayfasiState extends State<SiparisSayfasi> {
  final siparisServis = SiparisService();
  final urunServis = UrunService();
  final fiyatSvc = FiyatListesiService.instance; // aktif KDV

  // --- Arama & filtre state ---
  final _aramaCtrl = TextEditingController();
  String _arama = '';
  SiparisDurumu? _durumFiltre; // null => Tümü

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  bool _busyOnay = false;

  // Eski onay akışı: artık sadece "Üretim Onayı" için kullanıyoruz (beklemede + stok yetersiz)
  Future<void> _uretimeOnayla(SiparisModel siparis) async {
    if (_busyOnay) return;
    setState(() => _busyOnay = true);

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
                  child: const Text("Evet"),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (!devamEt) {
      setState(() => _busyOnay = false);
      return;
    }

    try {
      // stok düşmeden onayla → stok yetersizse durum=uretimde
      final ok = await siparisServis.onayla(siparis.docId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? "Onaylandı: Stok yeterli → Sevkiyat onayı verilebilir."
                : "Onaylandı: Stok yetersiz → Üretime aktarıldı.",
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("İşlem başarısız: $e")));
      }
    } finally {
      setState(() => _busyOnay = false);
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
    // Kullanıcıdan onay iste
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

  // --- küçük yardımcılar (aktif KDV & brüt hesap) ---
  double _aktifKdv() => fiyatSvc.aktifKdv;
  double _brut(double net, double kdvOrani) => net * (1 + kdvOrani / 100);

  // durum -> label
  String _durumLabel(SiparisDurumu? d) {
    switch (d) {
      case null:
        return "Tümü";
      case SiparisDurumu.beklemede:
        return "Beklemede";
      case SiparisDurumu.uretimde:
        return "Üretimde";
      case SiparisDurumu.sevkiyat:
        return "Sevkiyatta";
      case SiparisDurumu.reddedildi:
        return "Reddedildi";
      case SiparisDurumu.tamamlandi:
        return "Tamamlandı";
    }
  }

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

      body: Column(
        children: [
          // ---- Arama & Filtre barı ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                // Arama kutusu
                Expanded(
                  child: TextField(
                    controller: _aramaCtrl,
                    decoration: InputDecoration(
                      hintText: "Müşteri veya ürün ara…",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Renkler.kahveTon,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _arama = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                // Durum filtresi
                DropdownButtonHideUnderline(
                  child: DropdownButton<SiparisDurumu?>(
                    value: _durumFiltre,
                    items:
                        <SiparisDurumu?>[
                              null,
                              SiparisDurumu.beklemede,
                              SiparisDurumu.uretimde,
                              SiparisDurumu.sevkiyat,
                              SiparisDurumu.reddedildi,
                              SiparisDurumu.tamamlandi,
                            ]
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(_durumLabel(d)),
                              ),
                            )
                            .toList(),
                    onChanged: (d) => setState(() => _durumFiltre = d),
                  ),
                ),
                IconButton(
                  tooltip: "Temizle",
                  onPressed: () {
                    setState(() {
                      _aramaCtrl.clear();
                      _arama = '';
                      _durumFiltre = null;
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off),
                ),
              ],
            ),
          ),

          // ---- Liste ----
          Expanded(
            child: StreamBuilder<List<SiparisModel>>(
              stream: siparisServis.dinle(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }

                var siparisler = snap.data ?? [];
                if (siparisler.isEmpty) {
                  return const Center(
                    child: Text(
                      "Henüz sipariş yok.",
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                // filtre: durum
                if (_durumFiltre != null) {
                  siparisler = siparisler
                      .where((s) => s.durum == _durumFiltre)
                      .toList();
                }

                // filtre: arama (müşteri adı veya ürün adı)
                if (_arama.isNotEmpty) {
                  siparisler = siparisler.where((s) {
                    final musteriAdi =
                        (s.musteri.firmaAdi?.isNotEmpty == true
                                ? s.musteri.firmaAdi!
                                : (s.musteri.yetkili ?? ""))
                            .toLowerCase();
                    final urunMatch = s.urunler.any(
                      (u) => u.urunAdi.toLowerCase().contains(_arama),
                    );
                    return musteriAdi.contains(_arama) || urunMatch;
                  }).toList();
                }

                if (siparisler.isEmpty) {
                  return const Center(child: Text("Sonuç bulunamadı."));
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

                    // yalnızca Beklemede/Üretimde iken stok kontrolü + renkli gösterim
                    final stokKontrollu =
                        siparis.durum == SiparisDurumu.beklemede ||
                        siparis.durum == SiparisDurumu.uretimde;

                    // KDV/Toplam
                    final netToplam = (siparis.netTutar ?? siparis.toplamTutar);
                    final kdvOrani = (siparis.kdvOrani ?? _aktifKdv());
                    final brutToplam =
                        (siparis.brutTutar ?? _brut(netToplam, kdvOrani));

                    // 👉 TÜM KARTLARDA stok haritasını çekiyoruz (renk gri de olsa stok adetini göstermek için)
                    return FutureBuilder<Map<int, int>>(
                      future: urunServis.getStocksByNumericIds(numericIds),
                      builder: (context, stokSnap) {
                        final stokHaritasi = stokSnap.data ?? {};
                        final stokYeterli = siparis.urunler.every((su) {
                          final id = int.tryParse(su.id);
                          final mevcut = id == null
                              ? 0
                              : (stokHaritasi[id] ?? 0);
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
                                              builder: (_) =>
                                                  SiparisDetaySayfasi(
                                                    siparis: siparis,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          if (stokKontrollu)
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
                                            ),
                                        ],
                                      ),
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

                                    final netSatirToplam = urun.toplamFiyat;
                                    final brutSatirToplam = _brut(
                                      netSatirToplam,
                                      kdvOrani,
                                    );

                                    // renk seçimi
                                    final renk = stokKontrollu
                                        ? (yeterli ? Colors.green : Colors.red)
                                        : Colors.grey;

                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: renk,
                                        child: Text(
                                          "${urun.adet}x",
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        "${urun.urunAdi} | ${urun.renk != null && urun.renk!.isNotEmpty ? "${urun.renk}" : ""}",
                                        style: TextStyle(
                                          color: renk,
                                          fontWeight: stokKontrollu && !yeterli
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "Stok: $mevcut  |  Net ₺${netSatirToplam.toStringAsFixed(2)}"
                                        "  |  KDV %${kdvOrani.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
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
                                  child: SiparisDurumEtiketi(
                                    durum: siparis.durum,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Aksiyon satırı: bağlamsal buton + Reddet (her zaman)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // SOL: bağlamsal aksiyon
                                    if (siparis.durum ==
                                        SiparisDurumu.beklemede) ...[
                                      if (stokYeterli)
                                        ElevatedButton.icon(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                WidgetStatePropertyAll(
                                                  Colors.green,
                                                ),
                                          ),
                                          onPressed: () =>
                                              _sevkiyataOnayla(siparis),
                                          icon: const Icon(
                                            Icons.local_shipping,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            "Sevkiyat Onayı",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else
                                        ElevatedButton.icon(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                WidgetStatePropertyAll(
                                                  Colors.green,
                                                ),
                                          ),
                                          onPressed: _busyOnay
                                              ? null
                                              : () => _uretimeOnayla(siparis),
                                          icon: const Icon(
                                            Icons.build,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            "Üretim Onayı",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                    ] else if (siparis.durum ==
                                        SiparisDurumu.uretimde) ...[
                                      if (stokYeterli)
                                        ElevatedButton.icon(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                WidgetStatePropertyAll(
                                                  Colors.green,
                                                ),
                                          ),
                                          onPressed: () =>
                                              _sevkiyataOnayla(siparis),
                                          icon: const Icon(
                                            Icons.local_shipping,
                                            color: Colors.white,
                                          ),
                                          label: const Text(
                                            "Sevkiyat Onayı",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      else
                                        TextButton.icon(
                                          onPressed: null,
                                          icon: const Icon(
                                            Icons.more_time,
                                            color: Renkler.acikGri,
                                          ),
                                          label: const Text(
                                            "Üretim Bekleniyor",
                                            style: TextStyle(
                                              color: Renkler.acikGri,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                    ],

                                    if (siparis.durum !=
                                            SiparisDurumu.tamamlandi &&
                                        siparis.durum !=
                                            SiparisDurumu.reddedildi)
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
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
