// lib/pages/moduller/sevkiyat_sayfasi/tamamlanan_sevkiyatlar_sayfasi.dart
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/services/siparis_service.dart';

class TamamlananSevkiyatlarSayfasi extends StatelessWidget {
  const TamamlananSevkiyatlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final servis = SiparisService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tamamlanan Sevkiyatlar"),
        backgroundColor: Renkler.kahveTon,
      ),
      body: StreamBuilder<List<SiparisModel>>(
        stream: servis.hepsiDinle(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Hata: ${snap.error}'));
          }
          final tamamlananlar = (snap.data ?? [])
              .where((s) => s.durum == SiparisDurumu.tamamlandi)
              .toList();

          if (tamamlananlar.isEmpty) {
            return const Center(child: Text("Tamamlanmış sevkiyat bulunamadı."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tamamlananlar.length,
            itemBuilder: (context, index) {
              final siparis = tamamlananlar[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    "Müşteri: ${siparis.musteri.firmaAdi ?? '-'} | ${siparis.musteri.yetkili ?? '-'}",
                  ),
                  subtitle: Text("Ürün Sayısı: ${siparis.urunler.length}"),
                  children: siparis.urunler
                      .map((urun) => ListTile(
                            title: Text(urun.urunAdi),
                            trailing: Text("Adet: ${urun.adet}"),
                          ))
                      .toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
