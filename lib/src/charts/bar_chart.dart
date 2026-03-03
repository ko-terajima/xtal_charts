import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../painters/bar_chart_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/nice_numbers.dart';
import '../utils/value_formatter.dart';

/// Custom builder type for tooltips.
/// [categoryLabel] is the category label, [seriesValues] is a map of series name to (value, color).
typedef BarTooltipBuilder =
    Widget Function(
      BuildContext context,
      String categoryLabel,
      Map<String, (double value, Color color)> seriesValues,
    );

/// Callback type for element tap events.
/// [categoryIndex] / [seriesIndex] are the indices of the tapped bar,
/// [categoryLabel] is the category label, [seriesName] is the series name, [value] is the value.
typedef BarElementTapCallback =
    void Function(
      int categoryIndex,
      int seriesIndex,
      String categoryLabel,
      String seriesName,
      double value,
    );

/// A bar chart widget inspired by Ant Design Charts.
///
/// Renders one or more data series as grouped vertical bars.
/// Supports hover tooltips and bottom-to-top growth animations.
///
/// ```dart
/// BarChart(
///   seriesList: [
///     ChartSeries(
///       name: 'Tokyo',
///       dataPoints: [
///         ChartDataPoint(x: 0, y: 10, label: 'Jan'),
///         ChartDataPoint(x: 1, y: 25, label: 'Feb'),
///       ],
///       color: Colors.blue,
///     ),
///   ],
/// )
/// ```
class BarChart extends StatefulWidget {
  final List<ChartSeries> seriesList;
  final ChartTheme theme;

  /// Whether to show tooltips on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  final BarTooltipBuilder? tooltipBuilder;

  /// Callback for element tap events.
  final BarElementTapCallback? onElementTap;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve animationCurve;

  /// Y-axis minimum value (null for auto-calculation).
  final double? yMin;

  /// Y-axis maximum value (null for auto-calculation).
  final double? yMax;

  /// X-axis title text.
  final String? xAxisTitle;

  /// Y-axis title text.
  final String? yAxisTitle;

  /// Unit string for values (e.g., "%"). Hidden when null.
  final String? unit;

  /// Display position of the unit.
  final UnitPosition unitPosition;

  /// Scaling for display values.
  final ValueScale valueScale;

  /// Whether to use thousands separator commas.
  final bool useThousandsSeparator;

  /// Base text style. Takes priority over the theme's textStyle.
  final TextStyle? textStyle;

  /// Whether to rotate X-axis labels vertically (-90 degrees).
  final bool rotateXAxisLabels;

  const BarChart({
    super.key,
    required this.seriesList,
    this.theme = ChartTheme.defaultTheme,
    this.showTooltip = true,
    this.tooltipBuilder,
    this.onElementTap,
    this.animationDuration = const Duration(milliseconds: 800),
    this.animationCurve = Curves.easeOutCubic,
    this.yMin,
    this.yMax,
    this.xAxisTitle,
    this.yAxisTitle,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.textStyle,
    this.rotateXAxisLabels = false,
  });

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  /// Animation that grows bars from bottom to top.
  late Animation<double> _barGrowAnimation;

