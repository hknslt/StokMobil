// lib/pages/home/admin/siparis_kart.dart
import 'package:flutter/material.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';

class SiparisKart extends StatelessWidget {
  final SiparisModel siparis;
  final Color renk;

  const SiparisKart({super.key, required this.siparis, required this.renk});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: renk,
          child: const Icon(Icons.assignment, color: Colors.white),
        ),
        title: Text(
          "${siparis.musteri.firmaAdi} - ${siparis.musteri.yetkili}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text("Ürün Sayısı: ${siparis.urunler.length}"),
        trailing: SiparisDurumEtiketi(durum: siparis.durum)
      ),
    );
  }
}
