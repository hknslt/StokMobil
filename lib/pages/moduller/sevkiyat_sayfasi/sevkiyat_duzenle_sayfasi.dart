import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:capri/core/models/urun_model.dart';
import 'package:capri/services/sevkiyat_service.dart';
import 'package:capri/services/urun_service.dart';
import 'dart:async';

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}

class SevkiyatDuzenleSayfasi extends StatefulWidget {
  final SiparisModel siparis;
  const SevkiyatDuzenleSayfasi({super.key, required this.siparis});
  @override
  State<SevkiyatDuzenleSayfasi> createState() => _SevkiyatDuzenleSayfasiState();
}

class _SevkiyatDuzenleSayfasiState extends State<SevkiyatDuzenleSayfasi> {
  late List<SiparisUrunModel> _guncelUrunler;
  final _sevkiyatServis = SevkiyatService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _guncelUrunler = widget.siparis.urunler.map((u) => u.copyWith()).toList();
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _urunAdetGuncelleAnaSayfa(SiparisUrunModel urun, int yeniAdet) {
    if (_isLoading || yeniAdet < 0) return;
    setState(() {
      final index = _guncelUrunler.indexWhere((u) => u.id == urun.id);
      if (index != -1) {
        if (yeniAdet == 0) {
          _guncelUrunler.removeAt(index);
          _showSnackbar(
            'Ürün (${urun.urunAdi}) listeden çıkarıldı.',
            Colors.red.shade400,
          );
        } else {
          _guncelUrunler[index] = urun.copyWith(adet: yeniAdet);
        }
      }
    });
  }

  void _arttirAnaSayfa(SiparisUrunModel urun) {
    _urunAdetGuncelleAnaSayfa(urun, urun.adet + 1);
  }

  void _azaltAnaSayfa(SiparisUrunModel urun) {
    _urunAdetGuncelleAnaSayfa(urun, urun.adet - 1);
  }

