import 'package:capri/services/istatistik_servisi.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EnCokSatanUrunlerPaneli extends StatefulWidget {
  const EnCokSatanUrunlerPaneli({super.key});

  @override
  State<EnCokSatanUrunlerPaneli> createState() => _EnCokSatanUrunlerPaneliState();
}

class _EnCokSatanUrunlerPaneliState extends State<EnCokSatanUrunlerPaneli> {
  String _filtre = 'Günlük'; 

  DateTime _baslangic() {
    final now = DateTime.now();
    switch (_filtre) {
      case 'Günlük':   return now.subtract(const Duration(days: 1));
      case 'Haftalık': return now.subtract(const Duration(days: 7));
      case 'Aylık':    return now.subtract(const Duration(days: 30));
      case 'Yıllık':   return now.subtract(const Duration(days: 365));
      default:         return now.subtract(const Duration(days: 30));
    }
  }

  String _fmtTL(num n) => NumberFormat.currency(
        locale: 'tr_TR', symbol: '₺', decimalDigits: 0).format(n);

  @override
  Widget build(BuildContext context) {
    final filtreButtons = ToggleButtons(
      borderRadius: BorderRadius.circular(10),
      selectedColor: Colors.white,
      color: Colors.black54,
      fillColor: Colors.green,
      constraints: const BoxConstraints(minHeight: 28, minWidth: 54),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      isSelected: [
        _filtre == 'Günlük',
        _filtre == 'Haftalık',
        _filtre == 'Aylık',
        _filtre == 'Yıllık',
      ],
      onPressed: (i) {
        const f = ['Günlük', 'Haftalık', 'Aylık', 'Yıllık'];
        setState(() => _filtre = f[i]);
      },
      children: const [
        Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('Günlük')),
        Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('Haftalık')),
        Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('Aylık')),
        Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('Yıllık')),
      ],
    );

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
              Row(
                children: const [
                  Icon(Icons.leaderboard, color: Colors.green),
                  SizedBox(width: 8),
                  Text('En Çok Satan Ürünler',
                      style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: filtreButtons),
              const SizedBox(height: 12),

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: IstatistikServisi.instance.enCokSatanUrunlerAkim(
                  baslangic: _baslangic(),
                  limit: 15,
                ),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final list = snap.data ?? const <Map<String, dynamic>>[];
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('Veri yok', style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    );
                  }

                  final toplamAdet = list.fold<int>(0, (t, x) => t + (x['adet'] as int));
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final x = list[i];
                      final urunAdi = (x['urunAdi'] as String?) ?? '—';
                      final adet = (x['adet'] as int);
                      final ciro = (x['ciro'] as double);
                      final pct = toplamAdet == 0 ? 0 : ((adet / toplamAdet) * 100).round();

                      return Container(
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
                                Expanded(child: Text(urunAdi, style: const TextStyle(fontWeight: FontWeight.w700))),
                                const SizedBox(width: 8),
                                Text('Adet: $adet', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 16),
                                Text('Ciro: ${_fmtTL(ciro)}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Stack(
                              children: [
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                LayoutBuilder(
                                  builder: (_, c) => Container(
                                    height: 8,
                                    width: c.maxWidth * (pct / 100),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('%$pct', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
