import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/settings/_backup_password_dialogs.dart';

import '../client/fresh_accounts.dart';
import '../ui/pump_app.dart';

void main() {
  useFreshAccounts();

  group('The password of a new backup', () {
    late Completer<String?> password;

    Future<void> openDialog(WidgetTester tester) async {
      await pumpInApp(tester, const Text('export'));
      password = Completer();
      askNewBackupPassword(tester.element(find.text('export'))).then(password.complete);
      await tester.pumpAndSettle();
    }

    Future<void> submit(WidgetTester tester, String typed, String confirmed) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, typed);
      await tester.enterText(fields.last, confirmed);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
    }

    testWidgets('Should be refused when too short', (tester) async {
      await openDialog(tester);

      await submit(tester, 'short', 'short');

      expect(find.text('Use at least 12 characters'), findsOneWidget,
          reason: 'A short password is guessed quickly by anyone who gets the backup');
      expect(password.isCompleted, isFalse, reason: 'The export should wait for a long enough password');
    });

    testWidgets('Should be refused when typed differently twice', (tester) async {
      await openDialog(tester);

      await submit(tester, 'correct horse battery', 'correct hrose battery');

      expect(find.text('The passwords do not match'), findsOneWidget,
          reason: 'A typo would lock the user out of the accounts of the backup');
      expect(password.isCompleted, isFalse, reason: 'The export should wait for a password the user typed right');
    });

    testWidgets('Should be given once typed the same twice', (tester) async {
      await openDialog(tester);

      await submit(tester, 'correct horse battery', 'correct horse battery');

      expect(await password.future, 'correct horse battery',
          reason: 'The accounts should be encrypted with the password the user typed');
    });

    testWidgets('Should be offered to password managers', (tester) async {
      await openDialog(tester);

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.map((field) => field.autofillHints), everyElement([AutofillHints.password]),
          reason: 'Bitwarden only knows the hint of the Android View constants, and ignores newPassword');
      expect(find.byType(AutofillGroup), findsOneWidget,
          reason: 'The two fields should be filled together, and saved once the dialog closes');
    });
  });

  group('The accounts of a new backup', () {
    late Future<({Map<String, dynamic>? encrypted})?> exported;

    Future<void> startExport(WidgetTester tester) async {
      await pumpInApp(tester, const Text('export'));
      await tester.runAsync(() async {
        exported = encryptAccountsToExport(tester.element(find.text('export')));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('Should be left out without asking for a password when there is none', (tester) async {
      await startExport(tester);

      expect(find.byType(AlertDialog), findsNothing, reason: 'There is nothing to protect with a password');
      expect((await tester.runAsync(() => exported))!.encrypted, isNull,
          reason: 'A backup without accounts should not ask for a password when it is imported');
    });

    testWidgets('Should cancel the export when the user cancels the password', (tester) async {
      await tester.runAsync(() => saveAccount(Account(id: 'a1', authHeader: '{}', screenName: 'me')));
      await startExport(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await tester.runAsync(() => exported), isNull, reason: 'Cancel should write no backup at all');
    });

    testWidgets('Should hold no session in clear', (tester) async {
      await tester.runAsync(
          () => saveAccount(Account(id: 'a1', authHeader: '{"Cookie":"auth_token=secret"}', screenName: 'me')));
      await startExport(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'correct horse battery');
      await tester.enterText(fields.last, 'correct horse battery');
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      final backup = await tester.runAsync(() => exported);
      expect(jsonEncode(backup!.encrypted), isNot(contains('secret')),
          reason: 'Anyone who gets the backup could log in with the session');
    });
  });
}
