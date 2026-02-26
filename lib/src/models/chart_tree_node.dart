import 'package:flutter/material.dart';

/// Tree data model for hierarchical charts such as Sunburst.
///
/// Each node has a name and an optional numeric value; hierarchy is expressed
/// via a list of child nodes. Leaf nodes hold a [value], while branch node
/// values are automatically computed as the sum of their children.
class ChartTreeNode {
  final String name;
  final num? value;
  final List<ChartTreeNode> children;
  final Color? color;

  const ChartTreeNode({
    required this.name,
    this.value,
    this.children = const [],
    this.color,
  });

  /// Effective value of this node. Returns [value] for leaf nodes, or the sum of children for branch nodes.
  num get totalValue {
    if (children.isEmpty) return value ?? 0;
    return children.fold<num>(0, (sum, child) => sum + child.totalValue);
  }

  bool get isLeaf => children.isEmpty;
}
