import 'package:xtal_chart/src/utils/monotone_spline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildMonotoneCubicPath', () {
    test('returns an empty Path for an empty list', () {
      final path = buildMonotoneCubicPath([]);

      // Verify empty path by checking that PathMetrics is empty
      expect(path.computeMetrics().isEmpty, isTrue);
    });

    test('returns a Path without errors for a single point', () {
      final path = buildMonotoneCubicPath([const Offset(10, 20)]);

      // A moveTo-only Path has empty metrics, but verify no exception is thrown
      expect(path, isNotNull);
    });

    test('returns a straight-line Path for two points', () {
      final path = buildMonotoneCubicPath([
        const Offset(0, 0),
        const Offset(100, 50),
      ]);

      final bounds = path.getBounds();
      expect(bounds.left, closeTo(0, 0.1));
      expect(bounds.right, closeTo(100, 0.1));
    });

    test('returns a smooth curve Path for three or more points', () {
      final points = [
        const Offset(0, 100),
        const Offset(50, 20),
        const Offset(100, 80),
        const Offset(150, 10),
      ];

      final path = buildMonotoneCubicPath(points);
      final bounds = path.getBounds();

      // Path bounds encompass all data points
      expect(bounds.left, closeTo(0, 0.1));
      expect(bounds.right, closeTo(150, 0.1));
    });

    test('does not error on horizontal data (all Y values equal)', () {
      final points = [
        const Offset(0, 50),
        const Offset(50, 50),
        const Offset(100, 50),
      ];

      final path = buildMonotoneCubicPath(points);
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });
  });

  group('buildLinearPath', () {
    test('returns an empty Path for an empty list', () {
      final path = buildLinearPath([]);
      expect(path.computeMetrics().isEmpty, isTrue);
    });

    test('builds a linear path from multiple points', () {
      final points = [
        const Offset(0, 0),
        const Offset(50, 30),
        const Offset(100, 10),
      ];

      final path = buildLinearPath(points);
      final bounds = path.getBounds();

      expect(bounds.left, closeTo(0, 0.1));
      expect(bounds.right, closeTo(100, 0.1));
      expect(bounds.top, closeTo(0, 0.1));
      expect(bounds.bottom, closeTo(30, 0.1));
    });
  });
}
