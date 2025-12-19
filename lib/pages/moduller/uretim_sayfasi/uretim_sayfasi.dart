import 'package:capri/core/Color/Colors.dart';
import 'package:capri/services/siparis_yonetimi/siparis_service.dart';
import 'package:capri/services/urun_yonetimi/urun_service.dart';
import 'package:flutter/material.dart';

// Dosyaları import et
import 'uretim_models_controller.dart';
import 'utils/uretim_dialogs.dart';
import 'widgets/uretim_filtre_bari.dart';
import 'widgets/uretim_karti.dart';

class UretimSayfasi extends StatefulWidget {
  const UretimSayfasi({super.key});

  @override
  State<UretimSayfasi> createState() => _UretimSayfasiState();
}

class _UretimSayfasiState extends State<UretimSayfasi> with AutomaticKeepAliveClientMixin {
  late final UretimController _controller;
  
  final _aramaCtrl = TextEditingController();
  String _aramaMetni = '';
  UretimSiralama _siralama = UretimSiralama.enCokEksik;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = UretimController(
      siparisServis: SiparisService(),
      urunServis: UrunService(),
    );
    _controller.init();
    
    _aramaCtrl.addListener(() {
      if (_aramaMetni != _aramaCtrl.text) {
        setState(() => _aramaMetni = _aramaCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _aramaCtrl.dispose();
    super.dispose();
  }

  // Listeyi filtrele ve sırala
  List<EksikGrup> _filtreleVeSirala(List<EksikGrup> hamListe) {
    var liste = List<EksikGrup>.from(hamListe);
    final sorgu = _aramaMetni.trim().toLowerCase();

    // 1. Filtreleme
    if (sorgu.isNotEmpty) {
      liste = liste.where((grup) {
        final u = grup.urunAdi.toLowerCase();
        final r = grup.renk.toLowerCase();
        final m = grup.firmalar.any((f) => f.musteriAdi.toLowerCase().contains(sorgu));
        return u.contains(sorgu) || r.contains(sorgu) || m;
      }).toList();
    }

    // 2. Sıralama
    liste.sort((a, b) {
      switch (_siralama) {
        case UretimSiralama.urunAdinaGore:
          return a.urunAdi.compareTo(b.urunAdi);
        case UretimSiralama.enEskiIstek:
          // null check gerekmez, grup varsa firma da vardır mantığıyla
          final tA = a.firmalar.firstOrNull?.siparisTarihi ?? DateTime.now();
          final tB = b.firmalar.firstOrNull?.siparisTarihi ?? DateTime.now();
          return tA.compareTo(tB);
        case UretimSiralama.enCokEksik:
        default:
          final cmp = b.toplamEksik.compareTo(a.toplamEksik);
          return cmp != 0 ? cmp : a.urunAdi.compareTo(b.urunAdi);
      }
    });

    return liste;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Üretim Takip"),
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
      body: StreamBuilder<UretimViewState>(
        stream: _controller.stream,
        builder: (context, snapshot) {
          final state = snapshot.data;

          if (state == null || state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(child: Text('Hata: ${state.error}'));
          }
          if (state.eksikListe.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text("Harika! Bekleyen üretim isteği yok.", style: TextStyle(fontSize: 16)),
                ],
              ),
            );
          }

          final gorunenListe = _filtreleVeSirala(state.eksikListe);

          return Column(
            children: [
              // Filtreleme Bölümü
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: UretimFiltreBari(
                  aramaCtrl: _aramaCtrl,
                  siralama: _siralama,
                  onSiralamaChanged: (v) {
                    if (v != null) setState(() => _siralama = v);
                  },
                  onClear: () => _aramaCtrl.clear(),
                ),
              ),

              // Liste Bölümü
              Expanded(
                child: gorunenListe.isEmpty
                    ? const Center(child: Text("Arama sonucu bulunamadı."))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: gorunenListe.length,
                        itemBuilder: (context, index) {
                          return UretimKarti(
                            grup: gorunenListe[index],
                            tumUrunler: state.tumUrunler,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Mevcut ürün listesini servisten alıp dialogu aç
          final urunler = await UrunService().onceGetir();
          if (context.mounted) {
            UretimDialogs.showGenelStokEkle(context, urunler);
          }
        },
        backgroundColor: Renkler.kahveTon,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Genel Stok Ekle", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}