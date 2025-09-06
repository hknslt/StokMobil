// lib/pages/moduller/sevkiyat_sayfasi/sevkiyat_sayfasi.dart
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

  // 🔸 Seçili ürün indeksleri parent’ta tutulur (orderKey -> Set<int>)
  // Route değişince state korunur, Firebase’e yazılmaz.
  final Map<String, Set<int>> _secimler = {};

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

  // Sipariş için stabil bir key üret (docId yoksa güvenli fallback)
  String _orderKey(SiparisModel s, int index) {
    final doc = (s.docId ?? '').trim();
    if (doc.isNotEmpty) return doc;
    // modelde id varsa onu kullan; yoksa firma+index fallback
    final anyId = (s.id?.toString() ?? '').trim();
    if (anyId.isNotEmpty) return 'doc_$anyId';
    final firma = (s.musteri.firmaAdi ?? '').trim();
    return 'fallback_${firma}_$index';
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
        content: Text(
          'Bu siparişi “Tamamlandı” yapalım mı?\n\nMüşteri: ${s.musteri.firmaAdi ?? '-'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
        backgroundColor: Renkler.kahveTon,
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
          // ——— Arama kutusu (onChanged; listener yok → dispose sonrası setState olmaz)
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    return firma.contains(_query) ||
                        yetkili.contains(_query) ||
                        aciklama.contains(_query);
                  }).toList();
                }

                if (data.isEmpty) {
                  return const Center(child: Text('Sevkiyat bekleyen sipariş bulunamadı.'));
                }

                return ListView.builder(
                  key: const PageStorageKey('sevkiyat_list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final s = data[index];
                    final stableKey = _orderKey(s, index);

                    // Bu sipariş için set’i hazırla
                    final setRef = _secimler.putIfAbsent(stableKey, () => <int>{});

                    // Ürün sayısı kısaldıysa set içindeki geçersiz indeksleri temizle
                    setRef.removeWhere((i) => i < 0 || i >= s.urunler.length);

                    return _SiparisCard(
                      key: ValueKey(stableKey), // kart state’i bu key’e bağlı
                      siparis: s,
                      selectedIndexes: setRef,   // 🔸 shared referans
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

/// ———————————————————————————————
/// Kart bileşeni (kendi içinde setState)
/// ———————————————————————————————
class _SiparisCard extends StatefulWidget {
  final SiparisModel siparis;
  final Set<int> selectedIndexes; // parent’tan gelen referans (Firebase’e yazılmaz)
  final VoidCallback onTeslimEt;

  const _SiparisCard({
    super.key,
    required this.siparis,
    required this.selectedIndexes,
    required this.onTeslimEt,
  });

  @override
  State<_SiparisCard> createState() => _SiparisCardState();
}

class _SiparisCardState extends State<_SiparisCard> {
  void _selectAll() {
    setState(() {
      widget.selectedIndexes
        ..clear()
        ..addAll(List.generate(widget.siparis.urunler.length, (i) => i));
    });
  }

  void _clearSelection() {
    setState(() => widget.selectedIndexes.clear());
  }

  void _toggle(int i, bool v) {
    setState(() {
      if (v) {
        widget.selectedIndexes.add(i);
      } else {
        widget.selectedIndexes.remove(i);
      }
    });
  }

  void _gosterMusteriDetay() {
    final m = widget.siparis.musteri;
    final firma = m.firmaAdi ?? '-';
    final yetkili = m.yetkili ?? '-';
    final telefon = (m.telefon ?? '').trim().isEmpty ? '-' : m.telefon!.trim();
    final adres = (m.adres ?? '').trim().isEmpty ? '-' : m.adres!.trim();

    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Renkler.kahveTon.withOpacity(.15),
                    child: Text(
                      (firma.isNotEmpty ? firma[0] : '?').toUpperCase(),
                      style: TextStyle(color: Renkler.kahveTon),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      firma,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _infoRow('Yetkili', yetkili),
              const SizedBox(height: 6),
              _infoRow('Telefon', telefon),
              const SizedBox(height: 6),
              _infoRow('Adres', adres, multiline: true),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, {bool multiline = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: multiline ? null : 2,
            overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.siparis;

    final firma = s.musteri.firmaAdi ?? '-';
    final yetkili = s.musteri.yetkili ?? '-';
    final urunCesidi = s.urunler.length;
    final toplamAdet = s.urunler.fold<int>(0, (sum, u) => sum + u.adet);
    final aciklama = (s.aciklama ?? '').trim();
    final checkedCount = widget.selectedIndexes.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst satır: müşteri + teslim et
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _gosterMusteriDetay,
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    backgroundColor: Renkler.kahveTon.withOpacity(.15),
                    child: Text(
                      (firma.isNotEmpty ? firma[0] : '?').toUpperCase(),
                      style: TextStyle(color: Renkler.kahveTon),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _gosterMusteriDetay,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firma,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text('Yetkili: $yetkili', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: -6,
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
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: widget.onTeslimEt,
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

            // Ürünler (seçilebilir)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('exp_${s.docId ?? firma}_${s.urunler.length}'),
                maintainState: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text('Ürünler', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        checkedCount > 0
                            ? '$checkedCount / $urunCesidi seçili'
                            : '$urunCesidi çeşit / $toplamAdet adet',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Hepsini işaretle',
                      icon: const Icon(Icons.select_all),
                      onPressed: _selectAll,
                    ),
                    IconButton(
                      tooltip: 'Seçimi temizle',
                      icon: const Icon(Icons.clear_all),
                      onPressed: _clearSelection,
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
                      final checked = widget.selectedIndexes.contains(i);
                      return CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: checked,
                        onChanged: (v) => _toggle(i, v ?? false),
                        title: Text(u.urunAdi),
                        subtitle: Text(u.renk),
                        secondary: Text('Adet: ${u.adet}', style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
