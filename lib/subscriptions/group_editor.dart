import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/_search_field.dart';
import 'package:quax/subscriptions/group_appearance.dart';
import 'package:quax/subscriptions/group_appearance_sheet.dart';
import 'package:quax/subscriptions/group_editor_model.dart';
import 'package:quax/subscriptions/subscription_display.dart';
import 'package:quax/subscriptions/subscription_filters.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/confirm.dart';

/// A new group starts with [initialMembers]. Returns whether the group was saved.
Future<bool> openGroupEditor(
  BuildContext context, {
  String? id,
  Set<SubscriptionRef> initialMembers = const {},
}) async =>
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GroupEditorScreen(id: id, initialMembers: initialMembers),
      ),
    ) ??
    false;

class GroupEditorScreen extends StatefulWidget {
  final String? id;
  final Set<SubscriptionRef> initialMembers;

  const GroupEditorScreen({super.key, required this.id, required this.initialMembers});

  @override
  State<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<GroupEditorScreen> {
  late final GroupEditorModel _model = GroupEditorModel(context.read<GroupsModel>());
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model.load(widget.id, widget.initialMembers, context.read<SubscriptionsModel>().state).then((_) {
      _nameController.text = _model.state?.draft.name ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _model.destroy();
    super.dispose();
  }

  Future<void> _save() async {
    if (await _model.save() && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<GroupEditorModel, GroupEditorState?>(
      store: _model,
      onState: (_, state) {
        if (state == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return PopScope(
          canPop: !state.hasUnsavedChanges || state.isClosing,
          onPopInvokedWithResult: (didPop, _) async {
            if (!didPop && await _confirmDiscard(context) && context.mounted) {
              Navigator.pop(context);
            }
          },
          child: Scaffold(
            appBar: _appBar(context, state),
            body: _GroupEditorBody(model: _model, state: state, nameController: _nameController),
          ),
        );
      },
    );
  }

  AppBar _appBar(BuildContext context, GroupEditorState state) {
    final l10n = L10n.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.close,
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(state.draft.id == null ? l10n.new_group : state.original.name),
      actions: [
        FilledButton(onPressed: state.isClosing || !state.hasUnsavedChanges ? null : _save, child: Text(l10n.save)),
        if (state.draft.id == null)
          const SizedBox(width: 12)
        else
          PopupMenuButton<void>(
            tooltip: l10n.more_options,
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => _delete(context, state.draft.name),
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  title: Text(l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, String name) async {
    final l10n = L10n.of(context);
    final confirmed = await confirm(
      context,
      title: l10n.are_you_sure,
      content: l10n.are_you_sure_you_want_to_delete_the_subscription_group_name_of_group(name),
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.delete,
    );
    if (confirmed) {
      await _model.delete();
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}

Future<bool> _confirmDiscard(BuildContext context) {
  final l10n = L10n.of(context);
  return confirm(
    context,
    title: l10n.discard_changes,
    content: l10n.discard_changes_description,
    cancelLabel: l10n.keep_editing,
    confirmLabel: l10n.discard,
  );
}

class _GroupEditorBody extends StatelessWidget {
  final GroupEditorModel model;
  final GroupEditorState state;
  final TextEditingController nameController;

  const _GroupEditorBody({required this.model, required this.state, required this.nameController});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final (:matching, :shown) = filterSubscriptions(state.subscriptions, normalizeQuery(state.query), state.kind);
    // The members of the group as it opened stay first, so that ticking a box never moves a row
    bool wasMember(Subscription s) => state.original.members.contains(SubscriptionRef.of(s));
    final membersWhenOpened = shown.where(wasMember).toList();
    final otherSubscriptions = shown.where((s) => !wasMember(s)).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _NameAndAppearance(model: model, state: state, nameController: nameController),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: CompactSearchField(onChanged: model.search),
          ),
        ),
        SliverToBoxAdapter(
          child: KindFilters(subscriptions: matching, chosen: state.kind, onChosen: model.showKind),
        ),
        ..._section(context, l10n.section_with_count(l10n.in_the_group, state.draft.members.length), membersWhenOpened),
        ..._section(context, l10n.other_subscriptions, otherSubscriptions),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16)),
      ],
    );
  }

  List<Widget> _section(BuildContext context, String title, List<Subscription> subscriptions) {
    if (subscriptions.isEmpty) {
      return const [];
    }
    final theme = Theme.of(context);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ),
      ),
      SliverList.builder(
        itemCount: subscriptions.length,
        itemBuilder: (_, index) {
          final subscription = subscriptions[index];
          return CheckboxListTile(
            key: ValueKey(subscriptionKey(subscription)),
            secondary: SubscriptionAvatar(subscription: subscription),
            title: Text(subscription.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              subscriptionHandle(L10n.of(context), subscription),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: state.draft.members.contains(SubscriptionRef.of(subscription)),
            onChanged: (_) => model.toggleMember(SubscriptionRef.of(subscription)),
          );
        },
      ),
    ];
  }
}

class _NameAndAppearance extends StatelessWidget {
  final GroupEditorModel model;
  final GroupEditorState state;
  final TextEditingController nameController;

  const _NameAndAppearance({required this.model, required this.state, required this.nameController});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppearanceButton(
            tone: groupTone(context, state.draft.color),
            icon: state.draft.icon,
            onPressed: () => openAppearanceSheet(context, model),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: nameController,
              onChanged: model.rename,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.name,
                border: const OutlineInputBorder(),
                errorText: state.showNameError ? l10n.please_enter_a_name : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
