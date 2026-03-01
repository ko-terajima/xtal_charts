import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:xtalcharts/xtalcharts.dart';

void main() {
  group('ChartTreeNode', () {
    test('leaf node returns value as totalValue', () {
      const leaf = ChartTreeNode(name: 'leaf', value: 42);

      expect(leaf.totalValue, 42);
      expect(leaf.isLeaf, isTrue);
    });

    test('totalValue is 0 when leaf node value is null', () {
      const leaf = ChartTreeNode(name: 'empty');

      expect(leaf.totalValue, 0);
    });

    test('branch node totalValue returns the sum of children', () {
      const parent = ChartTreeNode(
        name: 'parent',
        children: [
          ChartTreeNode(name: 'a', value: 10),
          ChartTreeNode(name: 'b', value: 20),
          ChartTreeNode(name: 'c', value: 30),
        ],
      );

      expect(parent.totalValue, 60);
      expect(parent.isLeaf, isFalse);
    });

    test('totalValue is recursively summed in deep hierarchies', () {
      const root = ChartTreeNode(
        name: 'root',
        children: [
          ChartTreeNode(
            name: 'branch',
            children: [
              ChartTreeNode(name: 'x', value: 5),
              ChartTreeNode(name: 'y', value: 15),
            ],
          ),
          ChartTreeNode(name: 'leaf', value: 80),
        ],
      );

      expect(root.totalValue, 100);
    });

    test('color can be specified', () {
      const node = ChartTreeNode(
        name: 'colored',
        value: 10,
        color: Colors.red,
      );

      expect(node.color, Colors.red);
    });
  });
}
