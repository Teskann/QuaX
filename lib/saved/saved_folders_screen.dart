import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/saved/folder_picker.dart';
import 'package:quax/saved/saved_tab_order.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';

class SavedFoldersScreen extends StatefulWidget {
  const SavedFoldersScreen({super.key});

  @override
  State<SavedFoldersScreen> createState() => _SavedFoldersScreenState();
}

class _SavedFoldersScreenState extends State<SavedFoldersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SavedTweetFolderModel>().listFolders();
    context.read<SavedTweetModel>().listSavedTweets();
  }

  SavedTweetFolderModel get _folderModel => context.read<SavedTweetFolderModel>();

  int _countIn(String folderId) =>
      context.read<SavedTweetModel>().state.where((e) => e.folderId == folderId).length;

  Future<void> _rename(SavedTweetFolder folder) async {
    await showCreateFolderDialog(context, _folderModel, existing: folder);
  }

  Future<void> _confirmDelete(SavedTweetFolder folder) async {
    await showDeleteFolderDialog(context, _folderModel, folder);
  }

  Future<void> _onReorder(List<String> tokens, int oldIndex, int newIndex) async {
    var reordered = [...tokens];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));

    await PrefService.of(context, listen: false).set(optionSavedTabOrder, jsonEncode(reordered));
    if (mounted) setState(() {});
  }

  Widget _dragHandle(int index) {
    return ReorderableDragStartListener(
      index: index,
      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.drag_handle)),
    );
  }

  Widget _tabRow(String token, List<SavedTweetFolder> folders, int index) {
    if (token == savedTabAll) {
      return _builtInRow(token, L10n.of(context).all, optionSavedShowAllTab, index);
    }
    if (token == savedTabUnfiled) {
      return _builtInRow(token, L10n.of(context).unfiled, optionSavedShowUnfiledTab, index);
    }

    var folder = folders.firstWhere((f) => f.id == token);
    return ListTile(
      key: ValueKey(token),
      contentPadding: const EdgeInsets.only(left: 24, right: 16),
      title: Text(folder.name),
      subtitle: Text(L10n.of(context).folder_post_count(_countIn(folder.id))),
      onTap: () => _rename(folder),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: L10n.of(context).delete,
            onPressed: () => _confirmDelete(folder),
          ),
          _dragHandle(index),
        ],
      ),
    );
  }

  /// A built-in tab ("All" / "Unfiled") — not deletable, but its visibility in the
  /// Saved tab's folder strip can be toggled.
  Widget _builtInRow(String token, String label, String prefKey, int index) {
    var prefs = PrefService.of(context, listen: false);
    var visible = prefs.get<bool>(prefKey) ?? true;

    return ListTile(
      key: ValueKey(token),
      contentPadding: const EdgeInsets.only(left: 24, right: 16),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
            tooltip: visible ? L10n.of(context).hide : L10n.of(context).show,
            onPressed: () async {
              await prefs.set(prefKey, !visible);
              if (mounted) setState(() {});
            },
          ),
          _dragHandle(index),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).manage_folders),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: L10n.of(context).create_new_folder,
            onPressed: () => showCreateFolderDialog(context, _folderModel),
          ),
        ],
      ),
      body: ScopedBuilder<SavedTweetFolderModel, List<SavedTweetFolder>>(
        store: _folderModel,
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onState: (context, folders) {
          var tokens = orderedSavedTabs(folders, PrefService.of(context, listen: false).get(optionSavedTabOrder));

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: tokens.length,
            onReorderItem: (oldIndex, newIndex) => _onReorder(tokens, oldIndex, newIndex),
            itemBuilder: (context, index) => _tabRow(tokens[index], folders, index),
          );
        },
      ),
    );
  }
}
