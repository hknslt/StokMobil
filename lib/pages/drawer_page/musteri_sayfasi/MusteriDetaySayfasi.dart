import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_detay_sayfasi.dart';
import 'package:capri/pages/widgets/siparis_durum_etiketi.dart';
import 'package:capri/services/musteri/musteri_service.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';

class MusteriDetaySayfasi extends StatefulWidget {
  final MusteriModel musteri;
  const MusteriDetaySayfasi({super.key, required this.musteri});

  @override
  State<MusteriDetaySayfasi> createState() => _MusteriDetaySayfasiState();
}

class _MusteriDetaySayfasiState extends State<MusteriDetaySayfasi> {
  final _siparisSvc = SiparisService();
  final _musteriSvc = MusteriService.instance;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firmaCtrl;
  late final TextEditingController _yetkiliCtrl;
  late final TextEditingController _telefonCtrl;
  late final TextEditingController _adresCtrl;

  @override
  void initState() {
    super.initState();
    _firmaCtrl = TextEditingController(text: widget.musteri.firmaAdi ?? '');
    _yetkiliCtrl = TextEditingController(text: widget.musteri.yetkili ?? '');
    _telefonCtrl = TextEditingController(text: widget.musteri.telefon ?? '');
    _adresCtrl = TextEditingController(text: widget.musteri.adres ?? '');
  }

  @override
  void dispose() {
    _firmaCtrl.dispose();
    _yetkiliCtrl.dispose();
    _telefonCtrl.dispose();
    _adresCtrl.dispose();
    super.dispose();
  }

  Future<void> _duzenleKaydet() async {
    if (!_formKey.currentState!.validate()) return;

    final guncel = MusteriModel(
      id: widget.musteri.id,
      firmaAdi: _firmaCtrl.text.trim(),
      yetkili: _yetkiliCtrl.text.trim().isEmpty
          ? null
          : _yetkiliCtrl.text.trim(),
      telefon: _telefonCtrl.text.trim().isEmpty
          ? null
          : _telefonCtrl.text.trim(),
      adres: _adresCtrl.text.trim().isEmpty ? null : _adresCtrl.text.trim(),
    );

    await _musteriSvc.guncelle(guncel);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Müşteri bilgileri güncellendi")),
    );
    Navigator.pop(context);
    setState(() {});
  }

  void _acDuzenleDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Müşteri Bilgilerini Düzenle"),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _firmaCtrl,
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
                  controller: _yetkiliCtrl,
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
                  controller: _telefonCtrl,
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
                  controller: _adresCtrl,
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
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "İptal",
              style: TextStyle(color: Renkler.kahveTon),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Renkler.kahveTon),
            onPressed: _duzenleKaydet,
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _baslik(MusteriModel m) =>
      (m.firmaAdi?.isNotEmpty == true ? m.firmaAdi! : (m.yetkili ?? "Müşteri"));

  @override
  Widget build(BuildContext context) {
    final m = widget.musteri;
    print("Aranan Müşteri ID: ${m.id} (Türü: ${m.id.runtimeType})");

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
        title: Text(_baslik(m)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Müşteri Bilgilerini Düzenle",
            onPressed: _acDuzenleDialog,
          ),
        ],
      ),
      body: StreamBuilder<List<SiparisModel>>(
        stream: _siparisSvc.musteriSiparisleriDinle(m.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text("Hata: ${snap.error}"));
          }
          final siparisler = snap.data ?? [];
          final siparisAdedi = siparisler.length;
          final toplamBrut = siparisler.fold<double>(
            0.0,
            (s, sp) => s + sp.brutToplam,
          );

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Müşteri kısa bilgiler kartı
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _baslik(m),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (m.yetkili?.isNotEmpty == true)
                        Text("Yetkili: ${m.yetkili}"),
                      if (m.telefon?.isNotEmpty == true)
                        Text("Telefon: ${m.telefon}"),
                      if (m.adres?.isNotEmpty == true)
                        Text("Adres: ${m.adres}"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // İstatistik kartları
              Row(
                children: [
                  Expanded(
                    child: _istatistikKart(
                      baslik: "Sipariş Sayısı",
                      icerik: "$siparisAdedi",
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _istatistikKart(
                      baslik: "Toplam Ciro (Brüt)",
                      icerik: "₺${toplamBrut.toStringAsFixed(2)}",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                "Geçmiş Siparişler",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),

              if (siparisler.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text("${_baslik(m)} için henüz sipariş bulunmuyor."),
                  ),
                )
              else
                ...siparisler.map((sp) {
                  final tarihStr = DateFormat(
                    'dd.MM.yyyy – HH:mm',
                  ).format(sp.tarih);
                  final urunSayisi = sp.urunler.length;
                  final brutToplam = sp.brutToplam;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        tarihStr,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text("Durum: "),
                              SiparisDurumEtiketi(durum: sp.durum),
                            ],
                          ),
                          Text("Ürün Sayısı: $urunSayisi"),
                          Text(
                            "Toplam (Brüt): ₺${brutToplam.toStringAsFixed(2)}",
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SiparisDetaySayfasi(siparis: sp),
                          ),
                        );
                      },
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  Widget _istatistikKart({required String baslik, required String icerik}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
              icerik,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
