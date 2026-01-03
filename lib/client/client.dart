import 'dart:async';
import 'dart:convert';

import 'package:dart_twitter_api/src/utils/date_utils.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:ffcache/ffcache.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client_regular_account.dart';
import 'package:quax/client/client_unauthenticated.dart';
import 'package:quax/client/headers.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile_model.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/cache.dart';
import 'package:quax/utils/iterables.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:quiver/iterables.dart';

const Duration _defaultTimeout = Duration(seconds: 30);

class _QuackerTwitterClient extends TwitterClient {
  static final log = Logger('_QuackerTwitterClient');

  _QuackerTwitterClient() : super(consumerKey: '', consumerSecret: '', token: '', secret: '');

  @override
  Future<http.Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) {
    return fetch(uri, headers: headers).timeout(timeout ?? _defaultTimeout).then((response) {
      if (response?.statusCode != null && response!.statusCode >= 200 && response.statusCode < 300) {
        return response;
      } else {
        return Future.error(HttpException(response!));
      }
    });
  }

  static Future<http.Response?> fetch(Uri uri, {Map<String, String>? headers}) async {
    final XRegularAccount model = XRegularAccount();
    final authHeader = await TwitterHeaders.getAuthHeader();

    if (authHeader != null) {
      return await model.fetch(uri, headers: headers, log: log, authHeader: authHeader);
    } else {
      return await fetchUnauthenticated(uri, headers: headers, log: log);
    }
  }
}

class UnknownProfileResultType with SyntheticException implements Exception {
  final String type;
  final String message;
  final String uri;

  UnknownProfileResultType(this.type, this.message, this.uri);

  @override
  String toString() {
    return 'Unknown profile result type: {type: $type, message: $message, uri: $uri}';
  }
}

class UnknownProfileUnavailableReason with SyntheticException implements Exception {
  final String reason;
  final String uri;

  UnknownProfileUnavailableReason(this.reason, this.uri);

  @override
  String toString() {
    return 'Unknown profile unavailable reason: {reason: $reason, uri: $uri}';
  }
}

class Twitter {
  static final TwitterApi _twitterApi = TwitterApi(client: _QuackerTwitterClient());

  static final FFCache _cache = FFCache();

  static Map<String, String> defaultParams = {
    'include_profile_interstitial_type': '1',
    'include_blocking': '1',
    'include_blocked_by': '1',
    'include_followed_by': '1',
    'include_mute_edge': '1',
    'include_can_dm': '1',
    'include_can_media_tag': '1',
    'include_ext_has_nft_avatar': '1',
    'include_ext_is_blue_verified': '1',
    'skip_status': '1',
    'cards_platform': 'Web-12',
    'include_cards': '1',
    'include_ext_alt_text': 'true',
    'include_ext_limited_action_results': 'false',
    'include_quote_count': 'true',
    'include_reply_count': '1',
    'tweet_mode': 'extended',
    'include_ext_collab_control': 'true',
    'include_entities': 'true',
    'include_user_entities': 'true',
    'include_ext_media_color': 'true',
    'include_ext_media_availability': 'true',
    'include_ext_sensitive_media_warning': 'true',
    'include_ext_trusted_friends_metadata': 'true',
    'send_error_codes': 'true',
    'simple_quoted_tweet': 'true',
    'pc': '1',
    'spelling_corrections': '1',
    'include_ext_edit_control': 'true',
    'ext':
        'mediaStats,highlightedLabel,hasNftAvatar,voiceInfo,enrichments,superFollowMetadata,unmentionInfo,editControl,collab_control,vibe,'
  };

  static Map<String, bool> gqlFeatures = {
    "blue_business_profile_image_shape_enabled": true,
    "freedom_of_speech_not_reach_fetch_enabled": false,
    "graphql_is_translatable_rweb_tweet_is_translatable_enabled": false,
    "interactive_text_enabled": false,
    "longform_notetweets_consumption_enabled": true,
    "longform_notetweets_richtext_consumption_enabled": true,
    "longform_notetweets_rich_text_read_enabled": false,
    "responsive_web_edit_tweet_api_enabled": false,
    "responsive_web_enhance_cards_enabled": false,
    "responsive_web_graphql_exclude_directive_enabled": true,
    "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
    "responsive_web_graphql_timeline_navigation_enabled": false,
    "responsive_web_text_conversations_enabled": false,
    "responsive_web_twitter_blue_verified_badge_is_enabled": true,
    "spaces_2022_h2_clipping": true,
    "spaces_2022_h2_spaces_communities": true,
    "standardized_nudges_misinfo": false,
    "tweet_awards_web_tipping_enabled": false,
    "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": false,
    "tweetypie_unmention_optimization_enabled": false,
    "verified_phone_label_enabled": false,
    "vibe_api_enabled": false,
    "view_counts_everywhere_api_enabled": true
  };

  static Future<Profile> getProfileById(String id) async {
    var uri = Uri.https('twitter.com', '/i/api/graphql/Qs44y3K0SXxItjNi6mUFQA/UserByRestId', {
      'variables': jsonEncode({
        'userId': id,
        'withHighlightedLabel': true,
        'withSafetyModeUserFields': true,
        'withSuperFollowsUserFields': true
      }),
      'features': jsonEncode({
        'responsive_web_graphql_timeline_navigation_enabled': true,
        'responsive_web_twitter_blue_verified_badge_is_enabled': true,
        'verified_phone_label_enabled': true,
      })
    });

    return _getProfile(uri);
  }

  static Future<Profile> getProfileByScreenName(String screenName) async {
    if (screenName.startsWith('@')) {
      screenName = screenName.substring(1);
    }
    var uri = Uri.https('twitter.com', '/i/api/graphql/qW5u-DAuXpMEG0zA1F7UGQ/UserByScreenName', {
      'variables': jsonEncode({'screen_name': screenName, "withSafetyModeUserFields": true}),
      'features': jsonEncode({
        "hidden_profile_likes_enabled": true,
        "hidden_profile_subscriptions_enabled": true,
        "rweb_tipjar_consumption_enabled": true,
        "responsive_web_graphql_exclude_directive_enabled": true,
        "verified_phone_label_enabled": false,
        "subscriptions_verification_info_is_identity_verified_enabled": true,
        "subscriptions_verification_info_verified_since_enabled": true,
        "highlights_tweets_tab_ui_enabled": true,
        "responsive_web_twitter_article_notes_tab_enabled": true,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "responsive_web_graphql_timeline_navigation_enabled": true
      })
    });

    return _getProfile(uri);
  }

