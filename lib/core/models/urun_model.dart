// lib/core/models/urun_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Urun {
  final String? docId;            // <-- Firestore belge id'si
  final int id;                   // numeric id (bizde gerekli)
  final String urunKodu;
  final String urunAdi;
  final String renk;
  final int adet;
  final String? aciklama;
  final List<String>? resimYollari;
  final String? kapakResimYolu;

  Urun({
    this.docId,
    required this.id,
    required this.urunKodu,
    required this.urunAdi,
    required this.renk,
    required this.adet,
    this.aciklama,
    this.resimYollari,
    this.kapakResimYolu,
  });

  Urun copyWith({
    String? docId,
    int? id,
    String? urunKodu,
    String? urunAdi,
    String? renk,
    int? adet,
    String? aciklama,
    List<String>? resimYollari,
    String? kapakResimYolu,
  }) {
    return Urun(
      docId: docId ?? this.docId,
      id: id ?? this.id,
      urunKodu: urunKodu ?? this.urunKodu,
      urunAdi: urunAdi ?? this.urunAdi,
      renk: renk ?? this.renk,
      adet: adet ?? this.adet,
      aciklama: aciklama ?? this.aciklama,
      resimYollari: resimYollari ?? this.resimYollari,
      kapakResimYolu: kapakResimYolu ?? this.kapakResimYolu,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'urunKodu': urunKodu,
      'urunAdi': urunAdi,
      'renk': renk,
      'adet': adet,
      'aciklama': aciklama,
      'resimYollari': resimYollari,
      'kapakResimYolu': kapakResimYolu,
    };
  }

  factory Urun.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Urun(
      docId: docId,
      id: (map['id'] as num).toInt(),
      urunKodu: (map['urunKodu'] ?? '') as String,
      urunAdi: (map['urunAdi'] ?? '') as String,
      renk: (map['renk'] ?? '') as String,
      adet: (map['adet'] as num?)?.toInt() ?? 0,
      aciklama: map['aciklama'] as String?,
      resimYollari: (map['resimYollari'] as List?)?.cast<String>(),
      kapakResimYolu: map['kapakResimYolu'] as String?,
    );
  }

  factory Urun.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Urun.fromMap(data, docId: doc.id);
  }

  
}
