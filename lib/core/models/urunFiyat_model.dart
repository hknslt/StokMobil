class UrunFiyat {
  final int urunId;
  final String fiyatListesiAdi;
  double netFiyat;

  UrunFiyat({
    required this.urunId,
    required this.fiyatListesiAdi,
    required this.netFiyat,
  });

  UrunFiyat copyWith({int? urunId, String? fiyatListesiAdi, double? netFiyat}) {
    return UrunFiyat(
      urunId: urunId ?? this.urunId,
      fiyatListesiAdi: fiyatListesiAdi ?? this.fiyatListesiAdi,
      netFiyat: netFiyat ?? this.netFiyat,
    );
  }

  Map<String, dynamic> toMap() => {'urunId': urunId, 'netFiyat': netFiyat};

  factory UrunFiyat.fromMap(String listeAdi, Map<String, dynamic> m) {
    return UrunFiyat(
      urunId: (m['urunId'] as num).toInt(),
      fiyatListesiAdi: listeAdi,
      netFiyat: (m['netFiyat'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
