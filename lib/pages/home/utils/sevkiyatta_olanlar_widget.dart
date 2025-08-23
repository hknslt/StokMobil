// lib/pages/home/admin/sevkiyatta_olanlar_widget.dart
import 'package:flutter/material.dart';
import 'package:capri/pages/home/utils/siparis_kart.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/core/models/siparis_model.dart';

class SevkiyattaOlanlarWidget extends StatelessWidget {
  const SevkiyattaOlanlarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SiparisModel>>(
      stream: SiparisService().hepsiDinle(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // veya CircularProgressIndicator()
        }
        if (snap.hasError) {
          return Text('Hata: ${snap.error}');
        }

        final liste = (snap.data ?? [])
            .where((s) => s.durum == SiparisDurumu.sevkiyat)
            .toList();

        if (liste.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Sevkiyat Bekleyenler",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...liste.map((s) => SiparisKart(siparis: s, renk: Colors.green)),
          ],
        );
      },
    );
  }
}
