import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/core/Color/Colors.dart';

class StokGecmisiListesi extends StatefulWidget {
  final String docId;
  const StokGecmisiListesi({super.key, required this.docId});

  @override
  State<StokGecmisiListesi> createState() => _StokGecmisiListesiState();
}

class _StokGecmisiListesiState extends State<StokGecmisiListesi> {
  bool tumGecmisGoster = false;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy HH:mm');

    // Null/eksik timestamp'leri elemek için çok düşük bir eşik veriyoruz
    final tsFloor = Timestamp.fromMillisecondsSinceEpoch(1);

    final baseQuery = FirebaseFirestore.instance
        .collection('urunler')
        .doc(widget.docId)
        .collection('stok_gecmis')
        .where('tarih', isGreaterThan: tsFloor) // null/eksik tarihleri dışla
        .orderBy('tarih', descending: true);

    final stream = (tumGecmisGoster ? baseQuery.limit(50) : baseQuery.limit(3))
        .snapshots(includeMetadataChanges: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Limit değiştiğinde mutlaka yeniden abone ol
      key: ValueKey('stok_${widget.docId}_${tumGecmisGoster ? 'full' : 'short'}'),
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Text('Stok geçmişi okunamadı: ${snap.error}');
        }

        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) return const Text("Kayıt yok.");

        Widget list = ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = docs[i].data();
            final degisim = (m['degisim'] as num?)?.toInt() ?? 0;

            // tarih türlerini sağlam ele
            final dynamic ts = m['tarih'];
            DateTime? tarih;
            if (ts is Timestamp) {
              tarih = ts.toDate();
            } else if (ts is DateTime) {
              tarih = ts;
            } else if (ts is int) {
              // milis epoch gelirse
              tarih = DateTime.fromMillisecondsSinceEpoch(ts);
            } else if (ts is String) {
              // ISO string gelirse
              try { tarih = DateTime.parse(ts); } catch (_) {}
            }
            final tStr = tarih != null ? df.format(tarih) : "-";

            final pozitif = degisim >= 0;
            return ListTile(
              leading: Icon(
                pozitif ? Icons.arrow_upward : Icons.arrow_downward,
                color: pozitif ? Colors.green : Colors.red,
              ),
              title: Text(
                "${pozitif ? '+' : ''}$degisim adet",
                style: TextStyle(color: pozitif ? Colors.green : Colors.red),
              ),
              subtitle: Text(tStr),
              dense: true,
            );
          },
        );

        final showToggle =
            (!tumGecmisGoster && docs.length >= 3) || (tumGecmisGoster && docs.length >= 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            list,
            if (showToggle)
              TextButton(
                onPressed: () => setState(() => tumGecmisGoster = !tumGecmisGoster),
                child: Text(
                  tumGecmisGoster ? "Daha Az Göster" : "Daha Fazla Gör",
                  style: const TextStyle(color: Renkler.kahveTon),
                ),
              ),
          ],
        );
      },
    );
  }
}