  static Future<Profile> _getProfile(Uri uri) async {
    var response = await _twitterApi.client.get(uri);
    var content = jsonDecode(response.body) as Map<String, dynamic>;

    var hasErrors = content.containsKey('errors');
    if (hasErrors && content['errors'] != null) {
      var errors = List.from(content['errors']);
      if (errors.isEmpty) {
        throw TwitterError(code: 0, message: 'Unknown error', uri: uri.toString());
      } else {
        throw TwitterError(code: errors.first['code'], message: errors.first['message'], uri: uri.toString());
      }
    }

    var result = content['data']?['user']?['result'];
    if (result == null) {
      throw TwitterError(uri: uri.toString(), code: 50, message: L10n.current.user_not_found);
    }

    var resultType = result['__typename'];
    if (resultType != null) {
      switch (resultType) {
        case 'UserUnavailable':
          var code = result['reason'];
          if (code == 'Suspended') {
            throw TwitterError(code: 63, message: result['reason'], uri: uri.toString());
          } else {
            throw TwitterError(code: -1, message: result['reason'], uri: uri.toString());
          }
        case 'User':
          // This means everything's fine
          break;
        default:
          break;
      }
    }

    Logger.detached("").info(result);

    var user = UserWithExtra.fromJson(
        {...result['legacy'], 'id_str': result['rest_id'], 'ext_is_blue_verified': result['is_blue_verified']});
    var pins = List<String>.from(result['legacy']['pinned_tweet_ids_str']);

    return Profile(user, pins);
  }

  static Future<PaginatedUsers> friendsList(String userId, int count) async {
    final uri = Uri.https('x.com', '/i/api/graphql/FEcMGoVOUjm0aU9BJrrGZA/Following', {
      "variables": jsonEncode(
          {"userId": userId, "count": count, "includePromotedContent": false, "withGrokTranslatedBio": false}),
      "features": jsonEncode({
        "rweb_video_screen_enabled": false,
        "payments_enabled": false,
        "profile_label_improvements_pcf_label_in_post_enabled": true,
        "responsive_web_profile_redirect_enabled": false,
        "rweb_tipjar_consumption_enabled": true,
        "verified_phone_label_enabled": false,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_timeline_navigation_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "premium_content_api_read_enabled": false,
        "communities_web_enable_tweet_community_results_fetch": true,
        "c9s_tweet_anatomy_moderator_badge_enabled": true,
        "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
        "responsive_web_grok_analyze_post_followups_enabled": true,
        "responsive_web_jetfuel_frame": true,
        "responsive_web_grok_share_attachment_enabled": true,
        "articles_preview_enabled": true,
        "responsive_web_edit_tweet_api_enabled": true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
        "view_counts_everywhere_api_enabled": true,
        "longform_notetweets_consumption_enabled": true,
        "responsive_web_twitter_article_tweet_consumption_enabled": true,
        "tweet_awards_web_tipping_enabled": false,
        "responsive_web_grok_show_grok_translated_post": false,
        "responsive_web_grok_analysis_button_from_backend": true,
        "creator_subscriptions_quote_tweet_preview_enabled": false,
        "freedom_of_speech_not_reach_fetch_enabled": true,
        "standardized_nudges_misinfo": true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
        "longform_notetweets_rich_text_read_enabled": true,
        "longform_notetweets_inline_media_enabled": true,
        "responsive_web_grok_image_annotation_enabled": true,
        "responsive_web_grok_imagine_annotation_enabled": true,
        "responsive_web_grok_community_note_auto_translation_is_enabled": false,
        "responsive_web_enhance_cards_enabled": false
      })
    });

    return _twitterApi.client.get(uri).then((response) {
      var users = PaginatedUsers()..users = [];
      dynamic instructions =
          jsonDecode(response.body)?["data"]?["user"]?["result"]?["timeline"]?["timeline"]?["instructions"];
      for (final instruction in instructions) {
        if (instruction["type"] != "TimelineAddEntries" || instruction["entries"] == null) continue;
        for (final entry in instruction["entries"]) {
          final userResult = entry["content"]?["itemContent"]?["user_results"]?["result"];
          if (userResult == null) continue;
          var user = UserWithExtra()
            ..screenName = userResult["core"]?["screen_name"]
            ..name = userResult["core"]?["name"]
            ..profileImageUrlHttps = userResult["avatar"]?["image_url"]
            ..verified = userResult["is_blue_verified"]
            ..createdAt = convertTwitterDateTime(userResult["core"]?["created_at"])
            ..idStr = userResult["rest_id"];
          users.users!.add(user);
        }
      }
      return users;
    });
  }

  static Future<Follows> getProfileFollows(String screenName, String type,
      {int? cursor, int? count = 200, String? id}) async {
    if (type == "following" && id == null) {
      id = (await getProfileByScreenName(screenName)).user.idStr;
    }
    var response = type == 'following'
        ? (await friendsList(id!, count!))
        : await _twitterApi.userService
            .followersList(screenName: screenName, cursor: cursor, count: count, skipStatus: true);

    return Follows(
        cursorBottom: int.parse(response.nextCursorStr ?? '-1'),
        cursorTop: int.parse(response.previousCursorStr ?? '-1'),
        users: response.users?.map((e) => UserWithExtra.fromJson(e.toJson())).toList() ?? []);
  }

  static bool isNotPromoted(Map<String, dynamic> item) {
    final bool entryIdContainsPromoted = item['entryId']?.contains("promoted") ?? false;
    final bool hasPromotedMetadata = item['item']?['itemContent']?.containsKey("promotedMetadata") ?? false;
    return !(entryIdContainsPromoted || hasPromotedMetadata);
  }

  static List<TweetChain> createTweetChains(List<dynamic> addEntries) {
    List<TweetChain> replies = [];

    for (var entry in addEntries) {
      var entryId = entry['entryId'] as String;
      if (entryId.startsWith('tweet-')) {
        dynamic result;
        final tweetResults = entry['content']['itemContent']['tweet_results'];

        // This may happen for tweets that x.com cannot open neither
        if (!tweetResults.containsKey("result")) continue;

        if (tweetResults['result']["__typename"] == "TweetWithVisibilityResults") {
          result = tweetResults['result']['tweet'];
        } else {
          result = tweetResults['result'];
        }

        if (result != null && result.containsKey('rest_id')) {
          replies
              .add(TweetChain(id: result['rest_id'], tweets: [TweetWithCard.fromGraphqlJson(result)], isPinned: false));
        } else {
          replies.add(TweetChain(id: entryId.substring(6), tweets: [TweetWithCard.tombstone({})], isPinned: false));
        }
      }

      if (entryId.startsWith('cursor-bottom') || entryId.startsWith('cursor-showMore')) {
        // TODO: Use as the "next page" cursor
      }

      if (entryId.startsWith('conversationthread')) {
        List<TweetWithCard> tweets = [];

        // TODO: This is missing tombstone support
        for (var item in entry['content']['items'].where((e) => isNotPromoted(e))) {
          var itemType = item['item']?['itemContent']?['itemType'];
          if (itemType == 'TimelineTweet') {
            if (item['item']['itemContent']['tweet_results']?['result'] != null) {
              tweets.add(TweetWithCard.fromGraphqlJson(item['item']['itemContent']['tweet_results']['result']));
            }
          }
        }

        // TODO: There must be a better way of getting the conversation ID
        replies.add(TweetChain(id: entryId.replaceFirst('conversationthread-', ''), tweets: tweets, isPinned: false));
      }
    }

    return replies;
  }

