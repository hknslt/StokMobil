// lib/pages/moduller/urun_sayfasi/urun_detay_sayfasi.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/urun_service.dart';

class UrunDetaySayfasi extends StatefulWidget {
  final Urun urun;
  const UrunDetaySayfasi({Key? key, required this.urun}) : super(key: key);

  @override
  State<UrunDetaySayfasi> createState() => _UrunDetaySayfasiState();
}

class _UrunDetaySayfasiState extends State<UrunDetaySayfasi> {
  final _srv = UrunService();
  bool tumGecmisGoster = false;

  // ————— yardımcılar —————

  Widget _imageFor(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.image_not_supported)),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.image_not_supported)),
    );
  }

  /// u.resimYollari + kapakResimYolu’nu tek listede (tekrarsız) birleştirir.
  List<String> _gorselListesi(Urun u) {
    final set = <String>{};
    final list = <String>[];

    final cover = (u.kapakResimYolu ?? '').trim();
    if (cover.isNotEmpty) {
      set.add(cover);
      list.add(cover); // kapak en başta
    }

    final others = u.resimYollari ?? const <String>[];
    for (final p in others) {
      final pp = p.trim();
      if (pp.isEmpty) continue;
      if (set.add(pp)) list.add(pp);
    }
    return list;
  }

  Future<void> _stokGuncelleDialog(Urun u) async {
    final ctrl = TextEditingController();
    final delta = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Stok Güncelle"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Değişim (ör: +5 veya -3)",
            hintText: "Pozitif ekler, negatif düşer",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            onPressed: () {
              final raw = ctrl.text.trim();
              final parsed = int.tryParse(raw.replaceAll('+', ''));
              Navigator.pop(context, parsed);
            },
            child: const Text("Uygula", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (delta == null || delta == 0) return;
    if (u.docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu üründe Firestore docId bulunamadı.")),
      );
      return;
    }

    final yeniAdet = (u.adet + delta) < 0 ? 0 : (u.adet + delta);
    try {
      // 1) stok adet güncelle
      await _srv.guncelle(u.docId!, u.copyWith(adet: yeniAdet));

      // 2) alt koleksiyona hareketi yaz (aktif stok geçmişi)
      await FirebaseFirestore.instance
          .collection('urunler')
          .doc(u.docId!)
          .collection('stok_gecmis')
          .add({
        'tarih': FieldValue.serverTimestamp(),
        'degisim': delta,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stok güncellenemedi: $e")),
      );
    }
  }

  // Firestore'dan stok geçmişi (ALT KOLEKSİYON)
  Widget _stokGecmisiWidget(String? docId) {
    final df = DateFormat('dd MMM yyyy');

    if (docId == null) {
      return const Text("Stok geçmişi için ürün kaydı (docId) bulunamadı.");
    }

    final q = FirebaseFirestore.instance
        .collection('urunler')
        .doc(docId)
        .collection('stok_gecmis')
        .orderBy('tarih', descending: true)
        .limit(tumGecmisGoster ? 50 : 3)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Stok geçmişi okunamadı: ${snap.error}');
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Text("Kayıt yok.");
        }
        return Column(
          children: [
            ...docs.map((d) {
              final m = d.data();
              final degisim = (m['degisim'] as num?)?.toInt() ?? 0;
              final ts = m['tarih'];
              DateTime? tarih;
              if (ts is Timestamp) tarih = ts.toDate();
              if (ts is DateTime) tarih = ts;
              final tStr = tarih != null ? df.format(tarih) : "-";

              return ListTile(
                leading: Icon(
                  degisim >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  color: degisim >= 0 ? Colors.green : Colors.red,
                ),
                title: Text(
                  "${degisim >= 0 ? '+' : ''}$degisim adet",
                  style: TextStyle(color: degisim >= 0 ? Colors.green : Colors.red),
                ),
                subtitle: Text(tStr),
              );
            }),
            if ((snap.data?.size ?? 0) >= 3)
              TextButton(
                onPressed: () => setState(() => tumGecmisGoster = !tumGecmisGoster),
                child: Text(
                  tumGecmisGoster ? "Daha Az Göster" : "Daha Fazla Gör",
                  style: const TextStyle(color: Renkler.kahveTon),
                ),
              ),
          ],
        );
      },
    );
  }

  // ————— UI —————

  @override
  Widget build(BuildContext context) {
    final docId = widget.urun.docId;

    // docId varsa ürünü canlı dinle (adet/resimler vs anında güncellensin)
    if (docId != null) {
      final stream = FirebaseFirestore.instance
          .collection('urunler')
          .doc(docId)
          .snapshots();

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(
                title: const Text("Ürün Detayı"),
                backgroundColor: Renkler.kahveTon,
                centerTitle: true,
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return Scaffold(
              appBar: AppBar(
                title: const Text("Ürün Detayı"),
                backgroundColor: Renkler.kahveTon,
                centerTitle: true,
              ),
              body: const Center(child: Text("Ürün bulunamadı.")),
            );
          }
          final urun = Urun.fromFirestore(snap.data!);
          return _buildBody(urun);
        },
      );
    }

    // docId yoksa, parametreyle gelen ürün verisiyle göster
    return _buildBody(widget.urun);
  }

  Widget _buildBody(Urun u) {
    final gorseller = _gorselListesi(u); // kapak + diğerleri (tekrarsız)

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ürün Detayı"),
        backgroundColor: Renkler.kahveTon,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // RESİM / SLIDER (kapak dahil)
            if (gorseller.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: gorseller.length,
                  controller: PageController(viewportFraction: 0.90),
                  itemBuilder: (context, index) {
                    final p = gorseller[index];
                    final isCover = (u.kapakResimYolu ?? '').trim() == p.trim();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _imageFor(p),
                          ),
                          if (isCover)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Kapak",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                ),
              ),

            const SizedBox(height: 20),

            // ÜRÜN KARTI
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.urunAdi, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text("Kod: ${u.urunKodu}"),
                    Text("Renk: ${u.renk}"),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Stok"),
                        Text(
                          "${u.adet}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Renkler.kahveTon,
                          ),
                        ),
                      ],
                    ),
                    if ((u.aciklama ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text("Açıklama: ${u.aciklama!}"),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // STOK GEÇMİŞİ (aktif)
            Align(
              alignment: Alignment.centerLeft,
              child:
                  Text("Stok Geçmişi", style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            _stokGecmisiWidget(u.docId),

            const SizedBox(height: 20),

            // BUTONLAR
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
                  onPressed: () => _stokGuncelleDialog(u),
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text("Stok Güncelle", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
