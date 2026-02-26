import 'package:flutter/material.dart';

import '../models/calendar_heatmap_data.dart';
import '../theme/chart_theme.dart';
import '../utils/color_scale.dart';

/// Padding for text inside cells (px).
/// Corresponds to `EdgeInsets.all(8)` in the widget version.
const _cellPaddingPx = 8.0;

/// Grid line thickness (px).
/// Corresponds to `TableBorder.all(width: 0.5)` in the widget version.
const _gridLineWidthPx = 0.5;

/// Hover border thickness (px).
const _hoverBorderWidthPx = 2.0;

/// Painter that renders one month of a calendar heatmap on the Canvas.
///
/// Used for each page of a PageView. Since axes and plot area are not needed,
/// this directly extends [CustomPainter] rather than [BaseChartPainter].
class CalendarMonthPainter extends CustomPainter {
  final int year;
  final int month;
  final List<List<DateTime>> weeks;
  final CalendarHeatmapData data;
  final HeatmapColorScale colorScale;
  final double valueMin;
  final double valueMax;
  final ChartTheme theme;
  final TextStyle baseTextStyle;

  /// Fade-in animation progress (0.0 to 1.0).
  final double animationProgress;

  /// Currently hovered date. Null means no hover.
  final DateTime? hoveredDate;

  // Reusable Paint objects
  final Paint _cellPaint = Paint();
  final Paint _borderPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _gridPaint = Paint();

