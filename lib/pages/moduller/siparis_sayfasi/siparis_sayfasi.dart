import 'package:capri/services/siparis_yonetimi/sevkiyat_service.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_oluşturma/siparis_olustur_sayfasi.dart';

// Yeni oluşturduğumuz widget'ları import ediyoruz
import 'widgets/siparis_filtre_bari.dart';
import 'widgets/siparis_karti.dart';

class SiparisSayfasi extends StatefulWidget {
  const SiparisSayfasi({super.key});

  @override
  State<SiparisSayfasi> createState() => _SiparisSayfasiState();
}

class _SiparisSayfasiState extends State<SiparisSayfasi> {
  final siparisServis = SiparisService();
  final sevkiyatServis = SevkiyatService();

  // --- Arama & filtre state ---
  final _aramaCtrl = TextEditingController();
  String _arama = '';
  SiparisDurumu? _durumFiltre;

  // --- Busy State ---
  final Set<String> _busySiparisler = {};
  bool _isBusy(String? id) => id != null && _busySiparisler.contains(id);
  void _setBusy(String? id, bool v) {
    if (id == null) return;
    setState(() {
      if (v) {
        _busySiparisler.add(id);
      } else {
        _busySiparisler.remove(id);
      }
    });
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  // --- AKSİYONLAR (Onayla, Sevkiyat, Reddet) ---
  
  Future<void> _uretimeOnayla(SiparisModel siparis) async {
    final id = siparis.docId;
    if (_isBusy(id)) return;
    _setBusy(id, true);

    // Tarih kontrolü
    bool devamEt = true;
    if (siparis.islemeTarihi != null && siparis.islemeTarihi!.isAfter(DateTime.now())) {
      devamEt = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Erken Onaylama Uyarısı"),
              content: Text("Sipariş işleme tarihiniz: ${DateFormat('dd.MM.yyyy').format(siparis.islemeTarihi!)}\n\nBu siparişi şimdi onaylamak istediğinize emin misiniz?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hayır")),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Evet")),
              ],
            ),
          ) ?? false;
    }
    if (!devamEt) {
      _setBusy(id, false);
      return;
    }

    try {
      final ok = await siparisServis.onaylaVeStokAyir(id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? "Onaylandı: Stok yeterli → Sevkiyat." : "Onaylandı: Stok yetersiz → Üretim."),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      _setBusy(id, false);
    }
  }

  Future<void> _sevkiyataOnayla(SiparisModel siparis) async {
    final id = siparis.docId;
    if (_isBusy(id)) return;
    _setBusy(id, true);

    try {
      final ok = await sevkiyatServis.sevkiyataOnayla(id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? "Sevkiyat onayı başarılı." : "Stok yetersiz."),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      _setBusy(id, false);
    }
  }

  Future<void> _reddet(SiparisModel siparis) async {
    final id = siparis.docId;
    if (_isBusy(id)) return;

    final onay = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Reddetme Onayı"),
            content: const Text("Bu siparişi reddetmek istediğinize emin misiniz?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Reddet", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;

    if (!onay) return;

    _setBusy(id, true);
    try {
      await sevkiyatServis.reddetVeStokIade(id!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sipariş reddedildi.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      _setBusy(id, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sipariş Listesi"),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SiparisOlusturSayfasi()),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Yeni Sipariş", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Renkler.kahveTon,
      ),
      body: Column(
        children: [
          SiparisFiltreBari(
            aramaCtrl: _aramaCtrl,
            aktifDurum: _durumFiltre,
            onAramaChanged: (v) => setState(() => _arama = v.trim().toLowerCase()),
            onDurumChanged: (d) => setState(() => _durumFiltre = d),
            onTemizle: () => setState(() {
              _aramaCtrl.clear();
              _arama = '';
              _durumFiltre = null;
            }),
          ),
          Expanded(
            child: StreamBuilder<List<SiparisModel>>(
              stream: siparisServis.dinle(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) return Center(child: Text('Hata: ${snap.error}'));

                var siparisler = snap.data ?? [];
                if (siparisler.isEmpty) return const Center(child: Text("Henüz sipariş yok."));

                // Filtreleme
                if (_durumFiltre != null) {
                  siparisler = siparisler.where((s) => s.durum == _durumFiltre).toList();
                }
                if (_arama.isNotEmpty) {
                  siparisler = siparisler.where((s) {
                    final musteriAdi = (s.musteri.firmaAdi?.isNotEmpty == true
                            ? s.musteri.firmaAdi!
                            : (s.musteri.yetkili ?? ""))
                        .toLowerCase();
                    final urunMatch = s.urunler.any((u) => u.urunAdi.toLowerCase().contains(_arama));
                    return musteriAdi.contains(_arama) || urunMatch;
                  }).toList();
                }

                if (siparisler.isEmpty) return const Center(child: Text("Sonuç bulunamadı."));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: siparisler.length,
                  itemBuilder: (context, index) {
                    final siparis = siparisler[index];
                    return SiparisKarti(
                      key: ValueKey(siparis.docId), // Performans için key ekledik
                      siparis: siparis,
                      isBusy: _isBusy(siparis.docId),
                      onSevkiyataOnayla: _sevkiyataOnayla,
                      onUretimeOnayla: _uretimeOnayla,
                      onReddet: _reddet,
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