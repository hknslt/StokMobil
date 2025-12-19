import 'package:cloud_firestore/cloud_firestore.dart';

class StockChangeResult {
  final int oldQty;
  final int newQty;
  final int appliedDelta; // clamp sonrası gerçekten uygulanan fark
  final String? historyDocId;

  StockChangeResult({
    required this.oldQty,
    required this.newQty,
    required this.appliedDelta,
    this.historyDocId,
  });
}

class StockChangeService {
  final _db = FirebaseFirestore.instance;

  /// Üründe adet güncelle + stok_gecmis’e hareket ekle — TEK transaction.
  /// delta > 0 => ekle, delta < 0 => azalt. 0'ın altına düşmez.
  Future<StockChangeResult> changeStockAtomic({
    required String urunDocId,
    required int delta,
  }) async {
    assert(delta != 0);

    final urunRef = _db.collection('urunler').doc(urunDocId);
    final hareketRef = urunRef.collection('stok_gecmis').doc();

    return _db.runTransaction<StockChangeResult>((tx) async {
      final snap = await tx.get(urunRef);
      if (!snap.exists) throw StateError('Ürün bulunamadı');

      final data = snap.data() as Map<String, dynamic>;
      final oldQty = (data['adet'] as num?)?.toInt() ?? 0;

      final tentative = oldQty + delta;
      final newQty = tentative < 0 ? 0 : tentative;
      final appliedDelta = newQty - oldQty;
      if (appliedDelta == 0) {
        return StockChangeResult(
          oldQty: oldQty,
          newQty: newQty,
          appliedDelta: 0,
          historyDocId: null,
        );
      }

      // 1) Ürünü güncelle
      tx.update(urunRef, {'adet': newQty});

      // 2) Stok geçmişine SADECE kuralların izin verdiği alanları yaz
      tx.set(hareketRef, {
        'tarih': FieldValue.serverTimestamp(),
        'degisim': appliedDelta,
      });

      return StockChangeResult(
        oldQty: oldQty,
        newQty: newQty,
        appliedDelta: appliedDelta,
        historyDocId: hareketRef.id,
      );
    });
  }
}
