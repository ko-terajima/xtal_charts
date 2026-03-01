import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crystal_charts/crystal_charts.dart';

/// Test data for a single series.
List<ChartSeries> _singleSeries() => [
  ChartSeries(
    name: 'Sales',
    color: Colors.blue,
    dataPoints: const [
      ChartDataPoint(x: 0, y: 10, label: 'Jan'),
      ChartDataPoint(x: 1, y: 25, label: 'Feb'),
      ChartDataPoint(x: 2, y: 18, label: 'Mar'),
    ],
  ),
];

/// Test data for multiple series.
List<ChartSeries> _multiSeries() => [
  ChartSeries(
    name: 'Sales',
    color: Colors.blue,
    dataPoints: const [
      ChartDataPoint(x: 0, y: 10, label: 'Jan'),
      ChartDataPoint(x: 1, y: 25, label: 'Feb'),
      ChartDataPoint(x: 2, y: 18, label: 'Mar'),
    ],
  ),
  ChartSeries(
    name: 'Costs',
    color: Colors.orange,
    dataPoints: const [
      ChartDataPoint(x: 0, y: 5, label: 'Jan'),
      ChartDataPoint(x: 1, y: 12, label: 'Feb'),
      ChartDataPoint(x: 2, y: 9, label: 'Mar'),
    ],
  ),
];

void main() {
  group('AreaChartPainter', () {
    test('paints without error with a single series', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = AreaChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints without error with multiple series', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = AreaChartPainter(
        seriesList: _multiSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints without error with an empty seriesList', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 1);
      final painter = AreaChartPainter(
        seriesList: const [],
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints without error with smoothCurve enabled', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = AreaChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        smoothCurve: true,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints without error with hover state', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = AreaChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        hoveredXIndex: 1,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints without error with axis titles specified', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = AreaChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        xAxisTitle: 'Month',
        yAxisTitle: 'Sales',
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when seriesList changes', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = AreaChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = AreaChartPainter(
        seriesList: _multiSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      final series = _singleSeries();
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = AreaChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = AreaChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });
  });

  group('hitTestAreaChart', () {
    test('returns null outside plotArea', () {
      final result = hitTestAreaChart(
        localPosition: const Offset(5, 5),
        size: const Size(400, 300),
        seriesList: _singleSeries(),
      );

      expect(result, isNull);
    });

    test('returns null with an empty seriesList', () {
      final result = hitTestAreaChart(
        localPosition: const Offset(200, 150),
        size: const Size(400, 300),
        seriesList: const [],
      );

      expect(result, isNull);
    });

    test('returns a valid xIndex inside plotArea', () {
      final result = hitTestAreaChart(
        localPosition: const Offset(200, 150),
        size: const Size(400, 300),
        seriesList: _singleSeries(),
      );

      expect(result, isNotNull);
      expect(result!, greaterThanOrEqualTo(0));
      expect(result, lessThan(3));
    });
  });

  group('AreaChartPainter unit/valueScale', () {
    test('paints without error with unit specified', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = AreaChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        unit: 'K',
        unitPosition: UnitPosition.suffix,
        valueScale: ValueScale.none,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints without error with prefix unit + divideBy10000', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25000);
      final painter = AreaChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        unit: '\$',
        unitPosition: UnitPosition.prefix,
        valueScale: ValueScale.divideBy10000,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });
  });

  group('AreaChart widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: AreaChart(seriesList: _singleSeries()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AreaChart), findsOneWidget);
    });

    testWidgets('renders without error with an empty seriesList', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: AreaChart(seriesList: []),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(AreaChart), findsOneWidget);
    });

    testWidgets('accepts darkTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: AreaChart(
                seriesList: _multiSeries(),
                theme: ChartTheme.darkTheme,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AreaChart), findsOneWidget);
    });

    testWidgets('renders with smoothCurve enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: AreaChart(
                seriesList: _singleSeries(),
                smoothCurve: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AreaChart), findsOneWidget);
    });

    testWidgets('renders with unit/valueScale specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: AreaChart(
                seriesList: _singleSeries(),
                unit: 'K',
                valueScale: ValueScale.divideBy10000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(AreaChart), findsOneWidget);
    });
  });
}