  static List<TweetChain> createTweets(List<dynamic> addEntries, [bool isPinned = false]) {
    List<TweetChain> replies = [];

    for (var entry in addEntries) {
      var entryId = entry['entryId'] as String;
      if (entryId.startsWith('tweet-')) {
        var result = entry['content']['itemContent']['tweet_results']['result'];
        TweetWithCard? tweet = TweetWithCard.fromGraphqlJson(result);

        replies
            .add(TweetChain(id: result['rest_id'] ?? result['tweet']['rest_id'], tweets: [tweet], isPinned: isPinned));
      } else if (entryId.startsWith('profile-grid-')) {
        // We got a tweet queried from the media tab
        for (var mediaTweet in entry['content']['items']) {
          var result = mediaTweet['item']['itemContent']['tweet_results']['result'];
          TweetWithCard? tweet = TweetWithCard.fromGraphqlJson(result);
          replies.add(
              TweetChain(id: result['rest_id'] ?? result['tweet']['rest_id'], tweets: [tweet], isPinned: isPinned));
        }
      }

      if (entryId.startsWith('cursor-bottom') || entryId.startsWith('cursor-showMore')) {
        // TODO: Use as the "next page" cursor
      }

      if (entryId.startsWith('profile-conversation')) {
        List<TweetWithCard> tweets = [];

        // TODO: This is missing tombstone support
        for (var item in entry['content']['items']) {
          var itemType = item['item']?['itemContent']?['itemType'];
          if (itemType == 'TimelineTweet') {
            if (item['item']['itemContent']['tweet_results']?['result'] != null) {
              if (item['item']['itemContent']['tweet_results']['result']['tweet'] == null) {
                var tweet = TweetWithCard.fromGraphqlJson(item['item']['itemContent']['tweet_results']['result']);
                tweets.add(tweet);
              } else {
                var tweet =
                    TweetWithCard.fromGraphqlJson(item['item']['itemContent']['tweet_results']['result']['tweet']);
                tweets.add(tweet);
              }
            }
          }
        }

        // TODO: There must be a better way of getting the conversation ID
        replies.add(TweetChain(id: entryId.replaceFirst('profile-conversation-', ''), tweets: tweets, isPinned: false));
      }
    }
    return replies;
  }

