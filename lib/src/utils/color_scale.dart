import 'package:flutter/painting.dart';

/// A color scale that maps continuous values to gradient colors.
///
/// [colorStops] is a list of (ratio, color) pairs where ratio ranges from 0.0 to 1.0.
/// Pass a normalized value to [colorAt] to get the corresponding interpolated color.
///
/// ```dart
/// final scale = HeatmapColorScale.twoColor(
///   minColor: Color(0xFFD6E4FF),
///   maxColor: Color(0xFF1D39C4),
/// );
/// final color = scale.colorAt(0.5); // midpoint color
/// ```
class HeatmapColorScale {
  final List<(double ratio, Color color)> colorStops;

  const HeatmapColorScale({required this.colorStops});

  /// Returns the color corresponding to the normalized value [t] (0.0-1.0).
  Color colorAt(double t) {
    if (colorStops.isEmpty) return const Color(0x00000000);
    if (colorStops.length == 1) return colorStops.first.$2;

    final clamped = t.clamp(0.0, 1.0);

    // Find the two stops surrounding t and linearly interpolate
    for (var i = 0; i < colorStops.length - 1; i++) {
      final (r0, c0) = colorStops[i];
      final (r1, c1) = colorStops[i + 1];
      if (clamped >= r0 && clamped <= r1) {
        final localT = r1 == r0 ? 0.0 : (clamped - r0) / (r1 - r0);
        return Color.lerp(c0, c1, localT)!;
      }
    }

    return colorStops.last.$2;
  }

  /// Creates a two-color linear gradient scale.
  factory HeatmapColorScale.twoColor({
    required Color minColor,
    required Color maxColor,
  }) {
    return HeatmapColorScale(colorStops: [
      (0.0, minColor),
      (1.0, maxColor),
    ]);
  }

  /// Creates an automatic gradient from white to [maxColor] given only the max color.
  ///
  /// The min side blends 5% of [maxColor] into white, so the color
  /// direction is visible across the entire gradient.
  ///
  /// ```dart
  /// final scale = HeatmapColorScale.fromColor(Colors.red);
  /// final color = scale.colorAt(0.5); // light red
  /// ```
  factory HeatmapColorScale.fromColor(Color maxColor) {
    return HeatmapColorScale(colorStops: [
      (0.0, Color.lerp(const Color(0xFFFFFFFF), maxColor, 0.05)!),
      (1.0, maxColor),
    ]);
  }
}
