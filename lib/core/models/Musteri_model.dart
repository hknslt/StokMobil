import 'package:cloud_firestore/cloud_firestore.dart';

class MusteriModel {
  final String id;
  final int? idNum; // 💡 YENİ: Masaüstü ile uyum için eklendi
  final String? firmaAdi;
  final String? yetkili;
  final String? telefon;
  final String? adres;
  final bool guncel;
  final DateTime? createdAt; // 💡 YENİ: Masaüstü ile uyum için eklendi

  const MusteriModel({
    required this.id,
    this.idNum,
    this.firmaAdi,
    this.yetkili,
    this.telefon,
    this.adres,
    this.guncel = true,
    this.createdAt,
  });

  MusteriModel copyWith({
    String? id,
    int? idNum,
    String? firmaAdi,
    String? yetkili,
    String? telefon,
    String? adres,
    bool? guncel,
    DateTime? createdAt,
  }) {
    return MusteriModel(
      id: id ?? this.id,
      idNum: idNum ?? this.idNum,
      firmaAdi: firmaAdi ?? this.firmaAdi,
      yetkili: yetkili ?? this.yetkili,
      telefon: telefon ?? this.telefon,
      adres: adres ?? this.adres,
      guncel: guncel ?? this.guncel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'firmaAdi': firmaAdi,
      'yetkili': yetkili,
      'telefon': telefon,
      'adres': adres,
      'guncel': guncel,
    };

    if (idNum != null) map['idNum'] = idNum;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);

    return map;
  }

  factory MusteriModel.fromMap(Map<String, dynamic> map) => MusteriModel(
    id: (map['id'] as String?) ?? '',
    idNum: (map['idNum'] as num?)?.toInt(),
    firmaAdi: map['firmaAdi'] as String?,
    yetkili: map['yetkili'] as String?,
    telefon: map['telefon'] as String?,
    adres: map['adres'] as String?,
    guncel: (map['guncel'] as bool?) ?? true,
    createdAt: map['createdAt'] != null
        ? (map['createdAt'] as Timestamp).toDate()
        : null,
  );

  factory MusteriModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return MusteriModel(
      id: (data['id'] as String?) ?? doc.id,
      idNum: (data['idNum'] as num?)?.toInt(),
      firmaAdi: data['firmaAdi'] as String?,
      yetkili: data['yetkili'] as String?,
      telefon: data['telefon'] as String?,
      adres: data['adres'] as String?,
      guncel: (data['guncel'] as bool?) ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
