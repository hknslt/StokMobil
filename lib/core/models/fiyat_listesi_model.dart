class FiyatListesi {
  final String id;    // Firestore docId
  final String ad;
  final double kdv;
  final DateTime createdAt;

  FiyatListesi({
    required this.id,
    required this.ad,
    required this.kdv,
    required this.createdAt,
  });

  // 🔹 UI 'liste.kdvYuzde' bekliyor; modelde alan 'kdv'.
  double get kdvYuzde => kdv;

  Map<String, dynamic> toMap() => {
    'ad': ad,
    'kdv': kdv,
    'createdAt': createdAt,
  };

  factory FiyatListesi.fromDoc(String id, Map<String, dynamic> m) {
    return FiyatListesi(
      id: id,
      ad: (m['ad'] as String?) ?? ' ',
      kdv: (m['kdv'] as num?)?.toDouble() ?? 20.0,
      createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
