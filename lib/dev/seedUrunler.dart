import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:capri/mock/mock_urun_listesi.dart'; // liste
// Urun modeliniz zaten toMap() içeriyor

Future<void> seedUrunlerBirKerelik() async {
  final db = FirebaseFirestore.instance;

  // Daha önce yapıldı mı?
  final metaRef = db.collection('_meta').doc('seed_urunler_v1');
  if ((await metaRef.get()).exists) {
    debugPrint('Seed zaten yapılmış, atlanıyor.');
    return;
  }

  final batch = db.batch();
  final col = db.collection('urunler');

  for (final u in mockUrunListesi) {
    final docRef = col.doc(u.id.toString()); // docId = "1", "2", ...
    batch.set(docRef, u.toMap()); // merge:false (varsayılan), tertemiz yazar
  }

  batch.set(metaRef, {
    'doneAt': FieldValue.serverTimestamp(),
    'count': mockUrunListesi.length,
    'version': 1,
  });

  await batch.commit();
  debugPrint('Seed tamam: ${mockUrunListesi.length} ürün yazıldı.');
}
