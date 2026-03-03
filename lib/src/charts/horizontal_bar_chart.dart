import 'dart:math';

import 'package:flutter/material.dart';

import '../models/chart_data.dart';
import '../painters/horizontal_bar_chart_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/value_formatter.dart';

/// Custom builder type for tooltips.
typedef HorizontalBarTooltipBuilder =
    Widget Function(
      BuildContext context,
      String seriesName,
      double value,
      Color color,
    );

/// Callback type for element tap events.
typedef HorizontalBarElementTapCallback =
    void Function(int seriesIndex, String seriesName, double value);

/// Horizontal bar chart widget.
///
/// Displays each [ChartSeries] as a single horizontal bar.
/// Layout: color indicator + label on the left, bar in the center, value label on the right.
///
/// ```dart
/// HorizontalBarChart(
///   seriesList: [
///     ChartSeries(
///       name: 'Regular Orders',
///       dataPoints: [ChartDataPoint(x: 0, y: 18290)],
///       color: Color(0xFF5B8FF9),
///     ),
///   ],
///   valueLabelFormatter: (v) => '${v.toInt()} units',
/// )
/// ```
class HorizontalBarChart extends StatefulWidget {
  final List<ChartSeries> seriesList;
  final ChartTheme theme;

  /// Whether to show a tooltip on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  final HorizontalBarTooltipBuilder? tooltipBuilder;

  /// Callback for element tap events.
  final HorizontalBarElementTapCallback? onElementTap;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve animationCurve;

  /// Whether to show value labels to the right of bars.
  final bool showValueLabels;

  /// Formatter for value labels (e.g., for custom display like "18,290K").
  final ValueLabelFormatter? valueLabelFormatter;

  /// Whether to show colored indicator squares to the left of category labels.
  final bool showColorIndicators;

  /// Unit string for values (e.g., "USD", "%"). Hidden if null.
  final String? unit;

  /// Display position of the unit.
  final UnitPosition unitPosition;

  /// Scaling for displayed values.
  final ValueScale valueScale;

  /// Whether to use thousands separators (commas).
  final bool useThousandsSeparator;

  /// Base text style. Takes priority over the theme's textStyle.
  final TextStyle? textStyle;

  const HorizontalBarChart({
    super.key,
    required this.seriesList,
    this.theme = ChartTheme.defaultTheme,
    this.showTooltip = true,
    this.tooltipBuilder,
    this.onElementTap,
    this.animationDuration = const Duration(milliseconds: 800),
    this.animationCurve = Curves.easeOutCubic,
    this.showValueLabels = true,
    this.valueLabelFormatter,
    this.showColorIndicators = true,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.textStyle,
  });

  @override
  State<HorizontalBarChart> createState() =>
      _HorizontalBarChartState();
}