  NiceScale? _yScale;
  int? _hoveredCategoryIndex;
  int? _hoveredSeriesIndex;
  OverlayEntry? _tooltipOverlayEntry;
  Offset _mouseGlobalPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _yScale = _computeYScale();

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _barGrowAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 1.0, curve: widget.animationCurve),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(BarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesList != widget.seriesList ||
        oldWidget.yMin != widget.yMin ||
        oldWidget.yMax != widget.yMax) {
      _yScale = _computeYScale();
      _animationController.forward(from: 0);
      _removeTooltip();
    }
  }

  @override
  void dispose() {
    _removeTooltip();
    _animationController.dispose();
    super.dispose();
  }

  NiceScale _computeYScale() {
    if (widget.seriesList.isEmpty) {
      return calculateNiceScale(minValue: 0, maxValue: 1);
    }

    var minY = widget.yMin ?? double.infinity;
    var maxY = widget.yMax ?? double.negativeInfinity;

    for (final series in widget.seriesList) {
      for (final point in series.dataPoints) {
        if (widget.yMin == null && point.y < minY) minY = point.y;
        if (widget.yMax == null && point.y > maxY) maxY = point.y;
      }
    }

    // Bar charts typically start from 0
    if (minY > 0) minY = 0;

    // Fallback when data points are empty
    if (!maxY.isFinite) maxY = minY == 0 ? 1 : minY.abs();
    if (!minY.isFinite) minY = 0;

    return calculateNiceScale(minValue: minY, maxValue: maxY);
  }

  // --- Hover handling ---

  void _handleHover(Offset localPosition, Size size, Offset globalPosition) {
    final hitResult = hitTestBarChart(
      localPosition: localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
      yScale: _yScale,
      baseTextStyle: widget.textStyle,
      unit: widget.unit,
      unitPosition: widget.unitPosition,
      valueScale: widget.valueScale,
      useThousandsSeparator: widget.useThousandsSeparator,
      rotateXAxisLabels: widget.rotateXAxisLabels,
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    _mouseGlobalPosition = renderBox != null
        ? renderBox.localToGlobal(localPosition)
        : globalPosition;

    final newCatIdx = hitResult?.categoryIndex;
    final newSerIdx = hitResult?.seriesIndex;

    if (newCatIdx != _hoveredCategoryIndex ||
        newSerIdx != _hoveredSeriesIndex) {
      setState(() {
        _hoveredCategoryIndex = newCatIdx;
        _hoveredSeriesIndex = newSerIdx;
      });

      if (widget.showTooltip) {
        if (newCatIdx != null) {
          _showTooltip(newCatIdx);
        } else {
          _removeTooltip();
        }
      }
    } else if (widget.showTooltip && newCatIdx != null) {
      _updateTooltipPosition();
    }
  }

  void _handleMouseExit() {
    setState(() {
      _hoveredCategoryIndex = null;
      _hoveredSeriesIndex = null;
    });
    _removeTooltip();
  }

  // --- Tap handling ---

  void _handleTapDown(TapDownDetails details, Size size) {
    final hitResult = hitTestBarChart(
      localPosition: details.localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
      yScale: _yScale,
      baseTextStyle: widget.textStyle,
      unit: widget.unit,
      unitPosition: widget.unitPosition,
      valueScale: widget.valueScale,
      useThousandsSeparator: widget.useThousandsSeparator,
      rotateXAxisLabels: widget.rotateXAxisLabels,
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _mouseGlobalPosition = renderBox.localToGlobal(details.localPosition);
    }

    final newCatIdx = hitResult?.categoryIndex;
    final newSerIdx = hitResult?.seriesIndex;

    if (newCatIdx != _hoveredCategoryIndex ||
        newSerIdx != _hoveredSeriesIndex) {
      setState(() {
        _hoveredCategoryIndex = newCatIdx;
        _hoveredSeriesIndex = newSerIdx;
      });

      if (widget.showTooltip) {
        if (newCatIdx != null) {
          _showTooltip(newCatIdx);
        } else {
          _removeTooltip();
        }
      }
    }

    if (hitResult != null) {
      final catIdx = hitResult.categoryIndex;
      final serIdx = hitResult.seriesIndex;
      final series = widget.seriesList[serIdx];
      widget.onElementTap?.call(
        catIdx,
        serIdx,
        _categoryLabelAt(catIdx),
        series.name,
        series.dataPoints[catIdx].y,
      );
    }
  }

  // --- Tooltip ---

  void _showTooltip(int categoryIndex) {
    _removeTooltip();

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _BarTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(
                  overlayContext,
                  _categoryLabelAt(categoryIndex),
                  _seriesValuesAt(categoryIndex),
                )
              : _DefaultBarTooltip(
                  categoryLabel: _categoryLabelAt(categoryIndex),
                  seriesValues: _seriesValuesAt(categoryIndex),
                  theme: widget.theme,
                  unit: widget.unit,
                  unitPosition: widget.unitPosition,
                  valueScale: widget.valueScale,
                  useThousandsSeparator: widget.useThousandsSeparator,
                  baseTextStyle: widget.textStyle,
                ),
        );
      },
    );

    Overlay.of(context).insert(_tooltipOverlayEntry!);
  }

  void _updateTooltipPosition() {
    _tooltipOverlayEntry?.markNeedsBuild();
  }

  void _removeTooltip() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
  }

  String _categoryLabelAt(int index) {
    final point = widget.seriesList.first.dataPoints[index];
    return point.label ?? point.x.toString();
  }

  Map<String, (double, Color)> _seriesValuesAt(int index) {
    return {
      for (final series in widget.seriesList)
        series.name: (series.dataPoints[index].y, series.color),
    };
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    if (_yScale == null || widget.seriesList.isEmpty) {
      return Container(color: widget.theme.backgroundColor);
    }

    return RepaintBoundary(
      child: Container(
        color: widget.theme.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return MouseRegion(
              cursor: _hoveredCategoryIndex != null
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onHover: (event) =>
                  _handleHover(event.localPosition, size, event.position),
              onExit: (_) => _handleMouseExit(),
              child: GestureDetector(
                onTapDown: (details) => _handleTapDown(details, size),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: size,
                      painter: BarChartPainter(
                        seriesList: widget.seriesList,
                        yScale: _yScale!,
                        theme: widget.theme,
                        baseTextStyle: widget.textStyle,
                        animationProgress: _barGrowAnimation.value,
                        hoveredCategoryIndex: _hoveredCategoryIndex,
                        hoveredSeriesIndex: _hoveredSeriesIndex,
                        xAxisTitle: widget.xAxisTitle,
                        yAxisTitle: widget.yAxisTitle,
                        unit: widget.unit,
                        unitPosition: widget.unitPosition,
                        valueScale: widget.valueScale,
                        useThousandsSeparator: widget.useThousandsSeparator,
                        rotateXAxisLabels: widget.rotateXAxisLabels,
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- Tooltip positioning ---

/// Overlay widget that positions a tooltip at the mouse cursor location.
class _BarTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _BarTooltipPositioner({
    required this.mouseGlobalPosition,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return CustomSingleChildLayout(
      delegate: _TooltipLayoutDelegate(
        mousePosition: mouseGlobalPosition,
        cursorOffsetX: _cursorOffsetX,
        cursorOffsetY: _cursorOffsetY,
        screenSize: screenSize,
      ),
      child: child,
    );
  }
}

class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset mousePosition;
  final double cursorOffsetX;
  final double cursorOffsetY;
  final Size screenSize;

  _TooltipLayoutDelegate({
    required this.mousePosition,
    required this.cursorOffsetX,
    required this.cursorOffsetY,
    required this.screenSize,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: screenSize.width * 0.4,
      maxHeight: screenSize.height * 0.4,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = mousePosition.dx + cursorOffsetX;
    var top = mousePosition.dy + cursorOffsetY;

    if (left + childSize.width > screenSize.width - 8) {
      left = mousePosition.dx - cursorOffsetX - childSize.width;
    }
    if (top + childSize.height > screenSize.height - 8) {
      top = mousePosition.dy - cursorOffsetY - childSize.height;
    }

    left = left.clamp(
      8.0,
      (screenSize.width - childSize.width - 8).clamp(8.0, double.infinity),
    );
    top = top.clamp(
      8.0,
      (screenSize.height - childSize.height - 8).clamp(8.0, double.infinity),
    );

    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) {
    return mousePosition != oldDelegate.mousePosition ||
        screenSize != oldDelegate.screenSize;
  }
}

// --- Default tooltip ---

/// Default tooltip styled after Ant Design Charts.
/// Displays category label with colored dots, series names, and values.
class _DefaultBarTooltip extends StatelessWidget {
  final String categoryLabel;
  final Map<String, (double value, Color color)> seriesValues;
  final ChartTheme theme;
  final String? unit;
  final UnitPosition unitPosition;
  final ValueScale valueScale;
  final bool useThousandsSeparator;
  final TextStyle? baseTextStyle;

  const _DefaultBarTooltip({
    required this.categoryLabel,
    required this.seriesValues,
    required this.theme,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.baseTextStyle,
  });

  TextStyle _resolveStyle(TextStyle s) =>
      baseTextStyle == null ? s : baseTextStyle!.merge(s);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: theme.tooltipPadding,
      decoration: BoxDecoration(
        color: theme.tooltipBackgroundColor,
        borderRadius: BorderRadius.circular(theme.tooltipBorderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(categoryLabel, style: _resolveStyle(theme.tooltipLabelStyle)),
          const SizedBox(height: 4),
          for (final entry in seriesValues.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: entry.value.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${entry.key}: ', style: _resolveStyle(theme.tooltipValueStyle)),
                  Text(
                    formatChartValue(
                      entry.value.$1,
                      unit: unit,
                      unitPosition: unitPosition,
                      valueScale: valueScale,
                      decimalPlaces: 2,
                      useThousandsSeparator: useThousandsSeparator,
                    ),
                    style: _resolveStyle(theme.tooltipValueStyle).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
