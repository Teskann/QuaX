import 'dart:convert';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_triple/flutter_triple.dart';

import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/saved/folder_picker.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tab_order.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/errors.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class SavedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final bool? showTitle;

  const SavedScreen({super.key, required this.scrollController, this.showTitle});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with AutomaticKeepAliveClientMixin<SavedScreen> {
  // Selected folder filter: savedTabAll, savedTabUnfiled, or a folder id.
  String _filter = savedTabAll;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    context.read<SavedTweetModel>().listSavedTweets();
    context.read<SavedTweetFolderModel>().listFolders();
    context.read<LikedTweetModel>().listLikedTweets();
  }

  // If the selected tab is no longer reachable (folder deleted elsewhere, or its
  // built-in tab was hidden in settings), fall back to "All".
  void _reconcileFilter(List<SavedTweetFolder> folders, {required bool showUnfiled, required bool showFavorites}) {
    var reachable = _filter == savedTabAll ||
        (_filter == savedTabUnfiled && showUnfiled && folders.isNotEmpty) ||
        (_filter == savedTabFavorites && showFavorites) ||
        folders.any((f) => f.id == _filter);
    if (reachable) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _filter = savedTabAll);
      }
    });
  }

  Future<void> _refresh() async {
    // Silent reload: keeps the current list on screen while the RefreshIndicator
    // spinner runs, and swaps in the fresh data only once it is ready.
    if (_filter == savedTabFavorites) {
      await context.read<LikedTweetModel>().refreshLikedTweets();
    } else {
      await context.read<SavedTweetModel>().refreshSavedTweets();
    }
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Text(switch (_filter) {
              savedTabAll => L10n.of(context).you_have_not_saved_any_tweets_yet,
              savedTabFavorites => L10n.of(context).no_liked_posts_yet,
              _ => L10n.of(context).folder_is_empty,
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildList({required int itemCount, required SavedTweetTile Function(int) tileAt}) {
    return ListView.builder(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      itemCount: itemCount,
      itemBuilder: (context, index) => tileAt(index),
    );
  }

  List<SavedTweet> _applyFilter(List<SavedTweet> tweets) {
    switch (_filter) {
      case savedTabAll:
        return tweets;
      case savedTabUnfiled:
        return tweets.where((e) => e.folderId == null).toList();
      default:
        return tweets.where((e) => e.folderId == _filter).toList();
    }
  }

  Widget _buildFolderStrip() {
    var prefs = PrefService.of(context, listen: false);
    var showAll = prefs.get<bool>(optionSavedShowAllTab) ?? true;
    var showUnfiled = prefs.get<bool>(optionSavedShowUnfiledTab) ?? true;
    var showFavorites = prefs.get<bool>(optionSavedShowFavoritesTab) ?? true;
    var storedOrder = prefs.get<String>(optionSavedTabOrder);

    return ScopedBuilder<SavedTweetFolderModel, List<SavedTweetFolder>>(
      store: context.read<SavedTweetFolderModel>(),
      onState: (context, folders) {
        // Reconcile before the empty check, otherwise deleting the last folder would
        // leave `_filter` stranded on a now-deleted id (the strip returns early).
        _reconcileFilter(folders, showUnfiled: showUnfiled, showFavorites: showFavorites);

        // With no folders, only show the strip when the Favorites tab is available to
        // switch to — otherwise there is nothing to switch between (just "All").
        if (folders.isEmpty && !showFavorites) {
          return const SizedBox.shrink();
        }

        var chips = <Widget>[];
        for (var token in orderedSavedTabs(folders, storedOrder)) {
          if (token == savedTabAll) {
            if (showAll) chips.add(_folderChip(label: L10n.of(context).all, value: savedTabAll));
          } else if (token == savedTabUnfiled) {
            // "Unfiled" only makes sense with folders — otherwise it duplicates "All".
            if (showUnfiled && folders.isNotEmpty) {
              chips.add(_folderChip(label: L10n.of(context).unfiled, value: savedTabUnfiled));
            }
          } else if (token == savedTabFavorites) {
            if (showFavorites) chips.add(_folderChip(label: L10n.of(context).favorites, value: savedTabFavorites));
          } else {
            var matches = folders.where((f) => f.id == token);
            if (matches.isNotEmpty) chips.add(_folderChip(label: matches.first.name, value: token));
          }
        }

        return SizedBox(
          height: 52,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: chips),
            ),
          ),
        );
      },
    );
  }

  Widget _folderChip({required String label, required String value}) {
    var isFolder = value != savedTabAll && value != savedTabUnfiled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onLongPress: isFolder ? () => _showFolderMenu(value, label) : null,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ChoiceChip(
            label: Text(label),
            selected: _filter == value,
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide.none,
            onSelected: (_) => setState(() => _filter = value),
          ),
        ),
      ),
    );
  }

  Future<void> _showFolderMenu(String folderId, String label) async {
    var folderModel = context.read<SavedTweetFolderModel>();
    var matches = folderModel.state.where((f) => f.id == folderId);
    if (matches.isEmpty) {
      return;
    }
    var folder = matches.first;

    await HapticFeedback.lightImpact();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.edit_outlined),
              title: Text(L10n.of(sheetContext).rename),
              onTap: () {
                Navigator.pop(sheetContext);
                showCreateFolderDialog(context, folderModel, existing: folder);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.delete_outline),
              title: Text(L10n.of(sheetContext).delete),
              onTap: () async {
                Navigator.pop(sheetContext);
                var deleted = await showDeleteFolderDialog(context, folderModel, folder);
                if (deleted && mounted && _filter == folderId) {
                  setState(() => _filter = savedTabAll);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.folder_copy_outlined),
              title: Text(L10n.of(sheetContext).manage_folders),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Navigator.pushNamed(context, routeSavedFolders);
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedBody(SavedTweetModel model) {
    return ScopedBuilder<SavedTweetModel, List<SavedTweet>>.transition(
      store: model,
      onError: (_, e) => FullPageErrorWidget(
        error: e,
        stackTrace: null,
        prefix: L10n.current.unable_to_load_the_tweets,
        onRetry: () => model.listSavedTweets(),
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, data) {
        var filtered = _applyFilter(data);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: filtered.isEmpty
              ? _buildEmptyState()
              : _buildList(
                  itemCount: filtered.length,
                  tileAt: (i) => SavedTweetTile(id: filtered[i].id, content: filtered[i].content)),
        );
      },
    );
  }

  Widget _buildFavoritesBody() {
    var model = context.read<LikedTweetModel>();

    return ScopedBuilder<LikedTweetModel, List<LikedTweet>>.transition(
      store: model,
      onError: (_, e) => FullPageErrorWidget(
        error: e,
        stackTrace: null,
        prefix: L10n.current.unable_to_load_the_tweets,
        onRetry: () => model.listLikedTweets(),
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, data) => RefreshIndicator(
        onRefresh: _refresh,
        child: data.isEmpty
            ? _buildEmptyState()
            : _buildList(
                itemCount: data.length,
                tileAt: (i) => SavedTweetTile(id: data[i].id, content: data[i].content)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var model = context.read<SavedTweetModel>();

    var prefs = PrefService.of(context, listen: false);

    return NestedScrollView(
      controller: widget.scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          if (widget.showTitle != false)
            SliverAppBar(
              pinned: false,
              snap: true,
              floating: true,
              title: Text(L10n.current.saved),
              actions: [
                IconButton(
                    icon: const Icon(Icons.folder_copy_outlined),
                    tooltip: L10n.current.manage_folders,
                    onPressed: () async {
                      await Navigator.pushNamed(context, routeSavedFolders);
                      if (mounted) {
                        setState(() {});
                      }
                    }),
                IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () async {
                      Navigator.pushNamed(context, routeSettings);
                    })
              ],
            )
        ];
      },
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<TweetContextState>(
              create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive))),
        ],
        child: Column(
          children: [
            _buildFolderStrip(),
            Expanded(
              child: _filter == savedTabFavorites ? _buildFavoritesBody() : _buildSavedBody(model),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedTweetTile extends StatelessWidget {
  final String id;
  final String? content;

  const SavedTweetTile({super.key, required this.id, this.content});

  @override
  Widget build(BuildContext context) {
    var content = this.content;
    if (content == null) {
      // The tweet is probably too big to fit inside the cursor and has been removed from the result set
      return SavedTweetTooLarge(id: id);
    }

    var tweet = TweetWithCard.fromJson(jsonDecode(content));

    return TweetTile(key: Key(tweet.idStr!), tweet: tweet, clickable: true);
  }
}

class SavedTweetTooLarge extends StatelessWidget {
  final String id;

  const SavedTweetTooLarge({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading:
                  Icon(Icons.error_outline, color: Colors.red.harmonizeWith(Theme.of(context).colorScheme.primary)),
              title: Text(L10n.current.oops_something_went_wrong),
              subtitle: Text(L10n.current.saved_tweet_too_large),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedTweetTooLargeException implements Exception {
  final String id;

  SavedTweetTooLargeException(this.id);

  @override
  String toString() {
    return 'The saved tweet with the ID $id was too large';
  }
}
