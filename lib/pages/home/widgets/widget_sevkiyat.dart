import 'package:flutter/material.dart';
import 'package:capri/pages/home/utils/sevkiyatta_olanlar_widget.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/sevkiyat_sayfasi.dart';

class SevkiyatWidget extends StatelessWidget {
  const SevkiyatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SevkiyattaOlanlarWidget(),
        ],
      ),
    );
  }
}
