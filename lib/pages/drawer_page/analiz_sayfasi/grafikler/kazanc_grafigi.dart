// lib/pages/drawer_page/analiz_sayfasi/grafikler/kazanc_grafigi.dart
import 'dart:math' as math;
import 'package:capri/services/istatistik_servisi.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:capri/core/models/kazanc_verisi.dart';

class KazancGrafigi extends StatefulWidget {
  const KazancGrafigi({super.key});

  @override
  State<KazancGrafigi> createState() => _KazancGrafigiState();
}

class _KazancGrafigiState extends State<KazancGrafigi> {
  String secilenFiltre = 'Günlük';

  // 🔹 Dokunulan index'i grafiği rebuild etmeden tutmak için
  final ValueNotifier<int?> _hoveredIdxVN = ValueNotifier<int?>(null);

  @override
  void dispose() {
    _hoveredIdxVN.dispose();
    super.dispose();
  }

  DateTime _baslangicFromFiltre() {
    final now = DateTime.now();
    switch (secilenFiltre) {
      case 'Günlük':
        return now.subtract(const Duration(days: 6));
      case 'Haftalık':
        return now.subtract(const Duration(days: 30));
      case 'Aylık':
        return now.subtract(const Duration(days: 90));
      case 'Yıllık':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 6));
    }
  }

  String _tl(double v, {bool noDecimals = true}) {
    final f = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: noDecimals ? 0 : 2,
    );
    return f.format(v);
  }

  @override
  Widget build(BuildContext context) {
    const leftReservedSize = 56.0;

    final filtreButtons = ToggleButtons(
      borderRadius: BorderRadius.circular(10),
      selectedColor: Colors.white,
      color: Colors.black54,
      fillColor: Colors.indigo,
      constraints: const BoxConstraints(minHeight: 28, minWidth: 54),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      isSelected: [
        secilenFiltre == 'Günlük',
        secilenFiltre == 'Haftalık',
        secilenFiltre == 'Aylık',
        secilenFiltre == 'Yıllık',
      ],
      onPressed: (i) {
        const f = ['Günlük', 'Haftalık', 'Aylık', 'Yıllık'];
        // 🔹 filtre değişince info etiketini sıfırla
        _hoveredIdxVN.value = null;
        setState(() => secilenFiltre = f[i]);
      },
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Günlük'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Haftalık'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Aylık'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('Yıllık'),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: 360,
      child: Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.trending_up, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text(
                    'Kazanç Grafiği',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: filtreButtons,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<KazancVerisi>>(
                  stream: IstatistikServisi.instance.gunlukKazancAkim(
                    baslangic: _baslangicFromFiltre(),
                    // dahilDurumlar: {'tamamlandi', 'sevkiyat'},
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final veriler = snap.data ?? <KazancVerisi>[];
                    if (veriler.isEmpty) {
                      return const Center(
                        child: Text(
                          'Veri bulunamadı',
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    final spots = veriler
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.kazanc))
                        .toList();

                    // 🔹 Görüntü akışını sabitle: min/max X/Y belirle
                    final minX = 0.0;
                    final maxX = (spots.length - 1).toDouble();
                    final minYRaw = spots.map((s) => s.y).reduce(math.min);
                    final maxYRaw = spots.map((s) => s.y).reduce(math.max);
                    final minY =
                        0.0; // kazanç negatif değilse tabanı 0'a sabitle
                    final double yPad = (maxYRaw == 0 ? 1 : maxYRaw) * 0.15;
                    final maxY = (maxYRaw + yPad);

                    final gridInterval = _onerilenAralik(
                      spots.map((s) => s.y).toList(),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 Sadece bu minik label rebuild edilsin, grafik sabit kalsın
                        ValueListenableBuilder<int?>(
                          valueListenable: _hoveredIdxVN,
                          builder: (_, idx, __) {
                            if (idx == null ||
                                idx < 0 ||
                                idx >= veriler.length) {
                              return const SizedBox(height: 20);
                            }
                            final item = veriler[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${DateFormat('dd.MM.yyyy').format(item.tarih)} • ${_tl(item.kazanc)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          },
                        ),

                        Expanded(
                          child: LineChart(
                            LineChartData(
                              minX: minX,
                              maxX: maxX,
                              minY: minY,
                              maxY: maxY,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  barWidth: 2,
                                  color: Colors.indigo,
                                  shadow: const Shadow(
                                    color: Colors.indigo,
                                    blurRadius: 1.5,
                                  ),
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.indigo.withOpacity(0.15),
                                        Colors.indigo.withOpacity(0.0),
                                      ],
                                      stops: const [0.5, 1.0],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],

                              // 🔹 Dahili dokunuş açık kalsın ama biz setState çağırmayalım.
                              lineTouchData: LineTouchData(
                                handleBuiltInTouches: true,
                                touchSpotThreshold: 16,
                                getTouchLineStart: (_, __) => -double.infinity,
                                getTouchLineEnd: (_, __) => double.infinity,
                                touchCallback: (event, response) {
                                  if (response == null ||
                                      response.lineBarSpots == null ||
                                      response.lineBarSpots!.isEmpty) {
                                    _hoveredIdxVN.value = null; // rebuild yok
                                    return;
                                  }
                                  final idx = response.lineBarSpots!.first.x
                                      .toInt();
                                  // 🔹 Yalnız değişince güncelle (gereksiz olayları azalt)
                                  if (_hoveredIdxVN.value != idx) {
                                    _hoveredIdxVN.value = idx.clamp(
                                      0,
                                      veriler.length - 1,
                                    );
                                  }
                                },
                                getTouchedSpotIndicator:
                                    (barData, spotIndexes) {
                                      return spotIndexes.map((_) {
                                        return const TouchedSpotIndicatorData(
                                          FlLine(
                                            color: Colors.blueGrey,
                                            strokeWidth: 1.2,
                                            dashArray: [8, 3],
                                          ),
                                          FlDotData(show: true),
                                        );
                                      }).toList();
                                    },
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipItems: (touchedSpots) {
                                    if (veriler.isEmpty) return [];
                                    return touchedSpots.map((barSpot) {
                                      final idx = barSpot.x.toInt().clamp(
                                        0,
                                        veriler.length - 1,
                                      );
                                      final item = veriler[idx];
                                      final dateStr = DateFormat(
                                        'yyyy/MM/dd',
                                      ).format(item.tarih);
                                      final priceStr = _tl(
                                        item.kazanc,
                                        noDecimals: true,
                                      );
                                      return LineTooltipItem(
                                        '',
                                        const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: dateStr,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(
                                            text: '\n$priceStr',
                                            style: const TextStyle(
                                              color: Colors.indigo,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList();
                                  },
                                  getTooltipColor: (_) => Colors.white,
                                ),
                              ),

                              titlesData: FlTitlesData(
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  drawBelowEverything: true,
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: leftReservedSize,
                                    maxIncluded: false,
                                    minIncluded: false,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        _tl(value, noDecimals: true),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black87,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    maxIncluded: false,
                                    getTitlesWidget:
                                        (double value, TitleMeta meta) {
                                          final idx = value.toInt();
                                          if (idx < 0 ||
                                              idx >= veriler.length) {
                                            return const SizedBox.shrink();
                                          }
                                          final len = veriler.length;
                                          final step = len <= 12
                                              ? 1
                                              : (len / 12).ceil();
                                          if (idx % step != 0) {
                                            return const SizedBox.shrink();
                                          }
                                          final date = veriler[idx].tarih;
                                          final label = DateFormat(
                                            'M/d',
                                          ).format(date);
                                          return Transform.rotate(
                                            angle: -45 * math.pi / 180,
                                            child: Text(
                                              label,
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          );
                                        },
                                  ),
                                ),
                              ),

                              gridData: FlGridData(
                                show: true,
                                drawHorizontalLine: true,
                                drawVerticalLine: false,
                                horizontalInterval: gridInterval,
                                getDrawingHorizontalLine: (value) =>
                                    const FlLine(
                                      color: Colors.black12,
                                      strokeWidth: 1,
                                    ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: const Border(
                                  top: BorderSide(
                                    color: Colors.black12,
                                    width: 1,
                                  ),
                                  right: BorderSide(
                                    color: Colors.black12,
                                    width: 1,
                                  ),
                                  left: BorderSide(
                                    color: Colors.black26,
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.black26,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            // 🔹 rebuild’lerde animasyonu kapat
                            duration: Duration.zero,
                            curve: Curves.linear,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _onerilenAralik(List<double> values) {
    if (values.isEmpty) return 1000;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).abs();
    if (range <= 0) return (maxV == 0 ? 1 : maxV) / 2;

    final rough = range / 4;
    final double magnitude = math
        .pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final double residual = rough / magnitude;

    if (residual >= 5) return 5.0 * magnitude;
    if (residual >= 2) return 2.0 * magnitude;
    return 1.0 * magnitude;
  }
}
