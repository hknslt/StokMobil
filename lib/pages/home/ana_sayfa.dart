import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/user.dart';
import 'package:capri/pages/home/widgets/widget_admin.dart';
import 'package:capri/pages/home/widgets/widget_pazarlamaci.dart';
import 'package:capri/pages/home/widgets/widget_sevkiyat.dart';
import 'package:capri/pages/home/widgets/widget_uretim.dart';
import 'package:capri/pages/widgets/ana_drawer.dart';


class AnaSayfa extends StatelessWidget {
  final UserModel user;

  const AnaSayfa({super.key, required this.user});

  Widget _buildIcerik() {
    switch (user.role) {
      case 'admin':
        return  AdminWidget();
      case 'pazarlamaci':
        return const PazarlamaciWidget();
      case 'uretim':
        return const UretimWidget();
      case 'sevkiyat':
        return const SevkiyatWidget();
      default:
        return const Center(child: Text("Yetki tanımsız."));
    }
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
        centerTitle: true,
        title: Image.asset("assets/images/capri_logo.png", height: 50),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: AnaDrawer(user: user),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildIcerik(),
      ),
    );
  }
}
