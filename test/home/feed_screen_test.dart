import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/_feed.dart';
import 'package:quax/home/_x_feed.dart';
import 'package:quax/ui/x_overlay_feed.dart';

import 'x_pump.dart';

void main() {
  // The Following feed reads the database, so the tests open on For you
  Widget feedScreen() => FeedScreen(scrollController: ScrollController(), id: '-1', name: 'Feed');

  testWidgets('Should keep the dropdown of the feeds outside the X design', (tester) async {
    await pumpXApp(tester, feedScreen(), prefs: {optionXStyle: false, optionHomeDefaultFeedTab: 'foryou'});

    expect(find.byType(DropdownMenu<FeedTab>), findsOneWidget, reason: 'The regular design picks the feed in a menu');
    expect(find.byType(XFeedScreen), findsNothing, reason: 'The tabs belong to the X design');
    expect(find.byType(TabBar), findsNothing, reason: 'The regular design has no tabs');
    expect(find.byType(NestedScrollView), findsOneWidget, reason: 'The regular header still floats in a NestedScrollView');
    expect(find.byType(XOverlayFeed), findsNothing, reason: 'The regular design has no header laid over the feed');
  });

  testWidgets('Should show the tabs instead of the dropdown in the X design', (tester) async {
    await pumpXApp(tester, feedScreen(), prefs: {optionXStyle: true, optionHomeDefaultFeedTab: 'foryou'});

    expect(find.byType(XFeedScreen), findsOneWidget, reason: 'The X design has its own header');
    expect(find.byType(DropdownMenu<FeedTab>), findsNothing, reason: 'The dropdown is replaced by the tabs');
    expect(find.byType(XOverlayFeed), findsOneWidget, reason: 'The X header is laid over the feed');
    expect(find.byType(NestedScrollView), findsNothing, reason: 'The X feed scrolls under its header instead');
  });

  testWidgets('Should open the X design on the default feed tab of the preferences', (tester) async {
    await pumpXApp(tester, feedScreen(), prefs: {optionXStyle: true, optionHomeDefaultFeedTab: 'foryou'});

    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0, reason: 'For you is the first tab');
  });
}
