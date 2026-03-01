import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_charts/crystal_charts.dart';

void main() {
  group('ChartDataPoint', () {
    test('holds x and y values', () {
      const point = ChartDataPoint(x: 1.0, y: 2.5);

      expect(point.x, 1.0);
      expect(point.y, 2.5);
      expect(point.label, isNull);
    });

    test('can specify a label', () {
      const point = ChartDataPoint(x: 0, y: 10, label: 'Jan');

      expect(point.label, 'Jan');
    });
  });
}
