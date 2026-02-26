import 'dart:math';

import '../models/chart_tree_node.dart';

/// A laid-out segment for sunburst chart rendering.
///
/// Each segment is represented as an arc in polar coordinates.
/// [startAngle] and [sweepAngle] define the angular range of the arc,
/// and [depth] indicates the ring position from the center.
class SunburstSegment {
  final ChartTreeNode node;
  final double startAngle;
  final double sweepAngle;
  final int depth;
  final SunburstSegment? parent;

  const SunburstSegment({
    required this.node,
    required this.startAngle,
    required this.sweepAngle,
    required this.depth,
    this.parent,
  });

  double get endAngle => startAngle + sweepAngle;

  bool get hasChildren => node.children.isNotEmpty;
}

/// Converts a ChartTreeNode hierarchy into a flat list of segments for sunburst layout.
///
/// Equivalent to D3's partition layout, assigning angles proportional to each node's value.
/// Processes recursively starting from [rootNode], with [maxDepth] limiting the display depth.
List<SunburstSegment> computeSunburstLayout({
  required ChartTreeNode rootNode,
  double startAngle = -pi / 2,
  double totalSweep = 2 * pi,
  int? maxDepth,
}) {
  final segments = <SunburstSegment>[];
  final rootTotal = rootNode.totalValue;
  if (rootTotal == 0) return segments;

  _layoutChildren(
    children: rootNode.children,
    parentSegment: null,
    parentStartAngle: startAngle,
    parentSweep: totalSweep,
    parentTotal: rootTotal,
    depth: 1,
    maxDepth: maxDepth,
    segments: segments,
  );

  return segments;
}

void _layoutChildren({
  required List<ChartTreeNode> children,
  required SunburstSegment? parentSegment,
  required double parentStartAngle,
  required double parentSweep,
  required num parentTotal,
  required int depth,
  required int? maxDepth,
  required List<SunburstSegment> segments,
}) {
  if (maxDepth != null && depth > maxDepth) return;

  var currentAngle = parentStartAngle;

  for (final child in children) {
    final childTotal = child.totalValue;
    if (childTotal <= 0) continue;

    final sweepAngle = (childTotal / parentTotal) * parentSweep;

    final segment = SunburstSegment(
      node: child,
      startAngle: currentAngle,
      sweepAngle: sweepAngle,
      depth: depth,
      parent: parentSegment,
    );
    segments.add(segment);

    if (child.children.isNotEmpty) {
      _layoutChildren(
        children: child.children,
        parentSegment: segment,
        parentStartAngle: currentAngle,
        parentSweep: sweepAngle,
        parentTotal: childTotal,
        depth: depth + 1,
        maxDepth: maxDepth,
        segments: segments,
      );
    }

    currentAngle += sweepAngle;
  }
}
