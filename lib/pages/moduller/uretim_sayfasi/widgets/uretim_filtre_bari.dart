import 'package:capri/core/Color/Colors.dart';
import 'package:capri/pages/moduller/uretim_sayfasi/uretim_models_controller.dart';
import 'package:flutter/material.dart';

class UretimFiltreBari extends StatelessWidget {
  final TextEditingController aramaCtrl;
  final UretimSiralama siralama;
  final ValueChanged<UretimSiralama?> onSiralamaChanged;
  final VoidCallback onClear;

  const UretimFiltreBari({
    super.key,
    required this.aramaCtrl,
    required this.siralama,
    required this.onSiralamaChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Arama
        TextField(
          controller: aramaCtrl,
          decoration: InputDecoration(
            labelText: 'Ürün veya Müşteri Ara',
            labelStyle: TextStyle(color: Renkler.kahveTon),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: onClear,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        
        // Sıralama Başlığı ve Dropdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Eksik İstek Listesi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<UretimSiralama>(
                  value: siralama,
                  icon: const Icon(Icons.sort),
                  onChanged: onSiralamaChanged,
                  items: UretimSiralama.values.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.displayName, style: const TextStyle(fontSize: 13)),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}