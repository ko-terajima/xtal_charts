import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtalcharts/xtalcharts.dart';

/// Test data for the left axis (column).
List<ChartSeries> _leftColumnSeries() => [
      ChartSeries(
        name: 'Order Amount',
        color: Colors.blue,
        dataPoints: const [
          ChartDataPoint(x: 0, y: 120, label: 'Q1'),
          ChartDataPoint(x: 1, y: 180, label: 'Q2'),
          ChartDataPoint(x: 2, y: 150, label: 'Q3'),
          ChartDataPoint(x: 3, y: 200, label: 'Q4'),
        ],
      ),
    ];

/// Test data for the right axis (line).
List<ChartSeries> _rightLineSeries() => [
      ChartSeries(
        name: 'Growth Rate',
        color: Colors.orange,
        dataPoints: const [
          ChartDataPoint(x: 0, y: 5.2, label: 'Q1'),
          ChartDataPoint(x: 1, y: 12.8, label: 'Q2'),
          ChartDataPoint(x: 2, y: -3.5, label: 'Q3'),
          ChartDataPoint(x: 3, y: 8.1, label: 'Q4'),
        ],
      ),
    ];

/// Test data for the left axis (area).
List<ChartSeries> _leftAreaSeries() => [
      ChartSeries(
        name: 'Sales',
        color: Colors.green,
        dataPoints: const [
          ChartDataPoint(x: 0, y: 50, label: 'Jan'),
          ChartDataPoint(x: 1, y: 80, label: 'Feb'),
          ChartDataPoint(x: 2, y: 65, label: 'Mar'),
        ],
      ),
    ];

/// Test data for the right axis (line, 3 points).
List<ChartSeries> _rightLineSeriesShort() => [
      ChartSeries(
        name: 'Profit Margin',
        color: Colors.red,
        dataPoints: const [
          ChartDataPoint(x: 0, y: 15.0, label: 'Jan'),
          ChartDataPoint(x: 1, y: 22.5, label: 'Feb'),
          ChartDataPoint(x: 2, y: 18.3, label: 'Mar'),
        ],
      ),
    ];

