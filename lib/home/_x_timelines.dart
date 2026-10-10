import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/_x_feed_controller.dart';
import 'package:quax/home/_x_topics.dart';
import 'package:quax/subscriptions/_groups.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_overlay_feed.dart';
import 'package:quax/ui/x_sheet.dart';
import 'package:quax/ui/x_style.dart';

/// The ways to create a timeline, which becomes a tab of the home header.
class XCreateTimelineSheet extends StatelessWidget {
  final VoidCallback onFromAccounts;
  final VoidCallback onFromTopic;

  const XCreateTimelineSheet({super.key, required this.onFromAccounts, required this.onFromTopic});

  Widget _option(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return XSheetRow(
      icon: icon,
      label: label,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return XSheet(
      title: l10n.create_a_timeline,
      children: [
        _option(context, XIcons.profile, l10n.from_accounts, onFromAccounts),
        _option(context, XIcons.search, l10n.from_a_topic, onFromTopic),
      ],
    );
  }
}

Widget _topicsScreen(BuildContext context) => const XTopicsScreen();

/// Offers to create a timeline from accounts (a new group) or from a topic (a saved search in its own group), and
/// selects the tab of the new timeline in the home feed.
void showCreateTimelineSheet(BuildContext context, {WidgetBuilder topicsBuilder = _topicsScreen}) {
  final feed = context.read<XFeedController?>();
  showXSheet(
    context,
    (_) => XCreateTimelineSheet(
      onFromAccounts: () => _selectCreated(feed, openSubscriptionGroupDialog(context, null, '', defaultGroupIcon)),
      onFromTopic: () => _selectCreated(feed, Navigator.push<String>(context, MaterialPageRoute(builder: topicsBuilder))),
    ),
  );
}

Future<void> _selectCreated(XFeedController? feed, Future<Object?> created) async {
  final groupId = await created;
  if (groupId is String) feed?.selectGroup(groupId);
}

const _iconSize = 44.0;

/// The invitation is centered in the top 90% of the page, so at 45% of its height
const _centeredFlex = 9;
const _belowFlex = 1;

/// What the "add" tab shows: an invitation to create a timeline.
class XAddTimelinesPage extends StatelessWidget {
  final VoidCallback onAdd;

  const XAddTimelinesPage({super.key, required this.onAdd});

  Widget _invitation(XStyleColors colors, L10n l10n) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(XIcons.timelines, size: _iconSize, color: colors.secondaryText),
            const SizedBox(height: 12),
            Text(l10n.explore_your_interests,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: colors.primaryText)),
            const SizedBox(height: 4),
            Text(l10n.see_topics_that_interest_you,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: colors.secondaryText)),
            const SizedBox(height: 20),
            _AddTimelinesButton(onPressed: onAdd),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    final l10n = L10n.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: XHeaderInset.of(context))),
        SliverFillRemaining(
          hasScrollBody: false,
          // The invitation is centered in the top part of the page, which puts it above the middle
          child: Column(
            children: [
              Expanded(flex: _centeredFlex, child: Center(child: _invitation(colors, l10n))),
              const Spacer(flex: _belowFlex),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddTimelinesButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddTimelinesButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.primaryText,
        foregroundColor: colors.background,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: Text(L10n.of(context).add_timelines),
    );
  }
}
