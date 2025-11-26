import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/pages/moduller/uretim_sayfasi/uretim_models_controller.dart';
import 'package:capri/pages/moduller/uretim_sayfasi/utils/uretim_dialogs.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UretimKarti extends StatelessWidget {
  final EksikGrup grup;
  final List<Urun> tumUrunler;

  const UretimKarti({
    super.key,
    required this.grup,
    required this.tumUrunler,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: PageStorageKey('uretim-${grup.urunId}-${grup.renk}'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: Text(
            "${grup.firmalar.length}",
            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          "${grup.urunAdi} ${grup.renk.isNotEmpty ? '(${grup.renk})' : ''}",
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        subtitle: Text(
          "Toplam Eksik: ${grup.toplamEksik} Adet",
          style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
        ),
        trailing: FilledButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text("Stok"),
          style: FilledButton.styleFrom(
            backgroundColor: Renkler.kahveTon,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => UretimDialogs.showGrupStokEkle(context, grup, tumUrunler),
        ),
        children: grup.firmalar.map((istek) {
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.subdirectory_arrow_right, size: 18, color: Colors.grey),
            title: Text(
              istek.musteriAdi,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${DateFormat('dd.MM.yyyy').format(istek.siparisTarihi)} • ${istek.aciklama}",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                "-${istek.eksikAdet}",
                style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}