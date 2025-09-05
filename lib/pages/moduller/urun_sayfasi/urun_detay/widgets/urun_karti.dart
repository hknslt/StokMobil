import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';

class UrunKarti extends StatelessWidget {
  final Urun urun;
  const UrunKarti({super.key, required this.urun});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(urun.urunAdi, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text("Kod: ${urun.urunKodu}"),
            Text("Renk: ${urun.renk}"),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Stok"),
                Text(
                  "${urun.adet}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Renkler.kahveTon,
                  ),
                ),
              ],
            ),
            if ((urun.aciklama ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("Açıklama: ${urun.aciklama!}"),
            ],
          ],
        ),
      ),
    );
  }
}
