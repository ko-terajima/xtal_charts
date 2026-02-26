import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../layout/sunburst_layout.dart';
import '../theme/chart_theme.dart';

/// Default color palette for sunburst charts (ordered by hue strip).
const sunburstDefaultColorPalette = [
  Color(0xFF093E42),
  Color(0xFF0E7C7F),
  Color(0xFF28A8A0),
  Color(0xFF12325E),
  Color(0xFF2768B0),
  Color(0xFF4A93D0),
  Color(0xFF15512F),
  Color(0xFF28895A),
  Color(0xFF4DB87E),
  Color(0xFF263545),
  Color(0xFF1B3A4B),
  Color(0xFF456178),
  Color(0xFF68889E),
  Color(0xFF7A4E15),
  Color(0xFFB87A28),
  Color(0xFFD49B3E),
  Color(0xFF7B1D1D),
  Color(0xFFBE3B3B),
  Color(0xFF3E2462),
  Color(0xFF6E48A0),
  Color(0xFF0D1B2A),
];

/// Angular gap between segments (radians). Reference value at depth=1.
const _segmentGapAngle = 0.012;

/// Animation delay per ring (fraction of the 0.0 to 1.0 range).
const _staggerDelayPerRing = 0.12;

/// DaisyDisk-style sunburst chart painter.
///
/// Features gradient fills, inter-segment gaps, hover glow,
/// dark center circle, and staggered per-ring animation.
class SunburstPainter extends CustomPainter {
  final List<SunburstSegment> segments;
  final int maxVisibleDepth;
  final ChartTheme theme;
  final double innerRadiusRatio;
  final int? highlightedIndex;

  /// Animation progress (0.0 to 1.0).
  final double animationProgress;

  /// Whether drill-up is available (shows a back icon in the center).
  final bool canDrillUp;

  /// Name of the current root node (displayed in the center).
  final String currentRootName;

  /// Whether the center circle is being hovered.
  final bool isCenterHovered;

  /// Total value of the current root node (displayed in the center).
  final num currentRootTotalValue;

  /// Widget-level text style override.
  final TextStyle? baseTextStyle;

  /// Reusable Paint for glow effects (thick stroke as a lightweight blur substitute).
  final Paint _glowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6.0;

  /// Reusable Paint for gradient segments.
  final Paint _gradientPaint = Paint()..style = PaintingStyle.fill;

  /// Reusable Paint for the center circle.
  final Paint _centerPaint = Paint();

  /// Reusable Paint for hover ring.
  final Paint _hoverRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  /// Reusable Paint for the arrow icon.
  final Paint _arrowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  SunburstPainter({
    required this.segments,
    required this.maxVisibleDepth,
    required this.theme,
    this.innerRadiusRatio = 0.2,
    this.highlightedIndex,
    this.animationProgress = 1.0,
    this.canDrillUp = false,
    this.currentRootName = '',
    this.isCenterHovered = false,
    this.currentRootTotalValue = 0,
    this.baseTextStyle,
  });

  TextStyle _resolveStyle(TextStyle specificStyle) {
    final base = baseTextStyle ?? theme.textStyle;
    if (base == null) return specificStyle;
    return base.merge(specificStyle);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) / 2;
    final innerRadius = maxRadius * innerRadiusRatio;
    final availableRadius = maxRadius - innerRadius;
    final ringWidth = availableRadius / maxVisibleDepth;

    // Use arc length at depth=1's mid-radius as the reference gap (px), uniform across all depths
    final midRadius1 = innerRadius + ringWidth * 0.5;
    final referenceGapPx = midRadius1 * _segmentGapAngle;

