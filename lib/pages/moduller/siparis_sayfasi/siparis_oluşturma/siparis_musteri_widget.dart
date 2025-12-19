import 'dart:async';
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/services/musteri/musteri_service.dart';

class SiparisMusteriWidget extends StatefulWidget {
  final TextEditingController firmaAdiController;
  final TextEditingController yetkiliController;
  final TextEditingController telefonController;
  final TextEditingController adresController;
  final VoidCallback onIleri;
  final MusteriModel? secilenMusteri;
  final Function(MusteriModel)? onMusteriSecildi;

  const SiparisMusteriWidget({
    super.key,
    required this.firmaAdiController,
    required this.yetkiliController,
    required this.telefonController,
    required this.adresController,
    required this.onIleri,
    this.secilenMusteri,
    this.onMusteriSecildi,
  });

  @override
  State<SiparisMusteriWidget> createState() => _SiparisMusteriWidgetState();
}

class _SiparisMusteriWidgetState extends State<SiparisMusteriWidget> {
  final _musteriSvc = MusteriService.instance;

  MusteriModel? _secilen;
  bool _kayitliOlsun = false;

  @override
  void initState() {
    super.initState();
    _secilen = widget.secilenMusteri;
  }

  bool get _formGecerli =>
      widget.firmaAdiController.text.trim().isNotEmpty &&
      widget.telefonController.text.trim().isNotEmpty;

  void _musteriAta(MusteriModel m) {
    setState(() {
      _secilen = m;
      _kayitliOlsun = false;
    });
    widget.firmaAdiController.text = m.firmaAdi ?? '';
    widget.yetkiliController.text = m.yetkili ?? '';
    widget.telefonController.text = m.telefon ?? '';
    widget.adresController.text = m.adres ?? '';
    widget.onMusteriSecildi?.call(m);
  }

  void _musteriSecimiTemizle() {
    setState(() {
      _secilen = null;
    });
  }

