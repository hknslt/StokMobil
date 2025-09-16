import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';
import 'package:capri/core/models/siparis_model.dart';

class SiparisSevkiyatKart extends StatelessWidget {
  final SiparisModel siparis;
  final VoidCallback? onTeslimEt;
  final bool kompakt;

  const SiparisSevkiyatKart({
    super.key,
    required this.siparis,
    this.onTeslimEt,
    this.kompakt = false,
  });

  String _safe(String? v) => (v ?? '').trim().isEmpty ? '-' : v!.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = siparis;

    final firma = _safe(s.musteri.firmaAdi);
    final yetkili = _safe(s.musteri.yetkili);
    final urunCesidi = s.urunler.length;
    final toplamAdet = s.urunler.fold<int>(0, (sum, u) => sum + (u.adet ?? 0));
    final aciklama = (s.aciklama ?? '').trim();

    return Card(
      elevation: kompakt ? 1.5 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: kompakt ? 8 : 12),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          kompakt ? 10 : 12,
          12,
          kompakt ? 6 : 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: kompakt ? 16 : 18,
                  backgroundColor: Renkler.kahveTon.withOpacity(.15),
                  child: Text(
                    (firma.isNotEmpty ? firma[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Renkler.kahveTon),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firma,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Yetkili: $yetkili',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      SizedBox(height: kompakt ? 6 : 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Chip(
                            label: Text('Ürün: $urunCesidi'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Chip(
                            label: Text('Toplam Adet: $toplamAdet'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Chip(
                            label: Text('Durum: Sevkiyat'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                if (onTeslimEt != null)
                  Flexible(
                    fit: FlexFit.loose,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: SizedBox(
                          height: 40,
                          child: FittedBox(
                            child: ElevatedButton.icon(
                              onPressed: onTeslimEt,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 18,
                              ),
                              label: const Text(
                                'Teslim Et',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            if (aciklama.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(aciklama, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),

            // ÜRÜNLER
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: Renkler.kahveTon,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text('Ürünler', overflow: TextOverflow.ellipsis),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$urunCesidi çeşit / $toplamAdet adet',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: s.urunler.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = s.urunler[i];
                    final urunAdi = ((u.urunAdi ?? '').trim().isNotEmpty)
                        ? u.urunAdi!.trim()
                        : '-';
                    final renk = ((u.renk ?? '').trim().isNotEmpty)
                        ? u.renk!.trim()
                        : '-';
                    final adet = u.adet ?? 0;

                    return ListTile(
                      title: Text(urunAdi, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Renk: $renk'),
                      trailing: Text(
                        'Adet: $adet',
                        style: const TextStyle(fontSize: 12),
                      ),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
