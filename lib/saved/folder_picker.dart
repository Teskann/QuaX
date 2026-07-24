import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';

/// Opens the "save to folder" bottom sheet for a post, saving it first if needed.
Future<void> showSaveToFolderSheet(BuildContext context,
    {required String tweetId, String? userId, required Map<String, dynamic> content}) async {
  var savedModel = context.read<SavedTweetModel>();
  var folderModel = context.read<SavedTweetFolderModel>();
  var messenger = ScaffoldMessenger.of(context);

  await folderModel.listFolders();
  await HapticFeedback.lightImpact();

  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => _SaveToFolderSheet(
        tweetId: tweetId,
        userId: userId,
        content: content,
        savedModel: savedModel,
        folderModel: folderModel,
        messenger: messenger),
  );
}

class _SaveToFolderSheet extends StatelessWidget {
  final String tweetId;
  final String? userId;
  final Map<String, dynamic> content;
  final SavedTweetModel savedModel;
  final SavedTweetFolderModel folderModel;
  final ScaffoldMessengerState messenger;

  const _SaveToFolderSheet(
      {required this.tweetId,
      required this.userId,
      required this.content,
      required this.savedModel,
      required this.folderModel,
      required this.messenger});

  Future<void> _file(BuildContext context, String? folderId, String label) async {
    Navigator.pop(context);

    if (savedModel.isSaved(tweetId)) {
      await savedModel.setFolder(tweetId, folderId);
    } else {
      await savedModel.saveTweet(tweetId, userId, content, folderId: folderId);
    }

    messenger.showSnackBar(SnackBar(
      content: Text(L10n.current.saved_to_folder(label)),
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _createAndFile(BuildContext context) async {
    var folder = await showCreateFolderDialog(context, folderModel);
    if (folder != null && context.mounted) {
      await _file(context, folder.id, folder.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ScopedBuilder<SavedTweetFolderModel, List<SavedTweetFolder>>(
        store: folderModel,
        onState: (context, folders) {
          var current = savedModel.folderOf(tweetId);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_add_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).save_to_folder, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FolderTile(
                          label: L10n.of(context).unfiled,
                          selected: current == null,
                          onTap: () => _file(context, null, L10n.of(context).unfiled)),
                      ...folders.map((f) => _FolderTile(
                          label: f.name, selected: current == f.id, onTap: () => _file(context, f.id, f.name))),
                    ],
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(L10n.of(context).create_new_folder),
                onTap: () => _createAndFile(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FolderTile({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
      onTap: onTap,
    );
  }
}

Future<SavedTweetFolder?> showCreateFolderDialog(BuildContext context, SavedTweetFolderModel folderModel,
    {SavedTweetFolder? existing}) {
  return showDialog<SavedTweetFolder>(
    context: context,
    builder: (_) => _EditFolderDialog(folderModel: folderModel, existing: existing),
  );
}

/// Confirms deletion of [folder]; on confirm, deletes it (its posts return to
/// "unfiled") and reloads the saved list. Returns true if it was deleted.
Future<bool> showDeleteFolderDialog(
    BuildContext context, SavedTweetFolderModel folderModel, SavedTweetFolder folder) async {
  var savedModel = context.read<SavedTweetModel>();

  var confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(L10n.of(context).delete_folder),
      content: Text(L10n.of(context).delete_folder_description),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L10n.of(context).cancel)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L10n.of(context).delete)),
      ],
    ),
  );

  if (confirmed != true) {
    return false;
  }

  await folderModel.deleteFolder(folder.id);
  await savedModel.listSavedTweets();
  return true;
}

class _EditFolderDialog extends StatefulWidget {
  final SavedTweetFolderModel folderModel;
  final SavedTweetFolder? existing;

  const _EditFolderDialog({required this.folderModel, this.existing});

  @override
  State<_EditFolderDialog> createState() => _EditFolderDialogState();
}

class _EditFolderDialogState extends State<_EditFolderDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    var name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }

    var existing = widget.existing;
    if (existing == null) {
      var folder = await widget.folderModel.createFolder(name);
      if (mounted) Navigator.pop(context, folder);
    } else {
      await widget.folderModel.updateFolder(existing.id, name);
      if (mounted) {
        Navigator.pop(context, existing.copyWith(name: name));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? L10n.of(context).create_new_folder : L10n.of(context).edit_folder),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: L10n.of(context).folder_name),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).cancel)),
        TextButton(
            onPressed: _submit,
            child: Text(widget.existing == null ? L10n.of(context).create : L10n.of(context).save)),
      ],
    );
  }
}
