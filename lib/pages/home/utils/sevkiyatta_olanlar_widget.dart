import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/sevkiyat_sayfasi.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/widgets/siparis_sevkiyat_kart.dart';
import 'package:capri/services/siparis_service.dart';

class SevkiyattaOlanlarWidget extends StatelessWidget {
  const SevkiyattaOlanlarWidget({super.key});

  Future<void> _teslimEtDialog(BuildContext context, SiparisModel s) async {
    if (s.docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belge ID bulunamadı.')),
      );
      return;
    }

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teslimatı Onayla'),
        content: Text('Bu siparişi “Tamamlandı” yapalım mı?\n\nMüşteri: ${s.musteri.firmaAdi ?? '-'}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Renkler.kahveTon)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            child: const Text('Evet, Teslim Et', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (onay == true) {
      await SiparisService().durumuGuncelle(s.docId!, SiparisDurumu.tamamlandi);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sipariş teslim edildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SiparisModel>>(
      stream: SiparisService().hepsiDinle(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snap.hasError) {
          return Text('Hata: ${snap.error}');
        }

        final liste = (snap.data ?? [])
            .where((s) => s.durum == SiparisDurumu.sevkiyat)
            .toList();

        if (liste.isEmpty) return const SizedBox();

        final gosterilecek = liste.take(5).toList();

        return Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, c) {
                  final narrow = c.maxWidth < 380;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: Renkler.kahveTon),
                      const SizedBox(width: 8),

                      const Expanded(
                        child: Text(
                          "Sevkiyat Bekleyenler",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${liste.length}', style: const TextStyle(fontSize: 12)),
                      ),

                      const SizedBox(width: 4),

                      if (narrow)
                        IconButton(
                          tooltip: 'Tümünü Gör',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SevkiyatSayfasi()),
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                        )
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SevkiyatSayfasi()),
                                );
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Tümünü Gör'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                minimumSize: const Size(0, 36),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 8),

              ...gosterilecek.map(
                (s) => SizedBox(
                  width: double.infinity,
                  child: SiparisSevkiyatKart(
                    siparis: s,
                    kompakt: false, 
                    onTeslimEt: () => _teslimEtDialog(context, s),
                  ),
                ),
              ),

              if (liste.length > gosterilecek.length)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    '+${liste.length - gosterilecek.length} sipariş daha…',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
