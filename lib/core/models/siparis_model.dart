import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/core/models/siparis_urun_model.dart';

enum SiparisDurumu { beklemede, uretimde, sevkiyat, tamamlandi, reddedildi }

extension _SiparisDurumuParse on SiparisDurumu {
  static SiparisDurumu fromString(String v) {
    return SiparisDurumu.values.firstWhere(
      (e) => e.name == v,
      orElse: () => SiparisDurumu.beklemede,
    );
  }
}

class SiparisModel {
  final String? docId;
  final String id;

  final MusteriModel musteri;
  final List<SiparisUrunModel> urunler;
  final DateTime tarih;
  final DateTime? islemeTarihi;
  final String? aciklama;
  SiparisDurumu durum;

  final double? netTutar; // KDV hariç toplam
  final double? kdvOrani; // % olarak
  final double? kdvTutar;
  final double? brutTutar; // net + kdv

  final String? fiyatListesiId;
  final String? fiyatListesiAd;

  final bool? sevkiyatHazir;

  SiparisModel({
    this.docId,
    String? id,
    required this.musteri,
    required this.urunler,
    DateTime? tarih,
    this.islemeTarihi,
    this.aciklama,
    SiparisDurumu? durum,

    this.netTutar,
    this.kdvOrani,
    this.kdvTutar,
    this.brutTutar,

    this.fiyatListesiId,
    this.fiyatListesiAd,

    this.sevkiyatHazir,
  }) : id = id ?? const Uuid().v4(),
       tarih = tarih ?? DateTime.now(),
       durum = durum ?? SiparisDurumu.beklemede;

  // ---------- Helpers ----------
  static double _sumNet(List<SiparisUrunModel> items) =>
      items.fold(0.0, (s, u) => s + u.adet * (u.birimFiyat));

  static double _round2(double v) => double.parse(v.toStringAsFixed(2));

  double get toplamTutar => _round2(_netComputed);

  double get _netComputed => netTutar ?? _sumNet(urunler);
  double get _kdvOraniComputed => kdvOrani ?? 0.0;
  double get _kdvComputed =>
      kdvTutar ?? _round2(_netComputed * _kdvOraniComputed / 100.0);
  double get _brutComputed => brutTutar ?? _round2(_netComputed + _kdvComputed);

  double get netToplam => _round2(_netComputed);
  double get kdvToplam => _round2(_kdvComputed);
  double get brutToplam => _round2(_brutComputed);

  // ---------- Mapping ----------
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'musteri': musteri.toMap(),
      'urunler': urunler.map((e) => e.toMap()).toList(),
      'tarih': tarih,
      'islemeTarihi': islemeTarihi,
      'aciklama': aciklama,
      'durum': durum.name,

      'netTutar': netTutar ?? _netComputed,
      'kdvOrani': kdvOrani ?? _kdvOraniComputed,
      'kdvTutar': kdvTutar ?? _kdvComputed,
      'brutTutar': brutTutar ?? _brutComputed,

      'fiyatListesiId': fiyatListesiId,
      'fiyatListesiAd': fiyatListesiAd,

      'sevkiyatHazir': sevkiyatHazir ?? false,
    };
  }

  factory SiparisModel.fromMap(Map<String, dynamic> map) {
    DateTime readDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.now();
    }

    DateTime? readDateOpt(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      return null;
    }

    double? _num(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    return SiparisModel(
      id: (map['id'] as String?) ?? const Uuid().v4(),
      musteri: MusteriModel.fromMap(map['musteri'] as Map<String, dynamic>),
      urunler: (map['urunler'] as List)
          .map((e) => SiparisUrunModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      tarih: readDate(map['tarih']),
      islemeTarihi: readDateOpt(map['islemeTarihi']),
      aciklama: map['aciklama'] as String?,
      durum: _SiparisDurumuParse.fromString(
        (map['durum'] as String?) ?? 'beklemede',
      ),

      netTutar: _num(map['netTutar']),
      kdvOrani: _num(map['kdvOrani']),
      kdvTutar: _num(map['kdvTutar']),
      brutTutar: _num(map['brutTutar']),

      fiyatListesiId: map['fiyatListesiId'] as String?,
      fiyatListesiAd: map['fiyatListesiAd'] as String?,

      sevkiyatHazir: (map['sevkiyatHazir'] as bool?) ?? false,
    );
  }

  SiparisModel copyWith({
    String? docId,
    String? id,
    MusteriModel? musteri,
    List<SiparisUrunModel>? urunler,
    DateTime? tarih,
    DateTime? islemeTarihi,
    String? aciklama,
    SiparisDurumu? durum,

    double? netTutar,
    double? kdvOrani,
    double? kdvTutar,
    double? brutTutar,

    String? fiyatListesiId,
    String? fiyatListesiAd,

    bool? sevkiyatHazir,
  }) {
    return SiparisModel(
      docId: docId ?? this.docId,
      id: id ?? this.id,
      musteri: musteri ?? this.musteri,
      urunler: urunler ?? this.urunler,
      tarih: tarih ?? this.tarih,
      islemeTarihi: islemeTarihi ?? this.islemeTarihi,
      aciklama: aciklama ?? this.aciklama,
      durum: durum ?? this.durum,

      netTutar: netTutar ?? this.netTutar,
      kdvOrani: kdvOrani ?? this.kdvOrani,
      kdvTutar: kdvTutar ?? this.kdvTutar,
      brutTutar: brutTutar ?? this.brutTutar,

      fiyatListesiId: fiyatListesiId ?? this.fiyatListesiId,
      fiyatListesiAd: fiyatListesiAd ?? this.fiyatListesiAd,

      sevkiyatHazir: sevkiyatHazir ?? this.sevkiyatHazir,
    );
  }
}
