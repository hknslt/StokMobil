import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/user.dart';
import 'package:capri/pages/home/widgets/widget_admin.dart';
import 'package:capri/pages/home/widgets/widget_pazarlamaci.dart';
import 'package:capri/pages/home/widgets/widget_sevkiyat.dart';
import 'package:capri/pages/home/widgets/widget_uretim.dart';
import 'package:capri/pages/widgets/ana_drawer.dart';
import 'package:capri/services/update_service.dart'; 

// StatelessWidget yerine StatefulWidget yapıyoruz
class AnaSayfa extends StatefulWidget {
  final UserModel user;

  const AnaSayfa({super.key, required this.user});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.kontrolEtVeGoster(context);
    });
  }

  Widget _buildIcerik() {
    switch (widget.user.role) {
      case 'admin':
        return AdminWidget();
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
      drawer: AnaDrawer(user: widget.user), // widget.user kullanıldı
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildIcerik(),
      ),
    );
  }
}