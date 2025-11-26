import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/pages/moduller/uretim_sayfasi/uretim_models_controller.dart';
import 'package:capri/services/urun_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class UretimDialogs {
  
  /// Belirli bir eksik grup (ürün) için hızlı stok ekleme dialogu
  static Future<void> showGrupStokEkle(
    BuildContext context,
    EksikGrup grp,
    List<Urun> tumUrunler,
  ) async {
    final adetCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isBusy = false;
        return StatefulBuilder(
          builder: (localCtx, setLocal) => AlertDialog(
            title: Text("${grp.urunAdi} Stok Ekle"),
            content: TextField(
              controller: adetCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Eklenecek Adet (Eksik: ${grp.toplamEksik})",
                labelStyle: TextStyle(color: Renkler.kahveTon),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Renkler.kahveTon, width: 2)),
              ),
              enabled: !isBusy,
            ),
            actions: [
              TextButton(
                onPressed: isBusy ? null : () => Navigator.pop(dialogCtx),
                child: const Text("İptal", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
                onPressed: isBusy ? null : () async {
                  final ek = int.tryParse(adetCtrl.text.trim()) ?? 0;
                  if (ek <= 0) return;

                  setLocal(() => isBusy = true);
                  try {
                    final urun = tumUrunler.firstWhereOrNull((u) => u.id == grp.urunId);
                    if (urun?.docId != null) {
                      await UrunService().adetArtir(urun!.docId!, ek);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${grp.urunAdi} +$ek eklendi.")),
                        );
                      }
                      if (localCtx.mounted) Navigator.pop(dialogCtx);
                    }
                  } catch (e) {
                    if (localCtx.mounted) setLocal(() => isBusy = false);
                  }
                },
                child: isBusy 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Ekle", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Genel stok ekleme (arama yaparak)
  static Future<void> showGenelStokEkle(BuildContext context, List<Urun> urunler) async {
    final adetCtrl = TextEditingController();
    Urun? secilen;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isBusy = false;
        late TextEditingController typeAheadCtrl;

        return StatefulBuilder(
          builder: (localCtx, setLocal) => AlertDialog(
            title: const Text("Genel Stok Ekle"),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TypeAheadField<Urun>(
                    debounceDuration: const Duration(milliseconds: 300),
                    suggestionsCallback: (pattern) {
                      final p = pattern.trim().toLowerCase();
                      if (p.isEmpty) return urunler.take(20).toList();
                      return urunler.where((u) => 
                        u.urunAdi.toLowerCase().contains(p) || (u.renk ?? '').toLowerCase().contains(p)
                      ).take(20).toList();
                    },
                    itemBuilder: (_, u) => ListTile(
                      dense: true,
                      title: Text(u.urunAdi),
                      subtitle: Text("Renk: ${u.renk ?? '-'} | Mevcut: ${u.adet}"),
                    ),
                    onSelected: (u) {
                      secilen = u;
                      typeAheadCtrl.text = "${u.urunAdi} ${u.renk != null ? '(${u.renk})' : ''}";
                    },
                    builder: (ctx, controller, focusNode) {
                      typeAheadCtrl = controller;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: "Ürün Ara",
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: adetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Adet",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
                onPressed: isBusy ? null : () async {
                  final ek = int.tryParse(adetCtrl.text.trim()) ?? 0;
                  if (secilen == null || ek <= 0 || secilen!.docId == null) return;

                  setLocal(() => isBusy = true);
                  try {
                    await UrunService().adetArtir(secilen!.docId!, ek);
                    if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("${secilen!.urunAdi} +$ek eklendi.")),
                        );
                    }
                    Navigator.pop(dialogCtx);
                  } catch (e) {
                    setLocal(() => isBusy = false);
                  }
                },
                child: isBusy 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Ekle", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}