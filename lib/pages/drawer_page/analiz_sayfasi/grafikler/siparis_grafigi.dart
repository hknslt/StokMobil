import 'dart:math' as math;
import 'package:capri/services/analiz/istatistik_servisi.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SiparisGrafigi extends StatefulWidget {
  const SiparisGrafigi({super.key});

  @override
  State<SiparisGrafigi> createState() => _SiparisGrafigiState();
}

class _SiparisGrafigiState extends State<SiparisGrafigi> {
  static const double _cardHeight = 360;

  String secilenFiltre = 'Günlük';

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

  @override
  Widget build(BuildContext context) {
    final filtreButtons = ToggleButtons(
      borderRadius: BorderRadius.circular(10),
      selectedColor: Colors.white,
      color: Colors.black54,
      fillColor: Colors.green,
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
      height: _cardHeight,
      width: double.infinity,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.shopping_bag_outlined, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Sipariş Grafiği',
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
                child: StreamBuilder<Map<DateTime, int>>(
                  stream: IstatistikServisi.instance.gunlukSiparisSayisiAkim(
                    baslangic: _baslangicFromFiltre(),
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final map = snap.data ?? <DateTime, int>{};
                    final sortedDays = map.keys.toList()..sort();
                    final sayilar = sortedDays.map((d) => map[d] ?? 0).toList();

                    final spots = List.generate(
                      sayilar.length,
                      (i) => FlSpot(i.toDouble(), sayilar[i].toDouble()),
                    );

                    final maxY = sayilar.isEmpty
                        ? 0.0
                        : sayilar.reduce(math.max).toDouble();
                    final yInterval = _niceInterval(maxY);
                    final xStep = sortedDays.length <= 12
                        ? 1
                        : (sortedDays.length / 12).ceil();

                    return LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (sayilar.isEmpty ? 0 : sayilar.length - 1)
                            .toDouble(),
                        minY: 0,
                        maxY: (maxY == 0) ? 1 : (maxY + yInterval),

                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          horizontalInterval: yInterval,
                          getDrawingHorizontalLine: (value) => const FlLine(
                            color: Colors.black12,
                            strokeWidth: 1,
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
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: yInterval,
                              reservedSize: 36,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= sortedDays.length)
                                  return const SizedBox.shrink();
                                if (index % xStep != 0)
                                  return const SizedBox.shrink();

                                final d = sortedDays[index];
                                final label = DateFormat('M/d').format(d);
                                return Transform.rotate(
                                  angle: -0.785398163,
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            top: BorderSide(color: Colors.black12, width: 1),
                            right: BorderSide(color: Colors.black12, width: 1),
                            left: BorderSide(color: Colors.black26, width: 1),
                            bottom: BorderSide(color: Colors.black26, width: 1),
                          ),
                        ),

                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 2,
                            color: Colors.green,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.withOpacity(0.15),
                                  Colors.green.withOpacity(0.0),
                                ],
                                stops: const [0.5, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],

                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchSpotThreshold: 14,
                          getTouchLineStart: (_, __) => -double.infinity,
                          getTouchLineEnd: (_, __) => double.infinity,
                          getTouchedSpotIndicator: (barData, spotIndexes) {
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
                            getTooltipItems: (touched) {
                              return touched.map((barSpot) {
                                final i = barSpot.x.toInt().clamp(
                                  0,
                                  sortedDays.length - 1,
                                );
                                final d = sortedDays[i];
                                return LineTooltipItem(
                                  '',
                                  const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: DateFormat('dd.MM.yyyy').format(d),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '\n${barSpot.y.toInt()} sipariş',
                                      style: const TextStyle(
                                        color: Colors.green,
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
                      ),
                      duration: Duration.zero,
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
}

double _niceInterval(double maxY) {
  if (maxY <= 0) return 1;
  const targetLines = 5;
  final rough = (maxY / targetLines).clamp(1, double.infinity).toDouble();
  final magnitude = math
      .pow(10, (math.log(rough) / math.ln10).floor())
      .toDouble();
  final residual = rough / magnitude;
  if (residual >= 5) return 5 * magnitude;
  if (residual >= 2) return 2 * magnitude;
  return 1 * magnitude;
}
