import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtalcharts/xtalcharts.dart';

/// Test data for a single bar.
List<ChartSeries> _singleBar() => [
      ChartSeries(
        name: 'Category A',
        color: Colors.blue,
        dataPoints: const [ChartDataPoint(x: 0, y: 100)],
      ),
    ];

/// Test data for multiple bars (by order type).
List<ChartSeries> _multipleBars() => [
      ChartSeries(
        name: 'Standard Orders',
        color: Colors.blue,
        dataPoints: const [ChartDataPoint(x: 0, y: 18290)],
      ),
      ChartSeries(
        name: 'Special (N)',
        color: Colors.green,
        dataPoints: const [ChartDataPoint(x: 0, y: 2200)],
      ),
      ChartSeries(
        name: 'Repair (R)',
        color: Colors.yellow,
        dataPoints: const [ChartDataPoint(x: 0, y: 230)],
      ),
      ChartSeries(
        name: 'After-sales (A)',
        color: Colors.purple,
        dataPoints: const [ChartDataPoint(x: 0, y: 50)],
      ),
    ];

void main() {
  group('HorizontalBarChartPainter', () {
    test('renders a single bar without errors', () {
      final painter = HorizontalBarChartPainter(
        seriesList: _singleBar(),
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 200));
      recorder.endRecording();
    });

    test('renders multiple bars without errors', () {
      final painter = HorizontalBarChartPainter(
        seriesList: _multipleBars(),
        maxValue: 18290,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 250));
      recorder.endRecording();
    });

    test('renders empty seriesList without errors', () {
      final painter = HorizontalBarChartPainter(
        seriesList: const [],
        maxValue: 0,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 200));
      recorder.endRecording();
    });

    test('renders with hover state without errors', () {
      final painter = HorizontalBarChartPainter(
        seriesList: _multipleBars(),
        maxValue: 18290,
        theme: ChartTheme.defaultTheme,
        hoveredBarIndex: 1,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 250));
      recorder.endRecording();
    });

    test('renders mid-animation (0.5) without errors', () {
      final painter = HorizontalBarChartPainter(
        seriesList: _multipleBars(),
        maxValue: 18290,
        theme: ChartTheme.defaultTheme,
        animationProgress: 0.5,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 250));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when seriesList changes', () {
      final painter1 = HorizontalBarChartPainter(
        seriesList: _singleBar(),
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = HorizontalBarChartPainter(
        seriesList: _multipleBars(),
        maxValue: 18290,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when animationProgress changes', () {
      final series = _singleBar();
      final painter1 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
        animationProgress: 0.5,
      );
      final painter2 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
        animationProgress: 1.0,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      final series = _singleBar();
      final painter1 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isFalse);
    });
  });

  group('hitTestHorizontalBarChart', () {
    test('returns null outside the area', () {
      final result = hitTestHorizontalBarChart(
        localPosition: const Offset(5, 5),
        size: const Size(400, 250),
        seriesList: _multipleBars(),
        theme: ChartTheme.defaultTheme,
        maxValue: 18290,
        showColorIndicators: true,
        showValueLabels: true,
      );

      expect(result, isNull);
    });

    test('returns null for empty seriesList', () {
      final result = hitTestHorizontalBarChart(
        localPosition: const Offset(200, 100),
        size: const Size(400, 250),
        seriesList: const [],
        theme: ChartTheme.defaultTheme,
        maxValue: 0,
        showColorIndicators: true,
        showValueLabels: true,
      );

      expect(result, isNull);
    });

    test('returns a valid index inside the bar area', () {
      final result = hitTestHorizontalBarChart(
        localPosition: const Offset(250, 40),
        size: const Size(400, 250),
        seriesList: _multipleBars(),
        theme: ChartTheme.defaultTheme,
        maxValue: 18290,
        showColorIndicators: true,
        showValueLabels: true,
      );

      expect(result, isNotNull);
      expect(result!, greaterThanOrEqualTo(0));
      expect(result, lessThan(4));
    });
  });

  group('computeHorizontalBarGeometry', () {
    test('bar height does not exceed horizontalBarMaxHeightPx', () {
      const theme = ChartTheme(horizontalBarMaxHeightPx: 20.0);
      const plotArea = Rect.fromLTRB(100, 8, 350, 250);

      final (_, barHeight) = computeHorizontalBarGeometry(
        barIndex: 0,
        barCount: 4,
        plotArea: plotArea,
        theme: theme,
      );

      expect(barHeight, lessThanOrEqualTo(20.0));
    });

    test('adjacent rows do not overlap', () {
      const theme = ChartTheme();
      const plotArea = Rect.fromLTRB(100, 8, 350, 250);

      final (top0, height0) = computeHorizontalBarGeometry(
        barIndex: 0,
        barCount: 4,
        plotArea: plotArea,
        theme: theme,
      );
      final (top1, _) = computeHorizontalBarGeometry(
        barIndex: 1,
        barCount: 4,
        plotArea: plotArea,
        theme: theme,
      );

      // Bottom edge of row 0 is above the top edge of row 1
      expect(top0 + height0, lessThanOrEqualTo(top1));
    });

    test('bar is centered within its slot', () {
      const theme = ChartTheme();
      const plotArea = Rect.fromLTRB(100, 0, 350, 200);

      final (barTop, barHeight) = computeHorizontalBarGeometry(
        barIndex: 0,
        barCount: 4,
        plotArea: plotArea,
        theme: theme,
      );

      // Center Y of slot 0 = 0 + (200/4) * 0.5 = 25
      final barCenterY = barTop + barHeight / 2;
      final slotCenterY = plotArea.top + (plotArea.height / 4) * 0.5;
      expect(barCenterY, closeTo(slotCenterY, 0.01));
    });
  });

  group('HorizontalBarChart widget', () {
    testWidgets('renders multiple bars without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: HorizontalBarChart(seriesList: _multipleBars()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HorizontalBarChart), findsOneWidget);
    });

    testWidgets('renders empty seriesList without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: HorizontalBarChart(seriesList: []),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(HorizontalBarChart), findsOneWidget);
    });

    testWidgets('accepts darkTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: HorizontalBarChart(
                seriesList: _multipleBars(),
                theme: ChartTheme.darkTheme,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HorizontalBarChart), findsOneWidget);
    });

    testWidgets('valueLabelFormatter is applied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: HorizontalBarChart(
                seriesList: _multipleBars(),
                valueLabelFormatter: (v) => '${v.toInt()}K',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HorizontalBarChart), findsOneWidget);
    });

    testWidgets('can hide indicators and value labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: HorizontalBarChart(
                seriesList: _multipleBars(),
                showColorIndicators: false,
                showValueLabels: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HorizontalBarChart), findsOneWidget);
    });
  });

  group('HorizontalBarChartPainter unit/valueScale', () {
    test('renders without errors when unit is specified', () {
      final painter = HorizontalBarChartPainter(
        seriesList: _multipleBars(),
        maxValue: 18290,
        theme: ChartTheme.defaultTheme,
        unit: 'K',
        unitPosition: UnitPosition.suffix,
        valueScale: ValueScale.none,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 250));
      recorder.endRecording();
    });

    test('renders without errors with prefix unit + divideBy10000', () {
      final painter = HorizontalBarChartPainter(
        seriesList: _multipleBars(),
        maxValue: 18290,
        theme: ChartTheme.defaultTheme,
        unit: '\$',
        unitPosition: UnitPosition.prefix,
        valueScale: ValueScale.divideBy10000,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 250));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when unit changes', () {
      final series = _singleBar();
      final painter1 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
      );
      final painter2 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
        unit: 'K',
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when unitPosition changes', () {
      final series = _singleBar();
      final painter1 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
        unit: '\$',
        unitPosition: UnitPosition.prefix,
      );
      final painter2 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
        unit: '\$',
        unitPosition: UnitPosition.suffix,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when valueScale changes', () {
      final series = _singleBar();
      final painter1 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
        valueScale: ValueScale.none,
      );
      final painter2 = HorizontalBarChartPainter(
        seriesList: series,
        maxValue: 100,
        theme: ChartTheme.defaultTheme,
        valueScale: ValueScale.divideBy1000,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('HorizontalBarChart widget unit/valueScale', () {
    testWidgets('renders without errors when unit is specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 250,
              child: HorizontalBarChart(
                seriesList: _multipleBars(),
                unit: 'K',
                unitPosition: UnitPosition.suffix,
                valueScale: ValueScale.divideBy10000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HorizontalBarChart), findsOneWidget);
    });
  });

}
