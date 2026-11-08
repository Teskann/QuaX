import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_appearance.dart';
import 'package:quax/subscriptions/group_editor.dart';
import 'package:quax/subscriptions/subscription_display.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/users_model.dart';

enum _GroupsSheetChoice { done, newGroup }

Future<void> showGroupsSheet(BuildContext context, List<Subscription> selected, {required VoidCallback onDone}) async {
  final choice = await showModalBottomSheet<_GroupsSheetChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _GroupsSheet(selected: selected),
  );
  if (context.mounted) {
    await context.read<GroupsModel>().reloadGroups();
  }
  switch (choice) {
    case _GroupsSheetChoice.done:
      onDone();
    case _GroupsSheetChoice.newGroup when context.mounted:
      if (await openGroupEditor(context, initialMembers: selected.map(SubscriptionRef.of).toSet())) {
        onDone();
      }
    default:
  }
}

class _GroupsSheet extends StatelessWidget {
  final List<Subscription> selected;

  const _GroupsSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final groups = context.read<GroupsModel>();
    return ScopedBuilder<GroupMembershipsModel, Map<String, Set<SubscriptionRef>>>(
      store: context.read<GroupMembershipsModel>(),
      onState: (_, members) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(l10n.add_to_groups, style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text(membersSummary(context, selected)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: groups.state
                      .map(
                        (group) =>
                            _GroupChoice(group: group, members: members[group.id] ?? const {}, selected: selected),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, _GroupsSheetChoice.newGroup),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.new_group),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, _GroupsSheetChoice.done),
                      child: Text(l10n.done),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupChoice extends StatelessWidget {
  final SubscriptionGroup group;
  final Set<SubscriptionRef> members;
  final List<Subscription> selected;

  const _GroupChoice({required this.group, required this.members, required this.selected});

  @override
  Widget build(BuildContext context) {
    final selectedRefs = selected.map(SubscriptionRef.of).toSet();
    final selectedInGroup = selectedRefs.where(members.contains).length;
    final wholeSelectionInGroup = selectedInGroup == selectedRefs.length;
    final tone = groupTone(context, group.color);
    return CheckboxListTile(
      tristate: true,
      value: wholeSelectionInGroup ? true : (selectedInGroup == 0 ? false : null),
      secondary: CircleAvatar(
        backgroundColor: tone.background,
        child: Icon(group.iconData, color: tone.foreground, size: 22),
      ),
      title: Text(group.name),
      subtitle: Text(_subtitle(context, selectedInGroup, selectedRefs.length)),
      onChanged: (_) => _toggle(context, selectedRefs),
    );
  }

  /// Puts the whole selection in the group, or takes it out when it is all there.
  Future<void> _toggle(BuildContext context, Set<SubscriptionRef> selectedRefs) async {
    final memberships = context.read<GroupMembershipsModel>();
    // Read again rather than from the build: a quick second tap comes before the sheet shows the first one
    final members = memberships.state[group.id] ?? const {};
    await memberships.setMembership(group.id, selectedRefs, member: !members.containsAll(selectedRefs));
  }

  String _subtitle(BuildContext context, int selectedInGroup, int selectedCount) {
    final l10n = L10n.of(context);
    if (selectedInGroup == selectedCount) {
      return l10n.whole_selection_in_group;
    }
    if (selectedInGroup > 0) {
      return l10n.part_of_selection_in_group(selectedInGroup, selectedCount);
    }
    // None of the selection is in the group yet: it shows what the group holds
    final groupMembers = context.read<SubscriptionsModel>().state.where((s) => members.contains(SubscriptionRef.of(s)));
    return membersSummary(context, groupMembers);
  }
}
