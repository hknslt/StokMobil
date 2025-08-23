import 'package:capri/mock/mock_musteri_listesi.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Bir kerelik müşteri seed'i.
/// Çalıştırdıktan sonra bu çağrıyı KALDIR.
Future<void> runMusteriSeeding() async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();

  for (final m in mockMusteriler) {
    final ref = db
        .collection('musteriler')
        .doc(m.id); // docId olarak id'yi kullan
    batch.set(ref, {
      'id': m.id,
      'firmaAdi': m.firmaAdi,
      'firmaAdiLower': (m.firmaAdi ?? '').toLowerCase(),
      // aramalarda kolaylık
      'yetkili': m.yetkili,
      'telefon': m.telefon,
      'adres': m.adres,
      'createdAt': FieldValue.serverTimestamp(),
      'guncel': true,
    }, SetOptions(merge: true));
  }

  await batch.commit();
}
