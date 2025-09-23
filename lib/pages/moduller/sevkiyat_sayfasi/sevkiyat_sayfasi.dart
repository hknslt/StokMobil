
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/tamamlanan_sevkiyatlar_sayfasi.dart';
import 'package:capri/services/siparis_service.dart';

class SevkiyatSayfasi extends StatefulWidget {
  const SevkiyatSayfasi({super.key});

  @override
  State<SevkiyatSayfasi> createState() => _SevkiyatSayfasiState();
}

class _SevkiyatSayfasiState extends State<SevkiyatSayfasi> {
  final _siparisServis = SiparisService();
  Stream<List<SiparisModel>>? _sevkiyatStream;

  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sevkiyatStream = _siparisServis.hepsiDinle();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _teslimEt(SiparisModel s) async {
    if (s.docId == null) {
      if (!mounted) return;
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

    if (onay != true) return;

    await _siparisServis.durumuGuncelle(s.docId!, SiparisDurumu.tamamlandi);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sipariş teslim edildi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _sevkiyatStream ??= _siparisServis.hepsiDinle();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Renkler.anaMavi, Renkler.kahveTon.withOpacity(.9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Sevkiyat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rounded, color: Colors.white),
            tooltip: 'Tamamlananlar',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TamamlananSevkiyatlarSayfasi()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ——— Arama kutusu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                
                hintText: 'Müşteri / yetkili / açıklama içinde ara…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(() {
                          _query = '';
                          _searchCtrl.clear();
                        }),
                        icon: const Icon(Icons.clear),
                      ),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Renkler.kahveTon ,width: 2),borderRadius: BorderRadius.circular(20)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ——— Liste
          Expanded(
            child: StreamBuilder<List<SiparisModel>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }

                var data = (snap.data ?? [])
                    .where((s) => s.durum == SiparisDurumu.sevkiyat)
                    .toList();

                if (_query.isNotEmpty) {
                  data = data.where((s) {
                    final firma = (s.musteri.firmaAdi ?? '').toLowerCase();
                    final yetkili = (s.musteri.yetkili ?? '').toLowerCase();
                    final aciklama = (s.aciklama ?? '').toLowerCase();
                    return firma.contains(_query) || yetkili.contains(_query) || aciklama.contains(_query);
                  }).toList();
                }

                if (data.isEmpty) {
                  return const Center(child: Text('Sevkiyat bekleyen sipariş bulunamadı.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final s = data[index];
                    return _SiparisCard(
                      siparis: s,
                      onTeslimEt: () => _teslimEt(s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SiparisCard extends StatelessWidget {
  final SiparisModel siparis;
  final VoidCallback onTeslimEt;

  const _SiparisCard({
    super.key,
    required this.siparis,
    required this.onTeslimEt,
  });

  String _safe(String? v) => (v ?? '').trim().isEmpty ? '-' : v!.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = siparis;

    final firma = _safe(s.musteri.firmaAdi);
    final yetkili = _safe(s.musteri.yetkili);
    final urunCesidi = s.urunler.length;
    final toplamAdet = s.urunler.fold<int>(0, (sum, u) => sum + (u.adet ?? 0));
    final aciklama = (s.aciklama ?? '').trim();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Renkler.kahveTon.withOpacity(.15),
                  child: Text(
                    (firma.isNotEmpty ? firma[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Renkler.kahveTon),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(firma, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Yetkili: $yetkili', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text('Ürün: $urunCesidi'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          Chip(
                            label: Text('Toplam Adet: $toplamAdet'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Chip(
                            label: Text('Durum: Sevkiyat'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onTeslimEt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: const Text('Teslim Et', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),

            if (aciklama.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(aciklama, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 20, color: Renkler.kahveTon),
                  const SizedBox(width: 8),
                  Text('Ürünler', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$urunCesidi çeşit / $toplamAdet adet', style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: s.urunler.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = s.urunler[i];
                    final urunAdi = ((u.urunAdi ?? '').trim().isNotEmpty) ? u.urunAdi!.trim() : '-';
                    final renk = ((u.renk ?? '').trim().isNotEmpty) ? u.renk!.trim() : '-';
                    final adet = u.adet ?? 0;

                    return ListTile(
                      title: Text(urunAdi),
                      subtitle: Text('Renk: $renk'),
                      trailing: Text('Adet: $adet', style: const TextStyle(fontSize: 12)),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
