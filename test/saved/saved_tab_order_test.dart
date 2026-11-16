import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/saved/saved_tab_order.dart';

void main() {
  SavedTweetFolder folder(String id) => SavedTweetFolder(id: id, name: id, position: 0, createdAt: DateTime(2026));

  group('foldersInTabOrder()', () {
    final folders = [folder('cats'), folder('dogs'), folder('birds')];

    test('Should list the folders in the order the user gave their tabs', () {
      final stored = jsonEncode([savedTabAll, 'birds', savedTabUnfiled, 'cats', 'dogs', savedTabFavorites]);

      expect(foldersInTabOrder(folders, stored).map((f) => f.id), ['birds', 'cats', 'dogs'],
          reason: 'The "Save to folder" sheet should list the folders as they are ordered in Manage folders, '
              'without the tabs that are not folders');
    });

    test('Should keep the folders created after the order was set', () {
      final stored = jsonEncode(['dogs', 'cats']);

      expect(foldersInTabOrder(folders, stored).map((f) => f.id), ['dogs', 'cats', 'birds'],
          reason: 'A folder missing from the stored order should still be listed, after the ordered ones');
    });

    test('Should keep the order of creation when no order was set', () {
      expect(foldersInTabOrder(folders, null).map((f) => f.id), ['cats', 'dogs', 'birds'],
          reason: 'Without a custom order, the folders should keep the order they were listed in');
    });
  });
}
