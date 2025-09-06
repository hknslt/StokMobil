// lib/pages/moduller/sevkiyat_sayfasi/tamamlanan_sevkiyatlar_sayfasi.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp için

class TamamlananSevkiyatlarSayfasi extends StatefulWidget {
  const TamamlananSevkiyatlarSayfasi({super.key});

  @override
  State<TamamlananSevkiyatlarSayfasi> createState() =>
      _TamamlananSevkiyatlarSayfasiState();
}

enum _DateQuick { all, today, week, month, custom }

class _TamamlananSevkiyatlarSayfasiState
    extends State<TamamlananSevkiyatlarSayfasi> {
  final _servis = SiparisService();
  late final Stream<List<SiparisModel>> _stream;

  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _deb;

  _DateQuick _quick = _DateQuick.all;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _stream = _servis.hepsiDinle();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ——— Güvenli tarih okuma ———
  DateTime? _extractDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      // Basit parse denemesi
      try {
        return DateTime.tryParse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Siparişten anlamlı tarih çıkar: islemeTarihi → tarih → createdAt → olusturmaTarihi
  DateTime? _siparisTarihi(SiparisModel s) {
    final dyn = s as dynamic;
    return _extractDate(dyn.islemeTarihi) ??
        _extractDate(dyn.tarih) ??
        _extractDate(dyn.createdAt) ??
        _extractDate(dyn.olusturmaTarihi);
  }

  // ——— Tarih yardımcıları ———
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTimeRange? _activeRange() {
    final now = DateTime.now();
    switch (_quick) {
      case _DateQuick.all:
        return null;
      case _DateQuick.today:
        return DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
      case _DateQuick.week:
        final monday = _startOfDay(now.subtract(Duration(days: now.weekday - 1)));
        final sunday = _endOfDay(monday.add(const Duration(days: 6)));
        return DateTimeRange(start: monday, end: sunday);
      case _DateQuick.month:
        final first = DateTime(now.year, now.month, 1);
        final last = _endOfDay(DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(days: 1)));
        return DateTimeRange(start: first, end: last);
      case _DateQuick.custom:
        return _customRange;
    }
  }

  bool _inRange(DateTime? dt) {
    final r = _activeRange();
    if (r == null) return true;
    if (dt == null) return false;
    return (dt.isAtSameMomentAs(r.start) || dt.isAfter(r.start)) &&
        (dt.isAtSameMomentAs(r.end) || dt.isBefore(r.end));
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = _customRange ??
        DateTimeRange(start: _startOfDay(now), end: _endOfDay(now));
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Tarih aralığı seç',
      saveText: 'Uygula',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: Renkler.kahveTon),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _customRange = DateTimeRange(
          start: _startOfDay(picked.start),
          end: _endOfDay(picked.end),
        );
        _quick = _DateQuick.custom;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _searchCtrl.clear();
      _quick = _DateQuick.all;
      _customRange = null;
    });
  }

  // ——— UI ———
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tamamlanan Sevkiyatlar"),
        backgroundColor: Renkler.kahveTon,
        actions: [
          if (_query.isNotEmpty || _activeRange() != null)
            IconButton(
              tooltip: 'Filtreleri temizle',
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
            ),
        ],
      ),
      body: Column(
        children: [
          // Arama (debounce + onChanged; listener yok)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 200), () {
                  if (!mounted) return;
                  setState(() => _query = v.trim().toLowerCase());
                });
              },
              decoration: InputDecoration(
                hintText: 'Müşteri / yetkili / açıklama içinde ara…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => _clearFilters(),
                        icon: const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),

          // Tarih hızlı filtreler + özel aralık
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: -6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _quickChip('Tümü', _DateQuick.all),
                _quickChip('Bugün', _DateQuick.today),
                _quickChip('Bu Hafta', _DateQuick.week),
                _quickChip('Bu Ay', _DateQuick.month),
                ActionChip(
                  label: Text(
                    _quick == _DateQuick.custom && _customRange != null
                        ? '${_fmt(_customRange!.start)} - ${_fmt(_customRange!.end)}'
                        : 'Özel aralık',
                  ),
                  onPressed: _pickCustomRange,
                  avatar: const Icon(Icons.date_range, size: 18),
                  backgroundColor: _quick == _DateQuick.custom
                      ? Renkler.kahveTon.withOpacity(.12)
                      : null,
                  labelStyle: TextStyle(
                    color: _quick == _DateQuick.custom ? Renkler.kahveTon : null,
                    fontWeight:
                        _quick == _DateQuick.custom ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),

          // Liste
          Expanded(
            child: StreamBuilder<List<SiparisModel>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }

                // 1) sadece tamamlananlar
                var data = (snap.data ?? [])
                    .where((s) => s.durum == SiparisDurumu.tamamlandi)
                    .toList();

                // 2) arama
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

                // 3) tarih filtresi (islemeTarihi yoksa 'tarih' vs. denenir)
                data = data.where((s) => _inRange(_siparisTarihi(s))).toList();

                if (data.isEmpty) {
                  return const Center(child: Text("Kayıt bulunamadı."));
                }

                return ListView.builder(
                  key: const PageStorageKey('tamamlanan_list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final s = data[index];
                    final key = s.docId ?? 'done_$index';
                    return _TamamlananCard(key: ValueKey(key), siparis: s);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // UI helpers
  Widget _quickChip(String text, _DateQuick v) {
    final selected = _quick == v;
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) => setState(() => _quick = v),
      selectedColor: Renkler.kahveTon.withOpacity(.12),
      labelStyle: TextStyle(
        color: selected ? Renkler.kahveTon : null,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

// ————————————————————————————————————————————————
// Kart bileşeni
// ————————————————————————————————————————————————
class _TamamlananCard extends StatefulWidget {
  final SiparisModel siparis;
  const _TamamlananCard({super.key, required this.siparis});

  @override
  State<_TamamlananCard> createState() => _TamamlananCardState();
}

class _TamamlananCardState extends State<_TamamlananCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _gosterMusteriDetay() {
    final m = widget.siparis.musteri;
    final firma = m.firmaAdi ?? '-';
    final yetkili = m.yetkili ?? '-';
    final telefon = (m.telefon ?? '').trim().isEmpty ? '-' : m.telefon!.trim();
    final adres = (m.adres ?? '').trim().isEmpty ? '-' : m.adres!.trim();

    if (!mounted) return;
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
    super.build(context);
    final theme = Theme.of(context);
    final s = widget.siparis;

    final firma = s.musteri.firmaAdi ?? '-';
    final yetkili = s.musteri.yetkili ?? '-';
    final urunCesidi = s.urunler.length;
    final toplamAdet = s.urunler.fold<int>(0, (sum, u) => sum + u.adet);
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
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text('Yetkili: $yetkili', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: -6,
                          children: const [
                            // Çipler dinamik aşağıda
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (aciklama.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withOpacity(.35)),
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

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey('done_${s.docId ?? firma}_${s.urunler.length}'),
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
                      child: Text('$urunCesidi çeşit / $toplamAdet adet',
                          style: theme.textTheme.bodySmall),
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
                      return ListTile(
                        dense: true,
                        title: Text(u.urunAdi),
                        subtitle: Text(u.renk),
                        trailing: Text('Adet: ${u.adet}',
                            style: const TextStyle(fontSize: 12)),
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
