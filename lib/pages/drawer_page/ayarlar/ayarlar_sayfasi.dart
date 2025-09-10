import 'package:capri/core/Color/Colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'sifre_sifirlama_sayfasi.dart';
import 'kullanici_bilgileri_sayfasi.dart';
import 'bildirim_ayarlar_sayfasi.dart';

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final cs = baseTheme.colorScheme;

    // Firebase kullanıcı bilgileri
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '—';
    final displayName = user?.displayName?.trim();

    // İSİM GERİ DÖNÜŞ ZİNCİRİ:
    // 1) displayName dolu ise onu kullan
    // 2) değilse e-posta'nın '@' öncesini kullan
    // 3) o da yoksa 'Misafir'
    final fallbackFromEmail = email.contains('@')
        ? email.split('@').first
        : email;
    final resolvedName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (fallbackFromEmail.isNotEmpty ? fallbackFromEmail : 'Misafir');

    // Bu sayfa için bir alt tema: ana rengi kahveTon yap
    final themed = baseTheme.copyWith(
      colorScheme: cs.copyWith(
        primary: Renkler.kahveTon,
        secondary: Renkler.kahveTon,
        onPrimary: Colors.white,
        // İsteğe bağlı: container tonlarını da kahveTon’dan türetelim
        primaryContainer: Renkler.kahveTon.withOpacity(.15),
        secondaryContainer: Renkler.kahveTon.withOpacity(.15),
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(
                  start: 16,
                  bottom: 12,
                  end: 16,
                ),
                title: const Text('Ayarlar'),
                background: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Renkler.anaMavi,
                        Renkler.kahveTon.withOpacity(.85),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _ProfileHeader(
                  name: resolvedName,
                  email: email,
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KullaniciBilgileriSayfasi(),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bölüm: Hesap
            SliverToBoxAdapter(
              child: _Section(
                title: 'Hesap',
                children: [
                  _SettingTile(
                    leading: Icons.manage_accounts,
                    title: 'Kullanıcı bilgileri',
                    subtitle: 'Ad, soyad, kullanıcı adı, telefon',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const KullaniciBilgileriSayfasi(),
                      ),
                    ),
                  ),
                  _SettingTile(
                    leading: Icons.lock_reset,
                    title: 'Şifre sıfırlama',
                    subtitle: 'E-posta ile sıfırlama bağlantısı gönder',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SifreSifirlamaSayfasi(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bölüm: Bildirimler
            SliverToBoxAdapter(
              child: _Section(
                title: 'Bildirimler',
                children: [
                  _SettingTile(
                    leading: Icons.notifications_active_outlined,
                    title: 'Bildirim ayarları',
                    subtitle: 'Push / e-posta / uyarılar',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BildirimAyarSayfasi(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bölüm: Uygulama
            SliverToBoxAdapter(
              child: _Section(
                title: 'Uygulama',
                children: const [
                  _StaticInfoTile(
                    leading: Icons.info_outline,
                    title: 'Sürüm',
                    value: 'v1.0.0',
                  ),
                  _StaticInfoTile(
                    leading: Icons.privacy_tip_outlined,
                    title: 'Gizlilik',
                    value: 'Standart',
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/* ===================== BİLEŞENLER ===================== */

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final VoidCallback onEdit;
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _Avatar(name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              foregroundColor: Renkler.kahveTon,
              backgroundColor: Renkler.kahveTon.withOpacity(.08),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Düzenle'),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty
        ? trimmed.split(RegExp(r'\s+')).map((e) => e[0]).take(2).join()
        : 'M'; // Misafir -> 'M'
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Renkler.kahveTon, Renkler.kahveTon.withOpacity(.85)],
        ),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  final List<QuickItem> items;
  const _QuickGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Basit bir grid görünümü
    return Row(
      children: [
        for (int i = 0; i < items.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 10),
              child: _QuickCard(
                icon: items[i].icon,
                label: items[i].label,
                onTap: items[i].onTap,
                color: cs.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  QuickItem({required this.icon, required this.label, required this.onTap});
}

class _QuickCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).cardColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _hover ? widget.color.withOpacity(.08) : base,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            children: [
              Icon(widget.icon, color: widget.color),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(leading, color: cs.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _StaticInfoTile extends StatelessWidget {
  final IconData leading;
  final String title;
  final String value;
  const _StaticInfoTile({
    required this.leading,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withOpacity(.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(leading, color: cs.secondary),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
