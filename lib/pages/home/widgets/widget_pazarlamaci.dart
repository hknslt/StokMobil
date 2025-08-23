import 'package:flutter/material.dart';
import 'package:capri/pages/home/utils/bugunun_siparisleri_widget.dart';
import 'package:capri/pages/home/utils/sevkiyatta_olanlar_widget.dart';
import 'package:capri/pages/home/utils/siparis_ozet_paneli.dart';
import 'package:capri/pages/home/utils/uretimde_olanlar_widget.dart';
import 'package:capri/pages/moduller/uretim_sayfasi/uretim_sayfasi.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/sevkiyat_sayfasi.dart';

class PazarlamaciWidget extends StatelessWidget {
  const PazarlamaciWidget({super.key});

@override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SiparisOzetPaneli(),
          SizedBox(height: 16),
          BugununSiparisleriWidget(),
        ],
      ),
    );
  }
}
