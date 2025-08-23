// lib/pages/moduller/sevkiyat_sayfasi/sevkiyat_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/tamamlanan_sevkiyatlar_sayfasi.dart';
import 'package:capri/services/siparis_service.dart';

class SevkiyatSayfasi extends StatefulWidget {
  const SevkiyatSayfasi({super.key});

  @override
  State<SevkiyatSayfasi> createState() => _SevkiyatSayfasiState();
}

class _SevkiyatSayfasiState extends State<SevkiyatSayfasi> {
  final _siparisServis = SiparisService();

  Future<void> _teslimEt(SiparisModel s) async {
    if (s.docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belge ID bulunamadı.')),
      );
      return;
    }
    await _siparisServis.durumuGuncelle(s.docId!, SiparisDurumu.tamamlandi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Renkler.kahveTon,
        title: const Text("Sevkiyat"),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rounded, color: Colors.white),
            tooltip: "Tamamlananlar",
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
      body: StreamBuilder<List<SiparisModel>>(
        stream: _siparisServis.hepsiDinle(), // Firestore -> tüm siparişler
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          final sevkiyatListesi = (snap.data ?? [])
              .where((s) => s.durum == SiparisDurumu.sevkiyat)
              .toList();

          if (sevkiyatListesi.isEmpty) {
            return const Center(child: Text("Sevkiyat bekleyen sipariş bulunamadı."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sevkiyatListesi.length,
            itemBuilder: (context, index) {
              final siparis = sevkiyatListesi[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    "Müşteri: ${siparis.musteri.firmaAdi ?? '-'} | ${siparis.musteri.yetkili ?? '-'}",
                  ),
                  subtitle: Text("Ürün Sayısı: ${siparis.urunler.length}"),
                  children: [
                    ...siparis.urunler.map(
                      (urun) => ListTile(
                        title: Text(urun.urunAdi),
                        subtitle: Text(urun.renk),
                        trailing: Text("Adet: ${urun.adet}",
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: () => _teslimEt(siparis),
                          icon: const Icon(Icons.check_circle, color: Colors.white),
                          label: const Text("Teslim Et",
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
