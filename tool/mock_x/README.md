# Running QuaX against a mocked X

`server.dart` answers the app with the fixtures in `test/fixtures/`, so no X
account is needed.

```bash
fvm dart run tool/mock_x/server.dart          # listens on http://localhost:8787
adb reverse tcp:8787 tcp:8787                 # lets the device reach it
fvm flutter run --debug --dart-define=QUAX_MOCK_X=http://localhost:8787
```

The server only answers a request identical to one the website sent during the
capture. Any other request gets a 501 listing how it differs from the closest
fixture. The server prints that list and the app shows it in its error card.

## Coverage

The fixtures hold the @quax_tests and @quax_tests_2 profiles and posts, the
searches `from:quax_tests`, `quax` and `quax_tests`, and the subscriptions
feed. For the feed, subscribe to @FlutterDev, then to @dart_lang: the query
lists them in subscription order. Long lists end after three pages, as the
capture records no more.

Trends, translation and live broadcasts always fail. Images and videos come
from X's public servers, so the device needs internet.

`test/client/mock_x_test.dart` fails when the app's requests stop matching the
fixtures.
