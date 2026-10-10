import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/_settings.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/_x_account.dart';
import 'package:quax/ui/x_frosted.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_overlay_feed.dart';
import 'package:quax/ui/x_style.dart';

enum XFeedTabKind { forYou, following, group, add }

/// A tab of the home header of the X design: the two fixed feeds, one tab per group and the one that adds timelines.
class XFeedTab {
  final XFeedTabKind kind;
  final SubscriptionGroup? group;

  const XFeedTab(this.kind, {this.group});

  String get id => group?.id ?? kind.name;

  /// Where the feed of the tab keeps its loaded state in the `FeedSessionCache`, so that coming back to the tab does
  /// not load it again. Prefixed so as not to share the state of a group opened on its own
  String get cacheKey => 'x-home:$id';

  bool get hasSettings => kind == XFeedTabKind.following || kind == XFeedTabKind.group;

  String label(L10n l10n) => switch (kind) {
        XFeedTabKind.forYou => l10n.foryou,
        XFeedTabKind.following => l10n.following,
        XFeedTabKind.group => group!.name,
        XFeedTabKind.add => l10n.add,
      };
}

List<XFeedTab> xFeedTabs(List<SubscriptionGroup> groups) => [
      const XFeedTab(XFeedTabKind.forYou),
      const XFeedTab(XFeedTabKind.following),
      ...groups.map((e) => XFeedTab(XFeedTabKind.group, group: e)),
      const XFeedTab(XFeedTabKind.add),
    ];

const xToolbarHeight = 52.0;
const xTabBarHeight = 44.0;

/// The height of the home header below the status bar
const xFeedHeaderHeight = xToolbarHeight + xTabBarHeight;

const _toolbarLogoSize = 24.0;
const _avatarSize = 32.0;
const _tabLabelHorizontalPadding = 16.0;
const _tabLabelPadding = 2 * _tabLabelHorizontalPadding;
const _addIconSize = 18.0;
const _caretIconSize = 14.0;

double _textWidth(BuildContext context, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: xTabLabelStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The icon after the label of a tab, if it has one: the chevron of For you shows only while it is selected
(IconData, double)? _tabIcon(XFeedTab tab, {required bool selected}) => switch (tab.kind) {
      XFeedTabKind.add => (XIcons.plus, _addIconSize),
      XFeedTabKind.forYou when selected => (XIcons.caretDown, _caretIconSize),
      _ => null,
    };

// Counts the chevron of For you, so that the tabs do not switch between sharing the width and scrolling as the
// selection moves
double _tabWidth(BuildContext context, XFeedTab tab) {
  final icon = _tabIcon(tab, selected: true)?.$2;
  return _textWidth(context, tab.label(L10n.of(context))) + (icon == null ? 0 : icon + 4) + _tabLabelPadding;
}

/// Whether the tabs fit side by side in [maxWidth], sharing it evenly; they only scroll when they do not.
bool xTabsFit(BuildContext context, List<XFeedTab> tabs, double maxWidth) =>
    tabs.fold(0.0, (widest, tab) => max(widest, _tabWidth(context, tab))) * tabs.length <= maxWidth;

Widget _tabWidget(BuildContext context, XFeedTab tab, {required bool selected}) {
  final label = tab.label(L10n.of(context));
  final icon = _tabIcon(tab, selected: selected);
  if (icon == null) {
    return Tab(text: label, height: xTabBarHeight);
  }
  return Tab(
    height: xTabBarHeight,
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      const SizedBox(width: 4),
      Icon(icon.$1, size: icon.$2),
    ]),
  );
}

class _XFeedTabs extends StatelessWidget {
  final List<XFeedTab> tabs;
  final TabController controller;
  final VoidCallback onTap;

  const _XFeedTabs({required this.tabs, required this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: xTabBarHeight,
      child: LayoutBuilder(builder: (context, constraints) {
        final fit = xTabsFit(context, tabs, constraints.maxWidth);
        return TabBar(
          controller: controller,
          isScrollable: !fit,
          tabAlignment: fit ? TabAlignment.fill : TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: _tabLabelHorizontalPadding),
          onTap: (_) => onTap(),
          tabs: List.generate(
              tabs.length, (i) => _tabWidget(context, tabs[i], selected: i == controller.index)),
        );
      }),
    );
  }
}

/// What the Q fills of the Android monochrome icon, which leaves a margin around it, like an icon would
const _logoGlyphWidthFactor = 242 / 432;
const _logoGlyphHeightFactor = 286 / 432;

const xFeedLogoKey = Key('x-feed-logo');

class _XLogo extends StatelessWidget {
  const _XLogo();

  @override
  Widget build(BuildContext context) {
    // The image is scaled up so that the Q, not the whole icon, is as tall as the logo, and its margin is cropped
    return Align(
      key: xFeedLogoKey,
      widthFactor: _logoGlyphWidthFactor,
      heightFactor: _logoGlyphHeightFactor,
      child: Image.asset('assets/icon-monochrome-432x432.png',
          height: _toolbarLogoSize / _logoGlyphHeightFactor,
          color: XStyleColors.of(context).primaryText,
          colorBlendMode: BlendMode.srcIn),
    );
  }
}

/// The header of the home feed in the X design: the account avatar that opens the drawer, the logo, and the tabs, on
/// a frosted bar that starts under the status bar. It is laid over the feed (see [XOverlayFeed]).
class XFeedHeader extends StatelessWidget {
  final List<XFeedTab> tabs;
  final TabController controller;
  final VoidCallback onTabTap;

  const XFeedHeader({super.key, required this.tabs, required this.controller, required this.onTabTap});

  Widget _toolbar(BuildContext context) => SizedBox(
        height: xToolbarHeight,
        child: NavigationToolbar(
          leading: IconButton(
            icon: const XAccountAvatar(size: _avatarSize),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          middle: const _XLogo(),
          trailing: tabs[controller.index].hasSettings
              ? IconButton(
                  icon: const Icon(XIcons.dotsThree),
                  onPressed: () => showFeedSettings(context, context.read<GroupModel>()),
                )
              : null,
          centerMiddle: true,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return XFrostedBar(
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toolbar(context),
            _XFeedTabs(tabs: tabs, controller: controller, onTap: onTabTap),
          ],
        ),
      ),
    );
  }
}
