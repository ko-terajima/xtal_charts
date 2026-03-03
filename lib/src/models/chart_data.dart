import 'package:flutter/material.dart';

/// A single data point to display on a chart.
class ChartDataPoint {
  final double x;
  final double y;
  final String? label;

  const ChartDataPoint({required this.x, required this.y, this.label});
}

/// A single data series to display on a chart.
/// Contains multiple data points and per-series display settings.
class ChartSeries {
  final String name;
  final List<ChartDataPoint> dataPoints;
  final Color color;

  const ChartSeries({
    required this.name,
    required this.dataPoints,
    required this.color,
  });
}
