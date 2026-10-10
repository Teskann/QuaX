import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/_settings.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/_x_account.dart';
import 'package:quax/ui/x_frosted.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';

enum XFeedTabKind { forYou, following, group, add }

/// A tab of the home header of the X design: the two fixed feeds, one tab per group and the one that adds timelines.
class XFeedTab {
  final XFeedTabKind kind;
  final SubscriptionGroup? group;

  const XFeedTab(this.kind, {this.group});

  String get id => group?.id ?? kind.name;

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

const _toolbarLogoSize = 46.0;
const _tabLabelStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
const _tabLabelPadding = 32.0;
const _addIconSize = 18.0;

double _textWidth(BuildContext context, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: _tabLabelStyle),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

double _tabWidth(BuildContext context, XFeedTab tab) {
  final icon = tab.kind == XFeedTabKind.add ? _addIconSize + 4 : 0;
  return _textWidth(context, tab.label(L10n.of(context))) + icon + _tabLabelPadding;
}

/// Whether the tabs fit side by side in [maxWidth]; they only scroll when they do not.
bool xTabsFit(BuildContext context, List<XFeedTab> tabs, double maxWidth) =>
    tabs.fold(0.0, (sum, tab) => sum + _tabWidth(context, tab)) <= maxWidth;

Widget _tabWidget(BuildContext context, XFeedTab tab) {
  final label = tab.label(L10n.of(context));
  if (tab.kind != XFeedTabKind.add) {
    return Tab(text: label);
  }
  return Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      const SizedBox(width: 4),
      const Icon(XIcons.plus, size: _addIconSize),
    ]),
  );
}

class _XFeedTabs extends StatelessWidget implements PreferredSizeWidget {
  final List<XFeedTab> tabs;
  final TabController controller;
  final VoidCallback onTap;

  const _XFeedTabs({required this.tabs, required this.controller, required this.onTap});

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final fit = xTabsFit(context, tabs, constraints.maxWidth);
      return TabBar(
        controller: controller,
        isScrollable: !fit,
        tabAlignment: fit ? TabAlignment.fill : TabAlignment.start,
        labelStyle: _tabLabelStyle,
        unselectedLabelStyle: _tabLabelStyle,
        onTap: (_) => onTap(),
        tabs: tabs.map((e) => _tabWidget(context, e)).toList(),
      );
    });
  }
}

class _XLogo extends StatelessWidget {
  const _XLogo();

  @override
  Widget build(BuildContext context) {
    // The Android monochrome icon leaves a margin around the Q, like an icon would
    return Image.asset('assets/icon-monochrome-432x432.png',
        height: _toolbarLogoSize,
        color: XStyleColors.of(context).primaryText,
        colorBlendMode: BlendMode.srcIn);
  }
}

/// The app bar of the home feed in the X design: the account avatar that opens the drawer, the logo, and the tabs.
class XFeedAppBar extends StatelessWidget {
  final List<XFeedTab> tabs;
  final TabController controller;
  final VoidCallback onTabTap;

  const XFeedAppBar({super.key, required this.tabs, required this.controller, required this.onTabTap});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: const XFrostedBar(child: SizedBox.expand()),
      pinned: false,
      snap: true,
      floating: true,
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const XAccountAvatar(size: 32),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const _XLogo(),
      actions: [
        if (tabs[controller.index].hasSettings)
          IconButton(
            icon: const Icon(XIcons.dotsThree),
            onPressed: () => showFeedSettings(context, context.read<GroupModel>()),
          ),
      ],
      bottom: _XFeedTabs(tabs: tabs, controller: controller, onTap: onTabTap),
    );
  }
}
