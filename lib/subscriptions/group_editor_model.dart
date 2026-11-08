import 'package:flutter_triple/flutter_triple.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/subscription_order.dart';

class GroupEditorState {
  final GroupDraft original;
  final GroupDraft draft;

  /// Every subscription, by name.
  final List<Subscription> subscriptions;
  final String query;
  final SubscriptionKind? kind;
  final bool showNameError;
  final bool isClosing;
  final bool showsAllColors;

  const GroupEditorState({
    required this.original,
    required this.draft,
    required this.subscriptions,
    this.query = '',
    this.kind,
    this.showNameError = false,
    this.isClosing = false,
    this.showsAllColors = false,
  });

  bool get hasUnsavedChanges => !draft.hasSameContentAs(original);

  GroupEditorState copyWith({
    GroupDraft? draft,
    String? query,
    SubscriptionKind? Function()? kind,
    bool? showNameError,
    bool? isClosing,
    bool? showsAllColors,
  }) => GroupEditorState(
    original: original,
    draft: draft ?? this.draft,
    subscriptions: subscriptions,
    query: query ?? this.query,
    kind: kind == null ? this.kind : kind(),
    showNameError: showNameError ?? this.showNameError,
    isClosing: isClosing ?? this.isClosing,
    showsAllColors: showsAllColors ?? this.showsAllColors,
  );
}

/// Null until the group is loaded.
class GroupEditorModel extends Store<GroupEditorState?> {
  static final log = Logger('GroupEditorModel');

  final GroupsModel groups;

  GroupEditorModel(this.groups) : super(null);

  /// A new group starts with [initialMembers]. Nothing shows once the editor is closed.
  Future<void> load(String? id, Set<SubscriptionRef> initialMembers, List<Subscription> subscriptions) async {
    final group = await groups.loadGroupDraft(id);
    final draft = id == null ? group.copyWith(members: initialMembers) : group;
    if (!_closed) {
      update(GroupEditorState(original: draft, draft: draft, subscriptions: [...subscriptions]..sort(compareNames)));
    }
  }

  bool _closed = false;

  @override
  Future destroy() {
    _closed = true;
    return super.destroy();
  }

  void _edit(GroupEditorState Function(GroupEditorState state) change) {
    final current = state;
    if (current != null) {
      update(change(current));
    }
  }

  void rename(String name) => _edit((s) => s.copyWith(draft: s.draft.copyWith(name: name), showNameError: false));

  void pickIcon(String icon) => _edit((s) => s.copyWith(draft: s.draft.copyWith(icon: icon)));

  void pickColor(Color? color) => _edit((s) => s.copyWith(draft: s.draft.copyWith(color: () => color)));

  void showAllColors() => _edit((s) => s.copyWith(showsAllColors: true));

  void search(String query) => _edit((s) => s.copyWith(query: query));

  void showKind(SubscriptionKind? kind) => _edit((s) => s.copyWith(kind: () => kind));

  void toggleMember(SubscriptionRef member) => _edit((s) {
    final members = s.draft.members.contains(member)
        ? s.draft.members.where((m) => m != member).toSet()
        : {...s.draft.members, member};
    return s.copyWith(draft: s.draft.copyWith(members: members));
  });

  /// Returns false when the group has no name, is already being saved or deleted, or could not be saved.
  Future<bool> save() async {
    final current = state;
    if (current == null || current.isClosing) {
      return false;
    }
    final name = current.draft.name.trim();
    if (name.isEmpty) {
      update(current.copyWith(showNameError: true));
      return false;
    }
    update(current.copyWith(isClosing: true));
    try {
      await groups.saveGroup(current.draft, name);
      return true;
    } catch (e, stackTrace) {
      log.severe('Unable to save the group', e, stackTrace);
      update(current);
      return false;
    }
  }

  Future<void> delete() async {
    final current = state;
    final id = current?.draft.id;
    if (current != null && id != null) {
      update(current.copyWith(isClosing: true));
      await groups.deleteGroup(id);
    }
  }
}
