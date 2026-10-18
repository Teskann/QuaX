import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/_feed_shell.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/onboarding/_theme_picker.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/search/search_filters_screen.dart';
import 'package:quax/settings/_accessibility.dart';
import 'package:quax/settings/_general.dart';
import 'package:quax/settings/_media.dart';
import 'package:quax/settings/_posts.dart';
import 'package:quax/settings/_theme.dart';
import 'package:quax/settings/_tweet_actions.dart';
import 'package:quax/tweet/_media.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../profile/profile_content_test.dart' show openProfile, quaxTestsId;
import '../trends/pump_trends.dart';
import '../tweet/pump_tweets.dart';
import 'fake_images.dart';
import 'pump_app.dart';

/// Constructors of buttons that only show an icon, so a screen reader has nothing to read unless the button is named.
const _iconOnlyButtons = {
  'IconButton': {'', 'filled', 'filledTonal', 'outlined'},
  'FloatingActionButton': {'', 'small', 'large'},
};

/// Toggles of the pref package, whose switch is read apart from its title unless a LabeledPref merges them.
const _prefToggles = {'PrefSwitch', 'PrefCheckbox'};

/// Every widget of [file] that a screen reader would announce without a name, as `path:line`.
List<String> _unlabeledWidgets(File file) {
  final unit = parseString(content: file.readAsStringSync(), path: file.path).unit;
  final visitor = _UnlabeledWidgetVisitor();
  unit.accept(visitor);
  return visitor.unlabeled.map((offset) => '${file.path}:${unit.lineInfo.getLocation(offset).lineNumber}').toList();
}

bool _isChildOfLabeledPref(Expression widget) {
  final argument = widget.parent;
  final call = argument?.parent?.parent;
  final callee = switch (call) {
    MethodInvocation(:final methodName) => methodName.name,
    InstanceCreationExpression(:final constructorName) => constructorName.type.name.lexeme,
    _ => null,
  };
  return argument is NamedExpression && argument.name.label.name == 'child' && callee == 'LabeledPref';
}

/// Finds a `tooltip:`, a `semanticLabel:` or a `Semantics(label: ...)` anywhere in the arguments of a widget.
class _NameVisitor extends RecursiveAstVisitor<void> {
  var found = false;

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    final callee = switch (node.parent?.parent) {
      MethodInvocation(:final methodName) => methodName.name,
      InstanceCreationExpression(:final constructorName) => constructorName.type.name.lexeme,
      _ => null,
    };
    found = found || name == 'tooltip' || name == 'semanticLabel' || (name == 'label' && callee == 'Semantics');
    super.visitNamedExpression(node);
  }
}

bool _isNamed(ArgumentList arguments) {
  final visitor = _NameVisitor();
  arguments.accept(visitor);
  return visitor.found;
}

/// Without resolution, `IconButton(...)` parses as a method invocation, and `const IconButton(...)` as an
/// instance creation.
class _UnlabeledWidgetVisitor extends RecursiveAstVisitor<void> {
  final unlabeled = <int>[];

  void _check(String type, String constructor, ArgumentList arguments, Expression widget) {
    final silentButton = _iconOnlyButtons[type]?.contains(constructor) == true && !_isNamed(arguments);
    final silentToggle = _prefToggles.contains(type) && !_isChildOfLabeledPref(widget);
    if (silentButton || silentToggle) unlabeled.add(widget.offset);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target == null) {
      _check(node.methodName.name, '', node.argumentList, node);
    } else if (target is SimpleIdentifier) {
      _check(target.name, node.methodName.name, node.argumentList, node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName;
    _check(name.type.name.lexeme, name.name?.name ?? '', node.argumentList, node);
    super.visitInstanceCreationExpression(node);
  }
}

/// A label made of words, not a count alone such as "0" or "4.26K", which says nothing of what a button does.
final _words = RegExp(r'\p{L}{2,}', unicode: true);

/// A tap target is spoken when it, or something it holds, has words in its label, tooltip or value: TalkBack reads
/// what a button holds, so only targets made of icons, images or counts are silent.
bool _isSpoken(SemanticsNode node) {
  final data = node.getSemanticsData();
  if (_words.hasMatch('${data.label} ${data.tooltip} ${data.value}')) return true;
  var spoken = false;
  node.visitChildren((child) => !(spoken = _isSpoken(child)));
  return spoken;
}

class _SpokenTapTargetGuideline extends AccessibilityGuideline {
  const _SpokenTapTargetGuideline();

