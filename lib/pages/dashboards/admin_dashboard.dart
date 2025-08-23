import 'package:flutter/material.dart';
import 'package:capri/main.dart';
import 'package:capri/pages/home/ana_sayfa.dart';
import 'package:capri/pages/moduller/sevkiyat_sayfasi/sevkiyat_sayfasi.dart';
import 'package:capri/pages/moduller/siparis_sayfasi/siparis_sayfasi.dart';
import 'package:capri/pages/moduller/stok_sayfasi/stok_sayfasi.dart';
import 'package:capri/pages/moduller/uretim_sayfasi/uretim_sayfasi.dart';
import 'package:capri/pages/widgets/navbar_widget.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    AnaSayfa(user: MyApp.currentUser!),
    StokSayfasi(),
    SiparisSayfasi(),
    UretimSayfasi(),
    SevkiyatSayfasi(),
  ];

  final List<BottomNavigationBarItem> _navItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Anasayfa'),
    BottomNavigationBarItem(
      icon: Icon(Icons.inventory_2_outlined),
      label: 'Stok',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.shopping_cart_outlined),
      label: 'Sipariş',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.factory_outlined), label: 'Üretim'),
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
