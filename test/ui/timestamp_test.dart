import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/dates.dart';

import 'pump_app.dart';

final _olderPost = DateTime.now().subtract(const Duration(days: 3));
final _newerPost = DateTime.now().subtract(const Duration(minutes: 5));

/// Shows one [Timestamp] at the same place in the tree, like a feed tile reused after a refresh.
class _ReusedTimestamp extends StatefulWidget {
  const _ReusedTimestamp();

  @override
  State<_ReusedTimestamp> createState() => _ReusedTimestampState();
}

class _ReusedTimestampState extends State<_ReusedTimestamp> {
  DateTime timestamp = _olderPost;

  void showNewerPost() => setState(() => timestamp = _newerPost);

  @override
  Widget build(BuildContext context) => Timestamp(timestamp: timestamp);
}

Future<_ReusedTimestampState> _pumpReusedTimestamp(WidgetTester tester) async {
  await pumpInApp(tester, const _ReusedTimestamp());
  return tester.state<_ReusedTimestampState>(find.byType(_ReusedTimestamp));
}

Future<void> _showNewerPost(WidgetTester tester, _ReusedTimestampState host) async {
  host.showNewerPost();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Should show the absolute time on the first tap', (tester) async {
    await _pumpReusedTimestamp(tester);

    await tester.tap(find.byType(Timestamp));
    await tester.pumpAndSettle();

    expect(
      find.text(absoluteDateFormat.format(_olderPost.toLocal())),
      findsOneWidget,
      reason: 'A tap should switch from the relative time to the absolute one',
    );
  });

  testWidgets('Should show the new post in the default format after the old one was tapped', (tester) async {
    final host = await _pumpReusedTimestamp(tester);

    await tester.tap(find.byType(Timestamp));
    await tester.pumpAndSettle();
    await _showNewerPost(tester, host);

    expect(
      find.text(createRelativeDate(_newerPost)),
      findsOneWidget,
      reason: 'A tap on the previous post should not change the format of the post that replaced it',
    );
  });
}
