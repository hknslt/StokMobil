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
            // Ürün Adı
            Text(
              urun.urunAdi,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 8),
            
            // Detay Bilgiler (Kod, Grup, Renk)
            _buildDetaySatir("Kod", urun.urunKodu),
            _buildDetaySatir("Grup", urun.grup ?? '-'), // ✅ EKLENDİ
            _buildDetaySatir("Renk", urun.renk),
            
            const Divider(height: 24),
            
            // Stok Bilgisi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mevcut Stok",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  "${urun.adet}",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Renkler.kahveTon,
                  ),
                ),
              ],
            ),
            
            // Açıklama
            if ((urun.aciklama ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Açıklama:",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                urun.aciklama!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Satırları düzenli göstermek için yardımcı metod
  Widget _buildDetaySatir(String baslik, String deger) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              "$baslik:",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              deger,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}