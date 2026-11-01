import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/release_notes/release_notes_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<ReleaseNotesModel> _launch(String version) async {
  final model = ReleaseNotesModel(version);
  await model.load();
  return model;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await databaseFactory.deleteDatabase(databaseName);
    await Repository().migrate();
  });

  test('Should show the notes of every version installed since the notes were last hidden', () async {
    await (await _launch('4.19.2')).hide();

    final model = await _launch('4.20.1');

    expect(model.state.map((e) => e.version), ['4.20.1', '4.20.0'],
        reason: 'The user skipped 4.20.0, so its notes should come along with those of 4.20.1');
  });

  test('Should only show the notes of the version installed when none was stored', () async {
    final model = await _launch('4.20.1');

    expect(model.state.map((e) => e.version), ['4.20.1'],
        reason: 'Without a previous version, only what this version brings is known to be new');
  });

  test('Should show the notes again on the next launch until they are hidden', () async {
    await _launch('4.20.1');

    final relaunched = await _launch('4.20.1');

    expect(relaunched.state, isNotEmpty, reason: 'The user has not hidden the notes yet');
  });

  test('Should never show the notes of a version again once hidden', () async {
    await (await _launch('4.20.1')).hide();

    final relaunched = await _launch('4.20.1');

    expect(relaunched.state, isEmpty, reason: 'The user hid the notes of this version');
  });
}
