import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtal_chart/xtal_chart.dart';

/// Test data for a single series.
List<ChartSeries> _singleSeries() => [
      ChartSeries(
        name: 'Tokyo',
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
        name: 'Tokyo',
        color: Colors.blue,
        dataPoints: const [
          ChartDataPoint(x: 0, y: 10, label: 'Jan'),
          ChartDataPoint(x: 1, y: 25, label: 'Feb'),
          ChartDataPoint(x: 2, y: 18, label: 'Mar'),
        ],
      ),
      ChartSeries(
        name: 'Berlin',
        color: Colors.orange,
        dataPoints: const [
          ChartDataPoint(x: 0, y: 15, label: 'Jan'),
          ChartDataPoint(x: 1, y: 20, label: 'Feb'),
          ChartDataPoint(x: 2, y: 22, label: 'Mar'),
        ],
      ),
    ];

void main() {
  group('BarChartPainter', () {
    test('paints without error with a single series', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = BarChartPainter(
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
      final painter = BarChartPainter(
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
      final painter = BarChartPainter(
        seriesList: const [],
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('paints without error with hover state', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = BarChartPainter(
        seriesList: _multiSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        hoveredCategoryIndex: 1,
        hoveredSeriesIndex: 0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when seriesList changes', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = BarChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = BarChartPainter(
        seriesList: _multiSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when animationProgress changes', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = BarChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        animationProgress: 0.5,
      );
      final painter2 = BarChartPainter(
        seriesList: _singleSeries(),
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        animationProgress: 1.0,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      final series = _singleSeries();
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });
  });

  group('hitTestBarChart', () {
    test('returns null outside plotArea', () {
      final result = hitTestBarChart(
        localPosition: const Offset(5, 5),
        size: const Size(400, 300),
        seriesList: _singleSeries(),
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNull);
    });

    test('returns null with an empty seriesList', () {
      final result = hitTestBarChart(
        localPosition: const Offset(200, 150),
        size: const Size(400, 300),
        seriesList: const [],
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNull);
    });

    test('returns a valid categoryIndex inside plotArea', () {
      final result = hitTestBarChart(
        localPosition: const Offset(100, 150),
        size: const Size(400, 300),
        seriesList: _singleSeries(),
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNotNull);
      expect(result!.categoryIndex, greaterThanOrEqualTo(0));
      expect(result.categoryIndex, lessThan(3));
    });

    test('returns a valid seriesIndex with multiple series', () {
      final result = hitTestBarChart(
        localPosition: const Offset(200, 150),
        size: const Size(400, 300),
        seriesList: _multiSeries(),
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNotNull);
      expect(result!.seriesIndex, greaterThanOrEqualTo(0));
      expect(result.seriesIndex, lessThan(2));
    });
  });

  group('computeBarGeometry', () {
    test('bar width does not exceed barMaxWidthPx', () {
      const theme = ChartTheme(barMaxWidthPx: 20.0);
      const plotArea = Rect.fromLTRB(48, 16, 400, 268);

      final (_, barWidth) = computeBarGeometry(
        categoryIndex: 0,
        seriesIndex: 0,
        seriesCount: 1,
        plotArea: plotArea,
        categoryCount: 3,
        theme: theme,
      );

      expect(barWidth, lessThanOrEqualTo(20.0));
    });

    test('bars within a group do not overlap', () {
      const theme = ChartTheme();
      const plotArea = Rect.fromLTRB(48, 16, 400, 268);

      final (left0, width0) = computeBarGeometry(
        categoryIndex: 0,
        seriesIndex: 0,
        seriesCount: 2,
        plotArea: plotArea,
        categoryCount: 3,
        theme: theme,
      );
      final (left1, _) = computeBarGeometry(
        categoryIndex: 0,
        seriesIndex: 1,
        seriesCount: 2,
        plotArea: plotArea,
        categoryCount: 3,
        theme: theme,
      );

      // The right edge of the first bar is to the left of the second bar's left edge
      expect(left0 + width0, lessThanOrEqualTo(left1));
    });
  });

  group('BarChart widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: BarChart(seriesList: _singleSeries()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders without error with an empty seriesList', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: BarChart(seriesList: []),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('accepts darkTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: BarChart(
                seriesList: _multiSeries(),
                theme: ChartTheme.darkTheme,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsOneWidget);
    });
  });

  group('BarChartPainter unit/valueScale', () {
    test('paints without error with unit specified', () {
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = BarChartPainter(
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
      final painter = BarChartPainter(
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

    test('shouldRepaint returns true when unit changes', () {
      final series = _singleSeries();
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        unit: 'K',
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when unitPosition changes', () {
      final series = _singleSeries();
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        unit: '\$',
        unitPosition: UnitPosition.prefix,
      );
      final painter2 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        unit: '\$',
        unitPosition: UnitPosition.suffix,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when valueScale changes', () {
      final series = _singleSeries();
      final yScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter1 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        valueScale: ValueScale.none,
      );
      final painter2 = BarChartPainter(
        seriesList: series,
        yScale: yScale,
        theme: ChartTheme.defaultTheme,
        valueScale: ValueScale.divideBy1000,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('BarChart widget unit/valueScale', () {
    testWidgets('renders without error with unit specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: BarChart(
                seriesList: _singleSeries(),
                unit: 'K',
                unitPosition: UnitPosition.suffix,
                valueScale: ValueScale.divideBy10000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsOneWidget);
    });
  });

}
