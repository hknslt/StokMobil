import 'package:capri/pages/moduller/sevkiyat_sayfasi/utils/sevkiyat_fisi_pdf.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/widgets/siparis_sevkiyat_kart.dart';
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/tamamlanan_sevkiyatlar_sayfasi.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/sevkiyat_duzenle_sayfasi.dart';

class SevkiyatSayfasi extends StatefulWidget {
  const SevkiyatSayfasi({super.key});

  @override
  State<SevkiyatSayfasi> createState() => _SevkiyatSayfasiState();
}

class _SevkiyatSayfasiState extends State<SevkiyatSayfasi> {
  final _siparisServis = SiparisService();
  Stream<List<SiparisModel>>? _sevkiyatStream;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sevkiyatStream = _siparisServis.hepsiDinle();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _fisYazdir(SiparisModel s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SevkiyatFisiSayfasi(siparis: s)),
    );
  }

  Future<void> _teslimEt(SiparisModel s) async {
    if (s.docId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Belge ID bulunamadı.')));
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teslimatı Onayla'),
        content: Text(
          'Bu siparişi teslim ediyorsunuz?\n\nMüşteri: ${s.musteri.firmaAdi ?? '-'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Renkler.kahveTon),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            child: const Text(
              'Evet, Teslim Et',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (onay != true) return;

    await _siparisServis.durumuGuncelle(s.docId!, SiparisDurumu.tamamlandi);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sipariş teslim edildi.')));
  }

  // 💡 Sevkiyatı Düzenle metodu
  void _sevkiyariDuzenle(SiparisModel s) {
    if (s.docId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SevkiyatDuzenleSayfasi(siparis: s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _sevkiyatStream ??= _siparisServis.hepsiDinle();

    return Scaffold(
      appBar: AppBar(
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
        title: const Text('Sevkiyat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rounded, color: Colors.white),
            tooltip: 'Tamamlananlar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TamamlananSevkiyatlarSayfasi(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ——— Arama kutusu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Müşteri / yetkili / açıklama içinde ara…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() {
                          _query = '';
                          _searchCtrl.clear();
                        }),
                        icon: const Icon(Icons.clear),
                      ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ——— Liste
          Expanded(
            child: StreamBuilder<List<SiparisModel>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }

                var data = (snap.data ?? [])
                    .where((s) => s.durum == SiparisDurumu.sevkiyat)
                    .toList();

                if (_query.isNotEmpty) {
                  data = data.where((s) {
                    final firma = (s.musteri.firmaAdi ?? '').toLowerCase();
                    final yetkili = (s.musteri.yetkili ?? '').toLowerCase();
                    final aciklama = (s.aciklama ?? '').toLowerCase();
                    return firma.contains(_query) ||
                        yetkili.contains(_query) ||
                        aciklama.contains(_query);
                  }).toList();
                }

                if (data.isEmpty) {
                  return const Center(
                    child: Text('Sevkiyat bekleyen sipariş bulunamadı.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final s = data[index];
                    return SiparisSevkiyatKart(
                      siparis: s,
                      onTeslimEt: () => _teslimEt(s),
                      onDuzenle: () => _sevkiyariDuzenle(s),
                      onFisYazdir: () => _fisYazdir(s),
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
