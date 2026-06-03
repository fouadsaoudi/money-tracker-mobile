import 'package:flutter/material.dart';

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, value) => MapEntry('$key', value));
  return <String, dynamic>{};
}

List<Object?> asList(Object? value) {
  if (value is List) return value;
  return const [];
}

int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String isoDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

String isoDateTime(DateTime value) {
  final date = isoDate(value);
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$date $hour:$minute:$second';
}

String shortDateTime(DateTime value) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[value.weekday - 1];
  final month = months[value.month - 1];
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$weekday ${value.day} $month $hour:$minute';
}

String decimalText(String amount, {int maxFractionDigits = 2}) {
  final value = double.tryParse(amount);
  if (value == null) return amount;

  final fixed = value.toStringAsFixed(maxFractionDigits);
  if (!fixed.contains('.')) return fixed;

  return fixed
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String money(String amount, dynamic currency) {
  final value = double.tryParse(amount) ?? 0;
  final decimals = currency?.decimalPlaces.clamp(0, 2) ?? 2;
  final code = currency?.code ?? '';
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = _groupDigits(parts.first);
  final decimal = parts.length > 1
      ? parts.last.replaceFirst(RegExp(r'0+$'), '')
      : '';
  final formatted = decimal.isEmpty ? whole : '$whole.$decimal';
  return '$formatted $code'.trim();
}

String _groupDigits(String value) {
  final negative = value.startsWith('-');
  final digits = negative ? value.substring(1) : value;
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return negative ? '-$buffer' : buffer.toString();
}

Color? parseColor(String? value) {
  if (value == null || !value.startsWith('#')) return null;
  final hex = value.substring(1);
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xff000000 | parsed);
}

String colorToHex(Color color) {
  final red = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final green = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final blue = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$red$green$blue';
}
