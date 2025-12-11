import 'package:flutter/material.dart';

const optionDisableAnimations = 'accessibility.disable_animations';
const optionTextScaleFactor = 'accessibility.text_scale_factor';

const optionWizardCompleted = 'option.wizard_completed';

const optionDisableScreenshots = 'disable_screenshots';
const optionHelloLastBuild = 'hello.last_build';

const optionHomePages = 'home.pages';
const optionHomeInitialTab = 'home.initial_tab';

const optionMediaSize = 'media.size';
const optionMediaDefaultMute = 'media.mute';
const optionMediaDefaultLoop = 'media.loop';
const optionMediaDefaultAutoPlay = 'media.auto_play';
const optionMediaBackgroundPlayback = 'media.allow_background_play';
const optionMediaAllowBackgroundPlayOtherApps = 'media.allow_background_play.other_apps';

const optionDownloadType = 'download.type';
const optionDownloadPath = 'download.path';

const optionDownloadTypeDirectory = 'directory';
const optionDownloadTypeAsk = 'ask';

const optionLocale = 'locale';
const optionLocaleDefault = 'system';

const optionShouldCheckForUpdates = 'should_check_for_updates';
const optionConfirmClose = 'confirm_close';
const optionShareBaseUrl = 'share_base_url';

const optionDisableWarningsForUnrelatedPostsInFeed = 'disable_warnings_for_unrelated_posts_in_feed';

const optionSubscriptionGroupsOrderByAscending = 'subscription_groups.order_by.ascending';
const optionSubscriptionGroupsOrderByField = 'subscription_groups.order_by.field';
const optionSubscriptionOrderByAscending = 'subscription.order_by.ascending';
const optionSubscriptionOrderCustom = 'subscription.order_by.custom';
const optionSubscriptionOrderByField = 'subscription.order_by.field';

const optionThemeMode = 'theme.mode';
const optionThemeColor = 'theme.color';
const optionThemeTrueBlack = 'theme.true_black';
const optionThemeTrueBlackTweetCards = 'theme.true_black_tweet_cards';
const optionShowNavigationLabels = 'theme.show_navigation_labels';
const optionUseAbsoluteTimestamp = "option.absolute_timestamp";

const themeColors = {
  'red': Colors.red,
  'orange': Colors.orange,
  'yellow': Colors.yellow,
  'green': Colors.green,
  'blue': Colors.blue,
  'indigo': Colors.indigo,
  'violet': Color.fromARGB(255, 128, 0, 255),
};

const optionTweetsHideSensitive = 'tweets.hide_sensitive';

const optionUserTrendsLocations = 'trends.locations';

const optionNonConfirmationBiasMode = 'other.improve_non_confirmation_bias';

// Default instance of https://github.com/Teskann/x-client-transaction-id-generator
const String optionXClientTransactionIdProviderDefaultDomain = 'x-client-transaction-id-generator.xyz';

const String optionXClientTransactionIdProvider = 'x_client_transaction_id_provider';

final Map<String, String> userAgentHeader = {
  'user-agent':
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.3",
  "Pragma": "no-cache",
  "Cache-Control": "no-cache"
  // "If-Modified-Since": "Sat, 1 Jan 2000 00:00:00 GMT",
};

const String bearerToken =
    "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA";

const routeHome = '/';
const routeGroup = '/group';
const routeProfile = '/profile';
const routeSearch = '/search';
const routeSettings = '/settings';
const routeSettingsExport = '/settings/export';
const routeSettingsHome = '/settings/home';
const routeStatus = '/status';
