import 'package:flutter_test/flutter_test.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_editor_model.dart';

import '../group/open_feed.dart';

void main() {
  useFreshDatabase();

  test('Should create a single group when Save is pressed twice', () async {
    final groups = GroupsModel();
    final editor = GroupEditorModel(groups);
    await editor.load(null, const {}, const []);
    editor.rename('Tech');

    await Future.wait([editor.save(), editor.save()]);
    await groups.reloadGroups();

    expect(groups.state.map((g) => g.name), ['Tech'], reason: 'Only one group should be created');
  });
}
