import 'package:flutter/material.dart';

/// Theme configuration that controls the overall appearance of charts.
class ChartTheme {
  /// Base text style for all text. Merged into each text style (e.g. labelStyle).
  /// Used for global settings such as fontFamily and letterSpacing.
  final TextStyle? textStyle;

  final Color backgroundColor;
  final Color axisColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final double gridLineWidthPx;
  final double axisLineWidthPx;

  /// Text style for sunburst chart labels (names).
  final TextStyle sunburstLabelStyle;

  /// Text style for sunburst chart values.
  final TextStyle sunburstValueStyle;

  /// Whether to enable label display on sunburst charts.
  final bool showSunburstLabels;

  /// Whether to progressively lighten deeper sunburst segments based on parent color.
  final bool enableSunburstDepthTint;

  /// Tooltip background color.
  final Color tooltipBackgroundColor;

  /// Text style for tooltip labels (names).
  final TextStyle tooltipLabelStyle;

  /// Text style for tooltip values.
  final TextStyle tooltipValueStyle;

  /// Tooltip border radius.
  final double tooltipBorderRadius;

  /// Tooltip inner padding.
  final EdgeInsets tooltipPadding;

  // --- Area chart properties ---

  /// Area chart line width (px).
  final double areaLineWidthPx;

  /// Area fill opacity (0.0-1.0). Applied to the top of the gradient.
  final double areaFillOpacity;

  /// Radius of the data point dot shown on hover (px).
  final double areaPointHoverRadiusPx;

  /// Vertical crosshair line color on hover.
  final Color areaCrosshairColor;

  /// Crosshair line width (px).
  final double areaCrosshairWidthPx;

  // --- Bar chart properties ---

  /// Border radius of bar tops (px).
  final double barBorderRadiusPx;

  /// Maximum bar width (px). Upper limit when category spacing is wide.
  final double barMaxWidthPx;

  /// Gap between bars within a group (px).
  final double barGroupGapPx;

  /// Gap ratio between category groups (0.0-1.0, relative to slot width).
  final double barCategoryGapRatio;

  /// Opacity applied to non-hovered category bars on hover (0.0-1.0).
  final double barDimmedOpacity;

  /// HSL lightness boost for the hovered bar (0.0-1.0).
  final double barHoverBrightnessBoost;

  // --- Heatmap properties ---

  /// Gap between cells (px).
  final double heatmapCellGapPx;

  /// Cell border radius (px).
  final double heatmapCellBorderRadiusPx;

  /// Border color shown on hovered cells.
  final Color heatmapHoverBorderColor;

  /// Border width on hover (px).
  final double heatmapHoverBorderWidthPx;

  /// Opacity applied to non-hovered cells on hover (0.0-1.0).
  final double heatmapDimmedOpacity;

  /// Whether to show value labels inside cells.
  final bool showHeatmapCellLabels;

  /// Text style for in-cell labels.
  final TextStyle heatmapCellLabelStyle;

  /// Gradient colors for the color scale (min to max).
  final List<Color> heatmapGradientColors;

  /// Color legend bar height (px).
  final double heatmapLegendHeightPx;

  // --- Horizontal bar chart properties ---

  /// Border radius of horizontal bar right edges (px).
  final double horizontalBarBorderRadiusPx;

  /// Maximum height of horizontal bars (px).
  final double horizontalBarMaxHeightPx;

  /// Gap ratio between bar rows (0.0-1.0, relative to slot height).
  final double horizontalBarRowGapRatio;

  /// Opacity applied to non-hovered bars on hover (0.0-1.0).
  final double horizontalBarDimmedOpacity;

  /// HSL lightness boost for the hovered bar (0.0-1.0).
  final double horizontalBarHoverBrightnessBoost;

  /// Size of the color indicator square to the left of category labels (px).
  final double horizontalBarIndicatorSizePx;

  /// Text style for value labels.
  final TextStyle horizontalBarValueLabelStyle;

  // --- Axis label display control ---

  /// Whether to show X-axis labels.
  final bool showXAxisLabels;

  /// Whether to show Y-axis labels.
  final bool showYAxisLabels;

  // --- Axis title control ---

  /// Whether to show the X-axis title.
  final bool showXAxisTitle;

