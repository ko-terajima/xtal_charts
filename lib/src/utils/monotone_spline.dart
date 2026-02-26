import 'dart:math';
import 'dart:ui';

/// Builds a smooth path using monotone cubic spline interpolation.
///
/// Uses the Fritsch-Carlson method to preserve monotonicity between data points
/// (producing natural curves without overshoot).
/// [points] must be a list of Offsets sorted by x-coordinate.
Path buildMonotoneCubicPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  if (points.length == 1) {
    path.moveTo(points[0].dx, points[0].dy);
    return path;
  }
  if (points.length == 2) {
    path.moveTo(points[0].dx, points[0].dy);
    path.lineTo(points[1].dx, points[1].dy);
    return path;
  }

  final n = points.length;

  // Compute slopes (deltas) between adjacent points
  final deltas = List<double>.generate(n - 1, (i) {
    final dx = points[i + 1].dx - points[i].dx;
    if (dx == 0) return 0.0;
    return (points[i + 1].dy - points[i].dy) / dx;
  });

  // Compute tangents at each point
  final tangents = List<double>.filled(n, 0.0);
  tangents[0] = deltas[0];
  tangents[n - 1] = deltas[n - 2];
  for (var i = 1; i < n - 1; i++) {
    tangents[i] = (deltas[i - 1] + deltas[i]) / 2;
  }

  // Apply Fritsch-Carlson monotonicity constraints
  for (var i = 0; i < n - 1; i++) {
    if (deltas[i] == 0) {
      // Set tangents to 0 for flat (horizontal) segments
      tangents[i] = 0;
      tangents[i + 1] = 0;
      continue;
    }

    final alpha = tangents[i] / deltas[i];
    final beta = tangents[i + 1] / deltas[i];

    // If alpha^2 + beta^2 > 9, scale down the vector to preserve monotonicity
    final radiusSquared = alpha * alpha + beta * beta;
    if (radiusSquared > 9) {
      final scale = 3.0 / sqrt(radiusSquared);
      tangents[i] = scale * alpha * deltas[i];
      tangents[i + 1] = scale * beta * deltas[i];
    }
  }

  // Convert tangents to Bezier control points and build the path
  path.moveTo(points[0].dx, points[0].dy);
  for (var i = 0; i < n - 1; i++) {
    final dx = points[i + 1].dx - points[i].dx;
    final cp1x = points[i].dx + dx / 3;
    final cp1y = points[i].dy + tangents[i] * dx / 3;
    final cp2x = points[i + 1].dx - dx / 3;
    final cp2y = points[i + 1].dy - tangents[i + 1] * dx / 3;
    path.cubicTo(cp1x, cp1y, cp2x, cp2y, points[i + 1].dx, points[i + 1].dy);
  }

  return path;
}

/// Builds a linear interpolation path (for when smooth curves are not needed).
Path buildLinearPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;

  path.moveTo(points[0].dx, points[0].dy);
  for (var i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  return path;
}

