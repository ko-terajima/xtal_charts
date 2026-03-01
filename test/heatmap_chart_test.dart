import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtal_chart/xtal_chart.dart';

/// 3x2 test heatmap data.
HeatmapData _sampleData() => const HeatmapData(
      xCategories: ['Jan', 'Feb', 'Mar'],
      yCategories: ['2023', '2024'],
      values: [
        [10, 20, 30],
        [15, null, 25],
      ],
    );

/// Data where all cells are null.
HeatmapData _allNullData() => const HeatmapData(
      xCategories: ['A', 'B'],
      yCategories: ['X'],
      values: [
        [null, null],
      ],
    );

/// Empty data.
HeatmapData _emptyData() => const HeatmapData(
      xCategories: [],
      yCategories: [],
      values: [],
    );

void main() {
  group('HeatmapData', () {
    test('minValue returns the minimum excluding nulls', () {
      final data = _sampleData();
      expect(data.minValue, equals(10));
    });

    test('maxValue returns the maximum excluding nulls', () {
      final data = _sampleData();
      expect(data.maxValue, equals(30));
    });

    test('minValue returns 0 for all-null data', () {
      final data = _allNullData();
      expect(data.minValue, equals(0));
    });

    test('maxValue returns 1 for all-null data', () {
      final data = _allNullData();
      expect(data.maxValue, equals(1));
    });

    test('xCount and yCount are correct', () {
      final data = _sampleData();
      expect(data.xCount, equals(3));
      expect(data.yCount, equals(2));
    });

    test('fromCells builds a matrix from a flat list', () {
      final data = HeatmapData.fromCells(
        xCategories: ['A', 'B'],
        yCategories: ['X', 'Y'],
        cells: [
          const HeatmapCell(xIndex: 0, yIndex: 0, value: 1),
          const HeatmapCell(xIndex: 1, yIndex: 1, value: 2),
        ],
      );

      expect(data.values[0][0], equals(1));
      expect(data.values[0][1], isNull);
      expect(data.values[1][0], isNull);
      expect(data.values[1][1], equals(2));
    });

    test('fromCells ignores out-of-range indices', () {
      final data = HeatmapData.fromCells(
        xCategories: ['A'],
        yCategories: ['X'],
        cells: [
          const HeatmapCell(xIndex: 5, yIndex: 5, value: 99),
        ],
      );

      expect(data.values[0][0], isNull);
    });
  });

  group('HeatmapColorScale', () {
    test('twoColor produces correct start, end, and midpoint colors', () {
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFFFFFFF),
        maxColor: const Color(0xFF000000),
      );

      expect(scale.colorAt(0.0), equals(const Color(0xFFFFFFFF)));
      expect(scale.colorAt(1.0), equals(const Color(0xFF000000)));

      // Midpoint color should be grayish
      final midColor = scale.colorAt(0.5);
      expect(midColor.r, closeTo(0.5, 0.02));
      expect(midColor.g, closeTo(0.5, 0.02));
      expect(midColor.b, closeTo(0.5, 0.02));
    });

    test('colorAt clamps out-of-range values', () {
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFFF0000),
        maxColor: const Color(0xFF0000FF),
      );

      expect(scale.colorAt(-1.0), equals(const Color(0xFFFF0000)));
      expect(scale.colorAt(2.0), equals(const Color(0xFF0000FF)));
    });

    test('returns transparent color for empty colorStops', () {
      const scale = HeatmapColorScale(colorStops: []);
      expect(scale.colorAt(0.5), equals(const Color(0x00000000)));
    });
  });

  group('HeatmapPainter', () {
    test('renders normal data without errors', () {
      final data = _sampleData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('renders empty data without errors', () {
      final data = _emptyData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: 0,
        valueMax: 1,
        theme: ChartTheme.defaultTheme,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('renders with hover state without errors', () {
      final data = _sampleData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
        theme: ChartTheme.defaultTheme,
        hoveredXIndex: 1,
        hoveredYIndex: 0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when data changes', () {
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter1 = HeatmapPainter(
        data: _sampleData(),
        colorScale: scale,
        valueMin: 10,
        valueMax: 30,
        theme: ChartTheme.defaultTheme,
      );

      final painter2 = HeatmapPainter(
        data: _allNullData(),
        colorScale: scale,
        valueMin: 0,
        valueMax: 1,
        theme: ChartTheme.defaultTheme,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when animationProgress changes', () {
      final data = _sampleData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter1 = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: 10,
        valueMax: 30,
        theme: ChartTheme.defaultTheme,
        animationProgress: 0.5,
      );

      final painter2 = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: 10,
        valueMax: 30,
        theme: ChartTheme.defaultTheme,
        animationProgress: 1.0,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('hitTestHeatmap', () {
    test('returns null outside plotArea', () {
      final result = hitTestHeatmap(
        localPosition: const Offset(5, 5),
        size: const Size(400, 300),
        data: _sampleData(),
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNull);
    });

    test('returns null for empty data', () {
      final result = hitTestHeatmap(
        localPosition: const Offset(200, 150),
        size: const Size(400, 300),
        data: _emptyData(),
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNull);
    });

    test('returns valid indices inside plotArea', () {
      final result = hitTestHeatmap(
        localPosition: const Offset(150, 50),
        size: const Size(400, 300),
        data: _sampleData(),
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNotNull);
      expect(result!.xIndex, greaterThanOrEqualTo(0));
      expect(result.xIndex, lessThan(3));
      expect(result.yIndex, greaterThanOrEqualTo(0));
      expect(result.yIndex, lessThan(2));
    });

    test('returns null for a null cell', () {
      // data.values[1][1] == null, so hitting that cell position returns null
      const size = Size(400, 300);
      final data = _sampleData();

      // Calculate the approximate center of cell [1][1]
      const plotLeft = 64.0;
      const plotTop = 16.0;
      const plotRight = 400.0 - 16.0;
      const plotBottom = 300.0 - 48.0;
      const plotWidth = plotRight - plotLeft;
      const plotHeight = plotBottom - plotTop;

      final cellWidth = (plotWidth - (data.xCount - 1) * 2.0) / data.xCount;
      final cellHeight = (plotHeight - (data.yCount - 1) * 2.0) / data.yCount;

      final cellCenterX = plotLeft + 1 * (cellWidth + 2.0) + cellWidth / 2;
      final cellCenterY = plotTop + 1 * (cellHeight + 2.0) + cellHeight / 2;

      final result = hitTestHeatmap(
        localPosition: Offset(cellCenterX, cellCenterY),
        size: size,
        data: data,
        theme: ChartTheme.defaultTheme,
      );

      expect(result, isNull);
    });
  });

  group('HeatmapChart widget', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: HeatmapChart(data: _sampleData()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HeatmapChart), findsOneWidget);
    });

    testWidgets('renders empty data without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: HeatmapChart(data: _emptyData()),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(HeatmapChart), findsOneWidget);
    });

    testWidgets('accepts darkTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: HeatmapChart(
                data: _sampleData(),
                theme: ChartTheme.darkTheme,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HeatmapChart), findsOneWidget);
    });

    testWidgets('accepts a custom colorScale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: HeatmapChart(
                data: _sampleData(),
                colorScale: HeatmapColorScale.twoColor(
                  minColor: const Color(0xFFFFFFFF),
                  maxColor: const Color(0xFFFF0000),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HeatmapChart), findsOneWidget);
    });
  });

  group('HeatmapPainter unit/valueScale', () {
    test('renders without errors when unit is specified', () {
      final data = _sampleData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
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

    test('renders without errors with prefix unit + divideBy1000', () {
      final data = _sampleData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
        theme: ChartTheme.defaultTheme,
        unit: '\$',
        unitPosition: UnitPosition.prefix,
        valueScale: ValueScale.divideBy1000,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 300));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when unit changes', () {
      final data = _sampleData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter1 = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
        theme: ChartTheme.defaultTheme,
      );

      final painter2 = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
        theme: ChartTheme.defaultTheme,
        unit: 'K',
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });

    test('shouldRepaint returns true when valueScale changes', () {
      final data = _sampleData();
      final scale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      final painter1 = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
        theme: ChartTheme.defaultTheme,
        valueScale: ValueScale.none,
      );

      final painter2 = HeatmapPainter(
        data: data,
        colorScale: scale,
        valueMin: data.minValue,
        valueMax: data.maxValue,
        theme: ChartTheme.defaultTheme,
        valueScale: ValueScale.divideBy10000,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('HeatmapChart widget unit/valueScale', () {
    testWidgets('renders without errors when unit is specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: HeatmapChart(
                data: _sampleData(),
                unit: 'K',
                unitPosition: UnitPosition.suffix,
                valueScale: ValueScale.divideBy10000,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(HeatmapChart), findsOneWidget);
    });
  });

}
