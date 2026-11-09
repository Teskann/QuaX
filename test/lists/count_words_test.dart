import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/generated/l10n.dart';

void main() {
  test('Should write the word after a count in the plural only when the language does', () async {
    final french = await L10n.load(const Locale('fr'));

    expect([0, 1, 2].map(french.followers_after_count), ['Abonné', 'Abonné', 'Abonnés'],
        reason: 'In French, 0 and 1 take the singular');
    expect([1, 42].map(french.members_after_count), ['Membre', 'Membres'], reason: 'The members follow the same rule');

    final english = await L10n.load(const Locale('en'));
    expect([0, 1, 2].map(english.followers_after_count), ['Followers', 'Follower', 'Followers'],
        reason: 'In English, only 1 takes the singular');
  });
}
