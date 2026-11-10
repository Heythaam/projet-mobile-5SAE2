import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/entities/user/dial_codes.dart';

void main() {
  test('splits a saved number into its code and digits', () {
    final tunisia = splitPhone('+216 20123456');
    expect(tunisia.dial.code, '+216');
    expect(tunisia.digits, '20123456');
    final france = splitPhone('+33 612345678');
    expect(france.dial.country, 'France');
    expect(france.digits, '612345678');
  });

  test('a number without a code keeps Tunisia and its digits', () {
    final plain = splitPhone('20 123 456');
    expect(plain.dial.code, '+216');
    expect(plain.digits, '20123456');
  });

  test('Tunisian numbers have exactly 8 digits, others 6 to 12', () {
    expect(defaultDialCode.minDigits, 8);
    expect(defaultDialCode.maxDigits, 8);
    final france = dialCodes.firstWhere((d) => d.code == '+33');
    expect(france.minDigits, 6);
    expect(france.maxDigits, 12);
  });
}
