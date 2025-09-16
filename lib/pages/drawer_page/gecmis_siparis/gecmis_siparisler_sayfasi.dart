import 'package:capri/core/Color/Colors.dart';
import 'package:capri/pages/drawer_page/gecmis_siparis/siparis_detay_sayfasi.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/services/siparis_service.dart';
import 'package:capri/core/models/siparis_model.dart';

class GecmisSiparislerSayfasi extends StatefulWidget {
  const GecmisSiparislerSayfasi({super.key});

  @override
  State<GecmisSiparislerSayfasi> createState() =>
      _GecmisSiparislerSayfasiState();
}

class _GecmisSiparislerSayfasiState extends State<GecmisSiparislerSayfasi> {
  final _svc = SiparisService();
  final _araCtrl = TextEditingController();
  final _paraFmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  DateTimeRange? _range;

  @override
  void dispose() {
    _araCtrl.dispose();
    super.dispose();
  }

  String _fmtTarih(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  String _fmtGunKisa(DateTime? dt) {
    if (dt == null) return '--';
    return DateFormat('dd\nMMM', 'tr_TR').format(dt);
  }

  String _musteriAdi(dynamic m) {
    try {
      final ad = (m as dynamic).ad as String?;
      if (ad != null && ad.isNotEmpty) return ad;
    } catch (_) {}
    try {
      final firma = (m as dynamic).firmaAdi as String?;
      if (firma != null && firma.isNotEmpty) return firma;
    } catch (_) {}
    try {
      final isim = (m as dynamic).isimSoyisim as String?;
      if (isim != null && isim.isNotEmpty) return isim;
    } catch (_) {}
    return '-';
  }

  Color _durumRengi(String name) {
    switch (name.toLowerCase()) {
      case 'tamamlandi':
      case 'tamamlandı':
      case 'onaylandi':
      case 'onaylandı':
        return Colors.green;
      case 'iptal':
      case 'reddedildi':
        return Colors.red;
      case 'hazirlaniyor':
      case 'hazırlanıyor':
      case 'beklemede':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  bool _inDateRange(DateTime? dt) {
    if (_range == null || dt == null) return true;
    final start = DateTime(
      _range!.start.year,
      _range!.start.month,
      _range!.start.day,
    );
    final end = DateTime(
      _range!.end.year,
      _range!.end.month,
      _range!.end.day,
      23,
      59,
      59,
      999,
    );
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  Future<void> _pickRange() async {
    final initial =
        _range ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Renkler.kahveTon),
          ),
          child: child!,
        );
      },
    );
    if (r != null) setState(() => _range = r);
  }

  Future<bool> _confirmAndDelete(SiparisModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Siparişi sil'),
        content: Text(
          "'${_musteriAdi(s.musteri)}' müşterisinin ${_fmtTarih(s.islemeTarihi ?? s.tarih)} tarihli siparişi silinsin mi?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Renkler.kahveTon),
            ),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Evet, sil'),
          ),
        ],
      ),
    );
    if (ok != true) return false;

    try {
      await _svc.sil(s.docId!);
      if (!mounted) return true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sipariş silindi')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silinirken hata: $e')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş Siparişler'),
        backgroundColor: Renkler.kahveTon,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _araCtrl,
                    decoration: const InputDecoration(
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Renkler.kahveTon,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Müşteri / açıklama ara',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(
                    _range == null
                        ? 'Tarih'
                        : '${DateFormat('dd.MM.yyyy').format(_range!.start)} - ${DateFormat('dd.MM.yyyy').format(_range!.end)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Renkler.kahveTon,
                    side: const BorderSide(color: Renkler.kahveTon),
                  ),
                ),
                if (_range != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Tarih filtresini temizle',
                    onPressed: () => setState(() => _range = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<SiparisModel>>(
              stream: _svc.tamamlananDinle(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Hata: ${snap.error}'));
                }

                final list = snap.data ?? [];
                final q = _araCtrl.text.trim().toLowerCase();

                final filtreli =
                    list.where((s) {
                      final musteriAd = _musteriAdi(s.musteri).toLowerCase();
                      final acik = (s.aciklama ?? '').toLowerCase();
                      final bitti = s.islemeTarihi ?? s.tarih;
                      final matchQ =
                          q.isEmpty ||
                          musteriAd.contains(q) ||
                          acik.contains(q);
                      final matchDate = _inDateRange(bitti);
                      return matchQ && matchDate;
                    }).toList()..sort((a, b) {
                      final da = a.islemeTarihi ?? a.tarih;
                      final db = b.islemeTarihi ?? b.tarih;
                      return (db ?? DateTime(0)).compareTo(da ?? DateTime(0));
                    });

                if (filtreli.isEmpty) {
                  return const Center(child: Text('Kayıt bulunamadı.'));
                }

                final toplamTutar = filtreli.fold<double>(
                  0,
                  (t, s) => t + s.brutToplam,
                );
                final adet = filtreli.length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Row(
                        children: [
                          _istatistikMini(
                            icon: Icons.receipt_long,
                            etiket: 'Sipariş',
                            deger: adet.toString(),
                            scheme: scheme,
                          ),
                          const SizedBox(width: 8),
                          _istatistikMini(
                            icon: Icons.payments,
                            etiket: 'Toplam',
                            deger: _paraFmt.format(toplamTutar),
                            scheme: scheme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: filtreli.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = filtreli[i];
                          final ad = _musteriAdi(s.musteri);
                          final bitti = s.islemeTarihi ?? s.tarih;
                          final toplam = s.brutToplam;
                          final statusName = s.durum.name;
                          final statusColor = _durumRengi(statusName);

                          return Dismissible(
                            key: ValueKey('sip_${s.docId}'),
                            direction: DismissDirection.startToEnd,
                            confirmDismiss: (_) => _confirmAndDelete(s),
                            background: _dismissBg(),
                            child: _SiparisKart(
                              baslik: ad,
                              altYazi:
                                  'Durum: ${statusName.toUpperCase()}  •  ${_fmtTarih(bitti)}',
                              solGunKutucuk: _fmtGunKisa(bitti),
                              toplamYazi: _paraFmt.format(toplam),
                              statusColor: statusColor,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SiparisGecmisDetaySayfasi(
                                      siparisId: s.docId!,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _istatistikMini({
    required IconData icon,
    required String etiket,
    required String deger,
    required ColorScheme scheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(blurRadius: 6, offset: Offset(0, 1), color: Colors.black12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deger,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                etiket,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dismissBg() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade400,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Sil',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _SiparisKart extends StatelessWidget {
  final String baslik;
  final String altYazi;
  final String solGunKutucuk;
  final String toplamYazi;
  final Color statusColor;
  final VoidCallback onTap;

  const _SiparisKart({
    required this.baslik,
    required this.altYazi,
    required this.solGunKutucuk,
    required this.toplamYazi,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: statusColor.withOpacity(0.12),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
                ),
                child: Text(
                  solGunKutucuk,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      baslik,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      altYazi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    toplamYazi,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'durum',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