  @override
  String get description => 'Every tap target should give a screen reader something to read';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) => tester.binding.renderViews
      .map((view) => _evaluate(view.owner!.semanticsOwner!.rootSemanticsNode!))
      .fold<Evaluation>(const Evaluation.pass(), (all, one) => all + one);

  Evaluation _evaluate(SemanticsNode node) {
    var result = const Evaluation.pass();
    node.visitChildren((child) {
      result += _evaluate(child);
      return true;
    });
    final data = node.getSemanticsData();
    final tappable = data.hasAction(SemanticsAction.tap) || data.hasAction(SemanticsAction.longPress);
    final hidden = node.flagsCollection.isHidden;
    if (node.isMergedIntoParent || node.isInvisible || hidden || !tappable || _isSpoken(node)) return result;
    return result + Evaluation.fail('$node: a tap target with nothing for a screen reader to read');
  }
}

const _everyTapTargetIsSpoken = _SpokenTapTargetGuideline();

/// The screens rendered for the screen reader check, each by the name a failure reports.
Map<String, Future<void> Function(WidgetTester tester)> _screens() => {
      for (final post in fixturesOf('TweetDetail'))
        'the post "$post" (${post.path.split('/').last})': (tester) => pumpChains(tester, Twitter.parseTweetDetail(post.body).chains),
      'the feed toolbar': (tester) => pumpInApp(
          tester,
          Builder(
              builder: (context) => AppBar(
                  actions: defaultGroupActions(context,
                      model: GroupModel('group'), scrollToTopController: ScrollController(), onRefresh: () {})))),
      'the profile header': (tester) => openProfile(tester, 'quax-tests', 'quax_tests', quaxTestsId),
      'the media viewer': (tester) => pumpInApp(
          tester,
          TweetMediaView(
              initialIndex: 0,
              media: [createMediaFromUrl('https://pbs.twimg.com/media/photo.jpg', null)],
              username: 'quax_tests',
              tweetMedia: false),
          settle: false),
      'the theme colors of the onboarding': (tester) => pumpInApp(tester, const ThemePicker()),
      'the general settings': (tester) => pumpInApp(tester, const SettingsGeneralFragment()),
      'the media settings': (tester) => pumpInApp(tester, const SettingsMediaFragment()),
      'the posts settings': (tester) => pumpInApp(tester, const SettingsPostsFragment()),
      'the action bar settings': (tester) => pumpInApp(tester, withAppModels(const SettingsTweetActionsFragment())),
      'the theme settings': (tester) => pumpInApp(tester, const SettingsThemeFragment()),
      'the accessibility settings': (tester) => pumpInApp(tester, const SettingsAccessibilityFragment()),
      'the search results with filters': (tester) => pumpScreen(tester, const ResultsScreen(),
          arguments: SearchArguments(1, query: 'from:FlutterDev filter:images'),
          fixtures: {'SearchTimeline': fixture('SearchTimeline', 'from-flutterdev-filter-images', unstable: true)}),
      'the search bar of the trends': (tester) {
        Twitter.client = const FixtureTwitterClient({});
        return pumpInApp(tester, trendsScreenWithModels(), settle: false);
      },
      'the search filters': (tester) => pumpInApp(
          tester,
          SearchFiltersScreen(
              initial: SearchFilters(
                  language: LanguageChoice.other,
                  fromAccounts: const ['FlutterDev'],
                  since: DateTime(2025, 1, 1)))),
    };

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  test('Should name every icon-only button and settings switch of the app', () {
    final unlabeled = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart') && !file.path.startsWith('lib/generated/'))
        .expand(_unlabeledWidgets)
        .toList();

    expect(unlabeled, isEmpty,
        reason: 'TalkBack reads the name of an icon-only button, and Maestro taps it by that name: give the icon of '
            'these buttons a translated semanticLabel. Wrap a PrefSwitch or PrefCheckbox in a LabeledPref');
  });

  _screens().forEach((screen, pump) {
    testWidgets('Should give a screen reader a name for every tap target of $screen', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      await expectLater(tester, meetsGuideline(_everyTapTargetIsSpoken),
          reason: 'TalkBack announces a button, image or switch with no name, and Maestro cannot tap it by name');
      semantics.dispose();
    });
  });
}
