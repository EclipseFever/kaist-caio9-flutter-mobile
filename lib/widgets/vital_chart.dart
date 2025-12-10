import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/vital_data.dart';

/// Vital Signs 차트 위젯
class VitalChart extends StatelessWidget {
  final List<VitalData> data;
  final String title;

  const VitalChart({
    super.key,
    required this.data,
    this.title = 'Vital Signs',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for data...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _buildChart(),
          ),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final heartRateSpots = <FlSpot>[];
    final breathRateSpots = <FlSpot>[];

    for (var i = 0; i < data.length; i++) {
      if (data[i].heartRate != null) {
        heartRateSpots.add(FlSpot(i.toDouble(), data[i].heartRate!));
      }
      if (data[i].breathRate != null) {
        breathRateSpots.add(FlSpot(i.toDouble(), data[i].breathRate!));
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 10,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 10 == 0) {
                  final seconds = (data.length - value.toInt()).toInt();
                  return Text(
                    '${seconds}s',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble().clamp(1, double.infinity),
        minY: 0,
        maxY: 100,
        lineBarsData: [
          // Heart Rate Line
          if (heartRateSpots.isNotEmpty)
            LineChartBarData(
              spots: heartRateSpots,
              isCurved: true,
              color: const Color(0xFF1976D2),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF1976D2).withOpacity(0.1),
              ),
            ),
          // Breath Rate Line
          if (breathRateSpots.isNotEmpty)
            LineChartBarData(
              spots: breathRateSpots,
              isCurved: true,
              color: const Color(0xFF43A047),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF43A047).withOpacity(0.1),
              ),
            ),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('Heart Rate', const Color(0xFF1976D2)),
        const SizedBox(width: 24),
        _legendItem('Breath Rate', const Color(0xFF43A047)),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
