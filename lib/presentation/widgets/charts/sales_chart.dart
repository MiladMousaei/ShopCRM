import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_converter.dart';

class SalesChart extends StatelessWidget {
  final Map<String, double> dailySales; // key: 'YYYY-MM-DD', value: مبلغ

  const SalesChart({super.key, required this.dailySales});

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'داده‌ای برای نمایش وجود ندارد',
            style: TextStyle(fontFamily: 'Vazirmatn', color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final entries = dailySales.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value / 1000); // هزار تومان
    }).toList();

    final maxY = spots.map((s) => s.y).fold(0.0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.divider,
              strokeWidth: 0.5,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox();
                  final date = DateTime.tryParse(entries[idx].key);
                  final label = date != null ? DateConverter.weekDayName(date) : '';
                  return Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, _) => Text(
                  '${CurrencyFormatter.formatNumber(value)}k',
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (entries.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.3),
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                CurrencyFormatter.format(s.y * 1000),
                const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11,
                  color: Colors.white,
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
