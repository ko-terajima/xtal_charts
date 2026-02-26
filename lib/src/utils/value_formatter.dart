/// Scaling for display values.
enum ValueScale {
  /// Display as-is (x1).
  none,

  /// Divide by 1,000 (thousands).
  divideBy1000,

  /// Divide by 10,000 (ten-thousands).
  divideBy10000,
}

/// Unit display position.
enum UnitPosition {
  /// Prepend to the number (e.g. "$100").
  prefix,

  /// Append to the number (e.g. "100kg").
  suffix,
}

/// Value label formatter type.
typedef ValueLabelFormatter = String Function(double value);

/// Formats a chart numeric value.
///
/// 1. Scales the value according to [valueScale]
/// 2. Omits decimal point for integers; otherwise uses [decimalPlaces] digits
/// 3. Inserts commas every 3 digits when [useThousandsSeparator] is true
/// 4. Prepends or appends [unit] according to [unitPosition] if provided
String formatChartValue(
  double value, {
  String? unit,
  UnitPosition unitPosition = UnitPosition.suffix,
  int decimalPlaces = 1,
  ValueScale valueScale = ValueScale.none,
  bool useThousandsSeparator = true,
}) {
  final scaled = switch (valueScale) {
    ValueScale.none => value,
    ValueScale.divideBy1000 => value / 1000,
    ValueScale.divideBy10000 => value / 10000,
  };
  final formatted = scaled == scaled.roundToDouble()
      ? scaled.toInt().toString()
      : scaled.toStringAsFixed(decimalPlaces);
  final displayValue = useThousandsSeparator
      ? _addThousandsSeparator(formatted)
      : formatted;
  if (unit == null || unit.isEmpty) return displayValue;
  return switch (unitPosition) {
    UnitPosition.prefix => '$unit$displayValue',
    UnitPosition.suffix => '$displayValue$unit',
  };
}

/// Inserts commas every 3 digits in the integer part.
/// e.g. "18290" -> "18,290", "-1234567.89" -> "-1,234,567.89"
String _addThousandsSeparator(String numberStr) {
  final isNegative = numberStr.startsWith('-');
  final abs = isNegative ? numberStr.substring(1) : numberStr;
  final parts = abs.split('.');
  final intPart = parts[0];
  final decPart = parts.length > 1 ? '.${parts[1]}' : '';

  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intPart[i]);
  }
  return '${isNegative ? '-' : ''}$buffer$decPart';
}
