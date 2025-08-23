  // lib/widgets/siparis_durum_etiketi.dart

  import 'package:flutter/material.dart';
  import 'package:capri/core/models/siparis_model.dart';

  class SiparisDurumEtiketi extends StatelessWidget {
    final SiparisDurumu durum;

    const SiparisDurumEtiketi({super.key, required this.durum});

    @override
    Widget build(BuildContext context) {
      final renk = _renkSec(durum);
      final yazi = _yaziSec(durum);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: renk.withOpacity(0.1),
          border: Border.all(color: renk),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          yazi,
          style: TextStyle(
            color: renk,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    Color _renkSec(SiparisDurumu d) {
      switch (d) {
        case SiparisDurumu.beklemede:
          return Colors.orange;
        case SiparisDurumu.uretimde:
          return Colors.deepPurple;
        case SiparisDurumu.sevkiyat:
          return Colors.blue;
        case SiparisDurumu.tamamlandi:
          return Colors.green;
        case SiparisDurumu.reddedildi:
          return Colors.red;
      }
    }

    String _yaziSec(SiparisDurumu d) {
      switch (d) {
        case SiparisDurumu.beklemede:
          return "Beklemede";
        case SiparisDurumu.uretimde:
          return "Üretimde";
        case SiparisDurumu.sevkiyat:
          return "Sevkiyat";
        case SiparisDurumu.tamamlandi:
          return "Tamamlandı";
        case SiparisDurumu.reddedildi:
          return "Reddedildi";
      }
    }
  }
