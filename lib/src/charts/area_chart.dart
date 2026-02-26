import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../painters/area_chart_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/nice_numbers.dart';
import '../utils/value_formatter.dart';

/// Custom builder type for tooltips.
/// [xLabel] is the X-axis label, [seriesValues] is a map of series name to (value, color).
typedef AreaTooltipBuilder =
    Widget Function(
      BuildContext context,
      String xLabel,
      Map<String, (double value, Color color)> seriesValues,
    );

/// Callback type for element tap events.
/// [xIndex] is the X-axis index, [xLabel] is the X-axis label,
/// [seriesValues] is a map of series name to (value, color).
typedef AreaElementTapCallback =
    void Function(
      int xIndex,
      String xLabel,
      Map<String, (double value, Color color)> seriesValues,
    );

/// An area chart widget inspired by Ant Design Charts.
///
/// Renders one or more data series as gradient-filled areas.
/// Supports smooth curves, hover tooltips, and animations.
///
/// ```dart
/// AreaChart(
///   seriesList: [
///     ChartSeries(
///       name: 'Sales',
///       dataPoints: [
///         ChartDataPoint(x: 0, y: 10, label: 'Jan'),
///         ChartDataPoint(x: 1, y: 25, label: 'Feb'),
///       ],
///       color: Colors.blue,
///     ),
///   ],
/// )
/// ```
class AreaChart extends StatefulWidget {
  final List<ChartSeries> seriesList;
  final ChartTheme theme;

  /// Whether to use smooth curves (monotone cubic spline).
  final bool smoothCurve;

  /// Whether to show tooltips on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  final AreaTooltipBuilder? tooltipBuilder;

  /// Callback for element tap events.
  final AreaElementTapCallback? onElementTap;

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

  const AreaChart({
    super.key,
    required this.seriesList,
    this.theme = ChartTheme.defaultTheme,
    this.smoothCurve = false,
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
  });

  @override
  State<AreaChart> createState() => _AreaChartState();
}

class _AreaChartState extends State<AreaChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  /// Animation that reveals the line from left to right.
  late Animation<double> _lineRevealAnimation;

  /// Animation that fades in the area opacity.
  late Animation<double> _areaFadeAnimation;

  NiceScale? _yScale;
  int? _hoveredXIndex;
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

    // Line reveals left-to-right over the first 70% of the animation
    _lineRevealAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.0, 0.7, curve: widget.animationCurve),
    );

    // Area fades in from 30% to 100% (overlapping with the line reveal)
    _areaFadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(AreaChart oldWidget) {
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

    // Area charts typically start from 0
    if (minY > 0) minY = 0;

    // Fallback when data points are empty
    if (!maxY.isFinite) maxY = minY == 0 ? 1 : minY.abs();
    if (!minY.isFinite) minY = 0;

    return calculateNiceScale(minValue: minY, maxValue: maxY);
  }

  // --- Hover handling ---

  void _handleHover(Offset localPosition, Size size, Offset globalPosition) {
    final index = hitTestAreaChart(
      localPosition: localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    _mouseGlobalPosition = renderBox != null
        ? renderBox.localToGlobal(localPosition)
        : globalPosition;

    if (index != _hoveredXIndex) {
      setState(() => _hoveredXIndex = index);

      if (widget.showTooltip) {
        if (index != null) {
          _showTooltip(index);
        } else {
          _removeTooltip();
        }
      }
    } else if (widget.showTooltip && index != null) {
      _updateTooltipPosition();
    }
  }

  void _handleMouseExit() {
    setState(() => _hoveredXIndex = null);
    _removeTooltip();
  }

  // --- Tap handling ---

  void _handleTapDown(TapDownDetails details, Size size) {
    if (widget.onElementTap == null) return;

    final index = hitTestAreaChart(
      localPosition: details.localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      xAxisTitle: widget.xAxisTitle,
      yAxisTitle: widget.yAxisTitle,
    );
    if (index == null) return;

    widget.onElementTap!(index, _xLabelAt(index), _seriesValuesAt(index));
  }

  // --- Tooltip ---

  void _showTooltip(int xIndex) {
    _removeTooltip();

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _AreaTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(
                  overlayContext,
                  _xLabelAt(xIndex),
                  _seriesValuesAt(xIndex),
                )
              : _DefaultAreaTooltip(
                  xLabel: _xLabelAt(xIndex),
                  seriesValues: _seriesValuesAt(xIndex),
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

  String _xLabelAt(int index) {
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
              cursor: _hoveredXIndex != null
                  ? SystemMouseCursors.precise
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
                      painter: AreaChartPainter(
                        seriesList: widget.seriesList,
                        yScale: _yScale!,
                        theme: widget.theme,
                        baseTextStyle: widget.textStyle,
                        smoothCurve: widget.smoothCurve,
                        animationProgress: _lineRevealAnimation.value,
                        areaOpacity: _areaFadeAnimation.value,
                        hoveredXIndex: _hoveredXIndex,
                        xAxisTitle: widget.xAxisTitle,
                        yAxisTitle: widget.yAxisTitle,
                        unit: widget.unit,
                        unitPosition: widget.unitPosition,
                        valueScale: widget.valueScale,
                        useThousandsSeparator: widget.useThousandsSeparator,
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
class _AreaTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _AreaTooltipPositioner({
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
/// Displays X-axis label with colored dots, series names, and values.
class _DefaultAreaTooltip extends StatelessWidget {
  final String xLabel;
  final Map<String, (double value, Color color)> seriesValues;
  final ChartTheme theme;
  final String? unit;
  final UnitPosition unitPosition;
  final ValueScale valueScale;
  final bool useThousandsSeparator;
  final TextStyle? baseTextStyle;

  const _DefaultAreaTooltip({
    required this.xLabel,
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
          Text(xLabel, style: _resolveStyle(theme.tooltipLabelStyle)),
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
