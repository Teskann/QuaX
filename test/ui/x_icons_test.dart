import 'package:flutter_test/flutter_test.dart';
import 'package:quax/ui/x_icons.dart';

void main() {
  group('XIcons', () {
    test('Should draw the outlined icons with the regular font', () {
      for (final icon in [XIcons.reply, XIcons.repost, XIcons.like, XIcons.views, XIcons.bookmark, XIcons.share]) {
        expect(icon.fontFamily, 'PhosphorRegular', reason: '${icon.codePoint.toRadixString(16)} should be regular');
      }
      expect(XIcons.translate.fontFamily, 'PhosphorRegular', reason: 'Translate should be regular');
    });

    test('Should share with the connected dots icon', () {
      expect(XIcons.share.codePoint, 0xe408, reason: 'X shares with the shareNetwork glyph');
    });

    test('Should draw the icons of the home header and drawer with the regular font', () {
      const icons = [
        XIcons.userCircle, XIcons.profile, XIcons.dotsThree, XIcons.dotsThreeVertical, XIcons.plus, XIcons.sun,
        XIcons.moonStars, XIcons.lists, XIcons.settings, XIcons.timelines, XIcons.search,
      ];
      for (final icon in icons) {
        expect(icon.fontFamily, 'PhosphorRegular', reason: '${icon.codePoint.toRadixString(16)} should be regular');
      }
    });

    test('Should draw the filled icons with the fill font', () {
      for (final icon in [XIcons.liked, XIcons.bookmarked, XIcons.verified, XIcons.pinned]) {
        expect(icon.fontFamily, 'PhosphorFill', reason: '${icon.codePoint.toRadixString(16)} should be filled');
      }
    });

    test('Should use the bold magnifying glass for the selected search page', () {
      expect(XIcons.navigation['trending']!.$2.fontFamily, 'PhosphorBold', reason: 'Selected search should be bold');
    });

    test('Should only use the bundled Phosphor families', () {
      const families = {'PhosphorRegular', 'PhosphorFill', 'PhosphorBold'};
      for (final icon in XIcons.all) {
        expect(families, contains(icon.fontFamily), reason: '${icon.codePoint.toRadixString(16)} has a typo family');
        expect(icon.fontPackage, isNull, reason: 'The fonts come from the app, not from a package');
      }
    });

    test('Should map every navigation page to a regular and a selected icon of the same glyph', () {
      for (final entry in XIcons.navigation.entries) {
        expect(entry.value.$1.codePoint, entry.value.$2.codePoint, reason: '${entry.key} should keep its glyph');
      }
    });
  });
}