    // --- Draw segments ---
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.depth > maxVisibleDepth) continue;

      final outerR = innerRadius + ringWidth * segment.depth - referenceGapPx;
      final innerR = innerRadius + ringWidth * (segment.depth - 1);
      final baseColor = _segmentColor(segment);
      final isHighlighted = highlightedIndex == i;

      // Staggered animation per ring
      final ringDelay = (segment.depth - 1) * _staggerDelayPerRing;
      final ringProgress = ((animationProgress - ringDelay) / (1.0 - ringDelay))
          .clamp(0.0, 1.0);
      final animatedSweepAngle = segment.sweepAngle * ringProgress;

      // Adjust angle per depth to unify arc length with depth=1
      final midRadiusD = innerRadius + ringWidth * (segment.depth - 0.5);
      final adjustedGapAngle = referenceGapPx / midRadiusD;

      // Apply gap (only when the segment is wide enough)
      final gapAngle = segment.sweepAngle > adjustedGapAngle * 3
          ? adjustedGapAngle
          : 0.0;
      final gappedSweepAngle = (animatedSweepAngle - gapAngle).clamp(
        0.0,
        double.infinity,
      );
      final gappedStartAngle = segment.startAngle + gapAngle / 2;

      _drawGradientArcSegment(
        canvas: canvas,
        center: center,
        innerRadius: innerR,
        outerRadius: outerR,
        startAngle: gappedStartAngle,
        sweepAngle: gappedSweepAngle,
        baseColor: baseColor,
        depth: segment.depth,
        isHighlighted: isHighlighted,
      );
    }

    // --- Center circle (dark gradient) ---
    _drawCenterCircle(canvas, center, innerRadius);

    // --- Center label (root name + total value, with arrow when drill-up is available) ---
    _drawCenterLabel(canvas: canvas, center: center, radius: innerRadius);

    // --- Draw labels (after animation completes) ---
    if (theme.showSunburstLabels && animationProgress > 0.85) {
      final labelOpacity = ((animationProgress - 0.85) / 0.15).clamp(0.0, 1.0);
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        if (segment.depth > maxVisibleDepth) continue;

        final outerR = innerRadius + ringWidth * segment.depth - referenceGapPx;
        final innerR = innerRadius + ringWidth * (segment.depth - 1);

        _drawSegmentLabel(
          canvas: canvas,
          center: center,
          innerRadius: innerR,
          outerRadius: outerR,
          segment: segment,
          opacity: labelOpacity,
        );
      }
    }
  }

  /// Draws a solid-colored arc segment.
  void _drawGradientArcSegment({
    required Canvas canvas,
    required Offset center,
    required double innerRadius,
    required double outerRadius,
    required double startAngle,
    required double sweepAngle,
    required Color baseColor,
    required int depth,
    required bool isHighlighted,
  }) {
    if (sweepAngle < 0.001) return;

    final path = _buildArcPath(
      center: center,
      innerRadius: innerRadius,
      outerRadius: outerRadius,
      startAngle: startAngle,
      sweepAngle: sweepAngle,
    );

    // Hover glow (thick stroke as lightweight blur substitute for Web)
    if (isHighlighted) {
      _glowPaint.color = baseColor.withValues(alpha: 0.3);
      canvas.drawPath(path, _glowPaint);
    }

    // Lower alpha for non-highlighted segments (avoids saveLayer for Web performance)
    final isDimmed = !isHighlighted && highlightedIndex != null;
    final alpha = isDimmed ? 0.7 : 1.0;

    _gradientPaint
      ..shader = null
      ..color = baseColor.withValues(alpha: alpha);

    canvas.drawPath(path, _gradientPaint);
  }

  /// Builds the Path for an arc segment.
  Path _buildArcPath({
    required Offset center,
    required double innerRadius,
    required double outerRadius,
    required double startAngle,
    required double sweepAngle,
  }) {
    return Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + sweepAngle,
        -sweepAngle,
        false,
      )
      ..close();
  }

  /// Draws the center circle with a dark gradient.
  void _drawCenterCircle(Canvas canvas, Offset center, double radius) {
    final bgColor = theme.backgroundColor;
    final lighterBg = Color.lerp(bgColor, Colors.white, 0.08)!;

    _centerPaint.shader = ui.Gradient.radial(
      center,
      radius,
      [lighterBg, bgColor],
      [0.0, 1.0],
    );
    canvas.drawCircle(center, radius, _centerPaint);

    // Subtle glow ring on hover
    if (isCenterHovered && canDrillUp) {
      _hoverRingPaint.color = Colors.white.withValues(alpha: 0.15);
      canvas.drawCircle(center, radius - 1, _hoverRingPaint);
    }
  }

  /// Draws a label (name) and value on a segment.
  void _drawSegmentLabel({
    required Canvas canvas,
    required Offset center,
    required double innerRadius,
    required double outerRadius,
    required SunburstSegment segment,
    double opacity = 1.0,
  }) {
    final sweepAngle = segment.sweepAngle;
    final segmentRingWidth = outerRadius - innerRadius;

    final midRadius = (innerRadius + outerRadius) / 2;
    final arcLength = midRadius * sweepAngle;
    if (arcLength < 20 || segmentRingWidth < 14) return;

    final midAngle = segment.startAngle + sweepAngle / 2;
    final labelX = center.dx + midRadius * cos(midAngle);
    final labelY = center.dy + midRadius * sin(midAngle);

    final labelText = segment.node.name;
    final valueText = segment.node.totalValue.toString();

    // Text rotation angle (oriented for readability)
    final normalizedMidAngle = midAngle % (2 * pi) < 0
        ? midAngle % (2 * pi) + 2 * pi
        : midAngle % (2 * pi);
    final textAngle =
        (normalizedMidAngle > pi / 2 && normalizedMidAngle < 3 * pi / 2)
        ? midAngle + pi
        : midAngle;

    canvas.save();
    canvas.translate(labelX, labelY);
    canvas.rotate(textAngle);

    final maxLabelWidth = min(segmentRingWidth * 0.9, arcLength * 0.8);
    if (maxLabelWidth < 16) {
      canvas.restore();
      return;
    }

    final labelStyle = _resolveStyle(theme.sunburstLabelStyle).copyWith(
      fontSize: min(
        theme.sunburstLabelStyle.fontSize ?? 11,
        segmentRingWidth * 0.28,
      ),
      color: (theme.sunburstLabelStyle.color ?? Colors.white).withValues(
        alpha: opacity,
      ),
    );
    final labelPainter = TextPainter(
      text: TextSpan(text: labelText, style: labelStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxLabelWidth);

    final showValue = arcLength > 40 && segmentRingWidth > 24;

    if (showValue) {
      final valueStyle = _resolveStyle(theme.sunburstValueStyle).copyWith(
        fontSize: min(
          theme.sunburstValueStyle.fontSize ?? 9,
          segmentRingWidth * 0.22,
        ),
        color: (theme.sunburstValueStyle.color ?? Colors.white70).withValues(
          alpha: opacity * 0.7,
        ),
      );
      final valuePainter = TextPainter(
        text: TextSpan(text: valueText, style: valueStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: maxLabelWidth);

      final totalHeight = labelPainter.height + valuePainter.height + 1;
      final labelOffset = Offset(-labelPainter.width / 2, -totalHeight / 2);
      final valueOffset = Offset(
        -valuePainter.width / 2,
        -totalHeight / 2 + labelPainter.height + 1,
      );

      labelPainter.paint(canvas, labelOffset);
      valuePainter.paint(canvas, valueOffset);
    } else {
      final labelOffset = Offset(
        -labelPainter.width / 2,
        -labelPainter.height / 2,
      );
      labelPainter.paint(canvas, labelOffset);
    }

    canvas.restore();
  }

  /// Determines the color of a segment.
  /// Uses the node's own color if specified; otherwise assigns a solid color
  /// from the palette based on the topmost ancestor.
  Color _segmentColor(SunburstSegment segment) {
    return sunburstSegmentColor(
      segment,
      segments,
      enableDepthTint: theme.enableSunburstDepthTint,
    );
  }

  /// Draws the center label (root name + total value, with arrow when drill-up is available).
  void _drawCenterLabel({
    required Canvas canvas,
    required Offset center,
    required double radius,
  }) {
    final opacity = canDrillUp && isCenterHovered ? 1.0 : 0.7;
    final maxTextWidth = radius * 1.4;

    // Drill-up arrow (only shown when drilled down)
    double arrowBottomY = center.dy;
    if (canDrillUp) {
      final chevronOpacity = isCenterHovered ? 1.0 : 0.6;
      final chevronSize = radius * 0.25;
      _arrowPaint.color = Colors.white.withValues(alpha: chevronOpacity);

      // Upward chevron -- centered, indicates "go up one level"
      final chevronPath = Path()
        ..moveTo(center.dx - chevronSize * 0.5, center.dy - chevronSize * 0.3)
        ..lineTo(center.dx, center.dy - chevronSize * 0.8)
        ..lineTo(center.dx + chevronSize * 0.5, center.dy - chevronSize * 0.3);
      canvas.drawPath(chevronPath, _arrowPaint);

      arrowBottomY = center.dy - chevronSize * 0.05;
    }

    if (currentRootName.isEmpty) return;

    // Root name
    final nameStyle = TextStyle(
      fontFamily: (baseTextStyle ?? theme.textStyle)?.fontFamily,
      color: Colors.white.withValues(alpha: opacity),
      fontSize: min(radius * 0.22, 13.0),
      fontWeight: canDrillUp && isCenterHovered
          ? FontWeight.w600
          : FontWeight.w500,
    );
    final namePainter = TextPainter(
      text: TextSpan(text: currentRootName, style: nameStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);

    // Total value
    final valueStr = _formatCenterValue(currentRootTotalValue);
    final valueStyle = TextStyle(
      fontFamily: (baseTextStyle ?? theme.textStyle)?.fontFamily,
      color: Colors.white.withValues(alpha: opacity * 0.7),
      fontSize: min(radius * 0.18, 11.0),
      fontWeight: FontWeight.w400,
    );
    final valuePainter = TextPainter(
      text: TextSpan(text: valueStr, style: valueStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxTextWidth);

    final totalHeight = namePainter.height + valuePainter.height + 2;

    if (canDrillUp) {
      // Place text below the arrow
      namePainter.paint(
        canvas,
        Offset(center.dx - namePainter.width / 2, arrowBottomY),
      );
      valuePainter.paint(
        canvas,
        Offset(
          center.dx - valuePainter.width / 2,
          arrowBottomY + namePainter.height + 2,
        ),
      );
    } else {
      // Stack name + value vertically in the center
      final startY = center.dy - totalHeight / 2;
      namePainter.paint(
        canvas,
        Offset(center.dx - namePainter.width / 2, startY),
      );
      valuePainter.paint(
        canvas,
        Offset(
          center.dx - valuePainter.width / 2,
          startY + namePainter.height + 2,
        ),
      );
    }
  }

  /// Formats a number for center display.
  String _formatCenterValue(num value) {
    if (value is int) return value.toString();
    final d = value.toDouble();
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant SunburstPainter oldDelegate) {
    return baseTextStyle != oldDelegate.baseTextStyle ||
        segments != oldDelegate.segments ||
        maxVisibleDepth != oldDelegate.maxVisibleDepth ||
        highlightedIndex != oldDelegate.highlightedIndex ||
        animationProgress != oldDelegate.animationProgress ||
        canDrillUp != oldDelegate.canDrillUp ||
        currentRootName != oldDelegate.currentRootName ||
        currentRootTotalValue != oldDelegate.currentRootTotalValue ||
        isCenterHovered != oldDelegate.isCenterHovered;
  }
}

/// Public API to determine a segment's display color.
/// Uses the node's own color if specified; otherwise assigns a solid color
/// from the palette based on the topmost ancestor.
///
/// When [enableDepthTint] is `true`, depth=2 segments are progressively
/// tinted towards white in clockwise order based on the parent color.
/// Used when referencing colors outside the Painter, e.g. in legend widgets.
Color sunburstSegmentColor(
  SunburstSegment segment,
  List<SunburstSegment> allSegments, {
  bool enableDepthTint = true,
}) {
  if (segment.node.color != null) return segment.node.color!;

  // Traverse to the topmost ancestor (depth=1)
  var root = segment;
  while (root.parent != null) {
    root = root.parent!;
  }

  final rootIndex = allSegments
      .where((s) => s.depth == 1)
      .toList()
      .indexOf(root);
  final paletteIndex = rootIndex % sunburstDefaultColorPalette.length;
  final baseColor = sunburstDefaultColorPalette[paletteIndex];

  // depth=2 with depthTint enabled: progressively tint towards white clockwise based on parent color
  if (enableDepthTint && segment.depth == 2 && segment.parent != null) {
    final siblings =
        allSegments
            .where((s) => s.depth == 2 && s.parent == segment.parent)
            .toList()
          ..sort((a, b) => a.startAngle.compareTo(b.startAngle));
    final siblingCount = siblings.length;
    final siblingIndex = siblings.indexOf(segment);
    if (siblingIndex >= 0 && siblingCount > 1) {
      final t = siblingIndex / (siblingCount - 1) * 0.8;
      return Color.lerp(baseColor, Colors.white, t)!;
    }
  }

  return baseColor;
}

/// Returns the segment index at the given tap position.
/// Returns -1 for taps inside the center circle (drill-up action).
/// Returns null if no segment is hit.
int? hitTestSunburst({
  required Offset tapPosition,
  required Size size,
  required List<SunburstSegment> segments,
  required int maxVisibleDepth,
  double innerRadiusRatio = 0.2,
}) {
  final center = Offset(size.width / 2, size.height / 2);
  final maxRadius = min(size.width, size.height) / 2;
  final innerRadius = maxRadius * innerRadiusRatio;
  final availableRadius = maxRadius - innerRadius;
  final ringWidth = availableRadius / maxVisibleDepth;

  final dx = tapPosition.dx - center.dx;
  final dy = tapPosition.dy - center.dy;
  final distanceFromCenter = sqrt(dx * dx + dy * dy);

  if (distanceFromCenter <= innerRadius) return -1;
  if (distanceFromCenter > maxRadius) return null;

  var tapAngle = atan2(dy, dx);

  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (segment.depth > maxVisibleDepth) continue;

    final outerR = innerRadius + ringWidth * segment.depth;
    final innerR = innerRadius + ringWidth * (segment.depth - 1);

    if (distanceFromCenter < innerR || distanceFromCenter > outerR) continue;

    if (_isAngleInRange(tapAngle, segment.startAngle, segment.sweepAngle)) {
      return i;
    }
  }

  return null;
}

/// Checks whether an angle falls within the [start, start+sweep] range.
bool _isAngleInRange(double angle, double start, double sweep) {
  final normalizedAngle = (angle - start) % (2 * pi);
  final positiveAngle = normalizedAngle < 0
      ? normalizedAngle + 2 * pi
      : normalizedAngle;
  return positiveAngle <= sweep;
}
