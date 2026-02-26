import 'package:flutter/material.dart';

import '../theme/chart_theme.dart';

/// Base chart painter that handles drawing axes and grid lines.
abstract class BaseChartPainter extends CustomPainter {
  final ChartTheme theme;

  /// Widget-level text style override.
  /// Takes precedence over theme.textStyle.
  final TextStyle? baseTextStyle;

  /// Reusable Paint for grid lines.
  final Paint _gridPaint = Paint();

  /// Reusable Paint for axis lines.
  final Paint _axisPaint = Paint();

  BaseChartPainter({required this.theme, this.baseTextStyle});

  /// Merges base text style with a theme-specific style and returns the result.
  /// base = baseTextStyle ?? theme.textStyle.
  /// Non-null properties of specificStyle take precedence.
  TextStyle resolveStyle(TextStyle specificStyle) {
    final base = baseTextStyle ?? theme.textStyle;
    if (base == null) return specificStyle;
    return base.merge(specificStyle);
  }

  /// Returns the inner plot area (excluding padding).
  Rect calculatePlotArea(Size canvasSize) {
    const paddingPx = 40.0;
    return Rect.fromLTRB(
      paddingPx,
      paddingPx,
      canvasSize.width - paddingPx,
      canvasSize.height - paddingPx,
    );
  }

  void drawGridLines(Canvas canvas, Rect plotArea, int horizontalLineCount) {
    _gridPaint
      ..color = theme.gridColor
      ..strokeWidth = theme.gridLineWidthPx;

    final stepHeight = plotArea.height / horizontalLineCount;
    for (var i = 0; i <= horizontalLineCount; i++) {
      final y = plotArea.top + stepHeight * i;
      canvas.drawLine(
        Offset(plotArea.left, y),
        Offset(plotArea.right, y),
        _gridPaint,
      );
    }
  }

  /// Draws dashed horizontal grid lines (Ant Design Charts style).
  void drawDashedGridLines(
    Canvas canvas,
    Rect plotArea,
    int horizontalLineCount, {
    double dashWidthPx = 4,
    double gapWidthPx = 4,
  }) {
    _gridPaint
      ..color = theme.gridColor
      ..strokeWidth = theme.gridLineWidthPx;

    final stepHeight = plotArea.height / horizontalLineCount;
    final dashCycle = dashWidthPx + gapWidthPx;

    for (var i = 0; i <= horizontalLineCount; i++) {
      final y = plotArea.top + stepHeight * i;
      var x = plotArea.left;
      while (x < plotArea.right) {
        final endX = (x + dashWidthPx).clamp(x, plotArea.right);
        canvas.drawLine(Offset(x, y), Offset(endX, y), _gridPaint);
        x += dashCycle;
      }
    }
  }

  void drawAxes(Canvas canvas, Rect plotArea) {
    _axisPaint
      ..color = theme.axisColor
      ..strokeWidth = theme.axisLineWidthPx;

    // X axis
    canvas.drawLine(
      Offset(plotArea.left, plotArea.bottom),
      Offset(plotArea.right, plotArea.bottom),
      _axisPaint,
    );
    // Y axis
    canvas.drawLine(
      Offset(plotArea.left, plotArea.top),
      Offset(plotArea.left, plotArea.bottom),
      _axisPaint,
    );
  }
}
