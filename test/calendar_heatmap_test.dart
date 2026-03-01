import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtal_chart/xtal_chart.dart';

/// Test heatmap data for December 2025.
CalendarHeatmapData _sampleData() => CalendarHeatmapData(values: {
      DateTime(2025, 12, 1): 5,
      DateTime(2025, 12, 5): 10,
      DateTime(2025, 12, 10): 20,
      DateTime(2025, 12, 15): 30,
      DateTime(2025, 12, 20): 15,
      DateTime(2025, 12, 25): 25,
      DateTime(2025, 12, 31): 8,
    });

/// Empty data.
CalendarHeatmapData _emptyData() =>
    const CalendarHeatmapData(values: <DateTime, double>{});

/// Test helper: wraps a widget in MaterialApp + Scaffold.
Widget _wrapInApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

/// Test helper: groups calendar dates by week for the given year/month.
/// Same logic as _buildWeeks() in calendar_heatmap.dart.
List<List<DateTime>> _buildWeeksForTest(int year, int month) {
  final firstDayOfMonth = DateTime(year, month, 1);
  final lastDayOfMonth = DateTime(year, month + 1, 0);
  final startOffset = firstDayOfMonth.weekday % 7;
  final totalDays = lastDayOfMonth.day;
  final dates = <DateTime>[];

  for (var i = startOffset - 1; i >= 0; i--) {
    dates.add(firstDayOfMonth.subtract(Duration(days: i + 1)));
  }
  for (var d = 1; d <= totalDays; d++) {
    dates.add(DateTime(year, month, d));
  }
  var nextDay = 1;
  while (dates.length % 7 != 0) {
    dates.add(DateTime(year, month + 1, nextDay++));
  }
  final weeks = <List<DateTime>>[];
  for (var i = 0; i < dates.length; i += 7) {
    weeks.add(dates.sublist(i, i + 7));
  }
  return weeks;
}

/// Test helper: calculates the global center coordinate of a cell for the given date.
/// Computed from the RenderBox of the CustomPaint inside PageView.
Offset _cellGlobalCenter(
  WidgetTester tester,
  DateTime date,
  int year,
  int month,
) {
  final weeks = _buildWeeksForTest(year, month);

  // Find CustomPaint inside PageView
  final customPaintFinder = find.byType(CustomPaint);
  // Among multiple matches, find the one with CalendarMonthPainter
  final candidates = customPaintFinder.evaluate().where((element) {
    final widget = element.widget;
    if (widget is CustomPaint && widget.painter is CalendarMonthPainter) {
      final painter = widget.painter! as CalendarMonthPainter;
      return painter.year == year && painter.month == month;
    }
    return false;
  }).toList();

  if (candidates.isEmpty) {
    throw StateError('CalendarMonthPainter for $year/$month not found');
  }

  final renderBox = candidates.first.renderObject! as RenderBox;
  final size = renderBox.size;
  final cellWidth = size.width / 7;
  final cellHeight = size.height / weeks.length;

  for (var row = 0; row < weeks.length; row++) {
    for (var col = 0; col < 7; col++) {
      final d = weeks[row][col];
      if (d.year == date.year && d.month == date.month && d.day == date.day) {
        final localCenter = Offset(
          col * cellWidth + cellWidth / 2,
          row * cellHeight + cellHeight / 2,
        );
        return renderBox.localToGlobal(localCenter);
      }
    }
  }
  throw StateError('Date not found in calendar: $date');
}

