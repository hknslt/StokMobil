
import 'package:flutter/material.dart';
import 'package:capri/pages/home/utils/siparis_kart.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/core/models/siparis_model.dart';

class UretimdeOlanlarWidget extends StatelessWidget {
  const UretimdeOlanlarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SiparisModel>>(
      stream: SiparisService().hepsiDinle(), 
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final liste = (snap.data ?? [])
            .where((s) => s.durum == SiparisDurumu.uretimde)
            .toList();

        if (liste.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Üretimde Olanlar",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...liste.map((s) => SiparisKart(siparis: s, renk: Colors.orange)),
          ],
        );
      },
    );
  }
}