  static Future<TweetStatus> getTweet(String id, {String? cursor}) async {
    Map<String, Object> defaultParam = {
      "variables":
          "{\"focalTweetId\":\"1696081434153214389\",\"referrer\":\"profile\",\"controller_data\":\"DAACDAABDAABCgABAAAAAAAAAAAKAAkNObspUxawBQAAAAA=\",\"with_rux_injections\":false,\"includePromotedContent\":false,\"withCommunity\":true,\"withQuickPromoteEligibilityTweetFields\":true,\"withBirdwatchNotes\":true,\"withVoice\":true,\"withV2Timeline\":true}",
      "features":
          "{\"rweb_lists_timeline_redesign_enabled\":true,\"responsive_web_graphql_exclude_directive_enabled\":true,\"verified_phone_label_enabled\":true,\"creator_subscriptions_tweet_preview_api_enabled\":true,\"responsive_web_graphql_timeline_navigation_enabled\":true,\"responsive_web_graphql_skip_user_profile_image_extensions_enabled\":false,\"tweetypie_unmention_optimization_enabled\":true,\"responsive_web_edit_tweet_api_enabled\":true,\"graphql_is_translatable_rweb_tweet_is_translatable_enabled\":true,\"view_counts_everywhere_api_enabled\":true,\"longform_notetweets_consumption_enabled\":true,\"responsive_web_twitter_article_tweet_consumption_enabled\":false,\"tweet_awards_web_tipping_enabled\":false,\"freedom_of_speech_not_reach_fetch_enabled\":true,\"standardized_nudges_misinfo\":true,\"tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled\":true,\"longform_notetweets_rich_text_read_enabled\":true,\"longform_notetweets_inline_media_enabled\":true,\"responsive_web_media_download_video_enabled\":false,\"responsive_web_enhance_cards_enabled\":false}",
      "fieldToggles": "{\"withArticleRichContentState\":false}"
    };

    Map<String, dynamic> variables = json.decode(defaultParam["variables"].toString());
    variables["focalTweetId"] = id;

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    defaultParam["variables"] = json.encode(variables);

    var response = await _twitterApi.client
        .get(Uri.https('twitter.com', '/i/api/graphql/3XDB26fBve-MmjHaWTUZxA/TweetDetail', defaultParam));

    var result = json.decode(response.body);

    var instructions = List.from(result?['data']?['threaded_conversation_with_injections_v2']?['instructions'] ?? []);
    if (instructions.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntriesInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries');
    if (addEntriesInstructions == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntries = List.from(addEntriesInstructions['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));

    // TODO: Could this use createUnconversationedChains at some point?
    var chains = createTweetChains(addEntries);

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static Future<TweetStatus> searchTweets(String query, bool includeReplies,
      {int limit = 25, String? cursor, String product = "Latest"}) async {
    var variables = {
      "rawQuery": query,
      "count": limit.toString(),
      "querySource": "typed_query",
      "product": product,
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    };

    var features = {
      "responsive_web_graphql_exclude_directive_enabled": true,
      "verified_phone_label_enabled": true,
      "creator_subscriptions_tweet_preview_api_enabled": true,
      "responsive_web_graphql_timeline_navigation_enabled": true,
      "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
      "c9s_tweet_anatomy_moderator_badge_enabled": true,
      "tweetypie_unmention_optimization_enabled": true,
      "responsive_web_edit_tweet_api_enabled": true,
      "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
      "view_counts_everywhere_api_enabled": true,
      "longform_notetweets_consumption_enabled": true,
      "responsive_web_twitter_article_tweet_consumption_enabled": true,
      "tweet_awards_web_tipping_enabled": false,
      "freedom_of_speech_not_reach_fetch_enabled": true,
      "standardized_nudges_misinfo": true,
      "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
      "rweb_video_timestamps_enabled": true,
      "longform_notetweets_rich_text_read_enabled": true,
      "longform_notetweets_inline_media_enabled": true,
      "responsive_web_enhance_cards_enabled": false
    };

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    var uri = Uri.https('twitter.com', '/i/api/graphql/flaR-PUMshxFWZWPNpq4zA/SearchTimeline',
        {'variables': jsonEncode(variables), 'features': jsonEncode(features)});

    var response = await _twitterApi.client.get(uri);
    var result = json.decode(response.body);

    var timeline = result?['data']?['search_by_raw_query']?['search_timeline'];
    if (timeline == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    return createUnconversationedChainsGraphql(timeline, 'tweet', [], true, includeReplies);
  }

  static Future<List<UserWithExtra>> searchUsers(String query, {int limit = 25, String? cursor}) async {
    var variables = {
      "rawQuery": query,
      "count": limit.toString(),
      "querySource": "typed_query",
      "product": 'People',
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    };

    var searchFeatures = {
      "responsive_web_graphql_exclude_directive_enabled": true,
      "verified_phone_label_enabled": true,
      "creator_subscriptions_tweet_preview_api_enabled": true,
      "responsive_web_graphql_timeline_navigation_enabled": true,
      "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
      "c9s_tweet_anatomy_moderator_badge_enabled": true,
      "tweetypie_unmention_optimization_enabled": true,
      "responsive_web_edit_tweet_api_enabled": true,
      "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
      "view_counts_everywhere_api_enabled": true,
      "longform_notetweets_consumption_enabled": true,
      "responsive_web_twitter_article_tweet_consumption_enabled": true,
      "tweet_awards_web_tipping_enabled": false,
      "freedom_of_speech_not_reach_fetch_enabled": true,
      "standardized_nudges_misinfo": true,
      "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
      "rweb_video_timestamps_enabled": true,
      "longform_notetweets_rich_text_read_enabled": true,
      "longform_notetweets_inline_media_enabled": true,
      "responsive_web_enhance_cards_enabled": false
    };

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    var uri = Uri.https('twitter.com', '/i/api/graphql/-KWrbTBsPifMuLUqqDiU_A/SearchTimeline',
        {'variables': jsonEncode(variables), 'features': jsonEncode(searchFeatures)});

    var response = await _twitterApi.client.get(uri);
    if (response.body.isEmpty) {
      return [];
    }

    var result = json.decode(response.body);
    if (result.isEmpty) {
      return [];
    }

    List instructions =
        List.from(result?['data']?['search_by_raw_query']?['search_timeline']?['timeline']?['instructions'] ?? []);
    if (instructions.isEmpty) {
      return [];
    }
    List addEntries = List.from(
        instructions.firstWhere((e) => e['type'] == 'TimelineAddEntries', orElse: () => null)?['entries'] ?? []);
    if (addEntries.isEmpty) {
      return [];
    }

    return addEntries
        .where((entry) => entry['entryId']?.startsWith('user-'))
        .where((entry) => entry['content']?['itemContent']?['user_results']?['result']?['legacy'] != null)
        .map((entry) {
      var res = entry['content']['itemContent']['user_results']['result'];
      return UserWithExtra.fromJson(
          {...res['legacy'], 'id_str': res['rest_id'], 'ext_is_blue_verified': res['is_blue_verified']});
    }).toList();
  }

  static Future<List<TrendLocation>> getTrendLocations() async {
    var result = await _cache.getOrCreateAsJSON('trends.locations', const Duration(days: 2), () async {
      var locations = await _twitterApi.trendsService.available();

      return jsonEncode(locations.map((e) => e.toJson()).toList());
    });

    return List.from(jsonDecode(result)).map((e) => TrendLocation.fromJson(e)).toList(growable: false);
  }

  static Future<List<Trends>> getTrends(int location) async {
    var result = await _cache.getOrCreateAsJSON('trends.$location', const Duration(minutes: 2), () async {
      var trends = await _twitterApi.trendsService.place(id: location);

      return jsonEncode(trends.map((e) => e.toJson()).toList());
    });

    return List.from(jsonDecode(result)).map((e) => Trends.fromJson(e)).toList(growable: false);
  }

  static Future<TweetStatus> getTimelineTweets(
    String id,
    String type, {
    List<String>? pinnedTweets,
    int count = 10,
    String? cursor,
    bool includeReplies = true,
    bool includeRetweets = true,
    required int Function() getTweetsCounter,
    required void Function() incrementTweetsCounter,
  }) async {
    bool showPinnedTweet = true;
    Map<String, Object> defaultUserTweetsParam = {
      "variables":
          "{\"userId\":\"160534877\",\"count\":$count,\"includePromotedContent\":false,\"withQuickPromoteEligibilityTweetFields\":true,\"withVoice\":true,\"withV2Timeline\":true}",
      "features":
          "{\"rweb_lists_timeline_redesign_enabled\":true,\"responsive_web_graphql_exclude_directive_enabled\":true,\"verified_phone_label_enabled\":true,\"creator_subscriptions_tweet_preview_api_enabled\":true,\"responsive_web_graphql_timeline_navigation_enabled\":true,\"responsive_web_graphql_skip_user_profile_image_extensions_enabled\":false,\"tweetypie_unmention_optimization_enabled\":true,\"responsive_web_edit_tweet_api_enabled\":true,\"graphql_is_translatable_rweb_tweet_is_translatable_enabled\":true,\"view_counts_everywhere_api_enabled\":true,\"longform_notetweets_consumption_enabled\":true,\"responsive_web_twitter_article_tweet_consumption_enabled\":false,\"tweet_awards_web_tipping_enabled\":false,\"freedom_of_speech_not_reach_fetch_enabled\":true,\"standardized_nudges_misinfo\":true,\"tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled\":true,\"longform_notetweets_rich_text_read_enabled\":true,\"longform_notetweets_inline_media_enabled\":true,\"responsive_web_media_download_video_enabled\":false,\"responsive_web_enhance_cards_enabled\":false}",
      "fieldToggles": "{\"withAuxiliaryUserLabels\":false,\"withArticleRichContentState\":false}"
    };

    Map<String, dynamic> variables = json.decode(defaultUserTweetsParam["variables"].toString());
    variables["userId"] = id;
    if (cursor != null) {
      variables['cursor'] = cursor;
    }
    defaultUserTweetsParam["variables"] = json.encode(variables);

    var response = await _twitterApi.client
        .get(Uri.https('twitter.com', 'i/api/graphql/W4Tpu1uueTGK53paUgxF0Q/HomeTimeline', defaultUserTweetsParam));
    var result = json.decode(response.body);
    //if this page is not first one on the profile page, dont add pinned tweet
    if (variables['cursor'] != null) showPinnedTweet = false;
    return createTimelineChains(
      result,
      'tweet',
      pinnedTweets ?? [],
      includeReplies == false,
      includeReplies,
      showPinnedTweet,
      getTweetsCounter,
      incrementTweetsCounter,
    );
  }

  static Future<TweetStatus> getTweets(String id, String type, List<String> pinnedTweets,
      {int count = 10,
      String? cursor,
      bool includeReplies = true,
      bool includeRetweets = true,
      required int Function() getTweetsCounter,
      required void Function() incrementTweetsCounter}) async {
    bool showPinnedTweet = true;
    var query = {
      ...defaultParams,
      'count': count.toString(),
    };

    Map<String, Object> defaultUserTweetsParam = {
      "variables":
          "{\"userId\":\"160534877\",\"count\":20,\"includePromotedContent\":false,\"withQuickPromoteEligibilityTweetFields\":true,\"withVoice\":true,\"withV2Timeline\":true}",
      "features":
          "{\"rweb_lists_timeline_redesign_enabled\":true,\"responsive_web_graphql_exclude_directive_enabled\":true,\"verified_phone_label_enabled\":true,\"creator_subscriptions_tweet_preview_api_enabled\":true,\"responsive_web_graphql_timeline_navigation_enabled\":true,\"responsive_web_graphql_skip_user_profile_image_extensions_enabled\":false,\"tweetypie_unmention_optimization_enabled\":true,\"responsive_web_edit_tweet_api_enabled\":true,\"graphql_is_translatable_rweb_tweet_is_translatable_enabled\":true,\"view_counts_everywhere_api_enabled\":true,\"longform_notetweets_consumption_enabled\":true,\"responsive_web_twitter_article_tweet_consumption_enabled\":false,\"tweet_awards_web_tipping_enabled\":false,\"freedom_of_speech_not_reach_fetch_enabled\":true,\"standardized_nudges_misinfo\":true,\"tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled\":true,\"longform_notetweets_rich_text_read_enabled\":true,\"longform_notetweets_inline_media_enabled\":true,\"responsive_web_media_download_video_enabled\":false,\"responsive_web_enhance_cards_enabled\":false}",
      "fieldToggles": "{\"withAuxiliaryUserLabels\":false,\"withArticleRichContentState\":false}"
    };

    if (includeReplies) {
      defaultUserTweetsParam["features"] = jsonEncode({
        "rweb_video_screen_enabled": false,
        "payments_enabled": false,
        "profile_label_improvements_pcf_label_in_post_enabled": true,
        "responsive_web_profile_redirect_enabled": false,
        "rweb_tipjar_consumption_enabled": true,
        "verified_phone_label_enabled": false,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_timeline_navigation_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "premium_content_api_read_enabled": false,
        "communities_web_enable_tweet_community_results_fetch": true,
        "c9s_tweet_anatomy_moderator_badge_enabled": true,
        "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
        "responsive_web_grok_analyze_post_followups_enabled": true,
        "responsive_web_jetfuel_frame": true,
        "responsive_web_grok_share_attachment_enabled": true,
        "articles_preview_enabled": true,
        "responsive_web_edit_tweet_api_enabled": true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
        "view_counts_everywhere_api_enabled": true,
        "longform_notetweets_consumption_enabled": true,
        "responsive_web_twitter_article_tweet_consumption_enabled": true,
        "tweet_awards_web_tipping_enabled": false,
        "responsive_web_grok_show_grok_translated_post": false,
        "responsive_web_grok_analysis_button_from_backend": true,
        "creator_subscriptions_quote_tweet_preview_enabled": false,
        "freedom_of_speech_not_reach_fetch_enabled": true,
        "standardized_nudges_misinfo": true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
        "longform_notetweets_rich_text_read_enabled": true,
        "longform_notetweets_inline_media_enabled": true,
        "responsive_web_grok_image_annotation_enabled": true,
        "responsive_web_grok_imagine_annotation_enabled": true,
        "responsive_web_grok_community_note_auto_translation_is_enabled": false,
        "responsive_web_enhance_cards_enabled": false
      });

      defaultUserTweetsParam["filedToggles"] = jsonEncode({"withArticlePlainText": false});
    } else if (type == "media") {
      defaultUserTweetsParam["features"] = jsonEncode({
        "rweb_video_screen_enabled": false,
        "payments_enabled": false,
        "profile_label_improvements_pcf_label_in_post_enabled": true,
        "responsive_web_profile_redirect_enabled": false,
        "rweb_tipjar_consumption_enabled": true,
        "verified_phone_label_enabled": false,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_timeline_navigation_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "premium_content_api_read_enabled": false,
        "communities_web_enable_tweet_community_results_fetch": true,
        "c9s_tweet_anatomy_moderator_badge_enabled": true,
        "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
        "responsive_web_grok_analyze_post_followups_enabled": true,
        "responsive_web_jetfuel_frame": true,
        "responsive_web_grok_share_attachment_enabled": true,
        "articles_preview_enabled": true,
        "responsive_web_edit_tweet_api_enabled": true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
        "view_counts_everywhere_api_enabled": true,
        "longform_notetweets_consumption_enabled": true,
        "responsive_web_twitter_article_tweet_consumption_enabled": true,
        "tweet_awards_web_tipping_enabled": false,
        "responsive_web_grok_show_grok_translated_post": false,
        "responsive_web_grok_analysis_button_from_backend": true,
        "creator_subscriptions_quote_tweet_preview_enabled": false,
        "freedom_of_speech_not_reach_fetch_enabled": true,
        "standardized_nudges_misinfo": true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
        "longform_notetweets_rich_text_read_enabled": true,
        "longform_notetweets_inline_media_enabled": true,
        "responsive_web_grok_image_annotation_enabled": true,
        "responsive_web_grok_imagine_annotation_enabled": true,
        "responsive_web_grok_community_note_auto_translation_is_enabled": false,
        "responsive_web_enhance_cards_enabled": false
      });
      defaultUserTweetsParam["filedToggles"] = jsonEncode({"withArticlePlainText": false});
    }

    Map<String, dynamic> variables = json.decode(defaultUserTweetsParam["variables"].toString());
    variables["userId"] = id;
    if (cursor != null) {
      variables['cursor'] = cursor;
    }
    variables['count'] = count;
    defaultUserTweetsParam["variables"] = json.encode(variables);

    late String path;
    if (type == "media") {
      path = "/i/api/graphql/36oKqyQ7E_9CmtONGjJRsA/UserMedia";
    } else {
      path = includeReplies
          ? "/i/api/graphql/T52C7z3XOxUTSsIn1sQ5MA/UserTweetsAndReplies"
          : '/i/api/graphql/2GIWTr7XwadIixZDtyXd4A/UserTweets';
    }

    var response = await _twitterApi.client.get(Uri.https('x.com', path, defaultUserTweetsParam));

    if (cursor != null) {
      query['cursor'] = cursor;
    }

    var result = json.decode(response.body);

    //if this page is not first one on the profile page, dont add pinned tweet
    if (variables['cursor'] != null) showPinnedTweet = false;
    return createUnconversationedChains(result, 'tweet', pinnedTweets, includeReplies == false, includeReplies,
        showPinnedTweet, getTweetsCounter, incrementTweetsCounter);
  }

  static String? getCursor(List<dynamic> addEntries, List<dynamic> repEntries, String legacyType, String type) {
    String? cursor;

    Map<String, dynamic>? cursorEntry;

    var isLegacyCursor = addEntries.any((element) => element['entryId'].startsWith('cursor'));
    if (isLegacyCursor) {
      cursorEntry = addEntries.firstWhere((e) => e['entryId'].contains(legacyType), orElse: () => null);
    } else {
      cursorEntry = addEntries
          .where((e) => e['entryId'].startsWith('sq-C'))
          .firstWhere((e) => e['content']['operation']['cursor']['cursorType'] == type, orElse: () => null);
    }

    if (cursorEntry != null) {
      var content = cursorEntry['content'];
      if (content.containsKey('value')) {
        cursor = content['value'];
      } else if (content.containsKey('operation')) {
        cursor = content['operation']['cursor']['value'];
      } else {
        cursor = content['itemContent']['value'];
      }
    } else {
      // Look for a "replaceEntry" with the cursor
      var cursorReplaceEntry = repEntries.firstWhere(
          (e) => e.containsKey('replaceEntry')
              ? e['replaceEntry']['entryIdToReplace'].contains(type)
              : e['entry']['content']['cursorType'].contains(type),
          orElse: () => null);

      if (cursorReplaceEntry != null) {
        cursor = cursorReplaceEntry.containsKey('replaceEntry')
            ? cursorReplaceEntry['replaceEntry']['entry']['content']['operation']['cursor']['value']
            : cursorReplaceEntry['entry']['content']['value'];
      }
    }

    return cursor;
  }

  static TweetStatus createUnconversationedChainsGraphql(Map<String, dynamic> result, String tweetIndicator,
      List<String> pinnedTweets, bool mapToThreads, bool includeReplies) {
    var instructions = List.from(result['timeline']['instructions']);
    if (instructions.isEmpty || !instructions.any((e) => e['type'] == 'TimelineAddEntries')) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntries = List.from(instructions.firstWhere((e) => e['type'] == 'TimelineAddEntries')['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    var tweets = _createTweetsGraphql(tweetIndicator, addEntries, includeReplies);

    // First, get all the IDs of the tweets we need to display
    var tweetEntries = addEntries
        .where((e) =>
            e['entryId'].contains(tweetIndicator) &&
            e['content']?['itemContent']?['tweet_results']?['result']?['rest_id'] != null)
        .sorted((a, b) => b['sortIndex'].compareTo(a['sortIndex']))
        .map((e) => e['content']['itemContent']['tweet_results']['result']['rest_id'])
        .cast<String?>()
        .toList();

    Map<String, List<TweetWithCard>> conversations =
        tweets.values.where((e) => tweetEntries.contains(e.idStr)).groupBy((e) {
      // TODO: I don't think a flag is the right way to handle this
      if (mapToThreads) {
        // Then group the tweets-to-display by their conversation ID
        return e.conversationIdStr;
      }

      return e.idStr;
    }).cast<String, List<TweetWithCard>>();

    List<TweetChain> chains = [];

    // Order all the conversations by newest first (assuming the ID is an incrementing key), and create a chain from them
    for (var conversation in conversations.entries.sorted((a, b) => b.key.compareTo(a.key))) {
      var chainTweets = conversation.value.sorted((a, b) => a.idStr!.compareTo(b.idStr!)).toList();

      chains.add(TweetChain(id: conversation.key, tweets: chainTweets, isPinned: false));
    }

    // If we want to show pinned tweets, add them before the chains that we already have
    if (pinnedTweets.isNotEmpty) {
      for (var id in pinnedTweets) {
        // It's possible for the pinned tweet to either not exist, or not be returned, so handle that
        if (tweets.containsKey(id)) {
          chains.insert(0, TweetChain(id: id, tweets: [tweets[id]!], isPinned: true));
        }
      }
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static TweetStatus createUnconversationedChains(
    Map<String, dynamic> result,
    String tweetIndicator,
    List<String> pinnedTweets,
    bool mapToThreads,
    bool includeReplies,
    bool showPinnedTweet,
    int Function() getTweetsCounter,
    void Function() increaseTweetCounter,
  ) {
    final timeline = result["data"]["user"]["result"]["timeline_v2"] ?? result["data"]["user"]["result"]["timeline"];
    var instructions = List.from(timeline['timeline']?['instructions'] ?? []);
    var addEntriesInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries');
    if (addEntriesInstructions == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addPinnedTweetsInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelinePinEntry');
    var addEntries = List.from(addEntriesInstructions['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));
    List addPinnedEntries = List<dynamic>.empty(growable: true);
    if (addPinnedTweetsInstructions != null) {
      addPinnedEntries.add(addPinnedTweetsInstructions['entry']);
    }

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    var chains = createTweets(addEntries);
    // var debugTweets = json.encode(chains);
    //var debugTweets2 = json.encode(addEntries);
    var pinnedChains = createTweets(addPinnedEntries, true);

    //If we want to show pinned tweets, add them before the others that we already have
    if (pinnedTweets.isNotEmpty & showPinnedTweet) {
      chains.insertAll(0, pinnedChains);
    }
    //To prevent infinte loading of tweets while filtering via regex , we have to count added tweets.
    //(infinite loading originating in paged_silver_builder.dart at line 246)
    if (chains.length < 5) increaseTweetCounter();
    //As soon as there is no tweet left that passes regex critera and we also reached maximum attemps
    //to find them, than stop loading more.
    if (chains.length <= 5) {
      cursorBottom = null;
    }
    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static TweetStatus createTimelineChains(
    Map<String, dynamic> result,
    String tweetIndicator,
    List<String> pinnedTweets,
    bool mapToThreads,
    bool includeReplies,
    bool showPinnedTweet,
    int Function() getTweetsCounter,
    void Function() increaseTweetCounter,
  ) {
    var instructions = List.from(result["data"]["home"]["home_timeline_urt"]['instructions']);
    var addEntriesInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries');
    if (addEntriesInstructions == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    var addPinnedTweetsInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelinePinEntry');
    var addEntries = List.from(addEntriesInstructions['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));
    List addPinnedEntries = List<dynamic>.empty(growable: true);
    if (addPinnedTweetsInstructions != null) {
      addPinnedEntries.add(addPinnedTweetsInstructions['entry']);
    }

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');
    var chains = createTweets(addEntries);
    // var debugTweets = json.encode(chains);
    //var debugTweets2 = json.encode(addEntries);
    var pinnedChains = createTweets(addPinnedEntries, true);

    //If we want to show pinned tweets, add them before the others that we already have
    if (pinnedTweets.isNotEmpty & showPinnedTweet) {
      chains.insertAll(0, pinnedChains);
    }
    //To prevent infinte loading of tweets while filtering via regex , we have to count added tweets.
    //(infinite loading originating in paged_silver_builder.dart at line 246)
    if (chains.length < 5) increaseTweetCounter();
    //As soon as there is no tweet left that passes regex critera and we also reached maximum attemps
    //to find them, than stop loading more.
    if (chains.length <= 5) {
      cursorBottom = null;
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static Future<List<UserWithExtra>> getUsers(Iterable<String> ids) async {
    // Split into groups of 100, as the API only supports that many at a time
    List<Future<List<UserWithExtra>>> futures = [];

    var groups = partition(ids, 100);
    for (var group in groups) {
      futures.add(_getUsersPage(group));
    }

    return (await Future.wait(futures)).expand((element) => element).toList();
  }

  static Future<List<UserWithExtra>> _getUsersPage(Iterable<String> ids) async {
    final uri = Uri.https('api.x.com', '/2/users', {
      'user_id': ids.join(','),
    });
    var response = await _twitterApi.client.get(uri, headers: await TwitterHeaders.getHeaders(uri));

    var result = json.decode(response.body);

    return List.from(result).map((e) => UserWithExtra.fromJson(e)).toList(growable: false);
  }

  static Map<String, TweetWithCard> _createTweetsGraphql(
      String entryPrefix, List<dynamic> allTweets, bool includeReplies) {
    bool includeTweet(dynamic t) {
      // Exclude any items that aren't tweets
      if (!t['entryId'].startsWith(entryPrefix)) {
        return false;
      }

      if (t['content']['itemContent']['promotedMetadata'] != null) {
        return false;
      }

      if (t['content']?['itemContent']?['tweet_results']?['result'] == null) {
        return false;
      }

      if (includeReplies) {
        return true;
      }

      // TODO
      return t['in_reply_to_status_id'] == null || t['in_reply_to_user_id'] == null;
    }

    var filteredTweets = allTweets.where(includeTweet);

    var globalTweets = List.from(filteredTweets.map((e) {
      var elm = e['content']['itemContent']['tweet_results']['result'];
      if (elm['rest_id'] == null && elm['tweet'] != null) {
        elm = elm['tweet'];
      }

      return elm;
    }));

    var tweets = [];
    try {
      tweets = globalTweets.map((e) => TweetWithCard.fromGraphqlJson(e)).toList();
    } catch (exc) {
      rethrow;
    }

    return {for (var e in tweets) e.idStr: e};
  }

  static Future<Map<String, dynamic>> getBroadcastDetails(String key) async {
    var response = await _twitterApi.client.get(Uri.https('twitter.com', '/i/api/1.1/live_video_stream/status/$key'));

    return json.decode(response.body);
  }
}

class TweetWithCard extends Tweet {
  String? noteText;
  Entities? noteEntities;
  Map<String, dynamic>? card;
  String? conversationIdStr;
  TweetWithCard? quotedStatusWithCard;
  TweetWithCard? retweetedStatusWithCard;
  bool? isTombstone;

  TweetWithCard();

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['card'] = card;
    json['conversationIdStr'] = conversationIdStr;
    json['quotedStatusWithCard'] = quotedStatusWithCard?.toJson();
    json['retweetedStatusWithCard'] = retweetedStatusWithCard?.toJson();
    json['isTombstone'] = isTombstone;

    return json;
  }

  factory TweetWithCard.tombstone(dynamic e) {
    var tweetWithCard = TweetWithCard();
    tweetWithCard.idStr = '';
    tweetWithCard.isTombstone = true;
    tweetWithCard.text =
        ((e['richText']?['text'] ?? e['text']?['text'] ?? L10n.current.this_tweet_is_unavailable) as String)
            .replaceFirst(' Learn more', '');

    return tweetWithCard;
  }

  factory TweetWithCard.fromJson(Map<String, dynamic> e) {
    var tweet = Tweet.fromJson(e);

    var tweetWithCard = TweetWithCard();
    tweetWithCard.card = e['card'];
    tweetWithCard.conversationIdStr = e['conversationIdStr'];
    tweetWithCard.createdAt = tweet.createdAt;
    tweetWithCard.entities = tweet.entities;
    tweetWithCard.displayTextRange = tweet.displayTextRange;
    tweetWithCard.extendedEntities = tweet.extendedEntities;
    tweetWithCard.favorited = tweet.favorited;
    tweetWithCard.favoriteCount = tweet.favoriteCount;
    tweetWithCard.fullText = tweet.fullText;
    tweetWithCard.idStr = tweet.idStr;
    tweetWithCard.inReplyToScreenName = tweet.inReplyToScreenName;
    tweetWithCard.inReplyToStatusIdStr = tweet.inReplyToStatusIdStr;
    tweetWithCard.inReplyToUserIdStr = tweet.inReplyToUserIdStr;
    tweetWithCard.isQuoteStatus = tweet.isQuoteStatus;
    tweetWithCard.isTombstone = e['is_tombstone'];
    tweetWithCard.lang = tweet.lang;
    tweetWithCard.quoteCount = tweet.quoteCount;
    tweetWithCard.quotedStatusIdStr = tweet.quotedStatusIdStr;
    tweetWithCard.quotedStatusPermalink = tweet.quotedStatusPermalink;
    tweetWithCard.quotedStatusWithCard =
        e['quotedStatusWithCard'] == null ? null : TweetWithCard.fromJson(e['quotedStatusWithCard']);
    tweetWithCard.replyCount = tweet.replyCount;
    tweetWithCard.retweetCount = tweet.retweetCount;
    tweetWithCard.retweeted = tweet.retweeted;
    tweetWithCard.retweetedStatus = tweet.retweetedStatus;
    tweetWithCard.retweetedStatusWithCard =
        e['retweetedStatusWithCard'] == null ? null : TweetWithCard.fromJson(e['retweetedStatusWithCard']);
    tweetWithCard.source = tweet.source;
    tweetWithCard.text = tweet.text;
    tweetWithCard.user = tweet.user;
    tweetWithCard.coordinates = tweet.coordinates;
    tweetWithCard.truncated = tweet.truncated;
    tweetWithCard.place = tweet.place;
    tweetWithCard.possiblySensitive = tweet.possiblySensitive;
    tweetWithCard.possiblySensitiveAppealable = tweet.possiblySensitiveAppealable;

    return tweetWithCard;
  }

  factory TweetWithCard.fromGraphqlJson(Map<String, dynamic> result) {
    dynamic retweetedStatus;
    dynamic quotedStatus;
    dynamic user;

    if (result['tweet'] != null) {
      result = result['tweet']!;
    } else if (result['legacy']?['retweeted_status_result']?['result'] != null) {
      retweetedStatus = TweetWithCard.fromGraphqlJson(result['legacy']['retweeted_status_result']['result']!);
    }

    if (result['quoted_status_result'] != null &&
        result['quoted_status_result']['result'] != null &&
        result['quoted_status_result']['result']?['__typename'] != 'TweetWithVisibilityResults') {
      quotedStatus = TweetWithCard.fromGraphqlJson(result['quoted_status_result']['result']!);
    }

    var resCore = result['core']?['user_results']?['result'];
    if (resCore != null && resCore['legacy'] != null) {
      user = UserWithExtra.fromNonLegacyJson(resCore);
    }

    String? noteText;
    Entities? noteEntities;

    var noteResult = result['note_tweet']?['note_tweet_results']?['result'];
    if (noteResult != null) {
      noteText = noteResult['text'];
      noteEntities = Entities.fromJson(noteResult['entity_set']);
    }

    if (result['tombstone'] != null) {
      return TweetWithCard.tombstone(result['tombstone']!);
    }

    var tweet = TweetWithCard.fromData(
      result['legacy'],
      noteText,
      noteEntities,
      user,
      retweetedStatus,
      quotedStatus,
    );

    if (tweet.card == null && result['card']?['legacy'] != null) {
      tweet.card = result['card']['legacy'];
      var bindingValuesList = tweet.card!['binding_values'] as List?;
      if (bindingValuesList != null) {
        var bindingValues = <String, dynamic>{};
        for (var elm in bindingValuesList) {
          bindingValues[elm['key'] as String] = elm['value'];
        }
        tweet.card!['binding_values'] = bindingValues;
      }
    }

    return tweet;
  }

  factory TweetWithCard.fromCardJson(Map<String, dynamic> tweets, Map<String, dynamic> users, Map<String, dynamic> e) {
    var user = e['user_id_str'] == null ? null : UserWithExtra.fromJson(users[e['user_id_str']]);

    var retweetedStatus = e['retweeted_status_id_str'] == null
        ? null
        : TweetWithCard.fromCardJson(tweets, users, tweets[e['retweeted_status_id_str']]);

    // Some quotes aren't returned, even though we're given their ID, so double check and don't fail with a null value
    TweetWithCard? quotedStatus;
    var quoteId = e['quoted_status_id_str'];
    if (quoteId != null && tweets[quoteId] != null) {
      quotedStatus = TweetWithCard.fromCardJson(tweets, users, tweets[quoteId]);
    }

    return TweetWithCard.fromData(e, null, null, user, retweetedStatus, quotedStatus);
  }

  factory TweetWithCard.fromData(Map<String, dynamic> e, String? noteText, Entities? noteEntities, UserWithExtra? user,
      TweetWithCard? retweetedStatus, TweetWithCard? quotedStatus) {
    TweetWithCard tweet = TweetWithCard();
    tweet.card = e['card'];
    tweet.conversationIdStr = e['conversation_id_str'];
    tweet.createdAt = convertTwitterDateTime(e['created_at']);
    tweet.entities = e['entities'] == null ? null : Entities.fromJson(e['entities']);
    tweet.extendedEntities = e['extended_entities'] == null ? null : Entities.fromJson(e['extended_entities']);
    tweet.favorited = e['favorited'] as bool?;
    tweet.favoriteCount = e['favorite_count'] as int?;
    tweet.fullText = e['full_text'] as String?;
    tweet.idStr = e['id_str'] as String?;
    tweet.inReplyToScreenName = e['in_reply_to_screen_name'] as String?;
    tweet.inReplyToStatusIdStr = e['in_reply_to_status_id_str'] as String?;
    tweet.inReplyToUserIdStr = e['in_reply_to_user_id_str'] as String?;
    tweet.isQuoteStatus = e['is_quote_status'] as bool?;
    tweet.isTombstone = e['is_tombstone'] as bool?;
    tweet.lang = e['lang'] as String?;
    tweet.possiblySensitive = e['possibly_sensitive'] as bool?;
    tweet.quoteCount = e['quote_count'] as int?;
    tweet.quotedStatusIdStr = e['quoted_status_id_str'] as String?;
    tweet.quotedStatusPermalink =
        e['quoted_status_permalink'] == null ? null : QuotedStatusPermalink.fromJson(e['quoted_status_permalink']);
    tweet.replyCount = e['reply_count'] as int?;
    tweet.retweetCount = e['retweet_count'] as int?;
    tweet.retweeted = e['retweeted'] as bool?;
    tweet.source = e['source'] as String?;
    tweet.text = e['text'] ?? e['full_text'] as String?;
    tweet.user = user;

    if (tweet.user != null) {
      tweet.user!.idStr = e['user_id_str'];
    }

    tweet.retweetedStatus = retweetedStatus;
    tweet.retweetedStatusWithCard = retweetedStatus;
    tweet.quotedStatus = quotedStatus;
    tweet.quotedStatusWithCard = quotedStatus;

    tweet.displayTextRange = (e['display_text_range'] as List<dynamic>?)?.map((e) => e as int).toList();

    // TODO
    tweet.coordinates = null;
    tweet.truncated = null;
    tweet.place = null;
    tweet.possiblySensitiveAppealable = null;

    // notes are a new kind of tweets that can be longer, compared to old ones now marked as "legacy" but still used
    tweet.noteText = noteText;
    tweet.noteEntities = noteEntities;

    return tweet;
  }

  static Entities copyEntities(Entities src, Entities trg) {
    if (src.media != null) {
      trg.media = src.media;
    }
    if (src.urls != null) {
      trg.urls = src.urls;
    }
    if (src.userMentions != null) {
      trg.userMentions = src.userMentions;
    }
    if (src.hashtags != null) {
      trg.hashtags = src.hashtags;
    }
    if (src.symbols != null) {
      trg.symbols = src.symbols;
    }
    if (src.polls != null) {
      trg.polls = src.polls;
    }
    return trg;
  }
}

class TweetChain {
  final String id;
  final List<TweetWithCard> tweets;
  final bool isPinned;

  TweetChain({required this.id, required this.tweets, required this.isPinned});

  factory TweetChain.fromJson(Map<String, dynamic> e) {
    var tweets = List.from(e['tweets']).map((e) => TweetWithCard.fromJson(e)).toList();

    return TweetChain(id: e['id'], tweets: tweets, isPinned: e['isPinned']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'tweets': tweets.map((e) => e.toJson()).toList(), 'isPinned': isPinned};
  }
}

class Follows {
  final int? cursorBottom;
  final int? cursorTop;
  final List<UserWithExtra> users;

  Follows({required this.cursorBottom, required this.cursorTop, required this.users});
}

class TweetStatus {
  // final TweetChain after;
  // final TweetChain before;
  final String? cursorBottom;
  final String? cursorTop;
  final List<TweetChain> chains;

  TweetStatus({required this.chains, required this.cursorBottom, required this.cursorTop});
}

class TwitterError {
  final String uri;
  final int code;
  final String message;

  TwitterError({required this.uri, required this.code, required this.message});

  @override
  String toString() {
    return 'TwitterError{code: $code, message: $message, url: $uri}';
  }
}

class SearchHasNoTimelineException {
  final String? query;

  SearchHasNoTimelineException(this.query);

  @override
  String toString() {
    return 'The search has no timeline {query: $query}';
  }
}

class UnknownTimelineItemType with SyntheticException implements Exception {
  final String type;
  final String entryId;

  UnknownTimelineItemType(this.type, this.entryId);

  @override
  String toString() {
    return 'Unknown timeline item type: {type: $type, entryId: $entryId}';
  }
}
