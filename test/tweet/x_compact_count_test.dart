import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:quax/tweet/_x_tweet_layout.dart';

void main() {
  final english = NumberFormat.compact(locale: 'en');

  test('Should write counts under a thousand in full', () {
    expect(xCompactCount(428, english), '428', reason: 'X shows small counts as they are');
    expect(xCompactCount(999, english), '999', reason: 'The last count before a thousand stays in full');
  });

  test('Should keep one decimal below ten of a unit, cut rather than rounded', () {
    expect(xCompactCount(4199, english), '4.1K', reason: 'X writes 4,199 as 4.1K, never 4.2K');
    expect(xCompactCount(5860, english), '5.8K', reason: 'Two decimals do not fit the action bar');
    expect(xCompactCount(1000, english), '1K', reason: 'A round count drops its decimal');
    expect(xCompactCount(3370000, english), '3.3M', reason: 'Millions follow the same rule');
  });

  test('Should drop the decimal from ten of a unit on', () {
    expect(xCompactCount(28400, english), '28K', reason: 'X writes 28,400 as 28K');
    expect(xCompactCount(542999, english), '542K', reason: 'The count is cut, not rounded up to 543K');
    expect(xCompactCount(12900000, english), '12M', reason: 'Millions too');
  });

  test('Should write billions', () {
    expect(xCompactCount(2150000000, english), '2.1B', reason: 'The largest counts get a billion unit');
  });

  test('Should use the unit and decimal sign of the locale', () {
    expect(xCompactCount(4199, NumberFormat.compact(locale: 'pt_BR')), '4,1\u00a0mil',
        reason: 'X writes 4,1 mil in Portuguese');
  });
}
