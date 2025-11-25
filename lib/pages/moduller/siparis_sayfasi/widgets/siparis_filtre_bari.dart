import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:flutter/material.dart';

class SiparisFiltreBari extends StatelessWidget {
  final TextEditingController aramaCtrl;
  final SiparisDurumu? aktifDurum;
  final Function(String) onAramaChanged;
  final Function(SiparisDurumu?) onDurumChanged;
  final VoidCallback onTemizle;

  const SiparisFiltreBari({
    super.key,
    required this.aramaCtrl,
    required this.aktifDurum,
    required this.onAramaChanged,
    required this.onDurumChanged,
    required this.onTemizle,
  });

  String _durumLabel(SiparisDurumu? d) {
    switch (d) {
      case null:
        return "Tümü";
      case SiparisDurumu.beklemede:
        return "Beklemede";
      case SiparisDurumu.uretimde:
        return "Üretimde";
      case SiparisDurumu.sevkiyat:
        return "Sevkiyatta";
      case SiparisDurumu.reddedildi:
        return "Reddedildi";
      case SiparisDurumu.tamamlandi:
        return "Tamamlandı";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          // Arama kutusu
          Expanded(
            child: TextField(
              controller: aramaCtrl,
              decoration: InputDecoration(
                hintText: "Müşteri veya ürün ara…",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Renkler.kahveTon,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                isDense: true,
              ),
              onChanged: onAramaChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Durum filtresi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SiparisDurumu?>(
                value: aktifDurum,
                icon: const Icon(Icons.filter_list),
                items: [
                  null,
                  SiparisDurumu.beklemede,
                  SiparisDurumu.uretimde,
                  SiparisDurumu.sevkiyat,
                  SiparisDurumu.reddedildi,
                  SiparisDurumu.tamamlandi,
                ].map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(
                      _durumLabel(d),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: onDurumChanged,
              ),
            ),
          ),
          IconButton(
            tooltip: "Filtreleri Temizle",
            onPressed: onTemizle,
            icon: const Icon(Icons.filter_alt_off),
          ),
        ],
      ),
    );
  }
}