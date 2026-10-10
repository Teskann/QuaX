import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/home/_feed.dart';
import 'package:quax/home/_missing.dart';
import 'package:quax/home/_saved.dart';
import 'package:quax/home/_x_drawer.dart';
import 'package:quax/home/home_model.dart';
import 'package:quax/search/search.dart';
import 'package:quax/subscriptions/subscriptions.dart';
import 'package:quax/trends/trends_screen.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/x_frosted.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';

typedef NavigationTitleBuilder = String Function(BuildContext context);

class NavigationPage {
  final String id;
  final NavigationTitleBuilder titleBuilder;
  final Widget icon;
  final Widget selectedIcon;

  NavigationPage(this.id, this.titleBuilder, this.icon, this.selectedIcon);
}

final List<NavigationPage> defaultHomePages = [
  NavigationPage('feed', (c) => L10n.of(c).home, const Icon(Icons.home_outlined), const Icon(Icons.home)),
  NavigationPage('subscriptions', (c) => L10n.of(c).subscriptions, const Icon(Icons.people_outlined),
      const Icon(Icons.people)),
  NavigationPage('trending', (c) => L10n.of(c).search, const Icon(Icons.search_outlined), const Icon(Icons.search)),
  NavigationPage(
      'saved', (c) => L10n.of(c).saved, const Icon(Icons.bookmark_border_outlined), const Icon(Icons.bookmark)),
];

/// Frosts the navigation bar of the X design and tops it with a divider.
class _NavigationFrame extends StatelessWidget {
  final Widget child;

  const _NavigationFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!isXStyle(context)) {
      return child;
    }
    return XFrostedBar(child: Column(mainAxisSize: MainAxisSize.min, children: [const Divider(), child]));
  }
}

/// The icon of a page in the navigation bar: the X one in the X design when the page has one.
Widget _pageIcon(NavigationPage page, {required bool selected, required bool xStyle}) {
  final xIcons = xStyle ? XIcons.navigation[page.id] : null;
  if (xIcons == null) {
    return selected ? page.selectedIcon : page.icon;
  }
  return Icon(selected ? xIcons.$2 : xIcons.$1, size: XIcons.navSize);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context);
    var model = context.read<HomeModel>();

    return _HomeScreen(prefs: prefs, model: model);
  }
}

class _HomeScreen extends StatefulWidget {
  final BasePrefService prefs;
  final HomeModel model;

  const _HomeScreen({required this.prefs, required this.model});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  int _initialPage = 0;
  List<NavigationPage> _pages = [];

  @override
  void initState() {
    super.initState();

    _buildPages(widget.model.state);
    widget.model.observer(onState: _buildPages);
  }

  void _buildPages(List<HomePage> state) {
    var pages = state.where((element) => element.selected).map((e) => e.page).toList();

    if (widget.prefs.getKeys().contains(optionHomeInitialTab)) {
      _initialPage = max(0, pages.indexWhere((element) => element.id == widget.prefs.get(optionHomeInitialTab)));
    }

    setState(() {
      _pages = pages;
    });
  }

  final trendsFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<HomeModel, List<HomePage>>.transition(
      store: widget.model,
      onError: (_, e) => ScaffoldErrorWidget(
        prefix: (l10n) => l10n.unable_to_load_home_pages,
        error: e,
        stackTrace: null,
        onRetry: () async => await widget.model.resetPages(),
        retryText: L10n.current.reset_home_pages,
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, state) {
        return ScaffoldWithBottomNavigation(
          pages: _pages,
          prefs: widget.prefs,
          initialPage: _initialPage,
          builder: (scrollControllers, focusNodes) {
            return List.generate(_pages.length, (index) {
              final page = _pages[index];
              if (page.id.startsWith('group-')) {
                return SubscriptionGroupScreen(
                  scrollController: scrollControllers[index]!,
                  id: page.id.replaceAll('group-', ''),
                  name: '',
                );
              }
              switch (page.id) {
                case 'feed':
                  return FeedScreen(
                    scrollController: scrollControllers[index]!,
                    id: '-1',
                    name: L10n.current.feed,
                  );
                case 'subscriptions':
                  return SubscriptionsScreen(
                    scrollController: scrollControllers[index]!,
                  );
                case 'trending':
                  return TrendsScreen(
                    scrollController: scrollControllers[index]!,
                    focusNode: focusNodes[index]!,
                  );
                case 'saved':
                  return SavedScreen(
                    scrollController: scrollControllers[index]!,
                  );
                default:
                  return const MissingScreen();
              }
            });
          },
        );
      },
    );
  }
}

/// A page of the navigation that the user hid from the bottom bar, shown on its own from the drawer of the X design.
Widget _standalonePage(String pageId, ScrollController scrollController) {
  return switch (pageId) {
    'saved' => Scaffold(body: SavedScreen(scrollController: scrollController)),
    _ => SubscriptionsScreen(scrollController: scrollController),
  };
}

