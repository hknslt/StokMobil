import 'package:flutter/material.dart';
import 'package:capri/pages/home/utils/bugunun_siparisleri_widget.dart';
import 'package:capri/pages/home/utils/siparis_ozet_paneli.dart';
import 'package:capri/pages/home/utils/stoksuz_urunler_widget.dart.dart';
import 'package:capri/pages/home/utils/sevkiyatta_olanlar_widget.dart';
import 'package:capri/pages/home/utils/uretimde_olanlar_widget.dart';

class AdminWidget extends StatelessWidget {
  const AdminWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SiparisOzetPaneli(),
          SizedBox(height: 16),
          const BugununSiparisleriWidget(),
        ],
      ),
    );
  }
}
