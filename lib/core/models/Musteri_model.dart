import 'package:cloud_firestore/cloud_firestore.dart';

class MusteriModel {
  final String id;
  final String? firmaAdi;
  final String? yetkili;
  final String? telefon;
  final String? adres;
  final bool guncel; 

  const MusteriModel({
    required this.id,
    this.firmaAdi,
    this.yetkili,
    this.telefon,
    this.adres,
    this.guncel = true, 
  });

  MusteriModel copyWith({
    String? id,
    String? firmaAdi,
    String? yetkili,
    String? telefon,
    String? adres,
    bool? guncel,
  }) {
    return MusteriModel(
      id: id ?? this.id,
      firmaAdi: firmaAdi ?? this.firmaAdi,
      yetkili: yetkili ?? this.yetkili,
      telefon: telefon ?? this.telefon,
      adres: adres ?? this.adres,
      guncel: guncel ?? this.guncel,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firmaAdi': firmaAdi,
        'yetkili': yetkili,
        'telefon': telefon,
        'adres': adres,
        'guncel': guncel, 
      };

  factory MusteriModel.fromMap(Map<String, dynamic> map) => MusteriModel(
        id: (map['id'] as String?) ?? '',
        firmaAdi: map['firmaAdi'] as String?,
        yetkili: map['yetkili'] as String?,
        telefon: map['telefon'] as String?,
        adres: map['adres'] as String?,
        guncel: (map['guncel'] as bool?) ?? true, 
      );

  factory MusteriModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return MusteriModel(
      id: (data['id'] as String?) ?? doc.id,
      firmaAdi: data['firmaAdi'] as String?,
      yetkili: data['yetkili'] as String?,
      telefon: data['telefon'] as String?,
      adres: data['adres'] as String?,
      guncel: (data['guncel'] as bool?) ?? true, 
    );
  }
}