  /// Whether to show the Y-axis title.
  final bool showYAxisTitle;

  /// Text style for axis titles.
  final TextStyle axisTitleStyle;

  // --- Calendar heatmap properties ---

  /// Date cell border radius (px).
  final double calendarCellBorderRadiusPx;

  /// Sunday text color.
  final Color calendarSundayColor;

  /// Saturday text color.
  final Color calendarSaturdayColor;

  /// Regular date text color.
  final Color calendarDateColor;

  /// Text color for overflow dates from previous/next month.
  final Color calendarOverflowDateColor;

  /// Weekday header text color.
  final Color calendarWeekdayHeaderColor;

  /// Weekday header Sunday color. Falls back to [calendarSundayColor] if null.
  final Color? calendarWeekdayHeaderSundayColor;

  /// Weekday header Saturday color. Falls back to [calendarSaturdayColor] if null.
  final Color? calendarWeekdayHeaderSaturdayColor;

  /// Navigation arrow color.
  final Color calendarNavigationColor;

  /// Year/month selector text color.
  final Color calendarSelectorTextColor;

  /// Selector dropdown background color.
  final Color calendarSelectorDropdownColor;

  /// Background color of the selected item in the dropdown.
  final Color calendarSelectorSelectedColor;

  /// Opacity applied to non-hovered cells on hover (0.0-1.0).
  final double calendarHoverDimmedOpacity;

  /// Cell border color on hover.
  final Color calendarHoverBorderColor;

  /// Background color for weekend (Sat/Sun) cells (applied when no heatmap value).
  final Color calendarWeekendCellColor;

