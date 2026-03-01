import 'package:flutter/material.dart';

import '../models/calendar_heatmap_data.dart';
import '../models/legend_position.dart';
import '../painters/calendar_month_painter.dart';
import '../theme/chart_theme.dart';
import '../utils/color_scale.dart';
import '../utils/value_formatter.dart';

/// Callback type for date tap events.
typedef CalendarDateTapCallback = void Function(DateTime date, double? value);

/// Custom tooltip builder type for the calendar heatmap.
/// [date] is the hovered date, [value] is the heatmap value for that day (null if no data),
/// [cellColor] is the heatmap color (null if no data).
typedef CalendarHeatmapTooltipBuilder =
    Widget Function(
      BuildContext context,
      DateTime date,
      double? value,
      Color? cellColor,
    );

/// A calendar heatmap widget.
///
/// Displays a monthly calendar grid with date cell backgrounds colored according to heatmap values.
/// Includes year/month selector UI and navigation arrows.
///
/// ```dart
/// CalendarHeatmap(
///   data: CalendarHeatmapData(values: {
///     DateTime(2025, 12, 1): 10,
///     DateTime(2025, 12, 15): 25,
///   }),
/// )
/// ```
class CalendarHeatmap extends StatefulWidget {
  /// Heatmap data (date-to-value mapping).
  final CalendarHeatmapData data;

  /// Theme configuration.
  final ChartTheme theme;

  /// Color scale (null to auto-generate from theme gradient colors).
  final HeatmapColorScale? colorScale;

  /// Minimum value for normalization (null for auto-calculation).
  final double? valueMin;

  /// Maximum value for normalization (null for auto-calculation).
  final double? valueMax;

  /// Initial year and month to display (null for current date).
  final DateTime? initialMonth;

  /// Year selector range (start year).
  final int? yearRangeStart;

  /// Year selector range (end year).
  final int? yearRangeEnd;

  /// Callback for date tap events.
  final CalendarDateTapCallback? onDateTap;

  /// Callback when the year/month changes.
  final ValueChanged<DateTime>? onMonthChanged;

  /// Base text style. Takes priority over the theme's textStyle.
  final TextStyle? textStyle;

  /// Animation duration.
  final Duration animationDuration;

  /// Animation curve.
  final Curve animationCurve;

  /// Whether to show tooltips on hover.
  final bool showTooltip;

  /// Custom tooltip builder.
  final CalendarHeatmapTooltipBuilder? tooltipBuilder;

  /// Unit string for values (e.g., "%"). Used in default tooltip display.
  final String? unit;

  /// Display position of the unit.
  final UnitPosition unitPosition;

  /// Scaling for display values.
  final ValueScale valueScale;

  /// Whether to use thousands separator commas.
  final bool useThousandsSeparator;

  /// Minimum height (px) for date cell rows. No limit when null.
  /// Content grows naturally if it exceeds minHeight.
  final double? cellRowMinHeight;

  /// Display position of the color legend. Hidden when null.
  final LegendPosition? colorLegendPosition;

  /// Minimum value displayed on the legend bar (null defaults to 0).
  /// Does not affect color normalization (display only).
  final double? legendDisplayMinValue;

  const CalendarHeatmap({
    super.key,
    required this.data,
    this.theme = ChartTheme.defaultTheme,
    this.colorScale,
    this.valueMin,
    this.valueMax,
    this.initialMonth,
    this.yearRangeStart,
    this.yearRangeEnd,
    this.onDateTap,
    this.onMonthChanged,
    this.textStyle,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.showTooltip = true,
    this.tooltipBuilder,
    this.unit,
    this.unitPosition = UnitPosition.suffix,
    this.valueScale = ValueScale.none,
    this.useThousandsSeparator = true,
    this.cellRowMinHeight,
    this.colorLegendPosition = LegendPosition.bottom,
    this.legendDisplayMinValue,
  });

  @override
  State<CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<CalendarHeatmap>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late int _currentYear;
  late int _currentMonth;

  DateTime? _hoveredDate;
  OverlayEntry? _tooltipOverlayEntry;
  Offset _mouseGlobalPosition = Offset.zero;

  // --- PageView-based month switching via scroll ---
  late PageController _pageController;
  bool _isPageAnimating = false;
  bool _isPageTransitioning = false;
  DateTime? _lastPageChangeTime;

