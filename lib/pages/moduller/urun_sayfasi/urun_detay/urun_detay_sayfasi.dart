import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/utils/gorsel_listesi_olustur.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/widgets/stok_gecmisi_listesi.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/widgets/stok_guncelle.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/widgets/urun_gorsel_slider.dart';
import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/widgets/urun_karti.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/urun_service.dart';

class UrunDetaySayfasi extends StatelessWidget {
  final Urun urun;
  UrunDetaySayfasi({super.key, required this.urun});

  final _srv = UrunService();

  @override
  Widget build(BuildContext context) {
    final docId = urun.docId;

    if (docId != null) {
      final stream = FirebaseFirestore.instance
          .collection('urunler')
          .doc(docId)
          .snapshots(includeMetadataChanges: false);

      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _buildScaffold(
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return _buildScaffold(
              body: const Center(child: Text("Ürün bulunamadı veya silindi.")),
            );
          }

          // Firestore'dan gelen güncel veriyle (Grup dahil) modeli oluştur
          final u = Urun.fromFirestore(snap.data!);
          return _UrunDetayIcerik(urun: u, srv: _srv);
        },
      );
    }

    return _UrunDetayIcerik(urun: urun, srv: _srv);
  }

  Scaffold _buildScaffold({required Widget body}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ürün Detayı"),
        backgroundColor: Renkler.kahveTon,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: body,
    );
  }
}

class _UrunDetayIcerik extends StatelessWidget {
  final Urun urun;
  final UrunService srv;
  const _UrunDetayIcerik({required this.urun, required this.srv});

  @override
  Widget build(BuildContext context) {
    final gorseller = gorselListesiOlustur(urun);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ürün Detayı"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (gorseller.isNotEmpty)
              UrunGorselSlider(
                key: ValueKey('slider_${urun.docId ?? urun.urunKodu}'),
                gorseller: gorseller,
                kapak: (urun.kapakResimYolu ?? '').trim(),
                stableId: (urun.docId ?? urun.urunKodu) ?? 'noid',
              )
            else
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            UrunKarti(urun: urun),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Stok Geçmişi",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Renkler.kahveTon,
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (urun.docId != null)
              StokGecmisiListesi(docId: urun.docId!)
            else
              const Text("Stok geçmişi için ürün kaydı (docId) bulunamadı."),

            const SizedBox(height: 20),

            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Renkler.kahveTon,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      gosterVeStokGuncelle(context: context, urun: urun),
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    'Stok Güncelle',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30), 
          ],
        ),
      ),
    );
  }
}