  Future<void> _urunEkle() async {
    if (!mounted) return;
    final List<SiparisUrunModel> mevcutSecimKopyasi = _guncelUrunler
        .map((u) => u.copyWith())
        .toList();
    final List<SiparisUrunModel>? secilenler =
        await showModalBottomSheet<List<SiparisUrunModel>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.white,
          builder: (ctx) =>
              UrunSecimBottomSheet(initialSecilenler: mevcutSecimKopyasi),
        );
    if (secilenler != null && mounted) {
      setState(() {
        _guncelUrunler = secilenler;
      });
      _showSnackbar('Ürün listesi güncellendi.', Renkler.anaMavi);
    }
  }

  Future<void> _kaydet() async {
    if (widget.siparis.docId == null) {
      _showSnackbar('Sipariş ID bulunamadı.', Colors.red);
      return;
    }
    final toplamAdet = _guncelUrunler.fold<int>(0, (sum, u) => sum + u.adet);
    if (toplamAdet == 0) {
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Uyarı'),
          content: const Text(
            'Sevkiyatta hiç ürün kalmadı. Siparişin durumu değişmeyecek, yine de kaydetmek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Evet, Kaydet'),
            ),
          ],
        ),
      );
      if (onay != true) return;
    }
    setState(() => _isLoading = true);
    try {
      await _sevkiyatServis.sevkiyatUrunleriniGuncelle(
        widget.siparis.docId!,
        _guncelUrunler,
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackbar(
        'Sevkiyat ürünleri ve stoklar başarıyla güncellendi.',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().contains("Stok yetersiz")
          ? 'Stok hatası: Lütfen eklediğiniz ürünlerin stoğunu kontrol edin.'
          : 'Beklenmedik bir hata oluştu: ${e.toString()}';
      _showSnackbar(errorMessage, Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toplamAdet = _guncelUrunler.fold<int>(0, (sum, u) => sum + u.adet);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sevkiyat Düzenle: ${widget.siparis.musteri.firmaAdi ?? 'Sipariş'}',
        ),
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Mevcut Liste (${_guncelUrunler.length} çeşit / $toplamAdet adet)',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _urunEkle,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ürün Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Renkler.anaMavi,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _guncelUrunler.length,
              itemBuilder: (context, index) {
                final urun = _guncelUrunler[index];
                return ListTile(
                  leading: const Icon(
                    Icons.inventory_2_outlined,
                    color: Renkler.kahveTon,
                  ),
                  title: Text(urun.urunAdi ?? '-'),
                  subtitle: Text('Renk: ${urun.renk ?? '-'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => _azaltAnaSayfa(urun),
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: urun.adet > 1 ? null : Colors.grey,
                        ),
                        tooltip: "Adet Azalt",
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${urun.adet}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => _arttirAnaSayfa(urun),
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: "Adet Artır",
                      ),
                      IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => _urunAdetGuncelleAnaSayfa(urun, 0),
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        tooltip: "Ürünü Kaldır",
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _kaydet,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isLoading
                    ? 'Kaydediliyor...'
                    : 'Değişiklikleri Kaydet ($toplamAdet adet)',
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Renkler.kahveTon,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UrunSecimBottomSheet extends StatefulWidget {
  final List<SiparisUrunModel> initialSecilenler;
  const UrunSecimBottomSheet({super.key, required this.initialSecilenler});
  @override
  State<UrunSecimBottomSheet> createState() => _UrunSecimBottomSheetState();
}

class _UrunSecimBottomSheetState extends State<UrunSecimBottomSheet> {
  late List<SiparisUrunModel> _secilenler;
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _aramaCtrl = TextEditingController();
  final _srv = UrunService();
  String _arama = "";
  static const int _pageSize = 60;
  int _limit = _pageSize;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _secilenler = widget.initialSecilenler.map((u) => u.copyWith()).toList();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _debounce?.cancel();
    _aramaCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      setState(() => _limit += _pageSize);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _arama = v;
        _limit = _pageSize;
      });
    });
  }

  int _toplamAdet() => _secilenler.fold(0, (s, e) => s + e.adet);

  SiparisUrunModel? _bulSecim(String urunId) {
    return _secilenler.firstWhereOrNull((e) => e.id == urunId);
  }

  SiparisUrunModel? _findSecimInInitialList(String urunId) {
    return widget.initialSecilenler.firstWhereOrNull((e) => e.id == urunId);
  }

  void _ekleVeyaGuncelle(Urun u, int adet) {
    final String urunId = u.id.toString();
    setState(() {
      _secilenler.removeWhere((e) => e.id == urunId);
      if (adet > 0) {
        final mevcutFiyat = _findSecimInInitialList(urunId)?.birimFiyat ?? 0.0;
        _secilenler.add(
          SiparisUrunModel(
            id: urunId,
            urunAdi: u.urunAdi,
            renk: u.renk,
            adet: adet,
            birimFiyat: mevcutFiyat,
          ),
        );
      }
    });
  }

  void _arttir(Urun u) {
    final varOlan = _bulSecim(u.id.toString());
    _ekleVeyaGuncelle(u, (varOlan?.adet ?? 0) + 1);
  }

  void _azalt(Urun u) {
    final varOlan = _bulSecim(u.id.toString());
    if (varOlan == null || varOlan.adet <= 0) return;
    _ekleVeyaGuncelle(u, varOlan.adet - 1);
  }

  void _kaldir(Urun u) {
    _ekleVeyaGuncelle(u, 0);
  }

  Future<void> _adetSecBottomSheet(Urun u) async {
    int adet = _bulSecim(u.id.toString())?.adet ?? 1;
    final int stok = u.adet;
    final TextEditingController adetCtrl = TextEditingController(
      text: adet.toString(),
    );

    final sonuc = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          void syncText() {
            if (adetCtrl.text != adet.toString()) {
              adetCtrl.text = adet.toString();
              adetCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: adetCtrl.text.length),
              );
            }
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${u.urunAdi} | ${u.renk}",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text("Mevcut Stok: $stok"),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (adet > 1) {
                          setModalState(() => adet--);
                          syncText();
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: adetCtrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) {
                          final parsed = int.tryParse(v);
                          setModalState(
                            () => adet = (parsed == null || parsed <= 0)
                                ? 1
                                : parsed,
                          );
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setModalState(() => adet++);
                        syncText();
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Renkler.kahveTon,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final onayAdet = int.tryParse(adetCtrl.text) ?? adet;
                      Navigator.pop(modalCtx, onayAdet > 0 ? onayAdet : 1);
                    },
                    child: const Text(
                      "Onayla",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (sonuc != null && sonuc > 0) _ekleVeyaGuncelle(u, sonuc);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Ürün Seçimi (Sevkiyat)",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_secilenler.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Renkler.kahveTon.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Seçili: ${_secilenler.length} ürün • ${_toplamAdet()} adet",
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _aramaCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Ürün ara (ad / renk / kod)...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(height: 12),
          if (_secilenler.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _secilenler.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final e = _secilenler[i];
                  return Chip(
                    label: Text("${e.urunAdi} (${e.adet})"),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () {
                      _kaldir(
                        Urun(
                          id: int.parse(e.id),
                          urunKodu: '',
                          urunAdi: e.urunAdi ?? '',
                          renk: e.renk ?? '',
                          adet: 0,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Urun>>(
              stream: _srv.dinle(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snap.hasError)
                  return Center(child: Text('Hata: ${snap.error}'));
                var urunler = (snap.data ?? <Urun>[]);
                if (_arama.isNotEmpty) {
                  final q = _arama.toLowerCase();
                  urunler = urunler
                      .where(
                        (u) =>
                            u.urunAdi.toLowerCase().contains(q) ||
                            u.renk.toLowerCase().contains(q) ||
                            u.urunKodu.toLowerCase().contains(q),
                      )
                      .toList();
                }
                final sliced = urunler.take(_limit).toList();
                if (sliced.isEmpty)
                  return const Center(child: Text("Ürün bulunamadı."));
                return ListView.builder(
                  controller: _scrollCtrl,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: sliced.length,
                  itemBuilder: (_, i) => _UrunSatir(
                    urun: sliced[i],
                    secim: _bulSecim(sliced[i].id.toString()),
                    kahve: Renkler.kahveTon,
                    arttir: _arttir,
                    azalt: _azalt,
                    kaldir: _kaldir,
                    adetSec: _adetSecBottomSheet,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Renkler.kahveTon,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context, _secilenler),
              icon: const Icon(Icons.done_all, color: Colors.white),
              label: Text(
                _toplamAdet() == 0
                    ? "Seçimi Bitir"
                    : "Seçimi Onayla (${_toplamAdet()} adet)",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrunSatir extends StatelessWidget {
  final Urun urun;
  final SiparisUrunModel? secim;
  final Color kahve;
  final void Function(Urun) arttir;
  final void Function(Urun) azalt;
  final void Function(Urun) kaldir;
  final Future<void> Function(Urun) adetSec;

  const _UrunSatir({
    required this.urun,
    required this.secim,
    required this.kahve,
    required this.arttir,
    required this.azalt,
    required this.kaldir,
    required this.adetSec,
  });

  @override
  Widget build(BuildContext context) {
    final stok = urun.adet;
    final secili = secim != null;
    final titleText = "${urun.urunAdi} | ${urun.renk} (${urun.urunKodu})";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          titleText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        subtitle: Text("Stok: $stok"),
        trailing: SizedBox(
          width: 170,
          child: secili
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: "Azalt",
                        onPressed: () => azalt(urun),
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => adetSec(urun),
                        child: Text(
                          "${secim!.adet}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: "Arttır",
                        onPressed: () => arttir(urun),
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: "Kaldır",
                        onPressed: () => kaldir(urun),
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                )
              : TextButton.icon(
                  onPressed: () => adetSec(urun),
                  icon: Icon(Icons.add_circle_outline, color: kahve, size: 20),
                  label: Text("Ekle", style: TextStyle(color: kahve)),
                ),
        ),
      ),
    );
  }
}
