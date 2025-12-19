import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/renk_item.dart';
import 'package:capri/services/altyapi/log_service.dart';

class RenkService {
  RenkService._();
  static final RenkService instance = RenkService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('renkler');

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

  /// Sadece ad listesi stream’i (autocomplete vb. için)
  Stream<List<String>> dinleAdlar() {
    return _col.orderBy('adLower').snapshots().map((qs) {
      return qs.docs
          .map((d) => ((d.data()['ad'] as String?) ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
    });
  }

  /// Yeni renk ekle
  Future<void> ekle(String ad) async {
    final name = ad.trim();
    if (name.isEmpty) return;

    // aynı isim varsa tekrar ekleme
    final q = await _col.where('adLower', isEqualTo: name.toLowerCase()).limit(1).get();
    if (q.docs.isNotEmpty) return;

    final ref = await _col.add({
      'ad': name,
      'adLower': name.toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // LOG: renk_eklendi
    try {
      await LogService.instance.log(
        action: 'renk_eklendi',
        target: {'type': 'renk', 'docId': ref.id},
        meta: {'ad': name},
      );
    } catch (_) {}
  }

  /// Sil
  Future<void> sil(String id) async {
    String? ad;
    try {
      final snap = await _col.doc(id).get();
      ad = (snap.data()?['ad'] as String?)?.trim();
    } catch (_) {}

    await _col.doc(id).delete();

    // LOG: renk_silindi
    try {
      await LogService.instance.log(
        action: 'renk_silindi',
        target: {'type': 'renk', 'docId': id},
        meta: {if (ad != null && ad.isNotEmpty) 'ad': ad},
      );
    } catch (_) {}
  }
}
