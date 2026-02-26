import 'dart:math';

/// Computed Y-axis scale result.
///
/// Divides the range from [niceMin] to [niceMax] by [tickSpacing] intervals
/// to produce human-readable tick marks.
class NiceScale {
  final double niceMin;
  final double niceMax;
  final double tickSpacing;
  final int tickCount;

  const NiceScale({
    required this.niceMin,
    required this.niceMax,
    required this.tickSpacing,
    required this.tickCount,
  });

  /// Generates a list of tick values.
  List<double> get ticks {
    final result = <double>[];
    // Use half of tickSpacing as tolerance to avoid floating-point accumulation errors
    for (var v = niceMin; v <= niceMax + tickSpacing * 0.5; v += tickSpacing) {
      result.add(v);
    }
    return result;
  }
}

/// Computes a "nice" Y-axis scale from the data range.
///
/// Rounds tick values to multiples of 1, 2, or 5 (simplified Wilkinson method).
/// When [minValue] >= 0, niceMin is fixed to 0
/// (as it provides a natural baseline for area charts).
NiceScale calculateNiceScale({
  required double minValue,
  required double maxValue,
  int desiredTickCount = 5,
}) {
  // Fallback for infinity / NaN input
  if (!minValue.isFinite) minValue = 0;
  if (!maxValue.isFinite) maxValue = minValue == 0 ? 1 : minValue.abs();

  // Fallback when all values are identical
  if (minValue == maxValue) {
    final padding = minValue == 0 ? 1.0 : minValue.abs() * 0.1;
    return calculateNiceScale(
      minValue: minValue - padding,
      maxValue: maxValue + padding,
      desiredTickCount: desiredTickCount,
    );
  }

  // Swap if min > max
  if (minValue > maxValue) {
    return calculateNiceScale(
      minValue: maxValue,
      maxValue: minValue,
      desiredTickCount: desiredTickCount,
    );
  }

  final range = maxValue - minValue;
  final roughSpacing = range / (desiredTickCount - 1);
  final magnitude = pow(10, (log(roughSpacing) / ln10).floor()).toDouble();
  final fraction = roughSpacing / magnitude;

  // Snap fraction to {1, 2, 5, 10}
  final double niceSpacing;
  if (fraction <= 1.5) {
    niceSpacing = 1.0 * magnitude;
  } else if (fraction <= 3.0) {
    niceSpacing = 2.0 * magnitude;
  } else if (fraction <= 7.0) {
    niceSpacing = 5.0 * magnitude;
  } else {
    niceSpacing = 10.0 * magnitude;
  }

  var niceMin = (minValue / niceSpacing).floor() * niceSpacing;
  var niceMax = (maxValue / niceSpacing).ceil() * niceSpacing;

  // Fix baseline to 0 for non-negative data (natural for area charts)
  if (minValue >= 0) niceMin = 0;

  final tickCount = ((niceMax - niceMin) / niceSpacing).round() + 1;

  return NiceScale(
    niceMin: niceMin,
    niceMax: niceMax,
    tickSpacing: niceSpacing,
    tickCount: tickCount,
  );
}
