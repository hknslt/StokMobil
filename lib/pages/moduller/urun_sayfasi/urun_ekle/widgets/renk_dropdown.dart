import 'package:flutter/material.dart';
import 'package:capri/core/models/renk_item.dart';
import 'package:capri/services/renk_service.dart';

class RenkDropdown extends StatelessWidget {
  final String? seciliAd;
  final ValueChanged<String?> onDegisti;
  final VoidCallback onYeniRenk;

  const RenkDropdown({
    super.key,
    required this.seciliAd,
    required this.onDegisti,
    required this.onYeniRenk,
  });

  @override
  Widget build(BuildContext context) {
    final svc = RenkService.instance;

    return StreamBuilder<List<RenkItem>>(
      stream: svc.dinle(),
      builder: (context, snap) {
        final renkler = (snap.data ?? [])
            .where((r) => r.ad.trim().isNotEmpty)
            .toList();

        final seen = <String>{};
        final tekil = <RenkItem>[];
        for (final r in renkler) {
          final key = r.ad.trim().toLowerCase();
          if (seen.add(key)) tekil.add(RenkItem(id: r.id, ad: r.ad.trim()));
        }

        final seciliRaw = (seciliAd ?? '').trim();
        final seciliLower = seciliRaw.toLowerCase();

        String? value;
        final match = tekil.firstWhere(
          (r) => r.ad.trim().toLowerCase() == seciliLower,
          orElse: () => RenkItem(id: '', ad: ''),
        );
        if (match.ad.isNotEmpty) {
          value = match.ad;
        } else if (seciliRaw.isNotEmpty) {
          tekil.insert(0, RenkItem(id: '_local_', ad: seciliRaw));
          value = seciliRaw;
        }

        final items = tekil
            .map((r) => DropdownMenuItem<String>(value: r.ad, child: Text(r.ad)))
            .toList();

        if (value != null && items.where((it) => it.value == value).length != 1) {
          value = null;
        }

        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: 'Renk',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: IconButton(
              onPressed: onYeniRenk,
              icon: const Icon(Icons.add),
              tooltip: 'Yeni renk ekle',
            ),
          ),
          items: items,
          onChanged: onDegisti,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Renk seçiniz' : null,
          hint: const Text('Renk seçin'),
        );
      },
    );
  }
}
