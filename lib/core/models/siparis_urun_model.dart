class SiparisUrunModel {
  final String id;        // ürün id (stringleşmiş)
  final String urunAdi;
  final String renk;
  int adet;
  double birimFiyat;

  SiparisUrunModel({
    required this.id,
    required this.urunAdi,
    required this.renk,
    required this.adet,
    required this.birimFiyat,
  });

  /// Basit kopya
  SiparisUrunModel copy() => SiparisUrunModel(
        id: id,
        urunAdi: urunAdi,
        renk: renk,
        adet: adet,
        birimFiyat: birimFiyat,
      );

  /// ✅ UretimSayfasi vb. yerlerde lazım olan flexible kopya
  SiparisUrunModel copyWith({
    String? id,
    String? urunAdi,
    String? renk,
    int? adet,
    double? birimFiyat,
  }) {
    return SiparisUrunModel(
      id: id ?? this.id,
      urunAdi: urunAdi ?? this.urunAdi,
      renk: renk ?? this.renk,
      adet: adet ?? this.adet,
      birimFiyat: birimFiyat ?? this.birimFiyat,
    );
  }

  double get toplamFiyat => adet * birimFiyat;

  Map<String, dynamic> toMap() => {
        'id': id,
        'urunAdi': urunAdi,
        'renk': renk,
        'adet': adet,
        'birimFiyat': birimFiyat,
      };

  factory SiparisUrunModel.fromMap(Map<String, dynamic> map) => SiparisUrunModel(
        id: map['id'] as String,
        urunAdi: map['urunAdi'] as String,
        renk: map['renk'] as String,
        adet: (map['adet'] as num).toInt(),
        birimFiyat: (map['birimFiyat'] as num).toDouble(),
      );
}
