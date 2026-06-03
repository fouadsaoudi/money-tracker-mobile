import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/helpers.dart';
import 'package:money_tracker/models/models.dart';

void main() {
  test('decimalText trims trailing zeros and caps decimals', () {
    expect(decimalText('89500.00000000'), '89500');
    expect(decimalText('89500.50000000'), '89500.5');
    expect(decimalText('89500.56780000'), '89500.57');
  });

  test('money displays at most two decimals', () {
    final usd = Currency(
      id: 1,
      code: 'USD',
      name: 'US Dollar',
      symbol: r'$',
      decimalPlaces: 4,
      isActive: true,
    );

    expect(money('1234.5678', usd), '1,234.57 USD');
    expect(money('1234.5000', usd), '1,234.5 USD');
    expect(money('1234.0000', usd), '1,234 USD');
  });
}
