import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/_x_topics.dart';
import 'package:quax/subscriptions/_groups.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';

/// The ways to create a timeline, which becomes a tab of the home header.
class XCreateTimelineSheet extends StatelessWidget {
  final VoidCallback onFromAccounts;
  final VoidCallback onFromTopic;

  const XCreateTimelineSheet({super.key, required this.onFromAccounts, required this.onFromTopic});

  Widget _option(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.create_a_timeline, style: Theme.of(context).textTheme.titleLarge),
          ),
          _option(context, XIcons.profile, l10n.from_accounts, onFromAccounts),
          _option(context, XIcons.search, l10n.from_a_topic, onFromTopic),
        ],
      ),
    );
  }
}

/// Offers to create a timeline from accounts (a new group) or from a topic (a saved search in its own group).
void showCreateTimelineSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => XCreateTimelineSheet(
      onFromAccounts: () => openSubscriptionGroupDialog(context, null, '', defaultGroupIcon),
      onFromTopic: () => Navigator.push(context, MaterialPageRoute<String>(builder: (_) => const XTopicsScreen())),
    ),
  );
}

/// What the "add" tab shows: an invitation to create a timeline.
class XAddTimelinesPage extends StatelessWidget {
  final VoidCallback onAdd;

  const XAddTimelinesPage({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    final l10n = L10n.of(context);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(XIcons.timelines, size: 64, color: colors.secondaryText),
                  const SizedBox(height: 16),
                  Text(l10n.explore_your_interests,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.primaryText)),
                  const SizedBox(height: 8),
                  Text(l10n.see_topics_that_interest_you,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: colors.secondaryText)),
                  const SizedBox(height: 24),
                  _AddTimelinesButton(onPressed: onAdd),
                ],
              ),
            ),
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
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
      child: Text(L10n.of(context).add_timelines),
    );
  }
}
