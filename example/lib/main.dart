import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xtal_charts/xtal_charts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xtal_charts Demo',
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const SalesDashboardDemoPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Main page
// ---------------------------------------------------------------------------

class SalesDashboardDemoPage extends StatefulWidget {
  const SalesDashboardDemoPage({super.key});

  @override
  State<SalesDashboardDemoPage> createState() =>
      _SalesDashboardDemoPageState();
}

class _SalesDashboardDemoPageState extends State<SalesDashboardDemoPage> {
  ChartTreeNode? _sunburstData;
  bool _enableDepthTint = true;
  List<ChartSeries>? _monthlyRevenueSeries;
  List<ChartSeries>? _channelBarSeries;
  List<ChartSeries>? _monthlyRegionColumnSeries;
  HeatmapData? _heatmapData;
  List<ChartSeries>? _dualAxesLeftSeries;
  List<ChartSeries>? _dualAxesRightSeries;
  List<ChartSeries>? _regionRevenueHorizontalBarSeries;
  CalendarHeatmapData? _calendarHeatmapData;
  String? _errorMessage;
  bool _isLoading = true;

  /// Value scale for the horizontal bar chart.
  ValueScale _horizontalBarValueScale = ValueScale.divideBy1000;

  String get _horizontalBarUnit => r'$';

  @override
  void initState() {
    super.initState();
    _loadCsvAndBuildCharts();
  }

