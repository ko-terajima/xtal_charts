import 'package:flutter_test/flutter_test.dart';
import 'package:xtal_chart/xtal_chart.dart';

void main() {
  group('formatChartValue', () {
    test('integer values are displayed without decimals', () {
      expect(formatChartValue(10.0), equals('10'));
      expect(formatChartValue(0.0), equals('0'));
      expect(formatChartValue(100.0), equals('100'));
    });

    test('decimal values are displayed with 1 decimal place by default', () {
      expect(formatChartValue(10.5), equals('10.5'));
      expect(formatChartValue(3.14), equals('3.1'));
    });

    test('precision can be changed with decimalPlaces', () {
      expect(formatChartValue(10.5, decimalPlaces: 2), equals('10.50'));
      expect(formatChartValue(3.14159, decimalPlaces: 3), equals('3.142'));
    });

    group('unit (suffix)', () {
      test('is appended after the number', () {
        expect(formatChartValue(100.0, unit: 'K'), equals('100K'));
        expect(formatChartValue(10.5, unit: '%'), equals('10.5%'));
        expect(formatChartValue(42.0, unit: 'items'), equals('42items'));
      });

      test('shows only the number when null', () {
        expect(formatChartValue(100.0, unit: null), equals('100'));
      });

      test('shows only the number when empty string', () {
        expect(formatChartValue(100.0, unit: ''), equals('100'));
      });
    });

    group('unit (prefix)', () {
      test('is prepended before the number', () {
        expect(
          formatChartValue(100.0,
              unit: '\$', unitPosition: UnitPosition.prefix),
          equals('\$100'),
        );
        expect(
          formatChartValue(1500.0,
              unit: '¥', unitPosition: UnitPosition.prefix),
          equals('¥1,500'),
        );
      });
    });

    group('ValueScale', () {
      test('none displays the value as-is', () {
        expect(
          formatChartValue(18290.0, valueScale: ValueScale.none),
          equals('18,290'),
        );
      });

      test('divideBy1000 divides by 1000 before display', () {
        expect(
          formatChartValue(18290.0, valueScale: ValueScale.divideBy1000),
          equals('18.3'),
        );
        expect(
          formatChartValue(5000.0, valueScale: ValueScale.divideBy1000),
          equals('5'),
        );
      });

      test('divideBy10000 divides by 10000 before display', () {
        expect(
          formatChartValue(18290.0, valueScale: ValueScale.divideBy10000),
          equals('1.8'),
        );
        expect(
          formatChartValue(100000.0, valueScale: ValueScale.divideBy10000),
          equals('10'),
        );
      });
    });

    group('scaling + unit + position combinations', () {
      test('divideBy10000 + suffix unit', () {
        expect(
          formatChartValue(18290.0,
              unit: 'K', valueScale: ValueScale.divideBy10000),
          equals('1.8K'),
        );
      });

      test('divideBy10000 + suffix unit + high precision', () {
        expect(
          formatChartValue(18290.0,
              unit: 'K',
              valueScale: ValueScale.divideBy10000,
              decimalPlaces: 3),
          equals('1.829K'),
        );
      });

      test('divideBy1000 + prefix unit', () {
        expect(
          formatChartValue(5000.0,
              unit: '\$',
              unitPosition: UnitPosition.prefix,
              valueScale: ValueScale.divideBy1000),
          equals('\$5'),
        );
      });
    });

    group('useThousandsSeparator', () {
      test('integers get thousands separators', () {
        expect(formatChartValue(1234567.0), equals('1,234,567'));
      });

      test('decimals get thousands separators (no commas in decimal part)', () {
        expect(
          formatChartValue(1234567.89, decimalPlaces: 2),
          equals('1,234,567.89'),
        );
      });

      test('negative values get thousands separators', () {
        expect(formatChartValue(-1234567.0), equals('-1,234,567'));
      });

      test('values with 3 or fewer digits have no commas', () {
        expect(formatChartValue(999.0), equals('999'));
      });

      test('no commas when set to false', () {
        expect(
          formatChartValue(1234567.0, useThousandsSeparator: false),
          equals('1234567'),
        );
      });

      test('commas + unit + valueScale combination', () {
        expect(
          formatChartValue(
            18290000.0,
            unit: 'K',
            valueScale: ValueScale.divideBy10000,
          ),
          equals('1,829K'),
        );
      });

      test('commas + prefix unit', () {
        expect(
          formatChartValue(
            1500000.0,
            unit: '\$',
            unitPosition: UnitPosition.prefix,
          ),
          equals('\$1,500,000'),
        );
      });
    });
  });
}
