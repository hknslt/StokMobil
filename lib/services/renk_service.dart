// lib/services/renk_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/renk_item.dart';

class RenkService {
  RenkService._();
  static final RenkService instance = RenkService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('renkler');

  /// Firestore 'renkler' koleksiyonunu dinler (sadece ad alanı)
  Stream<List<RenkItem>> dinle() {
    return _col.orderBy('adLower').snapshots().map((qs) {
      return qs.docs
          .map((d) {
            final data = d.data();
            final ad = (data['ad'] as String?)?.trim() ?? '';
            return RenkItem(id: d.id, ad: ad);
          })
          .where((r) => r.ad.isNotEmpty)
          .toList();
    });
  }

  /// Yeni renk ekle (positional parametre)
  Future<void> ekle(String ad) async {
    final name = ad.trim();
    if (name.isEmpty) return;
    // aynı isim varsa tekrar ekleme
    final q = await _col
        .where('adLower', isEqualTo: name.toLowerCase())
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) return;

    await _col.add({
      'ad': name,
      'adLower': name.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // lib/services/renk_service.dart (içine ekle)
  Stream<List<String>> dinleAdlar() {
    return _col.orderBy('adLower').snapshots().map((qs) {
      return qs.docs
          .map((d) => ((d.data()['ad'] as String?) ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
    });
  }

  Future<void> sil(String id) => _col.doc(id).delete();
}
