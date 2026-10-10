import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/_x_account.dart';
import 'package:quax/home/x_account_model.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/search/search.dart';
import 'package:quax/settings/_account.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/locale_fallback.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';

typedef XDrawerPageBuilder = Widget Function(String pageId, ScrollController scrollController);

Widget _accountsPage(BuildContext context) => const SettingsAccountFragment(key: ValueKey('accounts'));

/// The side drawer of the X design.
///
/// The pages of the bottom navigation ([pageIds]) are switched to with [onSwitchPage]; the others are pushed.
class XDrawer extends StatelessWidget {
  final List<String> pageIds;
  final ValueChanged<String> onSwitchPage;
  final XDrawerPageBuilder pageBuilder;
  final WidgetBuilder accountsBuilder;

  const XDrawer({
    super.key,
    required this.pageIds,
    required this.onSwitchPage,
    required this.pageBuilder,
    this.accountsBuilder = _accountsPage,
  });

  // Closes the drawer before going anywhere, so that it is not left open under the new page
  void _go(BuildContext context, void Function(NavigatorState navigator) action) {
    final navigator = Navigator.of(context);
    navigator.pop();
    action(navigator);
  }

  void _openPage(BuildContext context, String pageId) => pageIds.contains(pageId)
      ? _go(context, (_) => onSwitchPage(pageId))
      : _go(context, (navigator) => navigator.push(MaterialPageRoute(builder: (_) => _StandalonePage(pageId, pageBuilder))));

  void _openProfile(BuildContext context, XAccount account) => _go(
      context,
      (navigator) => navigator.pushNamed(routeProfile,
          arguments: ProfileScreenArguments(null, account.screenName, null)));

  void _openSettings(BuildContext context) => _go(context, (navigator) => navigator.pushNamed(routeSettings));

  void _openSearch(BuildContext context) => _go(
      context,
      (navigator) => navigator.pushNamed(routeSearch, arguments: SearchArguments(0, focusInputOnOpen: true)));

  List<Widget> _items(BuildContext context, XAccountState state) {
    final l10n = L10n.of(context);
    final account = state.account;
    return [
      _XDrawerHeader(state: state, accountsBuilder: accountsBuilder),
      const Divider(),
      _XDrawerItem.primary(
          icon: XIcons.profile,
          label: l10n.profile,
          onTap: account == null ? null : () => _openProfile(context, account)),
      _XDrawerItem.primary(icon: XIcons.bookmark, label: l10n.bookmarks, onTap: () => _openPage(context, 'saved')),
      _XDrawerItem.primary(
          icon: XIcons.lists, label: l10n.lists, onTap: () => _openPage(context, 'subscriptions')),
      const Divider(),
      _XDrawerItem.secondary(
          icon: XIcons.settings, label: l10n.settings_and_privacy, onTap: () => _openSettings(context)),
      if (!pageIds.contains('trending'))
        _XDrawerItem.secondary(icon: XIcons.search, label: l10n.search, onTap: () => _openSearch(context)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: XStyleColors.of(context).background,
      child: SafeArea(
        child: XAccountBuilder(
          builder: (context, state) => Column(
            children: [
              Expanded(child: ListView(padding: EdgeInsets.zero, children: _items(context, state))),
              const Align(alignment: Alignment.centerLeft, child: _ThemeToggle()),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page of the bottom navigation, pushed on its own because the user hid it from the navigation.
class _StandalonePage extends StatefulWidget {
  final String pageId;
  final XDrawerPageBuilder builder;

  const _StandalonePage(this.pageId, this.builder);

  @override
  State<_StandalonePage> createState() => _StandalonePageState();
}

class _StandalonePageState extends State<_StandalonePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.pageId, _scrollController);
}

class _XDrawerHeader extends StatelessWidget {
  final XAccountState state;
  final WidgetBuilder accountsBuilder;

  const _XDrawerHeader({required this.state, required this.accountsBuilder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const XAccountAvatar(size: 48),
              IconButton.outlined(
                icon: const Icon(XIcons.dotsThreeVertical),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: accountsBuilder)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _identity(context),
        ],
      ),
    );
  }

  Widget _identity(BuildContext context) {
    final account = state.account;
    if (account != null) {
      return _XAccountIdentity(account: account);
    }
    if (!state.loaded) {
      return const SizedBox.shrink();
    }
    return FilledButton(onPressed: () => openAddAccount(context), child: Text(L10n.of(context).add_account));
  }
}

class _XAccountIdentity extends StatelessWidget {
  final XAccount account;

  const _XAccountIdentity({required this.account});

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(account.name ?? account.screenName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: colors.primaryText)),
        Text('@${account.screenName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, color: colors.secondaryText)),
        _XFollowCounts(account: account),
      ],
    );
  }
}

class _XFollowCounts extends StatelessWidget {
  final XAccount account;

  const _XFollowCounts({required this.account});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final counts = [(account.following, l10n.following), (account.followers, l10n.followers)]
        .where((e) => e.$1 != null)
        .toList();
    if (counts.isEmpty) {
      return const SizedBox.shrink();
    }
    final format = NumberFormat.compact(locale: safeIntlLocale());
    final colors = XStyleColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 16,
        children: counts
            .map((e) => Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: format.format(e.$1),
                        style: TextStyle(fontWeight: FontWeight.bold, color: colors.primaryText)),
                    TextSpan(text: ' ${e.$2}', style: TextStyle(color: colors.secondaryText)),
                  ]),
                  style: const TextStyle(fontSize: 15),
                ))
            .toList(),
      ),
    );
  }
}

class _XDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double iconSize;
  final double fontSize;
  final FontWeight weight;
  final double height;

  const _XDrawerItem.primary({required this.icon, required this.label, required this.onTap})
      : iconSize = 28,
        fontSize = 26,
        weight = FontWeight.bold,
        height = 64;

  const _XDrawerItem.secondary({required this.icon, required this.label, required this.onTap})
      : iconSize = 24,
        fontSize = 20,
        weight = FontWeight.normal,
        height = 52;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(icon, size: iconSize),
            const SizedBox(width: 20),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: fontSize, fontWeight: weight)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton(
        iconSize: 28,
        icon: Icon(dark ? XIcons.moonStars : XIcons.sun),
        onPressed: () => PrefService.of(context).set(optionThemeMode, dark ? 'light' : 'dark'),
      ),
    );
  }
}
