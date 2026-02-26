import 'package:xtal_charts/src/utils/nice_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateNiceScale', () {
    test('generates nice ticks for the range 0 to 100', () {
      final scale = calculateNiceScale(minValue: 0, maxValue: 100);

      expect(scale.niceMin, 0);
      expect(scale.niceMax, greaterThanOrEqualTo(100));
      expect(scale.tickSpacing, greaterThan(0));
      expect(scale.ticks.first, 0);
      expect(scale.ticks.last, greaterThanOrEqualTo(100));
    });

    test('niceMin is pinned to 0 for non-negative data', () {
      final scale = calculateNiceScale(minValue: 15, maxValue: 85);

      expect(scale.niceMin, 0);
    });

    test('sets niceMin at or below 0 for data containing negative values', () {
      final scale = calculateNiceScale(minValue: -30, maxValue: 70);

      expect(scale.niceMin, lessThanOrEqualTo(-30));
      expect(scale.niceMax, greaterThanOrEqualTo(70));
    });

    test('does not error when all values are the same', () {
      final scale = calculateNiceScale(minValue: 50, maxValue: 50);

      expect(scale.niceMin, lessThan(50));
      expect(scale.niceMax, greaterThan(50));
      expect(scale.tickCount, greaterThan(1));
    });

    test('does not error when all values are 0', () {
      final scale = calculateNiceScale(minValue: 0, maxValue: 0);

      expect(scale.tickCount, greaterThan(1));
      expect(scale.tickSpacing, greaterThan(0));
    });

    test('tick count is close to the desired value', () {
      final scale = calculateNiceScale(
        minValue: 0,
        maxValue: 1000,
        desiredTickCount: 5,
      );

      // Tick count falls within a range around the desired value
      expect(scale.tickCount, inInclusiveRange(3, 8));
    });

    test('ticks list falls within the niceMin to niceMax range', () {
      final scale = calculateNiceScale(minValue: 3, maxValue: 97);

      expect(scale.ticks.first, scale.niceMin);
      expect(scale.ticks.last, closeTo(scale.niceMax, scale.tickSpacing * 0.5));
      for (final tick in scale.ticks) {
        expect(tick, greaterThanOrEqualTo(scale.niceMin));
        expect(tick, lessThanOrEqualTo(scale.niceMax + scale.tickSpacing * 0.5));
      }
    });

    test('generates nice ticks for decimal data', () {
      final scale = calculateNiceScale(minValue: 0.0, maxValue: 1.0);

      expect(scale.niceMin, 0);
      expect(scale.niceMax, greaterThanOrEqualTo(1.0));
      expect(scale.tickSpacing, greaterThan(0));
    });

    test('swaps and computes correctly when minValue > maxValue', () {
      final scale = calculateNiceScale(minValue: 100, maxValue: 0);

      expect(scale.niceMin, 0);
      expect(scale.niceMax, greaterThanOrEqualTo(100));
    });
  });

  group('NiceScale.ticks', () {
    test('tick spacing is uniform', () {
      final scale = calculateNiceScale(minValue: 0, maxValue: 100);
      final ticks = scale.ticks;

      for (var i = 1; i < ticks.length; i++) {
        expect(
          ticks[i] - ticks[i - 1],
          closeTo(scale.tickSpacing, 0.0001),
        );
      }
    });
  });
}
