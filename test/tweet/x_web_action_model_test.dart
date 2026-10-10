import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/x_web_action_model.dart';

final _intent = Uri.parse('https://x.com/intent/post?in_reply_to=20');
final _home = Uri.parse('https://x.com/home');
final _login = Uri.parse('https://x.com/i/flow/login');

void main() {
  group('XWebActionModel', () {
    test('Should start loading, with nothing known about the page', () {
      final model = XWebActionModel();

      expect(model.state.loading, isTrue, reason: 'The page has not loaded yet');
      expect(model.state.progress, 0, reason: 'No progress was reported yet');
      expect(model.state.landedOn, isNull, reason: 'No page finished loading yet');
    });

    test('Should follow the progress of the page, loading until it is complete', () {
      final model = XWebActionModel();

      model.onProgress(40);
      expect(model.state.progress, 40, reason: 'The progress should be the one reported');
      expect(model.state.loading, isTrue, reason: 'The page is still loading at 40%');

      model.onProgress(100);
      expect(model.state.loading, isFalse, reason: 'The page is loaded at 100%');
    });

    test('Should be loaded once the page finished, even if the progress never said so', () {
      final model = XWebActionModel()..onProgress(80);

      model.onPageFinished(_intent);

      expect(model.state.loading, isFalse, reason: 'A finished page is not loading anymore');
    });

    test('Should keep the page where it landed on the first finish only', () {
      final model = XWebActionModel()..onPageFinished(_login);

      model.onPageFinished(_intent);

      expect(model.state.landedOn, _login, reason: 'Later pages must not replace where the action started');
    });

    test('Should keep where it landed when the progress changes afterwards', () {
      final model = XWebActionModel()..onPageFinished(_intent);

      model.onProgress(30);

      expect(model.state.landedOn, _intent, reason: 'The progress of a next page does not forget the first one');
    });

    test('Should not tell that X left the intent page before the first page finished', () {
      final model = XWebActionModel();

      expect(model.hasLeftIntent(_home), isFalse, reason: 'X redirects while loading; the action has not started');
    });

    test('Should tell that X left the intent page once it moved on after landing on it', () {
      final model = XWebActionModel()..onPageFinished(_intent);

      expect(model.hasLeftIntent(_home), isTrue, reason: 'The action is over when X goes to the home page');
      expect(model.hasLeftIntent(_intent), isFalse, reason: 'Staying on the intent page is not leaving it');
    });

    test('Should never tell that X left the intent page when it landed elsewhere, like the login', () {
      final model = XWebActionModel()..onPageFinished(_login);

      expect(model.hasLeftIntent(_home), isFalse, reason: 'Logging in must not close the page');
    });
  });
}