class _HorizontalBarChartState extends State<HorizontalBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _barGrowAnimation;

  double _maxValue = 0;
  int? _hoveredBarIndex;
  OverlayEntry? _tooltipOverlayEntry;
  Offset _mouseGlobalPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _maxValue = _computeMaxValue();

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
  void didUpdateWidget(HorizontalBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesList != widget.seriesList) {
      _maxValue = _computeMaxValue();
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

  /// Computes the maximum value across all bars.
  double _computeMaxValue() {
    if (widget.seriesList.isEmpty) return 1;

    var maxVal = 0.0;
    for (final series in widget.seriesList) {
      for (final point in series.dataPoints) {
        maxVal = max(maxVal, point.y);
      }
    }
    return maxVal > 0 ? maxVal : 1;
  }

  // --- Hover handling ---

  void _handleHover(Offset localPosition, Size size, Offset globalPosition) {
    final base = widget.textStyle ?? widget.theme.textStyle;
    final hitResult = hitTestHorizontalBarChart(
      localPosition: localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      maxValue: _maxValue,
      showColorIndicators: widget.showColorIndicators,
      showValueLabels: widget.showValueLabels,
      valueLabelFormatter: widget.valueLabelFormatter,
      resolvedLabelStyle: base?.merge(widget.theme.labelStyle),
      resolvedValueLabelStyle: base?.merge(widget.theme.horizontalBarValueLabelStyle),
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    _mouseGlobalPosition = renderBox != null
        ? renderBox.localToGlobal(localPosition)
        : globalPosition;

    if (hitResult != _hoveredBarIndex) {
      setState(() {
        _hoveredBarIndex = hitResult;
      });

      if (widget.showTooltip) {
        if (hitResult != null) {
          _showTooltip(hitResult);
        } else {
          _removeTooltip();
        }
      }
    } else if (widget.showTooltip && hitResult != null) {
      _updateTooltipPosition();
    }
  }

  void _handleMouseExit() {
    setState(() {
      _hoveredBarIndex = null;
    });
    _removeTooltip();
  }

  // --- Tap handling ---

  void _handleTapDown(TapDownDetails details, Size size) {
    final base = widget.textStyle ?? widget.theme.textStyle;
    final hitResult = hitTestHorizontalBarChart(
      localPosition: details.localPosition,
      size: size,
      seriesList: widget.seriesList,
      theme: widget.theme,
      maxValue: _maxValue,
      showColorIndicators: widget.showColorIndicators,
      showValueLabels: widget.showValueLabels,
      valueLabelFormatter: widget.valueLabelFormatter,
      resolvedLabelStyle: base?.merge(widget.theme.labelStyle),
      resolvedValueLabelStyle: base?.merge(widget.theme.horizontalBarValueLabelStyle),
    );

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _mouseGlobalPosition = renderBox.localToGlobal(details.localPosition);
    }

    if (hitResult != _hoveredBarIndex) {
      setState(() {
        _hoveredBarIndex = hitResult;
      });

      if (widget.showTooltip) {
        if (hitResult != null) {
          _showTooltip(hitResult);
        } else {
          _removeTooltip();
        }
      }
    }

    if (hitResult != null) {
      final series = widget.seriesList[hitResult];
      final value = series.dataPoints.isNotEmpty
          ? series.dataPoints.first.y
          : 0.0;
      widget.onElementTap?.call(hitResult, series.name, value);
    }
  }

  // --- Tooltip ---

  void _showTooltip(int barIndex) {
    _removeTooltip();

    final series = widget.seriesList[barIndex];
    final value = series.dataPoints.isNotEmpty
        ? series.dataPoints.first.y
        : 0.0;

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _HorizontalBarTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(
                  overlayContext,
                  series.name,
                  value,
                  series.color,
                )
              : _DefaultHorizontalBarTooltip(
                  seriesName: series.name,
                  unit: widget.unit,
                  unitPosition: widget.unitPosition,
                  valueScale: widget.valueScale,
                  useThousandsSeparator: widget.useThousandsSeparator,
                  value: value,
                  color: series.color,
                  theme: widget.theme,
                  valueLabelFormatter: widget.valueLabelFormatter,
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

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    if (widget.seriesList.isEmpty) {
      return Container(color: widget.theme.backgroundColor);
    }

    return RepaintBoundary(
      child: Container(
        color: widget.theme.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return MouseRegion(
              cursor: _hoveredBarIndex != null
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
                      painter: HorizontalBarChartPainter(
                        seriesList: widget.seriesList,
                        maxValue: _maxValue,
                        theme: widget.theme,
                        baseTextStyle: widget.textStyle,
                        animationProgress: _barGrowAnimation.value,
                        hoveredBarIndex: _hoveredBarIndex,
                        showColorIndicators: widget.showColorIndicators,
                        showValueLabels: widget.showValueLabels,
                        valueLabelFormatter: widget.valueLabelFormatter,
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
class _HorizontalBarTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _HorizontalBarTooltipPositioner({
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

/// Default tooltip for the horizontal bar chart.
/// Displays a colored dot + series name + value.
class _DefaultHorizontalBarTooltip extends StatelessWidget {
  final String seriesName;
  final double value;
  final Color color;
  final ChartTheme theme;
  final ValueLabelFormatter? valueLabelFormatter;
  final String? unit;
  final UnitPosition unitPosition;
  final ValueScale valueScale;
  final bool useThousandsSeparator;
  final TextStyle? baseTextStyle;

  const _DefaultHorizontalBarTooltip({
    required this.seriesName,
    required this.value,
    required this.color,
    required this.theme,
    this.valueLabelFormatter,
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
    final formattedValue = valueLabelFormatter != null
        ? valueLabelFormatter!(value)
        : formatChartValue(
            value,
            unit: unit,
            unitPosition: unitPosition,
            valueScale: valueScale,
            decimalPlaces: 2,
            useThousandsSeparator: useThousandsSeparator,
          );

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$seriesName: ', style: _resolveStyle(theme.tooltipValueStyle)),
          Text(
            formattedValue,
            style: _resolveStyle(theme.tooltipValueStyle).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