void main() {
  // =========================================================================
  // CalendarHeatmapData unit tests
  // =========================================================================

  group('CalendarHeatmapData', () {
    test('valueOf returns the value for a matching date', () {
      final data = _sampleData();
      expect(data.valueOf(DateTime(2025, 12, 15)), equals(30));
    });

    test('valueOf returns null for a date not in the data', () {
      final data = _sampleData();
      expect(data.valueOf(DateTime(2025, 12, 2)), isNull);
    });

    test('valueOf ignores time and searches by year/month/day only', () {
      final data = _sampleData();
      // A DateTime with a time component should still retrieve data for the same day
      expect(data.valueOf(DateTime(2025, 12, 1, 13, 45, 30)), equals(5));
    });

    test('minValue returns the minimum value in the data', () {
      final data = _sampleData();
      expect(data.minValue, equals(5));
    });

    test('maxValue returns the maximum value in the data', () {
      final data = _sampleData();
      expect(data.maxValue, equals(30));
    });

    test('minValue returns 0 for empty data', () {
      final data = _emptyData();
      expect(data.minValue, equals(0));
    });

    test('maxValue returns 1 for empty data', () {
      final data = _emptyData();
      expect(data.maxValue, equals(1));
    });

    test('fromEntries correctly builds a Map from a list', () {
      final data = CalendarHeatmapData.fromEntries(
        entries: [
          CalendarHeatmapEntry(date: DateTime(2025, 1, 1), value: 10),
          CalendarHeatmapEntry(date: DateTime(2025, 1, 15), value: 20),
        ],
      );

      expect(data.valueOf(DateTime(2025, 1, 1)), equals(10));
      expect(data.valueOf(DateTime(2025, 1, 15)), equals(20));
      expect(data.valueOf(DateTime(2025, 1, 2)), isNull);
    });

    test('fromEntries uses last-write-wins for duplicate dates', () {
      final data = CalendarHeatmapData.fromEntries(
        entries: [
          CalendarHeatmapEntry(date: DateTime(2025, 1, 1), value: 10),
          CalendarHeatmapEntry(date: DateTime(2025, 1, 1), value: 99),
        ],
      );

      expect(data.valueOf(DateTime(2025, 1, 1)), equals(99));
    });

    test('fromEntries normalizes time to unify keys', () {
      final data = CalendarHeatmapData.fromEntries(
        entries: [
          CalendarHeatmapEntry(
            date: DateTime(2025, 1, 1, 23, 59, 59),
            value: 42,
          ),
        ],
      );

      expect(data.valueOf(DateTime(2025, 1, 1)), equals(42));
    });
  });

  // =========================================================================
  // CalendarMonthPainter unit tests
  // =========================================================================

  group('CalendarMonthPainter', () {
    test('paints without error with normal data', () {
      final weeks = _buildWeeksForTest(2025, 12);
      final painter = CalendarMonthPainter(
        year: 2025,
        month: 12,
        weeks: weeks,
        data: _sampleData(),
        colorScale: HeatmapColorScale.twoColor(
          minColor: const Color(0xFFD6E4FF),
          maxColor: const Color(0xFF1D39C4),
        ),
        valueMin: 5,
        valueMax: 30,
        theme: ChartTheme.defaultTheme,
        baseTextStyle: const TextStyle(fontSize: 14.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(700, 300));
      recorder.endRecording();
    });

    test('paints without error with empty data', () {
      final weeks = _buildWeeksForTest(2025, 12);
      final painter = CalendarMonthPainter(
        year: 2025,
        month: 12,
        weeks: weeks,
        data: _emptyData(),
        colorScale: HeatmapColorScale.twoColor(
          minColor: const Color(0xFFD6E4FF),
          maxColor: const Color(0xFF1D39C4),
        ),
        valueMin: 0,
        valueMax: 1,
        theme: ChartTheme.defaultTheme,
        baseTextStyle: const TextStyle(fontSize: 14.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(700, 300));
      recorder.endRecording();
    });

    test('paints without error with hover state', () {
      final weeks = _buildWeeksForTest(2025, 12);
      final painter = CalendarMonthPainter(
        year: 2025,
        month: 12,
        weeks: weeks,
        data: _sampleData(),
        colorScale: HeatmapColorScale.twoColor(
          minColor: const Color(0xFFD6E4FF),
          maxColor: const Color(0xFF1D39C4),
        ),
        valueMin: 5,
        valueMax: 30,
        theme: ChartTheme.defaultTheme,
        baseTextStyle: const TextStyle(fontSize: 14.0),
        hoveredDate: DateTime(2025, 12, 15),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(700, 300));
      recorder.endRecording();
    });

    test('draws nothing with empty weeks', () {
      final painter = CalendarMonthPainter(
        year: 2025,
        month: 12,
        weeks: [],
        data: _sampleData(),
        colorScale: HeatmapColorScale.twoColor(
          minColor: const Color(0xFFD6E4FF),
          maxColor: const Color(0xFF1D39C4),
        ),
        valueMin: 5,
        valueMax: 30,
        theme: ChartTheme.defaultTheme,
        baseTextStyle: const TextStyle(fontSize: 14.0),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(700, 300));
      recorder.endRecording();
    });

    test('shouldRepaint returns true when hoveredDate changes', () {
      final weeks = _buildWeeksForTest(2025, 12);
      CalendarMonthPainter makePainter({DateTime? hovered}) {
        return CalendarMonthPainter(
          year: 2025,
          month: 12,
          weeks: weeks,
          data: _sampleData(),
          colorScale: HeatmapColorScale.twoColor(
            minColor: const Color(0xFFD6E4FF),
            maxColor: const Color(0xFF1D39C4),
          ),
          valueMin: 5,
          valueMax: 30,
          theme: ChartTheme.defaultTheme,
          baseTextStyle: const TextStyle(fontSize: 14.0),
          hoveredDate: hovered,
        );
      }

      final a = makePainter();
      final b = makePainter(hovered: DateTime(2025, 12, 15));
      expect(b.shouldRepaint(a), isTrue);
    });

    test('shouldRepaint returns false with the same state', () {
      final weeks = _buildWeeksForTest(2025, 12);
      final sharedData = _sampleData();
      final sharedColorScale = HeatmapColorScale.twoColor(
        minColor: const Color(0xFFD6E4FF),
        maxColor: const Color(0xFF1D39C4),
      );

      CalendarMonthPainter makePainter() {
        return CalendarMonthPainter(
          year: 2025,
          month: 12,
          weeks: weeks,
          data: sharedData,
          colorScale: sharedColorScale,
          valueMin: 5,
          valueMax: 30,
          theme: ChartTheme.defaultTheme,
          baseTextStyle: const TextStyle(fontSize: 14.0),
        );
      }

      final a = makePainter();
      final b = makePainter();
      expect(b.shouldRepaint(a), isFalse);
    });
  });

  // =========================================================================
  // hitTestCalendarCell unit tests
  // =========================================================================

  group('hitTestCalendarCell', () {
    test('returns the correct date for a valid cell', () {
      final weeks = _buildWeeksForTest(2025, 12);
      const size = Size(700, 300);
      final cellWidth = 700.0 / 7;
      final cellHeight = 300.0 / weeks.length;

      // Center of the first cell (row=0, col=0)
      final result = hitTestCalendarCell(
        localPosition: Offset(cellWidth / 2, cellHeight / 2),
        size: size,
        weeks: weeks,
      );

      expect(result, equals(weeks[0][0]));
    });

    test('returns the correct date for the last cell', () {
      final weeks = _buildWeeksForTest(2025, 12);
      const size = Size(700, 300);
      final cellWidth = 700.0 / 7;
      final cellHeight = 300.0 / weeks.length;

      // Center of the last cell
      final lastRow = weeks.length - 1;
      final result = hitTestCalendarCell(
        localPosition: Offset(
          6 * cellWidth + cellWidth / 2,
          lastRow * cellHeight + cellHeight / 2,
        ),
        size: size,
        weeks: weeks,
      );

      expect(result, equals(weeks[lastRow][6]));
    });

    test('returns null for negative coordinates', () {
      final weeks = _buildWeeksForTest(2025, 12);
      final result = hitTestCalendarCell(
        localPosition: const Offset(-10, -10),
        size: const Size(700, 300),
        weeks: weeks,
      );
      expect(result, isNull);
    });

    test('returns null for coordinates exceeding the size', () {
      final weeks = _buildWeeksForTest(2025, 12);
      final result = hitTestCalendarCell(
        localPosition: const Offset(800, 400),
        size: const Size(700, 300),
        weeks: weeks,
      );
      expect(result, isNull);
    });

    test('returns null with empty weeks', () {
      final result = hitTestCalendarCell(
        localPosition: const Offset(100, 100),
        size: const Size(700, 300),
        weeks: [],
      );
      expect(result, isNull);
    });
  });

  // =========================================================================
  // CalendarHeatmap widget tests
  // =========================================================================

  group('CalendarHeatmap widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CalendarHeatmap), findsOneWidget);
    });

    testWidgets('renders without error with empty data', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _emptyData(),
            initialMonth: DateTime(2025, 12),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CalendarHeatmap), findsOneWidget);
    });

    testWidgets('accepts darkTheme', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            theme: ChartTheme.darkTheme,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CalendarHeatmap), findsOneWidget);
    });

    testWidgets('weekday headers are displayed correctly', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('year and month are displayed', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2025'), findsOneWidget);
      expect(find.text('Dec'), findsOneWidget);
    });

    testWidgets('tapping right arrow navigates to the next month', (tester) async {
      DateTime? changedMonth;

      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            onMonthChanged: (dt) => changedMonth = dt,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the > button (next month)
      final nextMonthButton = find.byIcon(Icons.chevron_right);
      expect(nextMonthButton, findsOneWidget);
      await tester.tap(nextMonthButton);
      await tester.pumpAndSettle();

      expect(changedMonth, isNotNull);
      expect(changedMonth!.year, equals(2026));
      expect(changedMonth!.month, equals(1));
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Jan'), findsOneWidget);
    });

    testWidgets('tapping left arrow navigates to the previous month', (tester) async {
      DateTime? changedMonth;

      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            onMonthChanged: (dt) => changedMonth = dt,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final prevMonthButton = find.byIcon(Icons.chevron_left);
      expect(prevMonthButton, findsOneWidget);
      await tester.tap(prevMonthButton);
      await tester.pumpAndSettle();

      expect(changedMonth, isNotNull);
      expect(changedMonth!.year, equals(2025));
      expect(changedMonth!.month, equals(11));
      expect(find.text('Nov'), findsOneWidget);
    });

    testWidgets('tapping double right arrow navigates to the next year', (tester) async {
      DateTime? changedMonth;

      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            onMonthChanged: (dt) => changedMonth = dt,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nextYearButton = find.byIcon(Icons.keyboard_double_arrow_right);
      expect(nextYearButton, findsOneWidget);
      await tester.tap(nextYearButton);
      await tester.pumpAndSettle();

      expect(changedMonth, isNotNull);
      expect(changedMonth!.year, equals(2026));
      expect(changedMonth!.month, equals(12));
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('tapping double left arrow navigates to the previous year', (tester) async {
      DateTime? changedMonth;

      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            onMonthChanged: (dt) => changedMonth = dt,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final prevYearButton = find.byIcon(Icons.keyboard_double_arrow_left);
      expect(prevYearButton, findsOneWidget);
      await tester.tap(prevYearButton);
      await tester.pumpAndSettle();

      expect(changedMonth, isNotNull);
      expect(changedMonth!.year, equals(2024));
      expect(changedMonth!.month, equals(12));
      expect(find.text('2024'), findsOneWidget);
    });

    testWidgets('onDateTap returns the correct value when a date is tapped', (tester) async {
      DateTime? tappedDate;
      double? tappedValue;

      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            onDateTap: (date, value) {
              tappedDate = date;
              tappedValue = value;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cannot use find.text() for Canvas-drawn content. Tap using calculated coordinates.
      final day15Center = _cellGlobalCenter(
        tester,
        DateTime(2025, 12, 15),
        2025,
        12,
      );
      await tester.tapAt(day15Center);
      await tester.pumpAndSettle();

      expect(tappedDate, isNotNull);
      expect(tappedDate!.day, equals(15));
      expect(tappedValue, equals(30));
    });

    testWidgets('accepts a custom colorScale', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            colorScale: HeatmapColorScale.twoColor(
              minColor: const Color(0xFFFFFFFF),
              maxColor: const Color(0xFFFF0000),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CalendarHeatmap), findsOneWidget);
    });

    testWidgets('textStyle is applied', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 18.0),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CalendarHeatmap), findsOneWidget);
    });

    testWidgets('tapping year selector shows a dropdown', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            yearRangeStart: 2023,
            yearRangeEnd: 2027,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the year selector '2025'
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();

      // Years within the range are displayed in the dropdown
      expect(find.text('2023'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      // '2025' appears twice: in the selector itself and in the dropdown
      expect(find.text('2025'), findsNWidgets(2));
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('2027'), findsOneWidget);
    });

    testWidgets('tapping month selector shows a dropdown', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the month selector 'Dec'
      await tester.tap(find.text('Dec'));
      await tester.pumpAndSettle();

      // Months near the top of the dropdown are displayed (not all 12 are visible due to scroll limits)
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('Jun'), findsOneWidget);
    });

    testWidgets('selecting a year from the dropdown updates the display', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            yearRangeStart: 2023,
            yearRangeEnd: 2027,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open the year selector
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();

      // Select '2024'
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      // The year display is updated to '2024'
      expect(find.text('2024'), findsOneWidget);
    });
  });

  // =========================================================================
  // Hover / tooltip tests
  // =========================================================================

  group('CalendarHeatmap hover and tooltip', () {
    testWidgets('tooltip is not shown when showTooltip is false', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            showTooltip: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final day15Center = _cellGlobalCenter(
        tester,
        DateTime(2025, 12, 15),
        2025,
        12,
      );
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(day15Center);
      await tester.pumpAndSettle();

      // Tooltip is not displayed
      expect(find.text('2025/12/15'), findsNothing);
    });

    testWidgets('custom tooltip is displayed via tooltipBuilder', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
            tooltipBuilder: (context, date, value, cellColor) {
              return Text('custom-${date.day}');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final day15Center = _cellGlobalCenter(
        tester,
        DateTime(2025, 12, 15),
        2025,
        12,
      );
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(day15Center);
      await tester.pumpAndSettle();

      expect(find.text('custom-15'), findsOneWidget);
    });

    testWidgets('tooltip disappears when hover is removed', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final day15Center = _cellGlobalCenter(
        tester,
        DateTime(2025, 12, 15),
        2025,
        12,
      );
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(day15Center);
      await tester.pumpAndSettle();

      // Tooltip is displayed
      expect(find.text('2025/12/15'), findsOneWidget);

      // Move pointer outside the widget to remove hover
      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      // Tooltip disappears
      expect(find.text('2025/12/15'), findsNothing);
    });

    testWidgets('tooltip is shown when showTooltip defaults to true', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(
          CalendarHeatmap(
            data: _sampleData(),
            initialMonth: DateTime(2025, 12),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final day15Center = _cellGlobalCenter(
        tester,
        DateTime(2025, 12, 15),
        2025,
        12,
      );
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(day15Center);
      await tester.pumpAndSettle();

      expect(find.text('2025/12/15'), findsOneWidget);
    });
  });
}