  // --- Cache ---
  late HeatmapColorScale _cachedColorScale;
  final Map<(int, int), List<List<DateTime>>> _weeksCache = {};

  TextStyle get _effectiveBaseTextStyle {
    return widget.textStyle ??
        widget.theme.textStyle ??
        const TextStyle(fontSize: 14.0);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMonth ?? DateTime.now();
    _currentYear = initial.year;
    _currentMonth = initial.month;

    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    );
    _animationController.forward();

    _pageController = PageController(initialPage: 1);
    _cachedColorScale = _computeColorScale();
  }

  @override
  void didUpdateWidget(CalendarHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorScale != widget.colorScale ||
        oldWidget.theme.heatmapGradientColors !=
            widget.theme.heatmapGradientColors) {
      _cachedColorScale = _computeColorScale();
    }
    if (oldWidget.data != widget.data) {
      _animationController.forward(from: 0);
      _removeTooltip();
      _weeksCache.clear();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(1);
      }
      setState(() => _hoveredDate = null);
    }
  }

  @override
  void dispose() {
    _removeTooltip();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Hover / Tooltip
  // ---------------------------------------------------------------------------

  void _handleHover(
    Offset localPosition,
    Size canvasSize,
    Offset globalPosition,
    int year,
    int month,
  ) {
    final weeks = _getWeeks(year, month);
    final hitDate = hitTestCalendarCell(
      localPosition: localPosition,
      size: canvasSize,
      weeks: weeks,
    );

    _mouseGlobalPosition = globalPosition;

    // If same cell, only update tooltip position (no setState needed)
    final isSameCell =
        _hoveredDate != null &&
        hitDate != null &&
        _hoveredDate!.year == hitDate.year &&
        _hoveredDate!.month == hitDate.month &&
        _hoveredDate!.day == hitDate.day;
    if (isSameCell) {
      if (widget.showTooltip) _updateTooltipPosition();
      return;
    }

    setState(() => _hoveredDate = hitDate);

    if (widget.showTooltip) {
      if (hitDate != null) {
        final value = widget.data.valueOf(hitDate);
        _showTooltip(date: hitDate, value: value);
      } else {
        _removeTooltip();
      }
    }
  }

  void _handleMouseExit() {
    setState(() => _hoveredDate = null);
    _removeTooltip();
  }

  void _handleTap(
    TapDownDetails details,
    Size canvasSize,
    int year,
    int month,
  ) {
    if (widget.onDateTap == null) return;

    final weeks = _getWeeks(year, month);
    final hitDate = hitTestCalendarCell(
      localPosition: details.localPosition,
      size: canvasSize,
      weeks: weeks,
    );
    if (hitDate == null) return;

    final value = widget.data.valueOf(hitDate);
    widget.onDateTap!(hitDate, value);
  }

  void _showTooltip({required DateTime date, required double? value}) {
    _removeTooltip();

    Color? cellColor;
    if (value != null) {
      final range = _effectiveValueMax - _effectiveValueMin;
      final normalized = range > 0 ? (value - _effectiveValueMin) / range : 0.5;
      cellColor = _cachedColorScale.colorAt(normalized);
    }

    _tooltipOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _CalendarTooltipPositioner(
          mouseGlobalPosition: _mouseGlobalPosition,
          child: widget.tooltipBuilder != null
              ? widget.tooltipBuilder!(overlayContext, date, value, cellColor)
              : _DefaultCalendarTooltip(
                  date: date,
                  value: value,
                  cellColor: cellColor,
                  theme: widget.theme,
                  unit: widget.unit,
                  unitPosition: widget.unitPosition,
                  valueScale: widget.valueScale,
                  useThousandsSeparator: widget.useThousandsSeparator,
                  baseTextStyle: _effectiveBaseTextStyle,
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

  // ---------------------------------------------------------------------------
  // Color scale / Value range
  // ---------------------------------------------------------------------------

  HeatmapColorScale _computeColorScale() {
    if (widget.colorScale != null) return widget.colorScale!;
    final colors = widget.theme.heatmapGradientColors;
    if (colors.isEmpty) {
      return HeatmapColorScale.fromColor(const Color(0xFF1D39C4));
    }
    if (colors.length == 1) {
      return HeatmapColorScale.fromColor(colors.first);
    }
    final stops = <(double, Color)>[];
    for (var i = 0; i < colors.length; i++) {
      stops.add((i / (colors.length - 1), colors[i]));
    }
    return HeatmapColorScale(colorStops: stops);
  }

  double get _effectiveValueMin => widget.valueMin ?? widget.data.minValue;
  double get _effectiveValueMax => widget.valueMax ?? widget.data.maxValue;

  int get _yearRangeStart => widget.yearRangeStart ?? _currentYear - 5;
  int get _yearRangeEnd => widget.yearRangeEnd ?? _currentYear + 5;

  // ---------------------------------------------------------------------------
  // Weeks cache
  // ---------------------------------------------------------------------------

  List<List<DateTime>> _getWeeks(int year, int month) {
    return _weeksCache.putIfAbsent((
      year,
      month,
    ), () => _buildWeeks(year, month));
  }

  // ---------------------------------------------------------------------------
  // Month offset calculation
  // ---------------------------------------------------------------------------

  (int, int) _monthAtOffset(int offset) {
    var y = _currentYear;
    var m = _currentMonth + offset;
    while (m > 12) {
      y += 1;
      m -= 12;
    }
    while (m < 1) {
      y -= 1;
      m += 12;
    }
    return (y, m);
  }

  // ---------------------------------------------------------------------------
  // PageView-based month switching via scroll
  // ---------------------------------------------------------------------------

  void _onPageChanged(int pageIndex) {
    if (pageIndex == 1) return;
    if (_isPageTransitioning) return;

    // Prevent rapid consecutive snaps: ignore if within 300ms of last page transition
    final now = DateTime.now();
    if (_lastPageChangeTime != null &&
        now.difference(_lastPageChangeTime!) <
            const Duration(milliseconds: 300)) {
      return;
    }
    _lastPageChangeTime = now;

    _isPageTransitioning = true;

    final offset = pageIndex - 1;
    final (year, month) = _monthAtOffset(offset);

    setState(() {
      _currentYear = year;
      _currentMonth = month;
    });
    _weeksCache.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(1);
      }
      _isPageTransitioning = false;
    });

    _animationController.value = 1.0;
    widget.onMonthChanged?.call(DateTime(year, month));
  }

  Widget _buildPageView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (!_isPageAnimating) {
            setState(() {
              _isPageAnimating = true;
              _hoveredDate = null;
            });
            _removeTooltip();
          }
        } else if (notification is ScrollEndNotification) {
          if (_isPageAnimating) {
            setState(() => _isPageAnimating = false);
          }
        }
        return true; // Completely block scroll propagation to parent
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: _onPageChanged,
        itemCount: 3,
        itemBuilder: (context, index) {
          final offset = index - 1;
          final (year, month) = _monthAtOffset(offset);
          final isCenterPage = (index == 1);

          return _buildCanvasPage(
            year: year,
            month: month,
            isCenterPage: isCenterPage,
          );
        },
      ),
    );
  }

  /// Builds a single month's canvas page.
  /// Applies fade-in animation only to the center page.
  Widget _buildCanvasPage({
    required int year,
    required int month,
    required bool isCenterPage,
  }) {
    final weeks = _getWeeks(year, month);

    Widget buildPainter(double animProgress) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return MouseRegion(
            cursor: (_hoveredDate != null && widget.onDateTap != null)
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onHover: _isPageAnimating
                ? null
                : (event) => _handleHover(
                    event.localPosition,
                    size,
                    event.position,
                    year,
                    month,
                  ),
            onExit: _isPageAnimating ? null : (_) => _handleMouseExit(),
            child: GestureDetector(
              onTapDown: _isPageAnimating
                  ? null
                  : (details) => _handleTap(details, size, year, month),
              child: CustomPaint(
                size: size,
                painter: CalendarMonthPainter(
                  year: year,
                  month: month,
                  weeks: weeks,
                  data: widget.data,
                  colorScale: _cachedColorScale,
                  valueMin: _effectiveValueMin,
                  valueMax: _effectiveValueMax,
                  theme: widget.theme,
                  baseTextStyle: _effectiveBaseTextStyle,
                  animationProgress: animProgress,
                  hoveredDate: _isPageAnimating ? null : _hoveredDate,
                ),
              ),
            ),
          );
        },
      );
    }

    if (isCenterPage) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (_, _) => buildPainter(_fadeAnimation.value),
      );
    }
    return buildPainter(1.0);
  }

  double _calculatePageViewHeight() {
    final cellMin = widget.cellRowMinHeight ?? 48.0;
    final currentWeeks = _getWeeks(_currentYear, _currentMonth);
    return cellMin * currentWeeks.length;
  }

  // ---------------------------------------------------------------------------
  // Month navigation via arrow buttons / selectors
  // ---------------------------------------------------------------------------

  void _navigateToMonth(int year, int month) {
    if (_isPageAnimating || _isPageTransitioning) return;
    if (month < 1) {
      year -= 1;
      month = 12;
    } else if (month > 12) {
      year += 1;
      month = 1;
    }
    _removeTooltip();
    setState(() {
      _currentYear = year;
      _currentMonth = month;
      _hoveredDate = null;
    });
    _weeksCache.clear();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(1);
    }
    _animationController.forward(from: 0);
    widget.onMonthChanged?.call(DateTime(year, month));
  }

  Widget? _buildLegend() {
    final position = widget.colorLegendPosition;
    if (position == null) return null;
    return _CalendarHeatmapColorLegend(
      colorScale: _cachedColorScale,
      valueMin: _effectiveValueMin,
      valueMax: _effectiveValueMax,
      theme: widget.theme,
      baseTextStyle: _effectiveBaseTextStyle,
      unit: widget.unit,
      unitPosition: widget.unitPosition,
      valueScale: widget.valueScale,
      useThousandsSeparator: widget.useThousandsSeparator,
      position: position,
      displayMinValue: widget.legendDisplayMinValue ?? 0.0,
    );
  }

  // ---------------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final legend = _buildLegend();
    final position = widget.colorLegendPosition;

    final pageView = SizedBox(
      height: _calculatePageViewHeight(),
      child: _buildPageView(),
    );

    final weekdayHeader = _CalendarHeatmapWeekdayHeader(
      theme: widget.theme,
      baseTextStyle: _effectiveBaseTextStyle,
    );

    // left/right: Wrap weekday header and grid together in Expanded,
    // placed side-by-side with the legend (aligning weekday labels and grid columns)
    final isLegendSide =
        legend != null &&
        (position == LegendPosition.left || position == LegendPosition.right);

    Widget gridArea;
    if (isLegendSide) {
      final calendarBody = Column(
        mainAxisSize: MainAxisSize.min,
        children: [weekdayHeader, pageView],
      );
      gridArea = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: position == LegendPosition.left
              ? [
                  legend,
                  const SizedBox(width: 12),
                  Expanded(child: calendarBody),
                ]
              : [
                  Expanded(child: calendarBody),
                  const SizedBox(width: 12),
                  legend,
                ],
        ),
      );
    } else {
      gridArea = pageView;
    }

    return Container(
      color: widget.theme.backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CalendarHeatmapHeader(
            year: _currentYear,
            month: _currentMonth,
            yearRangeStart: _yearRangeStart,
            yearRangeEnd: _yearRangeEnd,
            baseTextStyle: _effectiveBaseTextStyle,
            theme: widget.theme,
            onPreviousYear: () =>
                _navigateToMonth(_currentYear - 1, _currentMonth),
            onNextYear: () => _navigateToMonth(_currentYear + 1, _currentMonth),
            onPreviousMonth: () =>
                _navigateToMonth(_currentYear, _currentMonth - 1),
            onNextMonth: () =>
                _navigateToMonth(_currentYear, _currentMonth + 1),
            onYearChanged: (year) => _navigateToMonth(year, _currentMonth),
            onMonthChanged: (month) => _navigateToMonth(_currentYear, month),
          ),
          const SizedBox(height: 8),
          if (legend != null && position == LegendPosition.top) legend,
          if (!isLegendSide) weekdayHeader,
          gridArea,
          if (legend != null && position == LegendPosition.bottom) legend,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: Navigation arrows + year/month selectors
// ---------------------------------------------------------------------------

String _monthAbbr(int month) => '$month';

class _CalendarHeatmapHeader extends StatelessWidget {
  final int year;
  final int month;
  final int yearRangeStart;
  final int yearRangeEnd;
  final TextStyle baseTextStyle;
  final ChartTheme theme;
  final VoidCallback onPreviousYear;
  final VoidCallback onNextYear;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMonthChanged;

  const _CalendarHeatmapHeader({
    required this.year,
    required this.month,
    required this.yearRangeStart,
    required this.yearRangeEnd,
    required this.baseTextStyle,
    required this.theme,
    required this.onPreviousYear,
    required this.onNextYear,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = theme.calendarNavigationColor;
    final iconSize = (baseTextStyle.fontSize ?? 14.0) + 8;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // << Go back 1 year
        _NavigationButton(
          icon: Icons.keyboard_double_arrow_left,
          color: iconColor,
          size: iconSize,
          onTap: onPreviousYear,
          semanticLabel: 'Previous year',
        ),
        // < Go back 1 month
        _NavigationButton(
          icon: Icons.chevron_left,
          color: iconColor,
          size: iconSize,
          onTap: onPreviousMonth,
          semanticLabel: 'Previous month',
        ),
        const SizedBox(width: 4),

        // Year selector
        _YearMonthSelector(
          label: '$year',
          items: [
            for (var y = yearRangeStart; y <= yearRangeEnd; y++)
              (label: '$y', value: y),
          ],
          selectedValue: year,
          onChanged: onYearChanged,
          baseTextStyle: baseTextStyle,
          theme: theme,
        ),
        const SizedBox(width: 4),

        // Month selector
        _YearMonthSelector(
          label: _monthAbbr(month),
          items: [
            for (var m = 1; m <= 12; m++) (label: _monthAbbr(m), value: m),
          ],
          selectedValue: month,
          onChanged: onMonthChanged,
          baseTextStyle: baseTextStyle,
          theme: theme,
        ),

        const SizedBox(width: 4),
        // > Go forward 1 month
        _NavigationButton(
          icon: Icons.chevron_right,
          color: iconColor,
          size: iconSize,
          onTap: onNextMonth,
          semanticLabel: 'Next month',
        ),
        // >> Go forward 1 year
        _NavigationButton(
          icon: Icons.keyboard_double_arrow_right,
          color: iconColor,
          size: iconSize,
          onTap: onNextYear,
          semanticLabel: 'Next year',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation button (arrow)
// ---------------------------------------------------------------------------

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final String semanticLabel;

  const _NavigationButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Year/month selector (shows dropdown on tap)
// ---------------------------------------------------------------------------

class _YearMonthSelector extends StatefulWidget {
  final String label;
  final List<({String label, int value})> items;
  final int selectedValue;
  final ValueChanged<int> onChanged;
  final TextStyle baseTextStyle;
  final ChartTheme theme;

  const _YearMonthSelector({
    required this.label,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    required this.baseTextStyle,
    required this.theme,
  });

  @override
  State<_YearMonthSelector> createState() => _YearMonthSelectorState();
}

class _YearMonthSelectorState extends State<_YearMonthSelector> {
  final _buttonKey = GlobalKey();
  OverlayEntry? _dropdownOverlay;

  bool get _isOpen => _dropdownOverlay != null;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    _dropdownOverlay = OverlayEntry(
      builder: (context) {
        return _SelectorDropdown(
          buttonPosition: buttonPosition,
          buttonSize: buttonSize,
          items: widget.items,
          selectedValue: widget.selectedValue,
          baseTextStyle: widget.baseTextStyle,
          theme: widget.theme,
          onSelected: (value) {
            _closeDropdown();
            widget.onChanged(value);
          },
          onDismiss: _closeDropdown,
        );
      },
    );

    Overlay.of(context).insert(_dropdownOverlay!);
    setState(() {}); // Toggle dropdown arrow icon direction
  }

  void _closeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Cannot call setState during dispose, so only remove the OverlayEntry
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: widget.theme.gridColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: widget.baseTextStyle.fontFamily,
                fontSize: widget.baseTextStyle.fontSize ?? 14.0,
                color: widget.theme.calendarSelectorTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              size: (widget.baseTextStyle.fontSize ?? 14.0) + 4,
              color: widget.theme.calendarSelectorTextColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selector dropdown overlay
// ---------------------------------------------------------------------------

class _SelectorDropdown extends StatelessWidget {
  final Offset buttonPosition;
  final Size buttonSize;
  final List<({String label, int value})> items;
  final int selectedValue;
  final TextStyle baseTextStyle;
  final ChartTheme theme;
  final ValueChanged<int> onSelected;
  final VoidCallback onDismiss;

  const _SelectorDropdown({
    required this.buttonPosition,
    required this.buttonSize,
    required this.items,
    required this.selectedValue,
    required this.baseTextStyle,
    required this.theme,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final itemHeight = (baseTextStyle.fontSize ?? 14.0) + 20;
    // Max dropdown height: limited to 6 items
    final maxDropdownHeight = itemHeight * 6;

    return Stack(
      children: [
        // Full-screen barrier: dismiss on tap
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        // Dropdown body
        Positioned(
          left: buttonPosition.dx,
          top: buttonPosition.dy + buttonSize.height + 4,
          width: buttonSize.width,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            color: theme.calendarSelectorDropdownColor,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxDropdownHeight),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: items.length,
                itemExtent: itemHeight,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item.value == selectedValue;
                  return InkWell(
                    onTap: () => onSelected(item.value),
                    child: Container(
                      alignment: Alignment.center,
                      color: isSelected
                          ? theme.calendarSelectorSelectedColor
                          : null,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: baseTextStyle.fontFamily,
                          fontSize: baseTextStyle.fontSize ?? 14.0,
                          color: theme.calendarSelectorTextColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weekday header (fixed display outside of PageView)
// ---------------------------------------------------------------------------

class _CalendarHeatmapWeekdayHeader extends StatelessWidget {
  final ChartTheme theme;
  final TextStyle baseTextStyle;

  const _CalendarHeatmapWeekdayHeader({
    required this.theme,
    required this.baseTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final side = BorderSide(color: theme.gridColor, width: 0.5);

    return Table(
      defaultColumnWidth: const FlexColumnWidth(1),
      // No bottom border -- the data Table's top border serves as the boundary
      border: TableBorder(
        top: side,
        left: side,
        right: side,
        verticalInside: side,
      ),
      children: [
        TableRow(
          children: weekdayLabels.asMap().entries.map((entry) {
            final Color headerColor;
            if (entry.key == 0) {
              headerColor =
                  theme.calendarWeekdayHeaderSundayColor ??
                  theme.calendarSundayColor;
            } else if (entry.key == 6) {
              headerColor =
                  theme.calendarWeekdayHeaderSaturdayColor ??
                  theme.calendarSaturdayColor;
            } else {
              headerColor = theme.calendarWeekdayHeaderColor;
            }
            return Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontFamily: baseTextStyle.fontFamily,
                  fontSize: baseTextStyle.fontSize ?? 14.0,
                  color: headerColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Color legend bar
// ---------------------------------------------------------------------------

/// Color legend bar for the calendar heatmap.
/// Switches between horizontal (top/bottom) and vertical (left/right) layout based on [position].
class _CalendarHeatmapColorLegend extends StatelessWidget {
  final HeatmapColorScale colorScale;
  final double valueMin;
  final double valueMax;
  final ChartTheme theme;
  final TextStyle baseTextStyle;
  final String? unit;
  final UnitPosition unitPosition;
  final ValueScale valueScale;
  final bool useThousandsSeparator;
  final LegendPosition position;
  final double displayMinValue;

  const _CalendarHeatmapColorLegend({
    required this.colorScale,
    required this.valueMin,
    required this.valueMax,
    required this.theme,
    required this.baseTextStyle,
    required this.unit,
    required this.unitPosition,
    required this.valueScale,
    required this.useThousandsSeparator,
    required this.position,
    required this.displayMinValue,
  });

  @override
  Widget build(BuildContext context) {
    final isHorizontal =
        position == LegendPosition.top || position == LegendPosition.bottom;
    return isHorizontal ? _buildHorizontal() : _buildVertical();
  }

  Widget _buildHorizontal() {
    final legendHeight = theme.heatmapLegendHeightPx;
    final colors = colorScale.colorStops.map((s) => s.$2).toList();
    final stops = colorScale.colorStops.map((s) => s.$1).toList();
    final labelStyle = baseTextStyle.merge(theme.labelStyle);

    return Padding(
      padding: EdgeInsets.only(
        top: position == LegendPosition.bottom ? 8 : 0,
        bottom: position == LegendPosition.top ? 8 : 0,
      ),
      child: Row(
        children: [
          Text(_formatValue(displayMinValue), style: labelStyle),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: legendHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(legendHeight / 2),
                gradient: LinearGradient(colors: colors, stops: stops),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(_formatValue(valueMax), style: labelStyle),
        ],
      ),
    );
  }

  Widget _buildVertical() {
    final legendWidth = theme.heatmapLegendHeightPx;
    // Vertical: max at top, min at bottom (same as typical heatmaps)
    final colors = colorScale.colorStops
        .map((s) => s.$2)
        .toList()
        .reversed
        .toList();
    final stops = colorScale.colorStops
        .map((s) => 1.0 - s.$1)
        .toList()
        .reversed
        .toList();
    final labelStyle = baseTextStyle.merge(theme.labelStyle);

    return Column(
      children: [
        Text(_formatValue(valueMax), style: labelStyle),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: legendWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(legendWidth / 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
                stops: stops,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(_formatValue(displayMinValue), style: labelStyle),
      ],
    );
  }

  String _formatValue(double value) {
    return formatChartValue(
      value,
      unit: unit,
      unitPosition: unitPosition,
      valueScale: valueScale,
      useThousandsSeparator: useThousandsSeparator,
    );
  }
}

/// Returns calendar dates for the given year/month, grouped by week.
/// Weeks start on Sunday. Includes overflow days from previous/next months.
List<List<DateTime>> _buildWeeks(int year, int month) {
  final firstDayOfMonth = DateTime(year, month, 1);
  final lastDayOfMonth = DateTime(year, month + 1, 0);

  // DateTime.weekday: Monday=1, Sunday=7 -> Convert to Sunday-start
  final startOffset = firstDayOfMonth.weekday % 7;
  final totalDays = lastDayOfMonth.day;

  final dates = <DateTime>[];

  // Overflow days from previous month
  for (var i = startOffset - 1; i >= 0; i--) {
    dates.add(firstDayOfMonth.subtract(Duration(days: i + 1)));
  }

  // Days of the current month
  for (var d = 1; d <= totalDays; d++) {
    dates.add(DateTime(year, month, d));
  }

  // Overflow days from next month (until total is a multiple of 7)
  var nextDay = 1;
  while (dates.length % 7 != 0) {
    dates.add(DateTime(year, month + 1, nextDay++));
  }

  // Split into groups of 7 days
  final weeks = <List<DateTime>>[];
  for (var i = 0; i < dates.length; i += 7) {
    weeks.add(dates.sublist(i, i + 7));
  }
  return weeks;
}

// ---------------------------------------------------------------------------
// Tooltip positioning
// ---------------------------------------------------------------------------

/// Overlay widget that positions a tooltip at the mouse cursor location.
class _CalendarTooltipPositioner extends StatelessWidget {
  final Offset mouseGlobalPosition;
  final Widget child;

  static const _cursorOffsetX = 12.0;
  static const _cursorOffsetY = 16.0;

  const _CalendarTooltipPositioner({
    required this.mouseGlobalPosition,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return CustomSingleChildLayout(
      delegate: _CalendarTooltipLayoutDelegate(
        mousePosition: mouseGlobalPosition,
        cursorOffsetX: _cursorOffsetX,
        cursorOffsetY: _cursorOffsetY,
        screenSize: screenSize,
      ),
      child: child,
    );
  }
}

class _CalendarTooltipLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset mousePosition;
  final double cursorOffsetX;
  final double cursorOffsetY;
  final Size screenSize;

  _CalendarTooltipLayoutDelegate({
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
  bool shouldRelayout(_CalendarTooltipLayoutDelegate oldDelegate) {
    return mousePosition != oldDelegate.mousePosition ||
        screenSize != oldDelegate.screenSize;
  }
}

// ---------------------------------------------------------------------------
// Default tooltip
// ---------------------------------------------------------------------------

/// Default tooltip for the calendar heatmap.
/// Displays date + colored square + value. Shows "No data" when there is no data.
class _DefaultCalendarTooltip extends StatelessWidget {
  final DateTime date;
  final double? value;
  final Color? cellColor;
  final ChartTheme theme;
  final String? unit;
  final UnitPosition unitPosition;
  final ValueScale valueScale;
  final bool useThousandsSeparator;
  final TextStyle? baseTextStyle;

  const _DefaultCalendarTooltip({
    required this.date,
    required this.value,
    required this.cellColor,
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
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

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
          Text(dateStr, style: _resolveStyle(theme.tooltipLabelStyle)),
          const SizedBox(height: 4),
          if (value != null && cellColor != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatChartValue(
                    value!,
                    unit: unit,
                    unitPosition: unitPosition,
                    valueScale: valueScale,
                    decimalPlaces: 1,
                    useThousandsSeparator: useThousandsSeparator,
                  ),
                  style: _resolveStyle(
                    theme.tooltipValueStyle,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            )
          else
            Text('No data', style: _resolveStyle(theme.tooltipValueStyle)),
        ],
      ),
    );
  }
}