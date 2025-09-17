import 'package:capri/pages/drawer_page/gecmis_siparis/gecmis_siparisler_sayfasi.dart';
import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/user.dart';
import 'package:capri/main.dart';
import 'package:capri/pages/drawer_page/analiz_sayfasi/analiz_sayfasi.dart';
import 'package:capri/pages/drawer_page/ayarlar/ayarlar_sayfasi.dart';
import 'package:capri/pages/drawer_page/fiyat_listesi_sayfasi.dart';
import 'package:capri/pages/drawer_page/hakkinda_sayfasi.dart';
import 'package:capri/pages/drawer_page/musteri_sayfasi/musteri_sayfasi.dart';
import 'package:capri/pages/home/ana_sayfa.dart';

// >> YENİ: Firebase signOut ve login'e dönüş için
import 'package:capri/services/auth_service.dart';
import 'package:capri/pages/login/login_page.dart';

class AnaDrawer extends StatelessWidget {
  final UserModel user;

  const AnaDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final izinliRotalar =
        _rolMenuHaritasi[user.role] ?? _rolMenuHaritasi['default']!;
    final gorunenOgeler = _tumOgeler
        .where((e) => izinliRotalar.contains(e.route))
        .toList();

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // ÜST LOGO + KULLANICI BİLGİSİ (modern header + LOGO)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Renkler.anaMavi, Renkler.kahveTon],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                  topRight: Radius.circular(24),
                  topLeft: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      "assets/images/capri_logo.png",
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withOpacity(.2),
                        child: Text(
                          _basHarfler(user),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${user.firstName} ${user.lastName}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "@${user.username}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.15),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(.35),
                                    ),
                                  ),
                                  child: Text(
                                    user.role.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // MENÜ ÖĞELERİ (rol bazlı filtreli)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: gorunenOgeler.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                      child: Text(
                        "Uygulama",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          letterSpacing: .2,
                        ),
                      ),
                    );
                  }
                  final item = gorunenOgeler[i - 1];
                  return _modernDrawerItem(
                    icon: item.icon,
                    text: item.title,
                    onTap: () => _navigateTo(context, item.route),
                  );
                },
              ),
            ),

            // Alt kısım
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // ÇIKIŞ BUTONU — sadece Firebase uyarlaması yapıldı
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Renkler.kahveTon,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text("Çıkış Yap"),
                    onPressed: () async {
                      await AuthService().signOut(); // << Firebase Auth çıkış
                      MyApp.currentUser = null; // << app içi user'ı sıfırla
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (_) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Capri Stok • v1.0",
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: .8,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListTile(
            leading: Icon(icon, color: Renkler.anaMavi),
            title: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeName) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _buildRouteWidget(routeName)),
    );
  }

  Widget _buildRouteWidget(String routeName) {
    switch (routeName) {
      case '/ayarlar':
        return const AyarlarSayfasi();
      case '/hakkinda':
        return const HakkindaSayfasi();
      case '/analiz':
        return const AnalizSayfasi();
      case '/musteriler':
        return const MusterilerSayfasi();
      case '/gecmis_siparis':
        return const GecmisSiparislerSayfasi();
      case '/FiyatListesi':
        return const FiyatListesiSayfasi();
      case '/anasayfa':
      default:
        return AnaSayfa(user: MyApp.currentUser!);
    }
  }

  static String _basHarfler(UserModel u) {
    final ad = (u.firstName.isNotEmpty ? u.firstName[0] : "").toUpperCase();
    final soyad = (u.lastName.isNotEmpty ? u.lastName[0] : "").toUpperCase();
    return "$ad$soyad";
  }
}

/// --- Menü veri modeli ve rol->menü haritası ---

class _DrawerItemData {
  final String route;
  final String title;
  final IconData icon;
  const _DrawerItemData(this.route, this.title, this.icon);
}

const List<_DrawerItemData> _tumOgeler = [
  _DrawerItemData('/musteriler', "Müşteriler", Icons.people_outline),
  _DrawerItemData(
    '/FiyatListesi',
    "Fiyat Listesi",
    Icons.price_change_outlined,
  ),
  _DrawerItemData('/gecmis_siparis', "Geçmiş Siparişler", Icons.history_outlined),
  _DrawerItemData('/analiz', "Analizler", Icons.analytics_outlined),
   _DrawerItemData('/hakkinda', "Hakkında", Icons.info_outline),
  _DrawerItemData('/ayarlar', "Ayarlar", Icons.settings_outlined),
  
];

const Map<String, List<String>> _rolMenuHaritasi = {
  'admin': [
    '/musteriler',
    '/FiyatListesi',
    '/gecmis_siparis',
    '/analiz',
    '/hakkinda',
    '/ayarlar',
  ],
  'pazarlamaci': [
    '/musteriler',
    '/FiyatListesi',
    '/gecmis_siparis',
    '/analiz',
    '/hakkinda',
    '/ayarlar',
  ],
  'uretim': ['/analiz', '/hakkinda', '/ayarlar'],
  'sevkiyat': ['/analiz', '/hakkinda', '/ayarlar'],
  'default': [
    '/musteriler',
    '/FiyatListesi',
    '/gecmis_siparis',
    '/analiz',
    '/hakkinda',
    '/ayarlar',
  ],
};
