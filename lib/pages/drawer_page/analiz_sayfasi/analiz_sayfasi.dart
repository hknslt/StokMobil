// lib/pages/drawer_page/analiz_sayfasi/analiz_sayfasi.dart
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/pages/drawer_page/analiz_sayfasi/grafikler/en_cok_satan_urunler.dart';
import 'package:flutter/material.dart';
import 'package:capri/pages/drawer_page/analiz_sayfasi/grafikler/kazanc_grafigi.dart';
import 'package:capri/pages/drawer_page/analiz_sayfasi/grafikler/siparis_grafigi.dart';

class AnalizSayfasi extends StatelessWidget {
  const AnalizSayfasi({super.key});

  static const double _gap = 12;
  static const double _twoColBreakpoint = 900; // >= 900px ise 2 sütun

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analiz Sayfası"),backgroundColor: Renkler.kahveTon,),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTwoCol = constraints.maxWidth >= _twoColBreakpoint;
          final columnCount = isTwoCol ? 2 : 1;
          final itemWidth = (constraints.maxWidth - _gap * (columnCount - 1)) / columnCount;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: const KazancGrafigi(),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: const SiparisGrafigi(),
                    ),
                    SizedBox(width: itemWidth, child: const EnCokSatanUrunlerPaneli()),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