  Future<void> _loadCsvAndBuildCharts() async {
    try {
      final records = await _loadSalesRecords();

      final dualAxes = _buildDualAxesData(records);

      setState(() {
        _sunburstData = _buildSunburstTree(records);
        _monthlyRevenueSeries = _buildMonthlyRevenueSeries(records);
        _channelBarSeries = _buildChannelBarSeries(records);
        _monthlyRegionColumnSeries = _buildMonthlyRegionColumnSeries(records);
        _heatmapData = _buildRegionCategoryHeatmap(records);
        _dualAxesLeftSeries = dualAxes.left;
        _dualAxesRightSeries = dualAxes.right;
        _regionRevenueHorizontalBarSeries =
            _buildRegionRevenueHorizontalBarSeries(records);
        _calendarHeatmapData = _buildCalendarHeatmapData(records);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Loads the CSV asset and converts it into a list of header-keyed maps.
  Future<List<Map<String, String>>> _loadSalesRecords() async {
    final csvString = await rootBundle.loadString('assets/sample_data.csv');
    final rows = const CsvToListConverter(eol: '\n').convert(csvString);
    if (rows.isEmpty) return [];

    final header = rows[0].map((e) => e.toString()).toList();

    return [
      for (var i = 1; i < rows.length; i++)
        {
          for (var j = 0; j < header.length && j < rows[i].length; j++)
            header[j]: rows[i][j].toString(),
        },
    ];
  }

  // -----------------------------------------------------------------------
  // Field extraction helpers
  // -----------------------------------------------------------------------

  /// Returns the region for this record.
  String _extractRegion(Map<String, String> record) {
    return record['region'] ?? 'Unknown';
  }

  /// Returns the sales channel(s) for this record.
  List<String> _extractChannels(Map<String, String> record) {
    final raw = record['channel'] ?? '';
    if (raw.isEmpty) return ['Unknown'];
    return raw.split(RegExp(r',\s*')).where((s) => s.isNotEmpty).toList();
  }

  /// Returns the revenue amount for this record.
  double _extractRevenue(Map<String, String> record) {
    final raw = record['revenue'] ?? '';
    if (raw.isEmpty) return 0;
    return double.tryParse(raw) ?? 0;
  }

  /// Returns the "YYYY-MM" portion of the order date.
  String _extractYearMonth(Map<String, String> record) {
    final date = record['order_date'] ?? '';
    if (date.length >= 7) return date.substring(0, 7);
    return 'Unknown';
  }

  // -----------------------------------------------------------------------
  // Chart data builders
  // -----------------------------------------------------------------------

  /// Sunburst: Total -> Region -> Channel -> order count
  ChartTreeNode _buildSunburstTree(List<Map<String, String>> records) {
    final countByRegionAndChannel = <String, Map<String, int>>{};

    for (final r in records) {
      final region = _extractRegion(r);
      for (final channel in _extractChannels(r)) {
        countByRegionAndChannel
            .putIfAbsent(region, () => {})
            .update(channel, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // Sort regions by total count (descending)
    final sortedRegions = countByRegionAndChannel.entries.toList()
      ..sort((a, b) {
        final totalA = a.value.values.fold(0, (s, v) => s + v);
        final totalB = b.value.values.fold(0, (s, v) => s + v);
        return totalB.compareTo(totalA);
      });

    final regionNodes = <ChartTreeNode>[
      for (final region in sortedRegions)
        ChartTreeNode(
          name: region.key,
          children:
              (region.value.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map((e) => ChartTreeNode(name: e.key, value: e.value))
                  .toList(),
        ),
    ];

    return ChartTreeNode(name: 'Total', children: regionNodes);
  }

  /// Area: monthly revenue trend (raw dollar values)
  List<ChartSeries> _buildMonthlyRevenueSeries(
    List<Map<String, String>> records,
  ) {
    final revenueByMonth = <String, double>{};
    for (final r in records) {
      final month = _extractYearMonth(r);
      final revenue = _extractRevenue(r);
      revenueByMonth.update(
        month,
        (v) => v + revenue,
        ifAbsent: () => revenue,
      );
    }

    final sortedMonths = revenueByMonth.keys.toList()..sort();

    return [
      ChartSeries(
        name: 'Total Revenue',
        color: const Color(0xFF5B8FF9),
        dataPoints: [
          for (var i = 0; i < sortedMonths.length; i++)
            ChartDataPoint(
              x: i.toDouble(),
              y: revenueByMonth[sortedMonths[i]]!,
              label: sortedMonths[i],
            ),
        ],
      ),
    ];
  }

  /// Bar: total revenue per channel (raw dollar values).
  /// When a record has multiple channels, the revenue is split equally.
  List<ChartSeries> _buildChannelBarSeries(
    List<Map<String, String>> records,
  ) {
    final revenueByChannel = <String, double>{};

    for (final r in records) {
      final channels = _extractChannels(r);
      final revenuePerChannel = _extractRevenue(r) / channels.length;
      for (final channel in channels) {
        revenueByChannel.update(
          channel,
          (v) => v + revenuePerChannel,
          ifAbsent: () => revenuePerChannel,
        );
      }
    }

    // Sort by revenue (descending)
    final sorted = revenueByChannel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      ChartSeries(
        name: 'Revenue',
        color: const Color(0xFFF6BD16),
        dataPoints: [
          for (var i = 0; i < sorted.length; i++)
            ChartDataPoint(
              x: i.toDouble(),
              y: sorted[i].value,
              label: sorted[i].key,
            ),
        ],
      ),
    ];
  }

  /// Column (Stacked): order count by month x region
  List<ChartSeries> _buildMonthlyRegionColumnSeries(
    List<Map<String, String>> records,
  ) {
    final countByMonthAndRegion = <String, Map<String, int>>{};
    final totalByRegion = <String, int>{};

    for (final r in records) {
      final month = _extractYearMonth(r);
      final region = _extractRegion(r);
      countByMonthAndRegion
          .putIfAbsent(month, () => {})
          .update(region, (v) => v + 1, ifAbsent: () => 1);
      totalByRegion.update(region, (v) => v + 1, ifAbsent: () => 1);
    }

    final sortedMonths = countByMonthAndRegion.keys.toList()..sort();

    // Sort regions by total count (descending)
    final sortedRegions = totalByRegion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const regionColors = [
      Color(0xFF5B8FF9),
      Color(0xFF5AD8A6),
      Color(0xFFF6BD16),
      Color(0xFFE86452),
      Color(0xFF6DC8EC),
      Color(0xFF945FB9),
      Color(0xFFFF9845),
      Color(0xFF1E9493),
      Color(0xFFFF99C3),
    ];

    return [
      for (var d = 0; d < sortedRegions.length; d++)
        ChartSeries(
          name: sortedRegions[d].key,
          color: regionColors[d % regionColors.length],
          dataPoints: [
            for (var m = 0; m < sortedMonths.length; m++)
              ChartDataPoint(
                x: m.toDouble(),
                y:
                    (countByMonthAndRegion[sortedMonths[m]]?[sortedRegions[d]
                                .key] ??
                            0)
                        .toDouble(),
                label: sortedMonths[m],
              ),
          ],
        ),
    ];
  }

  /// Heatmap: rows = regions, columns = product categories, values = order count
  HeatmapData _buildRegionCategoryHeatmap(List<Map<String, String>> records) {
    final countByRegionAndCategory = <String, Map<String, int>>{};
    final totalByRegion = <String, int>{};
    final totalByCategory = <String, int>{};

    for (final r in records) {
      final region = _extractRegion(r);
      final category = r['category'] ?? 'Unknown';
      countByRegionAndCategory
          .putIfAbsent(region, () => {})
          .update(category, (v) => v + 1, ifAbsent: () => 1);
      totalByRegion.update(region, (v) => v + 1, ifAbsent: () => 1);
      totalByCategory.update(category, (v) => v + 1, ifAbsent: () => 1);
    }

    // Sort by frequency (descending)
    final sortedRegions = totalByRegion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedCategories = totalByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final xCategories = sortedCategories.map((e) => e.key).toList();
    final yCategories = sortedRegions.map((e) => e.key).toList();

    final values = <List<double?>>[
      for (final region in yCategories)
        [
          for (final category in xCategories)
            countByRegionAndCategory[region]?[category]?.toDouble(),
        ],
    ];

    return HeatmapData(
      xCategories: xCategories,
      yCategories: yCategories,
      values: values,
    );
  }

  /// DualAxes: left axis (column) = monthly order count,
  /// right axis (line) = monthly average revenue per order
  ({List<ChartSeries> left, List<ChartSeries> right}) _buildDualAxesData(
    List<Map<String, String>> records,
  ) {
    final countByMonth = <String, int>{};
    final revenueByMonth = <String, double>{};

    for (final r in records) {
      final month = _extractYearMonth(r);
      final revenue = _extractRevenue(r);
      countByMonth.update(month, (v) => v + 1, ifAbsent: () => 1);
      revenueByMonth.update(
        month,
        (v) => v + revenue,
        ifAbsent: () => revenue,
      );
    }

    final sortedMonths = countByMonth.keys.toList()..sort();

    final countPoints = <ChartDataPoint>[];
    final avgRevenuePoints = <ChartDataPoint>[];

    for (var i = 0; i < sortedMonths.length; i++) {
      final month = sortedMonths[i];
      final count = countByMonth[month]!;
      final totalRevenue = revenueByMonth[month]!;
      final avgRevenue = count > 0 ? totalRevenue / count : 0.0;

      countPoints.add(
        ChartDataPoint(x: i.toDouble(), y: count.toDouble(), label: month),
      );
      avgRevenuePoints.add(
        ChartDataPoint(x: i.toDouble(), y: avgRevenue, label: month),
      );
    }

    return (
      left: [
        ChartSeries(
          name: 'Orders',
          color: const Color(0xFF5B8FF9),
          dataPoints: countPoints,
        ),
      ],
      right: [
        ChartSeries(
          name: 'Avg. Revenue',
          color: const Color(0xFFF6BD16),
          dataPoints: avgRevenuePoints,
        ),
      ],
    );
  }

  /// Horizontal Bar: total revenue per region (raw dollar values).
  /// Sorted by revenue (descending) with distinct colors.
  List<ChartSeries> _buildRegionRevenueHorizontalBarSeries(
    List<Map<String, String>> records,
  ) {
    final revenueByRegion = <String, double>{};
    final countByRegion = <String, int>{};

    for (final r in records) {
      final region = _extractRegion(r);
      final revenue = _extractRevenue(r);
      revenueByRegion.update(
        region,
        (v) => v + revenue,
        ifAbsent: () => revenue,
      );
      countByRegion.update(region, (v) => v + 1, ifAbsent: () => 1);
    }

    // Sort by revenue (descending)
    final sorted = revenueByRegion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const barColors = [
      Color(0xFF5B8FF9),
      Color(0xFF5AD8A6),
      Color(0xFFF6BD16),
      Color(0xFFE86452),
      Color(0xFF6DC8EC),
      Color(0xFF945FB9),
      Color(0xFFFF9845),
      Color(0xFF1E9493),
      Color(0xFFFF99C3),
    ];

    return [
      for (var i = 0; i < sorted.length; i++)
        ChartSeries(
          name: '${sorted[i].key} (${countByRegion[sorted[i].key]} orders)',
          color: barColors[i % barColors.length],
          dataPoints: [ChartDataPoint(x: 0, y: sorted[i].value)],
        ),
    ];
  }

  /// Calendar Heatmap: daily order count (normalized by date)
  CalendarHeatmapData _buildCalendarHeatmapData(
    List<Map<String, String>> records,
  ) {
    final countByDate = <DateTime, double>{};
    for (final r in records) {
      final raw = r['order_date'] ?? '';
      if (raw.length < 10) continue;
      final date = DateTime.tryParse(raw.substring(0, 10));
      if (date == null) continue;
      final key = DateTime(date.year, date.month, date.day);
      countByDate.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    return CalendarHeatmapData(values: countByDate);
  }

  // -----------------------------------------------------------------------
  // UI
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Sales Analytics Demo')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          'Error: $_errorMessage',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Sunburst ---
          if (_sunburstData != null && _sunburstData!.children.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Sunburst - Sales Channel Breakdown by Region',
            ),
            Row(
              children: [
                const Text('Auto-coloring (2nd-level gradient)'),
                const SizedBox(width: 8),
                Switch(
                  value: _enableDepthTint,
                  onChanged: (v) => setState(() => _enableDepthTint = v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 500,
              child: SunburstChart(
                data: _sunburstData!,
                theme: ChartTheme(
                  enableSunburstDepthTint: _enableDepthTint,
                  calendarWeekendCellColor: Colors.white,
                ),
                visibleDepth: 3,
                innerRadiusRatio: 0.25,
                showLegend: true,
                legendPosition: LegendPosition.bottom,
                onSegmentTap: (node, depth) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${node.name}: ${node.totalValue} orders',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- Area ---
          if (_monthlyRevenueSeries != null &&
              _monthlyRevenueSeries!.isNotEmpty) ...[
            const _SectionHeader(title: 'Area - Monthly Revenue Trend'),
            SizedBox(
              height: 350,
              child: AreaChart(
                seriesList: _monthlyRevenueSeries!,
                theme: ChartTheme.defaultTheme,
                xAxisTitle: 'Month',
                yAxisTitle: 'Revenue',
                unit: r'$',
                unitPosition: UnitPosition.prefix,
                valueScale: ValueScale.divideBy1000,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- Bar ---
          if (_channelBarSeries != null && _channelBarSeries!.isNotEmpty) ...[
            const _SectionHeader(title: 'Bar - Revenue by Channel'),
            SizedBox(
              height: 350,
              child: BarChart(
                seriesList: _channelBarSeries!,
                theme: ChartTheme.defaultTheme,
                xAxisTitle: 'Channel',
                yAxisTitle: 'Revenue',
                unit: r'$',
                unitPosition: UnitPosition.prefix,
                valueScale: ValueScale.divideBy1000,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- Horizontal Bar ---
          if (_regionRevenueHorizontalBarSeries != null &&
              _regionRevenueHorizontalBarSeries!.isNotEmpty) ...[
            const _SectionHeader(title: 'Horizontal Bar - Revenue by Region'),
            Row(
              children: [
                const Text(
                  'Scale:',
                  style: TextStyle(color: Colors.black87, fontSize: 13),
                ),
                const SizedBox(width: 8),
                SegmentedButton<ValueScale>(
                  segments: const [
                    ButtonSegment(
                      value: ValueScale.none,
                      label: Text(r'$'),
                    ),
                    ButtonSegment(
                      value: ValueScale.divideBy1000,
                      label: Text(r'$K'),
                    ),
                    ButtonSegment(
                      value: ValueScale.divideBy10000,
                      label: Text(r'$10K'),
                    ),
                  ],
                  selected: {_horizontalBarValueScale},
                  onSelectionChanged: (selected) {
                    setState(() => _horizontalBarValueScale = selected.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: HorizontalBarChart(
                seriesList: _regionRevenueHorizontalBarSeries!,
                theme: ChartTheme.defaultTheme,
                unit: _horizontalBarUnit,
                unitPosition: UnitPosition.prefix,
                valueScale: _horizontalBarValueScale,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- Bar (axis labels hidden) ---
          if (_channelBarSeries != null && _channelBarSeries!.isNotEmpty) ...[
            const _SectionHeader(
              title:
                  'Bar - Axis Labels Hidden (showXAxisLabels / showYAxisLabels: false)',
            ),
            SizedBox(
              height: 350,
              child: BarChart(
                seriesList: _channelBarSeries!,
                theme: const ChartTheme(
                  showXAxisLabels: false,
                  showYAxisLabels: false,
                ),
                unit: r'$',
                unitPosition: UnitPosition.prefix,
                valueScale: ValueScale.divideBy1000,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- Column (Stacked) ---
          if (_monthlyRegionColumnSeries != null &&
              _monthlyRegionColumnSeries!.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Column (Stacked) - Orders by Month & Region',
            ),
            SizedBox(
              height: 350,
              child: ColumnChart(
                seriesList: _monthlyRegionColumnSeries!,
                mode: ColumnMode.stacked,
                theme: ChartTheme.defaultTheme,
                xAxisTitle: 'Month',
                yAxisTitle: 'Orders',
                unit: '',
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- Heatmap ---
          if (_heatmapData != null &&
              _heatmapData!.xCount > 0 &&
              _heatmapData!.yCount > 0) ...[
            const _SectionHeader(
              title: 'Heatmap - Orders by Region x Category',
            ),
            SizedBox(
              height: 300,
              child: HeatmapChart(
                data: _heatmapData!,
                theme: ChartTheme.defaultTheme,
                colorLegendPosition: LegendPosition.right,
                xAxisTitle: 'Category',
                yAxisTitle: 'Region',
                unit: '',
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- DualAxes ---
          if (_dualAxesLeftSeries != null &&
              _dualAxesLeftSeries!.isNotEmpty &&
              _dualAxesRightSeries != null &&
              _dualAxesRightSeries!.isNotEmpty) ...[
            const _SectionHeader(
              title: 'DualAxes - Monthly Orders x Avg. Revenue',
            ),
            SizedBox(
              height: 350,
              child: DualAxesChart(
                leftSeriesList: _dualAxesLeftSeries!,
                rightSeriesList: _dualAxesRightSeries!,
                leftChartType: DualAxesChartType.column,
                rightChartType: DualAxesChartType.line,
                theme: ChartTheme.defaultTheme,
                xAxisTitle: 'Month',
                leftYAxisTitle: 'Orders',
                leftUnit: '',
                rightYAxisTitle: 'Avg. Revenue',
                rightUnit: r'$',
                rightUnitPosition: UnitPosition.prefix,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // --- Calendar Heatmap ---
          if (_calendarHeatmapData != null) ...[
            const _SectionHeader(title: 'Calendar Heatmap - Daily Orders'),
            CalendarHeatmap(
              data: _calendarHeatmapData!,
              theme: ChartTheme(
                calendarCellBorderRadiusPx: 0,
                calendarWeekendCellColor: Colors.white,
                textStyle: TextStyle(fontSize: 16),
              ),
              initialMonth: DateTime(2026, 2),
              cellRowMinHeight: 100,
              onDateTap: (date, value) {
                final count = value?.toInt() ?? 0;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${date.year}/${date.month}/${date.day}: $count orders',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              colorScale: HeatmapColorScale.fromColor(Colors.red),
              colorLegendPosition: LegendPosition.right,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}
