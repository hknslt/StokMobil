import 'package:capri/core/Color/Colors.dart';
import 'package:flutter/material.dart';
import 'package:capri/core/models/renk_item.dart';
import 'package:capri/services/renk_service.dart';

class RenkDropdown extends StatelessWidget {
  final String? seciliAd;
  final ValueChanged<String?> onDegisti;
  final VoidCallback onYeniRenk;

  const RenkDropdown({
    super.key,
    required this.seciliAd,
    required this.onDegisti,
    required this.onYeniRenk,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RenkItem>>(
      stream: RenkService.instance.dinle(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Hata oluştu");
        // Veri gelene kadar veya boşsa loading göstermek yerine boş bir dropdown gösterebiliriz
        // ama tutarlılık için progress bar da uygun.
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final renkler = snapshot.data!
            .where((r) => r.ad.trim().isNotEmpty)
            .toList();

        // Tekilleştirme (Case-insensitive)
        final seen = <String>{};
        final tekilRenkler = <RenkItem>[];
        for (final r in renkler) {
          final key = r.ad.trim().toLowerCase();
          if (seen.add(key)) {
            tekilRenkler.add(RenkItem(id: r.id, ad: r.ad.trim()));
          }
        }

        // Seçili değerin listede olup olmadığını kontrol et
        // Eğer listede yoksa (örn: silinmişse veya manuel bir değerse) null yap ki hata vermesin
        final gecerliSecim = tekilRenkler.any((r) => r.ad == seciliAd)
            ? seciliAd
            : null;

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: gecerliSecim,
                decoration: const InputDecoration(
                  labelText: 'Renk',
                  labelStyle: TextStyle(color: Renkler.kahveTon),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                items: [
                  // Temizleme seçeneği
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      "(Renk Seçin)",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ...tekilRenkler.map(
                    (r) => DropdownMenuItem<String>(
                      value: r.ad,
                      child: Text(r.ad),
                    ),
                  ),
                ],
                onChanged: onDegisti,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Renk zorunludur' : null,
              ),
            ),
            const SizedBox(width: 8),
            // Yeni renk ekleme butonu (Dışarı alındı)
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Renkler.kahveTon),
              onPressed: onYeniRenk,
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Yeni Renk Ekle",
            ),
          ],
        );
      },
    );
  }
}
