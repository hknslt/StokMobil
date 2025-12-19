import 'package:flutter/material.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/urun_yonetimi/urun_service.dart';
import 'package:capri/core/Color/Colors.dart';

class StoksuzUrunlerWidget extends StatefulWidget {
  const StoksuzUrunlerWidget({super.key});

  @override
  State<StoksuzUrunlerWidget> createState() => _StoksuzUrunlerWidgetState();
}

class _StoksuzUrunlerWidgetState extends State<StoksuzUrunlerWidget> {
  final urunServis = UrunService();
  bool acikMi = false;

  Future<void> _stokEkleDialog(Urun urun) async {
    final adetController = TextEditingController();

    final eklenecek = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("${urun.urunAdi} - Stok Ekle"),
        content: TextField(
          controller: adetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Eklenecek Adet",
            labelStyle: TextStyle(color: Renkler.kahveTon),
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Renkler.kahveTon ,width: 2))
          ),
        ),
        actions: [
          TextButton(
            child: const Text("İptal",style: TextStyle(color: Renkler.kahveTon),),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            child: const Text("Ekle", style: TextStyle(color: Colors.white),),
            onPressed: () {
              final v = int.tryParse(adetController.text);
              Navigator.pop(context, (v != null && v > 0) ? v : null);
            },
          ),
        ],
      ),
    );

    if (eklenecek == null) return;

    try {
      if (urun.docId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Belge kimliği (docId) bulunamadı.")),
        );
        return;
      }
      final yeniAdet = urun.adet + eklenecek;
      await urunServis.guncelle(
        urun.docId!,
        urun.copyWith(adet: yeniAdet),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stok güncellendi: ${urun.urunAdi} = $yeniAdet")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stok güncellenemedi: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Urun>>(
      stream: urunServis.dinle(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Hata: ${snap.error}'),
          );
        }

        final tum = snap.data ?? [];
        final stoksuzUrunler = tum.where((u) => u.adet == 0).toList();

        if (stoksuzUrunler.isEmpty) return const SizedBox();

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: acikMi,
            onExpansionChanged: (val) => setState(() => acikMi = val),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.warning_amber_rounded, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Stokta Olmayan Ürünler",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            subtitle: Text(
              "${stoksuzUrunler.length} ürün",
              style: const TextStyle(color: Colors.grey),
            ),
            children: stoksuzUrunler.map((urun) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_outlined, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(urun.urunAdi, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Renk: ${urun.renk}", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _stokEkleDialog(urun),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text("Stok Ekle", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Renkler.kahveTon,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
