import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtal_charts/xtal_charts.dart';

/// Simple tree data for testing.
ChartTreeNode _simpleTree() => ChartTreeNode(
  name: 'Root',
  children: [
    ChartTreeNode(name: 'A', value: 30),
    ChartTreeNode(name: 'B', value: 20),
    ChartTreeNode(name: 'C', value: 10),
  ],
);

/// Nested tree data for testing.
ChartTreeNode _nestedTree() => ChartTreeNode(
  name: 'Root',
  children: [
    ChartTreeNode(
      name: 'Dept-1',
      children: [
        ChartTreeNode(name: 'Sub-A', value: 15),
        ChartTreeNode(name: 'Sub-B', value: 10),
      ],
    ),
    ChartTreeNode(
      name: 'Dept-2',
      children: [ChartTreeNode(name: 'Sub-C', value: 20)],
    ),
  ],
);

void main() {
  group('SunburstPainter', () {
    test('renders without errors with a simple tree', () {
      final segments = computeSunburstLayout(
        rootNode: _simpleTree(),
        maxDepth: 3,
      );
      final painter = SunburstPainter(
        segments: segments,
        maxVisibleDepth: 3,
        theme: ChartTheme.defaultTheme,
        innerRadiusRatio: 0.2,
        animationProgress: 1.0,
        canDrillUp: false,
        currentRootName: 'Root',
        currentRootTotalValue: 60,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('renders without errors with a nested tree', () {
      final segments = computeSunburstLayout(
        rootNode: _nestedTree(),
        maxDepth: 3,
      );
      final painter = SunburstPainter(
        segments: segments,
        maxVisibleDepth: 3,
        theme: ChartTheme.defaultTheme,
        innerRadiusRatio: 0.2,
        animationProgress: 1.0,
        canDrillUp: true,
        currentRootName: 'Root',
        currentRootTotalValue: 45,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('renders without errors with a highlighted segment', () {
      final segments = computeSunburstLayout(
        rootNode: _simpleTree(),
        maxDepth: 3,
      );
      final painter = SunburstPainter(
        segments: segments,
        maxVisibleDepth: 3,
        theme: ChartTheme.defaultTheme,
        innerRadiusRatio: 0.2,
        animationProgress: 1.0,
        canDrillUp: false,
        currentRootName: 'Root',
        currentRootTotalValue: 60,
        highlightedIndex: 0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('renders during animation in progress', () {
      final segments = computeSunburstLayout(
        rootNode: _simpleTree(),
        maxDepth: 3,
      );
      final painter = SunburstPainter(
        segments: segments,
        maxVisibleDepth: 3,
        theme: ChartTheme.defaultTheme,
        innerRadiusRatio: 0.2,
        animationProgress: 0.5,
        canDrillUp: false,
        currentRootName: 'Root',
        currentRootTotalValue: 60,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('renders without errors with empty segments', () {
      final painter = SunburstPainter(
        segments: const [],
        maxVisibleDepth: 3,
        theme: ChartTheme.defaultTheme,
        innerRadiusRatio: 0.2,
        animationProgress: 1.0,
        canDrillUp: false,
        currentRootName: 'Root',
        currentRootTotalValue: 0,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });

    test('renders with dark theme', () {
      final segments = computeSunburstLayout(
        rootNode: _simpleTree(),
        maxDepth: 3,
      );
      final painter = SunburstPainter(
        segments: segments,
        maxVisibleDepth: 3,
        theme: ChartTheme.darkTheme,
        innerRadiusRatio: 0.25,
        animationProgress: 1.0,
        canDrillUp: false,
        currentRootName: 'Root',
        currentRootTotalValue: 60,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(400, 400));
      recorder.endRecording();
    });
  });

  group('hitTestSunburst', () {
    test('returns drill-up index (-1) when center circle is tapped', () {
      final segments = computeSunburstLayout(
        rootNode: _simpleTree(),
        maxDepth: 3,
      );
      // Exact center
      final result = hitTestSunburst(
        tapPosition: const Offset(200, 200),
        size: const Size(400, 400),
        segments: segments,
        maxVisibleDepth: 3,
        innerRadiusRatio: 0.2,
      );

      expect(result, equals(-1));
    });

    test('returns a valid index when a segment is tapped', () {
      final segments = computeSunburstLayout(
        rootNode: _simpleTree(),
        maxDepth: 3,
      );
      // Size 400x400: maxRadius=200, innerRadius=40, ringWidth≈53.3
      // depth=1 ring range: 40..93.3
      // center(200,200) + 65px right = offset(265,200) -> distance 65 is within ring
      final result = hitTestSunburst(
        tapPosition: const Offset(265, 200),
        size: const Size(400, 400),
        segments: segments,
        maxVisibleDepth: 3,
        innerRadiusRatio: 0.2,
      );

      expect(result, isNotNull);
      expect(result!, greaterThanOrEqualTo(0));
      expect(result, lessThan(segments.length));
    });

    test('returns null when tapped outside the chart', () {
      final segments = computeSunburstLayout(
        rootNode: _simpleTree(),
        maxDepth: 3,
      );
      // Corner (outside the circle)
      final result = hitTestSunburst(
        tapPosition: const Offset(0, 0),
        size: const Size(400, 400),
        segments: segments,
        maxVisibleDepth: 3,
        innerRadiusRatio: 0.2,
      );

      expect(result, isNull);
    });
  });

  group('SunburstChart widget', () {
    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: SunburstChart(data: _simpleTree()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SunburstChart), findsOneWidget);
    });

    testWidgets('renders with nested data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: SunburstChart(data: _nestedTree()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SunburstChart), findsOneWidget);
    });

    testWidgets('renders with legend', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: SunburstChart(
                data: _simpleTree(),
                showLegend: true,
                legendPosition: LegendPosition.bottom,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SunburstChart), findsOneWidget);
      // Each legend item text is displayed
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('accepts dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: SunburstChart(
                data: _simpleTree(),
                theme: ChartTheme.darkTheme,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SunburstChart), findsOneWidget);
    });

    testWidgets('renders with leaf-only data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: SunburstChart(
                data: ChartTreeNode(name: 'Leaf', value: 10),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SunburstChart), findsOneWidget);
    });
  });
}
