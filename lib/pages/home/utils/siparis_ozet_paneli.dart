
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';
import 'package:capri/core/models/siparis_model.dart';

class SiparisOzetPaneli extends StatelessWidget {
  final _siparisServis = SiparisService();
  SiparisOzetPaneli({super.key});

  @override
  Widget build(BuildContext context) {
    final tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

    bool _isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    double _safeBrut(SiparisModel s) {

      final net = s.netTutar ?? s.toplamTutar;
      final kdv = s.kdvOrani ?? 0.0;
      return s.brutTutar ?? (net * (1 + kdv / 100));
    }

    return StreamBuilder<List<SiparisModel>>(
      stream: _siparisServis.hepsiDinle(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData) return const SizedBox.shrink();

        final liste = snap.data!;
        final now = DateTime.now();
        final bugunBekleyenSayisi = liste.where((s) {
          if (s.durum != SiparisDurumu.beklemede) return false;
          if (s.islemeTarihi == null) return false;
          return _isSameDay(s.islemeTarihi!, now);
        }).length;

        final bugunTamamlanan = liste.where((s) {
          if (s.durum != SiparisDurumu.tamamlandi) return false;
          final ref = s.islemeTarihi ?? s.tarih;
          return _isSameDay(ref, now);
        }).toList();
        final bugunTamamlananSayisi = bugunTamamlanan.length;
        final bugunBrutKazanc = bugunTamamlanan.fold<double>(
          0.0, (sum, s) => sum + _safeBrut(s),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Günlük Sipariş Özeti",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    _satir(
                      context,
                      ikon: Icons.pending_actions,
                      baslik: "Bekleyen (Bugün)",
                      deger: "$bugunBekleyenSayisi adet",
                      renk: Colors.amber[800],
                    ),
                    const SizedBox(height: 10),

                    _satir(
                      context,
                      ikon: Icons.done_all,
                      baslik: "Tamamlanan (Bugün)",
                      deger: "$bugunTamamlananSayisi adet",
                      renk: Colors.green[700],
                    ),
                    const SizedBox(height: 10),

                    _satir(
                      context,
                      ikon: Icons.attach_money,
                      baslik: "Brüt Kazanç (Bugün)",
                      deger: tl.format(bugunBrutKazanc),
                      renk: Colors.green[900],
                      vurguluDeger: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _satir(
    BuildContext context, {
    required IconData ikon,
    required String baslik,
    required String deger,
    Color? renk,
    bool vurguluDeger = false,
  }) {
    final color = renk ?? Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ikon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            baslik,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          deger,
          style: TextStyle(
            fontSize: vurguluDeger ? 18 : 16,
            fontWeight: vurguluDeger ? FontWeight.w800 : FontWeight.bold,
            color: vurguluDeger ? Colors.green[800] : color,
          ),
        ),
      ],
    );
  }
}