class ScaffoldWithBottomNavigation extends StatefulWidget {
  final List<NavigationPage> pages;
  final BasePrefService prefs;
  final int initialPage;
  final List<Widget> Function(Map<int, ScrollController> scrollControllers, Map<int, FocusNode> focusNodes) builder; // changed here

  const ScaffoldWithBottomNavigation(
      {super.key, required this.pages, required this.prefs, required this.initialPage, required this.builder});

  @override
  State<ScaffoldWithBottomNavigation> createState() => _ScaffoldWithBottomNavigationState();
}

class _ScaffoldWithBottomNavigationState extends State<ScaffoldWithBottomNavigation> {
  late PageController _pageController;
  late int _currentPage;
  final Map<int, ScrollController> _scrollControllers = {};
  final Map<int, FocusNode> _focusNodes = {};

  void unfocusOtherPages(){
    _focusNodes.forEach((index, focusNode) {
      if(index != _currentPage) {
        focusNode.unfocus();
      }
    });
  }

  void _switchToPage(String pageId) {
    final index = widget.pages.indexWhere((e) => e.id == pageId);
    if (index >= 0) {
      unfocusOtherPages();
      _pageController.jumpToPage(index);
    }
  }

  Widget _buildDrawer(BuildContext context, bool xStyle) {
    if (xStyle) {
      return XDrawer(
        pageIds: widget.pages.map((e) => e.id).toList(),
        onSwitchPage: _switchToPage,
        pageBuilder: _standalonePage,
      );
    }
    return _buildDefaultDrawer(context);
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    for (int i = 0; i < widget.pages.length; i++) {
      _scrollControllers[i] = ScrollController();
      _focusNodes[i] = FocusNode();
    }
  }

  @override
  void didUpdateWidget(covariant ScaffoldWithBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pages.length != oldWidget.pages.length) {
      // Dispose controllers that are no longer needed.
      _scrollControllers.keys.where((k) => k >= widget.pages.length).toList().forEach((k) {
        _scrollControllers[k]?.dispose();
        _scrollControllers.remove(k);
      });
      // Create controllers for new pages.
      for (int i = 0; i < widget.pages.length; i++) {
        if (!_scrollControllers.containsKey(i)) {
          _scrollControllers[i] = ScrollController();
        }
      }
    }
  }

  Widget _buildDefaultDrawer(BuildContext context) {
    final l10n = L10n.of(context);
    return Drawer(
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.search),
            title: Text(l10n.search),
            onTap: () =>
                Navigator.pushNamed(context, routeSearch, arguments: SearchArguments(0, focusInputOnOpen: true)),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(l10n.settings),
            onTap: () => Navigator.pushNamed(context, routeSettings),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xStyle = isXStyle(context);
    final showLabels = !xStyle && widget.prefs.get(optionShowNavigationLabels);

    // The bars of the X design share one capture of what is behind them
    return BackdropGroup(child: Scaffold(
      extendBody: xStyle,
      drawer: _buildDrawer(context, xStyle),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: widget.builder(_scrollControllers, _focusNodes),
      ),
      bottomNavigationBar: _NavigationFrame(child: NavigationBar(
        selectedIndex: _currentPage,
        labelBehavior: showLabels
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.alwaysHide,
        shadowColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: xStyle ? null : 64,
        destinations: widget.pages.asMap().entries
            .map(
              (e) {
                final page = e.value;
                final hasXIcon = xStyle && XIcons.navigation.containsKey(page.id);
                final scale = showLabels || hasXIcon ? 1.0 : 1.2;
                return NavigationDestination(
                  icon: AnimatedScale(
                    scale: scale,
                    duration: const Duration(milliseconds: 0),
                    curve: Curves.easeOut,
                    child: _pageIcon(page, selected: false, xStyle: xStyle),
                  ),
                  selectedIcon: AnimatedScale(
                    scale: scale,
                    duration: const Duration(milliseconds: 0),
                    curve: Curves.easeOut,
                    child: _pageIcon(page, selected: true, xStyle: xStyle),
                  ),
                  label: page.titleBuilder(context),
                );
              })
            .toList(),
        onDestinationSelected: (index) async {
          if (index == _currentPage) {
            final tappedId = widget.pages[index].id;
            if (tappedId == "feed" || tappedId.startsWith("group-")) {
              final scrollController = _scrollControllers[_currentPage];
              if (scrollController != null) {
                await scrollController.animateTo(0, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
              }
            }
            if (tappedId == "trending") {
              _focusNodes[_currentPage]!.requestFocus();
            }
          }
          unfocusOtherPages();
          _pageController.jumpToPage(index);
        },
      )),
    ));
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