  const ChartTheme({
    this.textStyle,
    this.backgroundColor = Colors.white,
    this.axisColor = Colors.black87,
    this.gridColor = const Color(0xFFE0E0E0),
    this.labelStyle = const TextStyle(fontSize: 12, color: Colors.black54),
    this.gridLineWidthPx = 0.5,
    this.axisLineWidthPx = 1.0,
    this.sunburstLabelStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    this.sunburstValueStyle = const TextStyle(
      fontSize: 9,
      color: Colors.white70,
    ),
    this.showSunburstLabels = true,
    this.enableSunburstDepthTint = true,
    this.tooltipBackgroundColor = const Color(0xE6333333),
    this.tooltipLabelStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    this.tooltipValueStyle = const TextStyle(
      fontSize: 12,
      color: Color(0xCCFFFFFF),
    ),
    this.tooltipBorderRadius = 8.0,
    this.tooltipPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.areaLineWidthPx = 2.0,
    this.areaFillOpacity = 0.25,
    this.areaPointHoverRadiusPx = 4.0,
    this.areaCrosshairColor = const Color(0x40000000),
    this.areaCrosshairWidthPx = 1.0,
    this.barBorderRadiusPx = 2.0,
    this.barMaxWidthPx = 40.0,
    this.barGroupGapPx = 2.0,
    this.barCategoryGapRatio = 0.3,
    this.barDimmedOpacity = 0.4,
    this.barHoverBrightnessBoost = 0.1,
    this.heatmapCellGapPx = 2.0,
    this.heatmapCellBorderRadiusPx = 2.0,
    this.heatmapHoverBorderColor = const Color(0xFF333333),
    this.heatmapHoverBorderWidthPx = 2.0,
    this.heatmapDimmedOpacity = 0.4,
    this.showHeatmapCellLabels = false,
    this.heatmapCellLabelStyle = const TextStyle(
      fontSize: 10,
      color: Colors.white,
    ),
    this.heatmapGradientColors = const [Color(0xFFD6E4FF), Color(0xFF1D39C4)],
    this.heatmapLegendHeightPx = 12.0,
    this.horizontalBarBorderRadiusPx = 4.0,
    this.horizontalBarMaxHeightPx = 28.0,
    this.horizontalBarRowGapRatio = 0.25,
    this.horizontalBarDimmedOpacity = 0.4,
    this.horizontalBarHoverBrightnessBoost = 0.1,
    this.horizontalBarIndicatorSizePx = 10.0,
    this.horizontalBarValueLabelStyle = const TextStyle(
      fontSize: 12,
      color: Colors.black54,
    ),
    this.showXAxisLabels = true,
    this.showYAxisLabels = true,
    this.showXAxisTitle = true,
    this.showYAxisTitle = true,
    this.axisTitleStyle = const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.black54,
    ),
    this.calendarCellBorderRadiusPx = 4.0,
    this.calendarSundayColor = const Color(0xFFE53E3E),
    this.calendarSaturdayColor = const Color(0xFF3182CE),
    this.calendarDateColor = const Color(0xFF1A202C),
    this.calendarOverflowDateColor = const Color(0xFFCBD5E0),
    this.calendarWeekdayHeaderColor = const Color(0xFF4A5568),
    this.calendarWeekdayHeaderSundayColor,
    this.calendarWeekdayHeaderSaturdayColor,
    this.calendarNavigationColor = const Color(0xFF4A5568),
    this.calendarSelectorTextColor = const Color(0xFF1A202C),
    this.calendarSelectorDropdownColor = Colors.white,
    this.calendarSelectorSelectedColor = const Color(0xFFEBF4FF),
    this.calendarHoverDimmedOpacity = 0.4,
    this.calendarHoverBorderColor = const Color(0xFF333333),
    this.calendarWeekendCellColor = const Color(0xFFF6F6F8),
  });

  static const defaultTheme = ChartTheme();

  /// DaisyDisk-inspired dark theme.
  static const darkTheme = ChartTheme(
    backgroundColor: Color(0xFF1A1A2E),
    axisColor: Colors.white70,
    gridColor: Color(0xFF3A3A5E),
    labelStyle: TextStyle(fontSize: 12, color: Colors.white54),
    sunburstLabelStyle: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    sunburstValueStyle: TextStyle(
      fontSize: 9,
      color: Colors.white70,
    ),
    showSunburstLabels: true,
    enableSunburstDepthTint: true,
    tooltipBackgroundColor: Color(0xF0222244),
    tooltipLabelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    tooltipValueStyle: TextStyle(
      fontSize: 12,
      color: Color(0xCCFFFFFF),
    ),
    tooltipBorderRadius: 10.0,
    tooltipPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    areaCrosshairColor: Color(0x40FFFFFF),
    barDimmedOpacity: 0.3,
    heatmapHoverBorderColor: Color(0xFFFFFFFF),
    heatmapGradientColors: [Color(0xFF112A45), Color(0xFF36CFC9)],
    heatmapCellLabelStyle: TextStyle(fontSize: 10, color: Colors.white70),
    horizontalBarDimmedOpacity: 0.3,
    horizontalBarValueLabelStyle: TextStyle(
      fontSize: 12,
      color: Colors.white54,
    ),
    axisTitleStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.white54,
    ),
    calendarSundayColor: Color(0xFFFC8181),
    calendarSaturdayColor: Color(0xFF63B3ED),
    calendarDateColor: Color(0xFFE2E8F0),
    calendarOverflowDateColor: Color(0xFF4A5568),
    calendarWeekdayHeaderColor: Color(0xFFA0AEC0),
    calendarNavigationColor: Color(0xFFA0AEC0),
    calendarSelectorTextColor: Color(0xFFE2E8F0),
    calendarSelectorDropdownColor: Color(0xFF2D3748),
    calendarSelectorSelectedColor: Color(0xFF2A4365),
    calendarHoverDimmedOpacity: 0.3,
    calendarHoverBorderColor: Color(0xFFFFFFFF),
    calendarWeekendCellColor: Color(0xFF2D2D3A),
  );

  ChartTheme copyWith({
    TextStyle? textStyle,
    Color? backgroundColor,
    Color? axisColor,
    Color? gridColor,
    TextStyle? labelStyle,
    double? gridLineWidthPx,
    double? axisLineWidthPx,
    TextStyle? sunburstLabelStyle,
    TextStyle? sunburstValueStyle,
    bool? showSunburstLabels,
    bool? enableSunburstDepthTint,
    Color? tooltipBackgroundColor,
    TextStyle? tooltipLabelStyle,
    TextStyle? tooltipValueStyle,
    double? tooltipBorderRadius,
    EdgeInsets? tooltipPadding,
    double? areaLineWidthPx,
    double? areaFillOpacity,
    double? areaPointHoverRadiusPx,
    Color? areaCrosshairColor,
    double? areaCrosshairWidthPx,
    double? barBorderRadiusPx,
    double? barMaxWidthPx,
    double? barGroupGapPx,
    double? barCategoryGapRatio,
    double? barDimmedOpacity,
    double? barHoverBrightnessBoost,
    double? heatmapCellGapPx,
    double? heatmapCellBorderRadiusPx,
    Color? heatmapHoverBorderColor,
    double? heatmapHoverBorderWidthPx,
    double? heatmapDimmedOpacity,
    bool? showHeatmapCellLabels,
    TextStyle? heatmapCellLabelStyle,
    List<Color>? heatmapGradientColors,
    double? heatmapLegendHeightPx,
    double? horizontalBarBorderRadiusPx,
    double? horizontalBarMaxHeightPx,
    double? horizontalBarRowGapRatio,
    double? horizontalBarDimmedOpacity,
    double? horizontalBarHoverBrightnessBoost,
    double? horizontalBarIndicatorSizePx,
    TextStyle? horizontalBarValueLabelStyle,
    bool? showXAxisLabels,
    bool? showYAxisLabels,
    bool? showXAxisTitle,
    bool? showYAxisTitle,
    TextStyle? axisTitleStyle,
    double? calendarCellBorderRadiusPx,
    Color? calendarSundayColor,
    Color? calendarSaturdayColor,
    Color? calendarDateColor,
    Color? calendarOverflowDateColor,
    Color? calendarWeekdayHeaderColor,
    Color? calendarWeekdayHeaderSundayColor,
    Color? calendarWeekdayHeaderSaturdayColor,
    Color? calendarNavigationColor,
    Color? calendarSelectorTextColor,
    Color? calendarSelectorDropdownColor,
    Color? calendarSelectorSelectedColor,
    double? calendarHoverDimmedOpacity,
    Color? calendarHoverBorderColor,
    Color? calendarWeekendCellColor,
  }) {
    return ChartTheme(
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      axisColor: axisColor ?? this.axisColor,
      gridColor: gridColor ?? this.gridColor,
      labelStyle: labelStyle ?? this.labelStyle,
      gridLineWidthPx: gridLineWidthPx ?? this.gridLineWidthPx,
      axisLineWidthPx: axisLineWidthPx ?? this.axisLineWidthPx,
      sunburstLabelStyle: sunburstLabelStyle ?? this.sunburstLabelStyle,
      sunburstValueStyle: sunburstValueStyle ?? this.sunburstValueStyle,
      showSunburstLabels: showSunburstLabels ?? this.showSunburstLabels,
      enableSunburstDepthTint:
          enableSunburstDepthTint ?? this.enableSunburstDepthTint,
      tooltipBackgroundColor:
          tooltipBackgroundColor ?? this.tooltipBackgroundColor,
      tooltipLabelStyle: tooltipLabelStyle ?? this.tooltipLabelStyle,
      tooltipValueStyle: tooltipValueStyle ?? this.tooltipValueStyle,
      tooltipBorderRadius: tooltipBorderRadius ?? this.tooltipBorderRadius,
      tooltipPadding: tooltipPadding ?? this.tooltipPadding,
      areaLineWidthPx: areaLineWidthPx ?? this.areaLineWidthPx,
      areaFillOpacity: areaFillOpacity ?? this.areaFillOpacity,
      areaPointHoverRadiusPx:
          areaPointHoverRadiusPx ?? this.areaPointHoverRadiusPx,
      areaCrosshairColor: areaCrosshairColor ?? this.areaCrosshairColor,
      areaCrosshairWidthPx: areaCrosshairWidthPx ?? this.areaCrosshairWidthPx,
      barBorderRadiusPx: barBorderRadiusPx ?? this.barBorderRadiusPx,
      barMaxWidthPx: barMaxWidthPx ?? this.barMaxWidthPx,
      barGroupGapPx: barGroupGapPx ?? this.barGroupGapPx,
      barCategoryGapRatio: barCategoryGapRatio ?? this.barCategoryGapRatio,
      barDimmedOpacity: barDimmedOpacity ?? this.barDimmedOpacity,
      barHoverBrightnessBoost:
          barHoverBrightnessBoost ?? this.barHoverBrightnessBoost,
      heatmapCellGapPx: heatmapCellGapPx ?? this.heatmapCellGapPx,
      heatmapCellBorderRadiusPx:
          heatmapCellBorderRadiusPx ?? this.heatmapCellBorderRadiusPx,
      heatmapHoverBorderColor:
          heatmapHoverBorderColor ?? this.heatmapHoverBorderColor,
      heatmapHoverBorderWidthPx:
          heatmapHoverBorderWidthPx ?? this.heatmapHoverBorderWidthPx,
      heatmapDimmedOpacity: heatmapDimmedOpacity ?? this.heatmapDimmedOpacity,
      showHeatmapCellLabels:
          showHeatmapCellLabels ?? this.showHeatmapCellLabels,
      heatmapCellLabelStyle:
          heatmapCellLabelStyle ?? this.heatmapCellLabelStyle,
      heatmapGradientColors:
          heatmapGradientColors ?? this.heatmapGradientColors,
      heatmapLegendHeightPx:
          heatmapLegendHeightPx ?? this.heatmapLegendHeightPx,
      horizontalBarBorderRadiusPx:
          horizontalBarBorderRadiusPx ?? this.horizontalBarBorderRadiusPx,
      horizontalBarMaxHeightPx:
          horizontalBarMaxHeightPx ?? this.horizontalBarMaxHeightPx,
      horizontalBarRowGapRatio:
          horizontalBarRowGapRatio ?? this.horizontalBarRowGapRatio,
      horizontalBarDimmedOpacity:
          horizontalBarDimmedOpacity ?? this.horizontalBarDimmedOpacity,
      horizontalBarHoverBrightnessBoost: horizontalBarHoverBrightnessBoost ??
          this.horizontalBarHoverBrightnessBoost,
      horizontalBarIndicatorSizePx:
          horizontalBarIndicatorSizePx ?? this.horizontalBarIndicatorSizePx,
      horizontalBarValueLabelStyle:
          horizontalBarValueLabelStyle ?? this.horizontalBarValueLabelStyle,
      showXAxisLabels: showXAxisLabels ?? this.showXAxisLabels,
      showYAxisLabels: showYAxisLabels ?? this.showYAxisLabels,
      showXAxisTitle: showXAxisTitle ?? this.showXAxisTitle,
      showYAxisTitle: showYAxisTitle ?? this.showYAxisTitle,
      axisTitleStyle: axisTitleStyle ?? this.axisTitleStyle,
      calendarCellBorderRadiusPx:
          calendarCellBorderRadiusPx ?? this.calendarCellBorderRadiusPx,
      calendarSundayColor: calendarSundayColor ?? this.calendarSundayColor,
      calendarSaturdayColor:
          calendarSaturdayColor ?? this.calendarSaturdayColor,
      calendarDateColor: calendarDateColor ?? this.calendarDateColor,
      calendarOverflowDateColor:
          calendarOverflowDateColor ?? this.calendarOverflowDateColor,
      calendarWeekdayHeaderColor:
          calendarWeekdayHeaderColor ?? this.calendarWeekdayHeaderColor,
      calendarWeekdayHeaderSundayColor: calendarWeekdayHeaderSundayColor ??
          this.calendarWeekdayHeaderSundayColor,
      calendarWeekdayHeaderSaturdayColor:
          calendarWeekdayHeaderSaturdayColor ??
              this.calendarWeekdayHeaderSaturdayColor,
      calendarNavigationColor:
          calendarNavigationColor ?? this.calendarNavigationColor,
      calendarSelectorTextColor:
          calendarSelectorTextColor ?? this.calendarSelectorTextColor,
      calendarSelectorDropdownColor:
          calendarSelectorDropdownColor ?? this.calendarSelectorDropdownColor,
      calendarSelectorSelectedColor:
          calendarSelectorSelectedColor ?? this.calendarSelectorSelectedColor,
      calendarHoverDimmedOpacity:
          calendarHoverDimmedOpacity ?? this.calendarHoverDimmedOpacity,
      calendarHoverBorderColor:
          calendarHoverBorderColor ?? this.calendarHoverBorderColor,
      calendarWeekendCellColor:
          calendarWeekendCellColor ?? this.calendarWeekendCellColor,
    );
  }
}