void main() {
  group('DualAxesPainter', () {
    test('renders line+column without errors', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: -5, maxValue: 15);
      final painter = DualAxesPainter(
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        leftChartType: DualAxesChartType.column,
        rightChartType: DualAxesChartType.line,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(600, 400));
      recorder.endRecording();
    });

    test('renders line+line without errors', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 25);
      final painter = DualAxesPainter(
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeriesShort(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        leftChartType: DualAxesChartType.line,
        rightChartType: DualAxesChartType.line,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(600, 400));
      recorder.endRecording();
    });

    test('renders area+column without errors', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 100);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final painter = DualAxesPainter(
        leftSeriesList: _leftAreaSeries(),
        rightSeriesList: _leftColumnSeries(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        leftChartType: DualAxesChartType.area,
        rightChartType: DualAxesChartType.column,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(600, 400));
      recorder.endRecording();
    });

    test('renders empty series without errors', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 1);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 1);
      final painter = DualAxesPainter(
        leftSeriesList: const [],
        rightSeriesList: const [],
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(600, 400));
      recorder.endRecording();
    });

    test('renders with hover state without errors', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: -5, maxValue: 15);
      final painter = DualAxesPainter(
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        leftChartType: DualAxesChartType.column,
        rightChartType: DualAxesChartType.line,
        theme: ChartTheme.defaultTheme,
        hoveredXIndex: 1,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(600, 400));
      recorder.endRecording();
    });

    test('renders mid-animation (0.5) without errors', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: -5, maxValue: 15);
      final painter = DualAxesPainter(
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        leftChartType: DualAxesChartType.column,
        rightChartType: DualAxesChartType.line,
        theme: ChartTheme.defaultTheme,
        animationProgress: 0.5,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(600, 400));
      recorder.endRecording();
    });
  });

  group('DualAxesPainter shouldRepaint', () {
    test('returns true when leftSeriesList changes', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 15);
      final painter1 = DualAxesPainter(
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = DualAxesPainter(
        leftSeriesList: const [],
        rightSeriesList: _rightLineSeries(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('returns false when nothing changes', () {
      final leftSeries = _leftColumnSeries();
      final rightSeries = _rightLineSeries();
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 15);
      final painter1 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });

    test('returns true when hoveredXIndex changes', () {
      final leftSeries = _leftColumnSeries();
      final rightSeries = _rightLineSeries();
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 15);
      final painter1 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
        hoveredXIndex: 2,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('hitTestDualAxes', () {
    test('returns null outside plotArea', () {
      final result = hitTestDualAxes(
        localPosition: const Offset(5, 5),
        size: const Size(600, 400),
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
      );

      expect(result, isNull);
    });

    test('returns null for empty series', () {
      final result = hitTestDualAxes(
        localPosition: const Offset(300, 200),
        size: const Size(600, 400),
        leftSeriesList: const [],
        rightSeriesList: const [],
      );

      expect(result, isNull);
    });

    test('returns a valid X index inside plotArea', () {
      final result = hitTestDualAxes(
        localPosition: const Offset(200, 200),
        size: const Size(600, 400),
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
      );

      expect(result, isNotNull);
      expect(result!, greaterThanOrEqualTo(0));
      expect(result, lessThan(4));
    });

    test('returns the last index near the right edge', () {
      // plotArea right is 600 - 48 = 552
      final result = hitTestDualAxes(
        localPosition: const Offset(540, 200),
        size: const Size(600, 400),
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
      );

      expect(result, isNotNull);
      expect(result!, equals(3));
    });
  });

  group('DualAxesChart widget', () {
    testWidgets('renders column+line without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: DualAxesChart(
                leftSeriesList: _leftColumnSeries(),
                rightSeriesList: _rightLineSeries(),
                leftChartType: DualAxesChartType.column,
                rightChartType: DualAxesChartType.line,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DualAxesChart), findsOneWidget);
    });

    testWidgets('renders area+line without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: DualAxesChart(
                leftSeriesList: _leftAreaSeries(),
                rightSeriesList: _rightLineSeriesShort(),
                leftChartType: DualAxesChartType.area,
                rightChartType: DualAxesChartType.line,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DualAxesChart), findsOneWidget);
    });

    testWidgets('renders empty series without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: DualAxesChart(
                leftSeriesList: [],
                rightSeriesList: [],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(DualAxesChart), findsOneWidget);
    });

    testWidgets('accepts darkTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: DualAxesChart(
                leftSeriesList: _leftColumnSeries(),
                rightSeriesList: _rightLineSeries(),
                theme: ChartTheme.darkTheme,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DualAxesChart), findsOneWidget);
    });

    testWidgets('renders when only one side has data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: DualAxesChart(
                leftSeriesList: _leftColumnSeries(),
                rightSeriesList: const [],
                leftChartType: DualAxesChartType.column,
                rightChartType: DualAxesChartType.line,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DualAxesChart), findsOneWidget);
    });
  });

  group('DualAxesPainter unit/valueScale', () {
    test('renders without errors when leftUnit + rightUnit are specified', () {
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: -5, maxValue: 15);
      final painter = DualAxesPainter(
        leftSeriesList: _leftColumnSeries(),
        rightSeriesList: _rightLineSeries(),
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        leftChartType: DualAxesChartType.column,
        rightChartType: DualAxesChartType.line,
        theme: ChartTheme.defaultTheme,
        leftUnit: 'K',
        leftUnitPosition: UnitPosition.suffix,
        leftValueScale: ValueScale.divideBy10000,
        rightUnit: '%',
        rightUnitPosition: UnitPosition.suffix,
        rightValueScale: ValueScale.none,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(600, 400));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when leftUnit changes', () {
      final leftSeries = _leftColumnSeries();
      final rightSeries = _rightLineSeries();
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 15);
      final painter1 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
        leftUnit: 'K',
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when rightValueScale changes', () {
      final leftSeries = _leftColumnSeries();
      final rightSeries = _rightLineSeries();
      final leftYScale = calculateNiceScale(minValue: 0, maxValue: 200);
      final rightYScale = calculateNiceScale(minValue: 0, maxValue: 15);
      final painter1 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = DualAxesPainter(
        leftSeriesList: leftSeries,
        rightSeriesList: rightSeries,
        leftYScale: leftYScale,
        rightYScale: rightYScale,
        theme: ChartTheme.defaultTheme,
        rightValueScale: ValueScale.divideBy1000,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('DualAxesChart widget unit/valueScale', () {
    testWidgets('renders without errors when leftUnit + rightUnit are specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: DualAxesChart(
                leftSeriesList: _leftColumnSeries(),
                rightSeriesList: _rightLineSeries(),
                leftChartType: DualAxesChartType.column,
                rightChartType: DualAxesChartType.line,
                leftUnit: 'K',
                leftValueScale: ValueScale.divideBy10000,
                rightUnit: '%',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(DualAxesChart), findsOneWidget);
    });
  });

}
