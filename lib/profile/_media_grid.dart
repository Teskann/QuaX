import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/media_grid/media_grid.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:quax/profile/media_kind.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/paging.dart';

class ProfileMediaGrid extends StatefulWidget {
  final UserWithExtra user;
  final BasePrefService pref;
  final MediaKindModel kind;

  const ProfileMediaGrid({super.key, required this.user, required this.pref, required this.kind});

  @override
  State<ProfileMediaGrid> createState() => _ProfileMediaGridState();
}

class _ProfileMediaGridState extends State<ProfileMediaGrid> {
  late final Map<MediaKind, CursorPagingController<String, MediaGridItem>> _paging = {
    for (final kind in MediaKind.values) kind: CursorPagingController<String, MediaGridItem>((c) => _fetchPage(kind, c)),
  };

  static const int pageSize = 20;
  int loadTweetsCounter = 0;

  @override
  void dispose() {
    for (final paging in _paging.values) {
      paging.dispose();
    }
    super.dispose();
  }

  void incrementLoadTweetsCounter() {
    ++loadTweetsCounter;
  }

  int getLoadTweetsCounter() {
    return loadTweetsCounter;
  }

  Future<CursorPage<String, MediaGridItem>> _fetchPage(MediaKind kind, String? cursor) async {
    var result = await Twitter.getTweets(
      widget.user.idStr!,
      kind == MediaKind.photos ? 'photos' : 'media',
      const [],
      cursor: cursor,
      count: pageSize,
      includeReplies: false,
      getTweetsCounter: getLoadTweetsCounter,
      incrementTweetsCounter: incrementLoadTweetsCounter,
    );

    final page = mediaPageFromStatus(result, cursor);
    return (items: page.items.where((item) => (item is PhotoGridItem) == (kind == MediaKind.photos)).toList(), nextCursor: page.nextCursor);
  }

  Widget _grid(MediaKind kind) => MediaGrid(
        key: ValueKey(kind),
        controller: _paging[kind]!.pagingController,
        firstPageErrorPrefix: (l10n) => l10n.unable_to_load_the_tweets,
        newPageErrorPrefix: (l10n) => l10n.unable_to_load_the_next_page_of_tweets,
        errorScreenName: widget.user.screenName,
        emptyMessage: L10n.of(context).could_not_find_any_tweets_by_this_user,
      );

  @override
  Widget build(BuildContext context) {
    return Consumer<TweetContextState>(builder: (context, model, child) {
      if (model.hideSensitive && (widget.user.possiblySensitive ?? false)) {
        return EmojiErrorWidget(
          emoji: '🍆🙈🍆',
          message: L10n.current.possibly_sensitive,
          errorMessage: L10n.current.possibly_sensitive_profile,
          onRetry: () async => model.setHideSensitive(false),
          retryText: L10n.current.yes_please,
        );
      }

      return TripleBuilder<MediaKindModel, MediaKind>(
        store: widget.kind,
        builder: (context, triple) => _grid(triple.state),
      );
    });
  }
}
