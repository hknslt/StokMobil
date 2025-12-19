import 'package:cloud_firestore/cloud_firestore.dart';

class GrupService {
  // Singleton
  static final GrupService instance = GrupService._internal();
  GrupService._internal();

  final CollectionReference _col =
      FirebaseFirestore.instance.collection('gruplar');

  /// Grupları isim sırasına göre dinle
  Stream<List<String>> dinle() {
    return _col.orderBy('adLower').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['ad'] ?? '') as String;
      }).toList();
    });
  }

  /// Yeni grup ekle
  Future<void> ekle(String ad) async {
    final adLower = ad.trim().toLowerCase();
    
    // Aynı isimde var mı kontrol et
    final varMi = await _col.where('adLower', isEqualTo: adLower).get();
    if (varMi.docs.isNotEmpty) {
      throw Exception("Bu grup zaten mevcut.");
    }

    await _col.add({
      'ad': ad.trim(),
      'adLower': adLower,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  /// Grup sil
  Future<void> sil(String ad) async {
     final snapshot = await _col.where('ad', isEqualTo: ad).get();
     for (var doc in snapshot.docs) {
       await doc.reference.delete();
     }
  }
}