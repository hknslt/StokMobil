import 'dart:async';
import 'package:capri/core/models/musteri_model.dart';
import 'package:capri/core/models/siparis_urun_model.dart';
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';

class TamamlananSevkiyatlarSayfasi extends StatefulWidget {
  const TamamlananSevkiyatlarSayfasi({super.key});

  @override
  State<TamamlananSevkiyatlarSayfasi> createState() =>
      _TamamlananSevkiyatlarSayfasiState();
}

class _TamamlananSevkiyatlarSayfasiState
    extends State<TamamlananSevkiyatlarSayfasi> {
  final _servis = SiparisService();
  late final Stream<List<SiparisModel>> _stream;

  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    try {
      _stream = _servis.hepsiDinle();
      debugPrint('Stream başlatıldı');
    } catch (e) {
      debugPrint('Stream başlatma hatası: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('TamamlananSevkiyatlar dispose ediliyor');
    _deb?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearSearch() {
    setState(() {
      _query = '';
      _searchCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _onSearchChanged(String value) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tamamlanan Sevkiyatlar"),
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
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Aramayı temizle',
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear),
            ),
        ],
      ),
      body: Column(
        children: [
          // Arama kutusu
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: 'Müşteri adı veya yetkili ara...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Renkler.kahveTon, width: 2),
                  borderRadius: BorderRadius.circular(20),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          // Sipariş listesi
          Expanded(
            child: StreamBuilder<List<SiparisModel>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Hata: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Yeniden Dene'),
                        ),
                      ],
                    ),
                  );
                }

                // Sadece tamamlanan siparişler
                var siparisler = (snapshot.data ?? [])
                    .where((s) => s.durum == SiparisDurumu.tamamlandi)
                    .toList();

                // Arama filtresi
                if (_query.isNotEmpty) {
                  siparisler = siparisler.where((s) {
                    final firma = (s.musteri?.firmaAdi ?? '').toLowerCase();
                    final yetkili = (s.musteri?.yetkili ?? '').toLowerCase();
                    return firma.contains(_query) || yetkili.contains(_query);
                  }).toList();
                }

                if (siparisler.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text("Tamamlanan sevkiyat bulunamadı"),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: siparisler.length,
                  itemBuilder: (context, index) {
                    final siparis = siparisler[index];
                    return _SiparisKarti(siparis: siparis);
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

class _SiparisKarti extends StatelessWidget {
  final SiparisModel siparis;

  const _SiparisKarti({required this.siparis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final musteri = siparis.musteri;
    final firma = musteri?.firmaAdi ?? 'Firma adı yok';
    final yetkili = musteri?.yetkili ?? 'Yetkili yok';
    final urunler = siparis.urunler ?? [];
    final toplamUrun = urunler.fold<int>(0, (sum, u) => sum + (u.adet ?? 0));
    final aciklama = siparis.aciklama?.trim() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Müşteri bilgisi
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Renkler.kahveTon.withOpacity(0.15),
                  child: Text(
                    firma.isNotEmpty ? firma[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Renkler.kahveTon,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firma,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Yetkili: $yetkili',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Durum etiketi
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Tamamlandı',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            // Açıklama varsa göster
            if (aciklama.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_alt_outlined,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        aciklama,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Ürün özeti
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '${urunler.length} çeşit ürün',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Toplam: $toplamUrun adet',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            if (urunler.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _showProductDetails(context, urunler),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_outlined, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Ürün detaylarını görüntüle',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showCustomerDetails(context, musteri),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Renkler.kahveTon.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Renkler.kahveTon.withOpacity(0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Müşteri detaylarını görüntüle',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetails(
    BuildContext context,
    List<SiparisUrunModel> urunler,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ürün Detayları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Ürün listesi
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: urunler.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final urun = urunler[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          urun.urunAdi ?? 'Ürün adı yok',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(urun.renk ?? 'Renk belirtilmemiş'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${urun.adet ?? 0} adet',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomerDetails(BuildContext context, MusteriModel musteri) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Müşteri Detayları',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Müşteri bilgileri
              _buildInfoRow('Firma Adı', musteri.firmaAdi ?? '-'),
              const SizedBox(height: 12),
              _buildInfoRow('Yetkili', musteri.yetkili ?? '-'),
              const SizedBox(height: 12),
              _buildInfoRow('Telefon', musteri.telefon ?? '-'),
              const SizedBox(height: 12),
              _buildInfoRow('Adres', musteri.adres ?? '-', isMultiline: true),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isMultiline = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: isMultiline ? null : 2,
            overflow: isMultiline ? null : TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