  CalendarMonthPainter({
    required this.year,
    required this.month,
    required this.weeks,
    required this.data,
    required this.colorScale,
    required this.valueMin,
    required this.valueMax,
    required this.theme,
    required this.baseTextStyle,
    this.animationProgress = 1.0,
    this.hoveredDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;

    final cellWidth = size.width / 7;
    final cellHeight = size.height / weeks.length;

    // 1. Cell backgrounds (backmost layer)
    _drawCellBackgrounds(canvas, cellWidth, cellHeight);
    // 2. Grid lines (overlaid on backgrounds so they are always visible)
    _drawGridLines(canvas, size, cellWidth, cellHeight);
    // 3. Hover border + date text (frontmost layer)
    _drawCellForegrounds(canvas, cellWidth, cellHeight);
  }

  /// Draws grid lines equivalent to the Table border.
  void _drawGridLines(
    Canvas canvas,
    Size size,
    double cellWidth,
    double cellHeight,
  ) {
    _gridPaint
      ..color = theme.gridColor
      ..strokeWidth = _gridLineWidthPx;

    // Half of stroke width: offset to prevent edge lines from being clipped outside the canvas
    final half = _gridLineWidthPx / 2;

    // Horizontal lines (row count + 1)
    for (var row = 0; row <= weeks.length; row++) {
      var y = row * cellHeight;
      if (row == 0) {
        y += half; // Top edge: offset inward
      } else if (row == weeks.length) {
        y -= half; // Bottom edge: offset inward
      }
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    // Vertical lines (8 lines: left edge of column 0 to right edge of column 6)
    for (var col = 0; col <= 7; col++) {
      var x = col * cellWidth;
      if (col == 0) {
        x += half; // Left edge: offset inward
      } else if (col == 7) {
        x -= half; // Right edge: offset inward
      }
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
  }

  /// Draws background colors for all cells (called before grid lines).
  void _drawCellBackgrounds(Canvas canvas, double cellWidth, double cellHeight) {
    final hasHover = hoveredDate != null;

    for (var row = 0; row < weeks.length; row++) {
      for (var col = 0; col < 7; col++) {
        final date = weeks[row][col];
        final isCurrentMonth = date.month == month && date.year == year;
        final value = isCurrentMonth ? data.valueOf(date) : null;

        final isHovered = _isSameDate(hoveredDate, date);
        final opacity = _cellOpacity(hasHover, isHovered);

        final cellRect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        ).deflate(_gridLineWidthPx / 2);

        final bgColor = _cellBackgroundColor(date, isCurrentMonth, value);
        if (bgColor != null) {
          _drawCellBackground(canvas, cellRect, bgColor, opacity,
              isHovered: isHovered);
        }
      }
    }
  }

  /// Draws hover border and date text (called after grid lines).
  void _drawCellForegrounds(Canvas canvas, double cellWidth, double cellHeight) {
    final hasHover = hoveredDate != null;
    final fontSize = baseTextStyle.fontSize ?? 14.0;
    final fontFamily = baseTextStyle.fontFamily;

    for (var row = 0; row < weeks.length; row++) {
      for (var col = 0; col < 7; col++) {
        final date = weeks[row][col];
        final isCurrentMonth = date.month == month && date.year == year;

        final isHovered = _isSameDate(hoveredDate, date);
        final opacity = _cellOpacity(hasHover, isHovered);

        final cellRect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        ).deflate(_gridLineWidthPx / 2);

        if (isHovered) {
          _drawHoverBorder(canvas, cellRect);
        }

        _drawDateText(
          canvas,
          cellRect,
          date,
          isCurrentMonth: isCurrentMonth,
          opacity: opacity,
          fontSize: fontSize,
          fontFamily: fontFamily,
        );
      }
    }
  }

  /// Draws a cell background.
  void _drawCellBackground(
    Canvas canvas,
    Rect cellRect,
    Color bgColor,
    double opacity, {
    required bool isHovered,
  }) {
    final radius = isHovered
        ? Radius.circular(theme.calendarCellBorderRadiusPx)
        : Radius.zero;
    final cellRRect = RRect.fromRectAndRadius(cellRect, radius);
    _cellPaint.color = bgColor.withValues(alpha: opacity);
    canvas.drawRRect(cellRRect, _cellPaint);
  }

  /// Draws the border for a hovered cell.
  void _drawHoverBorder(Canvas canvas, Rect cellRect) {
    final hoverRRect = RRect.fromRectAndRadius(
      cellRect,
      Radius.circular(theme.calendarCellBorderRadiusPx),
    );
    _borderPaint
      ..color = theme.calendarHoverBorderColor
      ..strokeWidth = _hoverBorderWidthPx;
    canvas.drawRRect(hoverRRect, _borderPaint);
  }

  /// Draws date text at the top-right of a cell.
  void _drawDateText(
    Canvas canvas,
    Rect cellRect,
    DateTime date, {
    required bool isCurrentMonth,
    required double opacity,
    required double fontSize,
    required String? fontFamily,
  }) {
    var textColor = _dateTextColor(date, isCurrentMonth);
    if (opacity < 1.0) {
      textColor = textColor.withValues(alpha: textColor.a * opacity);
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${date.day}',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          color: textColor,
          fontWeight: isCurrentMonth ? FontWeight.w500 : FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Corresponds to Alignment.topRight + padding 8px
    final textX =
        cellRect.right - _cellPaddingPx - textPainter.width;
    final textY = cellRect.top + _cellPaddingPx;
    textPainter.paint(canvas, Offset(textX, textY));
  }

  // ---------------------------------------------------------------------------
  // Color determination logic (same as widget version _CalendarHeatmapCell)
  // ---------------------------------------------------------------------------

  /// Cell background color based on heatmap value and day of week.
  Color? _cellBackgroundColor(
    DateTime date,
    bool isCurrentMonth,
    double? value,
  ) {
    if (!isCurrentMonth) {
      return _isWeekend(date) ? theme.calendarWeekendCellColor : null;
    }
    if (value != null) {
      final range = valueMax - valueMin;
      final normalized = range > 0 ? (value - valueMin) / range : 0.5;
      return colorScale.colorAt(normalized);
    }
    return _isWeekend(date) ? theme.calendarWeekendCellColor : null;
  }

  /// Date text color based on day of week and current month.
  Color _dateTextColor(DateTime date, bool isCurrentMonth) {
    if (!isCurrentMonth) {
      if (date.weekday == DateTime.sunday) {
        return theme.calendarSundayColor.withValues(alpha: 0.4);
      }
      if (date.weekday == DateTime.saturday) {
        return theme.calendarSaturdayColor.withValues(alpha: 0.4);
      }
      return theme.calendarOverflowDateColor;
    }
    if (date.weekday == DateTime.sunday) return theme.calendarSundayColor;
    if (date.weekday == DateTime.saturday) return theme.calendarSaturdayColor;
    return theme.calendarDateColor;
  }

  /// Cell opacity based on hover state.
  double _cellOpacity(bool hasHover, bool isHovered) {
    var opacity = animationProgress;
    if (hasHover && !isHovered) {
      opacity *= theme.calendarHoverDimmedOpacity;
    }
    return opacity;
  }

  static bool _isSameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.sunday ||
        date.weekday == DateTime.saturday;
  }

  @override
  bool shouldRepaint(covariant CalendarMonthPainter oldDelegate) {
    return year != oldDelegate.year ||
        month != oldDelegate.month ||
        data != oldDelegate.data ||
        animationProgress != oldDelegate.animationProgress ||
        hoveredDate != oldDelegate.hoveredDate ||
        valueMin != oldDelegate.valueMin ||
        valueMax != oldDelegate.valueMax;
  }
}

// ---------------------------------------------------------------------------
// Hit test
// ---------------------------------------------------------------------------

/// Returns the date of the calendar cell at the given local position.
/// Returns null if outside any cell.
DateTime? hitTestCalendarCell({
  required Offset localPosition,
  required Size size,
  required List<List<DateTime>> weeks,
}) {
  if (weeks.isEmpty) return null;

  final cellWidth = size.width / 7;
  final cellHeight = size.height / weeks.length;

  final col = (localPosition.dx / cellWidth).floor();
  final row = (localPosition.dy / cellHeight).floor();

  if (row < 0 || row >= weeks.length || col < 0 || col >= 7) return null;

  return weeks[row][col];
}
