import 'package:flutter/material.dart';
import 'package:capri/pages/home/utils/stoksuz_urunler_widget.dart.dart';
import 'package:capri/pages/home/utils/uretimde_olanlar_widget.dart';


class UretimWidget extends StatelessWidget {
  const UretimWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          StoksuzUrunlerWidget(),
          SizedBox(height: 24),
          UretimdeOlanlarWidget(),
        ],
      ),
    );
  }
}
