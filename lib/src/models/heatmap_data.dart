/// Data representing a single heatmap cell.
/// Used when building a matrix from a flat list via the [HeatmapData.fromCells] factory.
class HeatmapCell {
  final int xIndex;
  final int yIndex;
  final double value;

  const HeatmapCell({
    required this.xIndex,
    required this.yIndex,
    required this.value,
  });
}

/// Data model for a heatmap chart.
///
/// Has X-axis categories (bottom edge) and Y-axis categories (left edge).
/// Values are managed as a 2D matrix via `values[yIndex][xIndex]`.
/// `null` means no data (the cell is not rendered).
///
/// ```dart
/// final data = HeatmapData(
///   xCategories: ['Jan', 'Feb', 'Mar'],
///   yCategories: ['2023', '2024'],
///   values: [
///     [10, 20, 30],
///     [15, null, 25],
///   ],
/// );
/// ```
class HeatmapData {
  final List<String> xCategories;
  final List<String> yCategories;

  /// `values[yIndex][xIndex]` -- `null` means no data.
  final List<List<double?>> values;

  const HeatmapData({
    required this.xCategories,
    required this.yCategories,
    required this.values,
  });

  int get xCount => xCategories.length;
  int get yCount => yCategories.length;

  /// Minimum value in the data (excluding nulls). Returns 0 if empty.
  double get minValue {
    var min = double.infinity;
    for (final row in values) {
      for (final v in row) {
        if (v != null && v < min) min = v;
      }
    }
    return min == double.infinity ? 0 : min;
  }

  /// Maximum value in the data (excluding nulls). Returns 1 if empty.
  double get maxValue {
    var max = double.negativeInfinity;
    for (final row in values) {
      for (final v in row) {
        if (v != null && v > max) max = v;
      }
    }
    return max == double.negativeInfinity ? 1 : max;
  }

  /// Builds a 2D matrix from a flat list of [HeatmapCell].
  /// Useful for converting row-based data from Supabase RPC results, etc.
  factory HeatmapData.fromCells({
    required List<String> xCategories,
    required List<String> yCategories,
    required List<HeatmapCell> cells,
  }) {
    final matrix = List.generate(
      yCategories.length,
      (_) => List<double?>.filled(xCategories.length, null),
    );
    for (final cell in cells) {
      if (cell.yIndex < yCategories.length &&
          cell.xIndex < xCategories.length) {
        matrix[cell.yIndex][cell.xIndex] = cell.value;
      }
    }
    return HeatmapData(
      xCategories: xCategories,
      yCategories: yCategories,
      values: matrix,
    );
  }
}