  Future<void> _kayitlidanSec() async {
    final secilen = await showModalBottomSheet<MusteriModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.95,
        child: MusteriSecBottomSheet(),
      ),
    );

    if (secilen != null) {
      _musteriAta(secilen);
    }
  }

  Future<void> _handleIleri() async {
    if (_secilen != null) {
      widget.onMusteriSecildi?.call(_secilen!);
      widget.onIleri();
      return;
    }

    if (!_formGecerli) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Firma adı ve telefon zorunludur.")),
      );
      return;
    }

    final yeni = MusteriModel(
      id: '',
      firmaAdi: widget.firmaAdiController.text.trim(),
      yetkili: widget.yetkiliController.text.trim().isEmpty
          ? null
          : widget.yetkiliController.text.trim(),
      telefon: widget.telefonController.text.trim(),
      adres: widget.adresController.text.trim().isEmpty
          ? null
          : widget.adresController.text.trim(),
    );

    try {
      MusteriModel sonKullanilacakModel;

      if (_kayitliOlsun) {
        final docId = await _musteriSvc.ekle(yeni);
        sonKullanilacakModel = MusteriModel(
          id: docId,
          firmaAdi: yeni.firmaAdi,
          yetkili: yeni.yetkili,
          telefon: yeni.telefon,
          adres: yeni.adres,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Müşteri kayıtlılara eklendi.")),
        );
      } else {
        sonKullanilacakModel = yeni;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Müşteri kaydedilmedi, yalnızca siparişe işlendi."),
          ),
        );
      }

      widget.onMusteriSecildi?.call(sonKullanilacakModel);
      widget.onIleri();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Müşteri kaydedilemedi: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final alanlarKilitli = _secilen != null;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Renkler.kahveTon.withOpacity(.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Müşteri Bilgileri",
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alanlarKilitli
                            ? "Kayıtlı müşteri seçildi — bilgiler kilitli."
                            : "Kayıtlı müşteriden seç veya bilgileri elle doldur",
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.textTheme.bodySmall?.color?.withOpacity(
                            .7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Renkler.kahveTon,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _kayitlidanSec,
                  icon: const Icon(Icons.person_search, color: Colors.white),
                  label: const Text(
                    "Kayıtlıdan Seç",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          if (_secilen != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Renkler.kahveTon.withOpacity(.5),
                    child: Text(
                      ((_secilen!.firmaAdi ?? _secilen!.yetkili ?? '?')
                              .isNotEmpty)
                          ? (_secilen!.firmaAdi ?? _secilen!.yetkili!)![0]
                          : '?',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  title: Text(_secilen!.firmaAdi ?? _secilen!.yetkili ?? '—'),
                  subtitle: Text(
                    "${_secilen!.yetkili ?? '—'} • ${_secilen!.telefon ?? '—'}",
                  ),
                  trailing: IconButton(
                    tooltip: "Seçimi temizle",
                    onPressed: _musteriSecimiTemizle,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _MetinAlani(
                        label: "Firma Adı *",
                        icon: Icons.apartment,
                        controller: widget.firmaAdiController,
                        enabled: !alanlarKilitli,
                      ),
                      const SizedBox(height: 12),
                      _MetinAlani(
                        label: "Yetkili Kişi",
                        icon: Icons.person_outline,
                        controller: widget.yetkiliController,
                        enabled: !alanlarKilitli,
                      ),
                      const SizedBox(height: 12),
                      _MetinAlani(
                        label: "Telefon *",
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        controller: widget.telefonController,
                        enabled: !alanlarKilitli,
                      ),
                      const SizedBox(height: 12),
                      _MetinAlani(
                        label: "Adres",
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                        controller: widget.adresController,
                        enabled: !alanlarKilitli,
                      ),

                      const Divider(height: 24),
                      if (!alanlarKilitli)
                        CheckboxListTile(
                          activeColor: Renkler.kahveTon,
                          value: _kayitliOlsun,
                          onChanged: (v) {
                            setState(() => _kayitliOlsun = v ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text("Kayıtlı müşterilere ekle"),
                          subtitle: const Text(
                            "İşaretlersen, bu müşteriyi müşteri listene kaydedeceğiz.",
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: tema.scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _handleIleri,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Renkler.kahveTon,
                  disabledBackgroundColor: Renkler.kahveTon.withOpacity(.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: Text(
                  _secilen != null
                      ? "İleri (Kayıtlı Müşteri)"
                      : _kayitliOlsun
                      ? "İleri (Kaydet)"
                      : "İleri (Kaydetmeden)",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MusteriSecBottomSheet extends StatefulWidget {
  const MusteriSecBottomSheet({super.key});

  @override
  State<MusteriSecBottomSheet> createState() => _MusteriSecBottomSheetState();
}

class _MusteriSecBottomSheetState extends State<MusteriSecBottomSheet> {
  final _svc = MusteriService.instance;

  final TextEditingController _aramaCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  Timer? _debounce;
  String _harfFiltre = 'Tümü';
  bool _azToZa = true;

  static const int _pageSize = 40;
  int _limit = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _aramaCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      setState(() => _limit += _pageSize);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _limit = _pageSize;
      });
    });
  }

  List<MusteriModel> _uygulanmisListe(List<MusteriModel> tum) {
    final q = _aramaCtrl.text.toLowerCase();

    Iterable<MusteriModel> veri = tum;

    // Harf filtresi (firmaAdi yoksa yetkili’yi baz al)
    if (_harfFiltre != 'Tümü') {
      veri = veri.where((m) {
        final base =
            (m.firmaAdi?.trim().isNotEmpty == true
                    ? m.firmaAdi!
                    : (m.yetkili ?? ''))
                .trim();
        return base.isNotEmpty && base.toUpperCase().startsWith(_harfFiltre);
      });
    }

    // Arama (firma/yetkili/telefon/adres)
    if (q.isNotEmpty) {
      veri = veri.where((m) {
        final firma = (m.firmaAdi ?? '').toLowerCase();
        final yetkili = (m.yetkili ?? '').toLowerCase();
        final tel = (m.telefon ?? '').toLowerCase();
        final adr = (m.adres ?? '').toLowerCase();
        return firma.contains(q) ||
            yetkili.contains(q) ||
            tel.contains(q) ||
            adr.contains(q);
      });
    }

    // Sıralama
    final liste = veri.toList()
      ..sort((a, b) {
        final aa = (a.firmaAdi ?? a.yetkili ?? '').toLowerCase();
        final bb = (b.firmaAdi ?? b.yetkili ?? '').toLowerCase();
        return _azToZa ? aa.compareTo(bb) : bb.compareTo(aa);
      });
    final int son = _limit.clamp(0, liste.length).toInt();
    return liste.take(son).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kayıtlı Müşteri Seç"),
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
        actions: [
          IconButton(
            tooltip: _azToZa ? "Z→A sırala" : "A→Z sırala",
            onPressed: () => setState(() => _azToZa = !_azToZa),
            icon: Icon(_azToZa ? Icons.sort_by_alpha : Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _aramaCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Firma adı / yetkili / telefon",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor.withOpacity(.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
              ),
            ),
          ),

          SizedBox(
            height: 46,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                _harfChip('Tümü'),
                ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map(_harfChip),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<MusteriModel>>(
              stream: _svc.dinle(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text("Hata: ${snap.error}"));
                }
                final tum = snap.data ?? [];
                final filtrelenmis = _uygulanmisListe(tum);

                if (filtrelenmis.isEmpty) {
                  return _BosSonuc(onKapat: () => Navigator.pop(context));
                }

                return ListView.separated(
                  controller: _scrollCtrl,
                  itemCount: filtrelenmis.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = filtrelenmis[i];
                    final base = (m.firmaAdi?.isNotEmpty == true)
                        ? m.firmaAdi!
                        : (m.yetkili ?? '');
                    final harf = base.isNotEmpty ? base[0].toUpperCase() : '?';

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          harf,
                          style: TextStyle(color: Colors.black),
                        ),
                        backgroundColor: Renkler.kahveTon.withOpacity(.5),
                      ),
                      title: Text(m.firmaAdi ?? m.yetkili ?? '—'),
                      subtitle: Text(
                        "${m.yetkili ?? '—'} • ${m.telefon ?? '—'}",
                      ),
                      onTap: () => Navigator.pop(context, m),
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

  Widget _harfChip(String harf) {
    final secili = _harfFiltre == harf;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(harf),
        selectedColor: Renkler.kahveTon.withOpacity(.7),
        selected: secili,
        onSelected: (_) {
          setState(() {
            _harfFiltre = harf;
            _limit = _pageSize;
          });
        },
      ),
    );
  }
}

class _BosSonuc extends StatelessWidget {
  final VoidCallback onKapat;
  const _BosSonuc({required this.onKapat});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_off, size: 48),
          const SizedBox(height: 8),
          const Text("Eşleşen müşteri bulunamadı."),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onKapat,
            icon: const Icon(Icons.close),
            label: const Text("Kapat"),
          ),
        ],
      ),
    );
  }
}

class _MetinAlani extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool enabled;

  const _MetinAlani({
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Renkler.kahveTon),
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
