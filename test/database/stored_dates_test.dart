import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quax/database/entities.dart';

void main() {
  test('Should store a creation date that does not depend on the language', () async {
    await initializeDateFormatting();
    final subscription = UserSubscription(
        id: '1',
        screenName: 'dogs',
        name: 'Dogs',
        profileImageUrlHttps: null,
        verified: false,
        createdAt: DateTime(2026, 9, 4, 13, 37, 5),
        inFeed: true);

    final map = Intl.withLocale('fa', subscription.toMap);

    expect(map['created_at'], '2026-09-04 13:37:05',
        reason: "created_at is stored, not shown, so it should not take the digits of the user's language, "
            'which DateTime.parse cannot read');
  });
}
