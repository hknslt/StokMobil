import 'package:capri/pages/moduller/urun_sayfasi/urun_detay/utils/stock_change_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/stock_change_service.dart';


final _stockSvc = StockChangeService();

Future<void> gosterVeStokGuncelle({
  required BuildContext context,
  required Urun urun,
}) async {
  final input = await showStockChangeSheet(context);
  if (input == null) return;

  try {
    final res = await _stockSvc.changeStockAtomic(
      urunDocId: urun.docId!,
      delta: input.delta,
    );

    if (!context.mounted) return;
    if (res.appliedDelta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok değişmedi (0 altına düşmez).')),
      );
      return;
    }

    final oldToNew = '${res.oldQty} → ${res.newQty}';
    final applied = res.appliedDelta > 0 ? '+${res.appliedDelta}' : '${res.appliedDelta}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stok güncellendi: $oldToNew ($applied)'),
        action: SnackBarAction(
          label: 'Geri Al',
          textColor: Renkler.kahveTon,
          onPressed: () async {
            try {
              await _stockSvc.changeStockAtomic(
                urunDocId: urun.docId!,
                delta: -res.appliedDelta,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Geri alındı.')),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Geri alma başarısız: $e')),
              );
            }
          },
        ),
      ),
    );
  } on FirebaseException catch (e) {
    final msg = e.code == 'permission-denied'
        ? 'İzin yok. Kuralları/rolü ve oturum durumunu kontrol et.'
        : (e.message ?? e.toString());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Stok güncellenemedi: $e')),
    );
  }
}
