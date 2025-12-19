import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/services/urun_yonetimi/grup_service.dart';

class GrupDropdown extends StatelessWidget {
  final String? seciliAd;
  final ValueChanged<String?> onDegisti;
  final VoidCallback onYeniGrup;

  const GrupDropdown({
    super.key,
    required this.seciliAd,
    required this.onDegisti,
    required this.onYeniGrup,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: GrupService.instance.dinle(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text("Hata oluştu");
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final gruplar = snapshot.data!;
        
        // Eğer seçili grup listede yoksa (örn: silindiyse) null yap
        final gecerliSecim = (seciliAd != null && gruplar.contains(seciliAd)) 
            ? seciliAd 
            : null;

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: gecerliSecim,
                decoration: const InputDecoration(
                  labelText: 'Grup',
                  labelStyle: TextStyle(color: Renkler.kahveTon),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: [
                  // Temizleme seçeneği
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text("(Grup Yok)", style: TextStyle(color: Colors.grey)),
                  ),
                  ...gruplar.map((g) => DropdownMenuItem<String>(
                        value: g,
                        child: Text(g),
                      ))
                ],
                onChanged: onDegisti,
              ),
            ),
            const SizedBox(width: 8),
            // Yeni grup ekleme butonu
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Renkler.kahveTon),
              onPressed: onYeniGrup,
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: "Yeni Grup Ekle",
            ),
          ],
        );
      },
    );
  }
}