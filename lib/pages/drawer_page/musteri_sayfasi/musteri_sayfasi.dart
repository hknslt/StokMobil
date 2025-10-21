import 'package:capri/pages/drawer_page/musteri_sayfasi/MusteriDetaySayfasi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/services/musteri_service.dart';

class MusterilerSayfasi extends StatefulWidget {
  const MusterilerSayfasi({super.key});

  @override
  State<MusterilerSayfasi> createState() => _MusterilerSayfasiState();
}

class _MusterilerSayfasiState extends State<MusterilerSayfasi> {
  final _svc = MusteriService.instance;

  final TextEditingController _aramaController = TextEditingController();
  String _siralaTuru = 'Ada göre';

  String _initialsFrom(MusteriModel m) {
    final base = (m.firmaAdi != null && m.firmaAdi!.trim().isNotEmpty)
        ? m.firmaAdi!.trim()
        : (m.yetkili ?? 'Müşteri').trim();
    final parts = base
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final i1 = first.isNotEmpty ? first[0] : 'M';
    final i2 = last.isNotEmpty ? last[0] : '';
    return (i1 + i2).toUpperCase();
  }

  // --- Ekle ---
  void _musteriEkleDialog() {
    final formKey = GlobalKey<FormState>();
    final firmaController = TextEditingController();
    final yetkiliController = TextEditingController();
    final telefonController = TextEditingController();
    final adresController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yeni Müşteri Ekle"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: firmaController,
                  decoration: const InputDecoration(
                    labelText: "Firma Adı",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(Icons.apartment, color: Renkler.kahveTon),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Firma adı zorunlu"
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: yetkiliController,
                  decoration: const InputDecoration(
                    labelText: "Yetkili",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(Icons.badge, color: Renkler.kahveTon),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: telefonController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Telefon",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(Icons.phone, color: Renkler.kahveTon),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: adresController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Adres",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(
                      Icons.location_on,
                      color: Renkler.kahveTon,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              "İptal",
              style: TextStyle(color: Renkler.kahveTon),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            child: const Text("Ekle", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final yeni = MusteriModel(
                id: '',
                firmaAdi: firmaController.text.trim(),
                yetkili: yetkiliController.text.trim().isEmpty
                    ? null
                    : yetkiliController.text.trim(),
                telefon: telefonController.text.trim().isEmpty
                    ? null
                    : telefonController.text.trim(),
                adres: adresController.text.trim().isEmpty
                    ? null
                    : adresController.text.trim(),
              );

              try {
                await _svc.ekle(yeni);
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Müşteri eklendi")),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Kaydetme hatası: $e")));
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Düzenle ---
  void _musteriDuzenleDialog(MusteriModel m) {
    final formKey = GlobalKey<FormState>();
    final firmaController = TextEditingController(text: m.firmaAdi ?? '');
    final yetkiliController = TextEditingController(text: m.yetkili ?? '');
    final telefonController = TextEditingController(text: m.telefon ?? '');
    final adresController = TextEditingController(text: m.adres ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Müşteri Düzenle"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: firmaController,
                  decoration: const InputDecoration(
                    labelText: "Firma Adı",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(Icons.apartment, color: Renkler.kahveTon),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Firma adı zorunlu"
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: yetkiliController,
                  decoration: const InputDecoration(
                    labelText: "Yetkili",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(Icons.badge, color: Renkler.kahveTon),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: telefonController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Telefon",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(Icons.phone, color: Renkler.kahveTon),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: adresController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Adres",
                    labelStyle: TextStyle(color: Renkler.kahveTon),
                    prefixIcon: Icon(
                      Icons.location_on,
                      color: Renkler.kahveTon,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              "İptal",
              style: TextStyle(color: Renkler.kahveTon),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final guncel = MusteriModel(
                id: m.id,
                firmaAdi: firmaController.text.trim(),
                yetkili: yetkiliController.text.trim().isEmpty
                    ? null
                    : yetkiliController.text.trim(),
                telefon: telefonController.text.trim().isEmpty
                    ? null
                    : telefonController.text.trim(),
                adres: adresController.text.trim().isEmpty
                    ? null
                    : adresController.text.trim(),
              );

              try {
                await _svc.guncelle(guncel);
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Güncellendi")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Güncelleme hatası: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // --- Sil ---
  void _musteriSil(MusteriModel m) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: Text(
          "\"${m.firmaAdi ?? m.yetkili ?? 'Müşteri'}\" kaydını silmek üzeresiniz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "İptal",
              style: TextStyle(color: Renkler.kahveTon),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (onay == true) {
      try {
        await _svc.sil(m.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Silindi")));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Silme hatası: $e")));
      }
    }
  }

  @override
  void dispose() {
    _aramaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        elevation: 0,
        title: const Text("Müşteriler"),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) => setState(() => _siralaTuru = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Ada göre', child: Text('Ada göre')),
              PopupMenuItem(value: 'En yeni', child: Text('En yeni')),
              PopupMenuItem(value: 'En eski', child: Text('En eski')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _aramaController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Ara: firma, yetkili, telefon...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _aramaController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _aramaController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _musteriEkleDialog,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          "Müşteri Ekle",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Renkler.kahveTon,
        elevation: 3,
      ),
      body: StreamBuilder<List<MusteriModel>>(
        stream: _svc.dinle(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Hata: ${snap.error}"));
          }
          var liste = snap.data ?? [];

          final q = _aramaController.text.trim().toLowerCase();
          if (q.isNotEmpty) {
            liste = liste.where((m) {
              final f = (m.firmaAdi ?? '').toLowerCase();
              final y = (m.yetkili ?? '').toLowerCase();
              final t = (m.telefon ?? '').toLowerCase();
              final a = (m.adres ?? '').toLowerCase();
              return f.contains(q) ||
                  y.contains(q) ||
                  t.contains(q) ||
                  a.contains(q);
            }).toList();
          }

          switch (_siralaTuru) {
            case 'En yeni':
              liste.sort((b, a) => a.id.compareTo(b.id));
              break;
            case 'En eski':
              liste.sort((a, b) => a.id.compareTo(b.id));
              break;
            default:
              liste.sort(
                (a, b) => (a.firmaAdi ?? a.yetkili ?? '')
                    .toLowerCase()
                    .compareTo((b.firmaAdi ?? b.yetkili ?? '').toLowerCase()),
              );
          }

          if (liste.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.person_search,
                  size: 64,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    q.isEmpty
                        ? "Hiç müşteri yok."
                        : "Arama ile eşleşen müşteri bulunamadı.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: liste.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final m = liste[index];

              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MusteriDetaySayfasi(musteri: m),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Renkler.kahveTon.withOpacity(0.15),
                        foregroundColor: Renkler.kahveTon,
                        child: Text(_initialsFrom(m)),
                      ),
                      title: Text(
                        m.firmaAdi ?? m.yetkili ?? "Müşteri",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m.yetkili?.isNotEmpty == true)
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(m.yetkili!)),
                                ],
                              ),
                            if (m.telefon?.isNotEmpty == true)
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: m.telefon!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Telefon kopyalandı"),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.phone, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        m.telefon!,
                                        style: const TextStyle(
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (m.adres?.isNotEmpty == true)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(m.adres!)),
                                ],
                              ),
                          ],
                        ),
                      ),
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: "Düzenle",
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _musteriDuzenleDialog(m),
                          ),
                          IconButton(
                            tooltip: "Sil",
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _musteriSil(m),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
