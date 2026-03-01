import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:xtal_chart/xtal_chart.dart';

/// 3-level tree for testing:
///   root (total=100)
///   ├── A (60)
///   │   ├── A1 (40)
///   │   └── A2 (20)
///   └── B (40)
ChartTreeNode _buildTestTree() {
  return const ChartTreeNode(
    name: 'root',
    children: [
      ChartTreeNode(
        name: 'A',
        children: [
          ChartTreeNode(name: 'A1', value: 40),
          ChartTreeNode(name: 'A2', value: 20),
        ],
      ),
      ChartTreeNode(name: 'B', value: 40),
    ],
  );
}

void main() {
  group('computeSunburstLayout', () {
    test('direct children of root are generated as segments', () {
      final tree = _buildTestTree();
      final segments = computeSunburstLayout(rootNode: tree);

      final depth1Segments =
          segments.where((s) => s.depth == 1).toList();

      expect(depth1Segments.length, 2);
      expect(depth1Segments[0].node.name, 'A');
      expect(depth1Segments[1].node.name, 'B');
    });

    test('segment sweepAngle is proportional to the value ratio', () {
      final tree = _buildTestTree();
      final segments = computeSunburstLayout(rootNode: tree);

      final segmentA = segments.firstWhere((s) => s.node.name == 'A');
      final segmentB = segments.firstWhere((s) => s.node.name == 'B');

      // A is 60% of total, B is 40%
      expect(segmentA.sweepAngle, closeTo(2 * pi * 0.6, 0.001));
      expect(segmentB.sweepAngle, closeTo(2 * pi * 0.4, 0.001));
    });

    test('child nodes are generated as depth=2 segments', () {
      final tree = _buildTestTree();
      final segments = computeSunburstLayout(rootNode: tree);

      final depth2Segments =
          segments.where((s) => s.depth == 2).toList();

      expect(depth2Segments.length, 2);
      expect(depth2Segments[0].node.name, 'A1');
      expect(depth2Segments[1].node.name, 'A2');
    });

    test('maxDepth limits the visible depth', () {
      final tree = _buildTestTree();
      final segments = computeSunburstLayout(
        rootNode: tree,
        maxDepth: 1,
      );

      expect(segments.every((s) => s.depth <= 1), isTrue);
      expect(segments.length, 2);
    });

    test('nodes with value 0 are excluded from segments', () {
      const tree = ChartTreeNode(
        name: 'root',
        children: [
          ChartTreeNode(name: 'valid', value: 50),
          ChartTreeNode(name: 'zero', value: 0),
        ],
      );

      final segments = computeSunburstLayout(rootNode: tree);

      expect(segments.length, 1);
      expect(segments[0].node.name, 'valid');
    });

    test('returns an empty segment list for an empty root', () {
      const tree = ChartTreeNode(name: 'empty');
      final segments = computeSunburstLayout(rootNode: tree);

      expect(segments, isEmpty);
    });

    test('total sweep angle of all segments equals 2*pi (depth=1)', () {
      final tree = _buildTestTree();
      final segments = computeSunburstLayout(rootNode: tree);

      final totalSweep = segments
          .where((s) => s.depth == 1)
          .fold<double>(0, (sum, s) => sum + s.sweepAngle);

      expect(totalSweep, closeTo(2 * pi, 0.001));
    });
  });

  group('hitTestSunburst', () {
    test('returns -1 for center tap (drill up)', () {
      final tree = _buildTestTree();
      final segments = computeSunburstLayout(rootNode: tree);
      const size = Size(400, 400);

      // Center = (200, 200)
      final result = hitTestSunburst(
        tapPosition: const Offset(200, 200),
        size: size,
        segments: segments,
        maxVisibleDepth: 3,
      );

      expect(result, -1);
    });

    test('returns null for tap outside the chart', () {
      final tree = _buildTestTree();
      final segments = computeSunburstLayout(rootNode: tree);
      const size = Size(400, 400);

      final result = hitTestSunburst(
        tapPosition: const Offset(0, 0),
        size: size,
        segments: segments,
        maxVisibleDepth: 3,
      );

      expect(result, isNull);
    });
  });
}
