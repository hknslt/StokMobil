import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/analiz/istatistik_servisi.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';
import 'package:capri/services/urun_yonetimi/urun_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

enum AnalizModu { satanlar, stokGrup, siparisGrup }

class AnalizListeleriPaneli extends StatefulWidget {
  const AnalizListeleriPaneli({super.key});

  @override
  State<AnalizListeleriPaneli> createState() => _AnalizListeleriPaneliState();
}

class _AnalizListeleriPaneliState extends State<AnalizListeleriPaneli> {
  AnalizModu _mod = AnalizModu.satanlar;
  String _zamanFiltre = 'Aylık';

  DateTime _baslangic() {
    final now = DateTime.now();
    switch (_zamanFiltre) {
      case 'Günlük': return now.subtract(const Duration(days: 1));
      case 'Haftalık': return now.subtract(const Duration(days: 7));
      case 'Aylık': return now.subtract(const Duration(days: 30));
      case 'Yıllık': return now.subtract(const Duration(days: 365));
      default: return now.subtract(const Duration(days: 30));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Başlık ve Mod Seçimi ---
              Row(
                children: [
                  Icon(_getIcon(), color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getTitle(),
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Mod Butonları
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ToggleButtons(
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(minHeight: 32, minWidth: 80),
                  isSelected: [
                    _mod == AnalizModu.satanlar,
                    _mod == AnalizModu.stokGrup,
                    _mod == AnalizModu.siparisGrup,
                  ],
                  onPressed: (index) {
                    setState(() => _mod = AnalizModu.values[index]);
                  },
                  fillColor: Colors.green.shade50,
                  selectedColor: Colors.green.shade900,
                  selectedBorderColor: Colors.green,
                  children: const [
                    Padding(padding: EdgeInsets.all(8.0), child: Text("En Çok Satan")),
                    Padding(padding: EdgeInsets.all(8.0), child: Text("Stok (Grup)")),
                    Padding(padding: EdgeInsets.all(8.0), child: Text("Sipariş (Grup)")),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),

              // --- Zaman Filtresi (Sadece Satanlar modunda aktif) ---
              if (_mod == AnalizModu.satanlar) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(10),
                    selectedColor: Colors.white,
                    color: Colors.black54,
                    fillColor: Colors.green,
                    constraints: const BoxConstraints(minHeight: 28, minWidth: 54),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    isSelected: ['Günlük', 'Haftalık', 'Aylık', 'Yıllık'].map((e) => e == _zamanFiltre).toList(),
                    onPressed: (i) {
                      const f = ['Günlük', 'Haftalık', 'Aylık', 'Yıllık'];
                      setState(() => _zamanFiltre = f[i]);
                    },
                    children: const [
                      Text('Günlük'), Text('Haftalık'), Text('Aylık'), Text('Yıllık'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // --- İçerik ---
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (_mod) {
      case AnalizModu.satanlar: return Icons.leaderboard;
      case AnalizModu.stokGrup: return Icons.pie_chart;
      case AnalizModu.siparisGrup: return Icons.pending_actions;
    }
  }

  String _getTitle() {
    switch (_mod) {
      case AnalizModu.satanlar: return 'En Çok Satan Ürünler';
      case AnalizModu.stokGrup: return 'Stok Dağılımı (Grup)';
      case AnalizModu.siparisGrup: return 'Sipariş İhtiyacı (Grup)';
    }
  }

  Widget _buildContent() {
    switch (_mod) {
      case AnalizModu.satanlar:
        return _SatanlarListesi(baslangic: _baslangic());
      case AnalizModu.stokGrup:
        return const _StokGrupListesi();
      case AnalizModu.siparisGrup:
        return const _SiparisGrupListesi();
    }
  }
}

// ---------------------------------------------------------------------------
// 1. EN ÇOK SATANLAR (Mevcut Kodun Uyarlanmış Hali)
// ---------------------------------------------------------------------------
class _SatanlarListesi extends StatelessWidget {
  final DateTime baslangic;
  const _SatanlarListesi({required this.baslangic});

  String _fmtTL(num n) => NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: IstatistikServisi.instance.enCokSatanUrunlerAkim(baslangic: baslangic, limit: 15),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        final list = snap.data ?? [];
        if (list.isEmpty) return const Center(child: Text("Veri Yok", style: TextStyle(color: Colors.grey)));

        final toplamAdet = list.fold<int>(0, (t, x) => t + (x['adet'] as int));

        return Column(
          children: list.map((x) {
            final urunAdi = x['urunAdi'] ?? '—';
            final adet = x['adet'] as int;
            final ciro = x['ciro'] as double;
            final pct = toplamAdet == 0 ? 0 : ((adet / toplamAdet) * 100).round();

            return _AnalizRow(
              baslik: urunAdi,
              ortaYazi: "Adet: $adet",
              sagYazi: _fmtTL(ciro),
              yuzde: pct,
            );
          }).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 2. STOK GRUP LİSTESİ (Ürünleri çeker, gruplara göre toplar)
// ---------------------------------------------------------------------------
class _StokGrupListesi extends StatelessWidget {
  const _StokGrupListesi();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Urun>>(
      stream: UrunService().dinle(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        final urunler = snap.data ?? [];
        if (urunler.isEmpty) return const Center(child: Text("Ürün Yok", style: TextStyle(color: Colors.grey)));

        // Gruplama Mantığı
        final gruplar = <String, int>{};
        for (var u in urunler) {
          final grupAdi = (u.grup == null || u.grup!.trim().isEmpty) ? "(Grupsuz)" : u.grup!;
          gruplar[grupAdi] = (gruplar[grupAdi] ?? 0) + u.adet;
        }

        // Sıralama (Çoktan aza)
        final siraliListe = gruplar.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final toplamAdet = urunler.fold<int>(0, (t, u) => t + u.adet);

        return Column(
          children: siraliListe.map((e) {
            final pct = toplamAdet == 0 ? 0 : ((e.value / toplamAdet) * 100).round();
            return _AnalizRow(
              baslik: e.key,
              ortaYazi: "Stok: ${e.value}",
              sagYazi: "%$pct",
              yuzde: pct,
            );
          }).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. SİPARİŞ GRUP LİSTESİ (Aktif siparişleri çeker, ürünlerin grubunu bulur ve toplar)
// ---------------------------------------------------------------------------
class _SiparisGrupListesi extends StatelessWidget {
  const _SiparisGrupListesi();

  @override
  Widget build(BuildContext context) {
    // Ürünleri de çekmemiz lazım ki siparişteki ürünün hangi gruba ait olduğunu bilelim
    return StreamBuilder<List<Urun>>(
      stream: UrunService().dinle(),
      builder: (context, urunSnap) {
        if (!urunSnap.hasData) return const Center(child: CircularProgressIndicator());
        
        // Ürün Adı -> Grup Adı haritası oluştur (Performans için)
        final urunGrupMap = <String, String>{};
        for (var u in urunSnap.data!) {
          urunGrupMap[u.urunAdi] = (u.grup == null || u.grup!.trim().isEmpty) ? "(Grupsuz)" : u.grup!;
        }

        return StreamBuilder<List<SiparisModel>>(
          // Sadece aktif siparişler
          stream: SiparisService().dinle(), // İçeride filtreleme yapacağız veya servis methodu varsa o kullanılır
          builder: (context, sipSnap) {
            if (sipSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            
            final aktifSiparisler = (sipSnap.data ?? [])
                .where((s) => s.durum == SiparisDurumu.beklemede || s.durum == SiparisDurumu.uretimde)
                .toList();

            if (aktifSiparisler.isEmpty) return const Center(child: Text("Aktif Sipariş Yok", style: TextStyle(color: Colors.grey)));

            // Hesaplama
            final gruplar = <String, int>{};
            int genelToplam = 0;

            for (var sip in aktifSiparisler) {
              for (var satir in sip.urunler) {
                final grup = urunGrupMap[satir.urunAdi] ?? "(Bilinmeyen Grup)";
                gruplar[grup] = (gruplar[grup] ?? 0) + satir.adet;
                genelToplam += satir.adet;
              }
            }

            final siraliListe = gruplar.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            if (siraliListe.isEmpty) return const Center(child: Text("Ürün ihtiyacı yok."));

            return Column(
              children: siraliListe.map((e) {
                final pct = genelToplam == 0 ? 0 : ((e.value / genelToplam) * 100).round();
                return _AnalizRow(
                  baslik: e.key,
                  ortaYazi: "İhtiyaç: ${e.value}",
                  sagYazi: "%$pct",
                  yuzde: pct,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// ORTAK SATIR WIDGETI
// ---------------------------------------------------------------------------
class _AnalizRow extends StatelessWidget {
  final String baslik;
  final String ortaYazi;
  final String sagYazi;
  final int yuzde;

  const _AnalizRow({
    required this.baslik,
    required this.ortaYazi,
    required this.sagYazi,
    required this.yuzde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Text(ortaYazi, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 16),
              Text(sagYazi, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (yuzde / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}