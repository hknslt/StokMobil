import 'package:flutter/material.dart';
import 'package:capri/main.dart';
import 'package:capri/pages/home/ana_sayfa.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/sevkiyat_sayfasi.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_sayfasi.dart';
import 'package:capri/pages/moduller/stok_sayfasi/stok_sayfasi.dart';
import 'package:capri/pages/moduller/uretim_sayfasi/uretim_sayfasi.dart';
import 'package:capri/pages/widgets/navbar_widget.dart';

class SevkiyatDashboard extends StatefulWidget {
  const SevkiyatDashboard({Key? key}) : super(key: key);

  @override
  State<SevkiyatDashboard> createState() => _SevkiyatDashboardState();
}

class _SevkiyatDashboardState extends State<SevkiyatDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    AnaSayfa(user: MyApp.currentUser!),
    StokSayfasi(),
    SevkiyatSayfasi(),
  ];

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Anasayfa'),
    BottomNavigationBarItem(
      icon: Icon(Icons.inventory_2_outlined),
      label: 'Stok',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.local_shipping_outlined),
      label: 'Sevkiyat',
    ),
  ];

  void _onNavbarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: CommonNavbar(
        currentIndex: _selectedIndex,
        onTap: _onNavbarTap,
        items: _navItems,
      ),
    );
  }
}
