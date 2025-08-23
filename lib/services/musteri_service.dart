import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capri/core/models/musteri_model.dart';

class MusteriService {
  MusteriService._();
  static final MusteriService instance = MusteriService._();

  final _col = FirebaseFirestore.instance.collection('musteriler');

  /// Canlı liste
  Stream<List<MusteriModel>> dinle() {
    // Firma adı zorunlu verdiğin için orderBy güvenli.
    return _col
        .orderBy('firmaAdi')
        .snapshots()
        .map(
          (qs) => qs.docs.map((d) => MusteriModel.fromFirestore(d)).toList(),
        );
  }

  /// Tek seferlik getir
  Future<List<MusteriModel>> onceGetir() async {
    final qs = await _col.orderBy('firmaAdi').get();
    return qs.docs.map((d) => MusteriModel.fromFirestore(d)).toList();
  }

  /// Ekle (docId == id olacak şekilde kaydeder)
  Future<String> ekle(MusteriModel m) async {
    final ref = _col.doc();
    await ref.set({
      ...m.toMap(),
      'id': ref.id, // belge içindeki id alanını da doldur
    });
    return ref.id;
  }

  /// Güncelle
  Future<void> guncelle(MusteriModel m) async {
    await _col.doc(m.id).set(m.toMap(), SetOptions(merge: true));
  }

  /// Sil
  Future<void> sil(String id) async {
    await _col.doc(id).delete();
  }
}
