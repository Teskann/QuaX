import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:flutter/services.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:quax/client/accounts.dart';

import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/feed_session_cache.dart';
import 'package:quax/tweet/video_controller_pool.dart';
import 'package:quax/tweet/video_player_budget.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/home/_feed.dart';
import 'package:quax/home/home_model.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/onboarding/onboarding_screen.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_folders_screen.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_model.dart';
import 'package:quax/settings/_home.dart';
import 'package:quax/settings/settings.dart';
import 'package:quax/settings/settings_export_screen.dart';
import 'package:quax/status.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/trends/trends_model.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/ui/discord_popup.dart';
import 'package:quax/ui/errors.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/utils/urls.dart';
import 'package:secure_content/secure_content.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:app_links/app_links.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<void> checkForUpdates(BuildContext context) async {
  Logger.root.info('Checking for updates');

  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final client = HttpClient();
  client.userAgent =
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36";

  final request = await client.getUrl(Uri.parse("https://api.github.com/repos/teskann/quax/releases/latest"));
  final response = await request.close();

  if (response.statusCode == 200) {
    final contentAsString = await utf8.decodeStream(response);
    final Map<dynamic, dynamic> map = json.decode(contentAsString);
    if (map["tag_name"] != null) {
      if (map["tag_name"] != 'v${packageInfo.version}') {
        if (!context.mounted) {
          return;
        }

        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(L10n.of(context).an_update_for_fritter_is_available),
              content: Text(L10n.of(context).view_version_on_github(map["tag_name"])),
              actions: [
                TextButton(
                  child: Text(L10n.of(context).dismiss),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text(L10n.of(context).view_on_github),
                  onPressed: () async {
                    await openUri(context, map['html_url']);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      } else if (map['html_url'].isEmpty) {
        Logger.root.severe('Unable to check for updates');
      }
    }
  }
}

class UnableToCheckForUpdatesException {
  final String body;

  UnableToCheckForUpdatesException(this.body);

  @override
  String toString() {
    return 'Unable to check for updates: {body: $body}';
  }
}

void setTimeagoLocales() {
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('az', timeago.AzMessages());
  timeago.setLocaleMessages('ca', timeago.CaMessages());
  timeago.setLocaleMessages('cs', timeago.CsMessages());
  timeago.setLocaleMessages('da', timeago.DaMessages());
  timeago.setLocaleMessages('de', timeago.DeMessages());
  timeago.setLocaleMessages('dv', timeago.DvMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());
  timeago.setLocaleMessages('es', timeago.EsMessages());
  timeago.setLocaleMessages('fa', timeago.FaMessages());
  timeago.setLocaleMessages('fr', timeago.FrMessages());
  timeago.setLocaleMessages('gr', timeago.GrMessages());
  timeago.setLocaleMessages('he', timeago.HeMessages());
  timeago.setLocaleMessages('he', timeago.HeMessages());
  timeago.setLocaleMessages('hi', timeago.HiMessages());
  timeago.setLocaleMessages('id', timeago.IdMessages());
  timeago.setLocaleMessages('it', timeago.ItMessages());
  timeago.setLocaleMessages('ja', timeago.JaMessages());
  timeago.setLocaleMessages('km', timeago.KmMessages());
  timeago.setLocaleMessages('ko', timeago.KoMessages());
  timeago.setLocaleMessages('ku', timeago.KuMessages());
  timeago.setLocaleMessages('mn', timeago.MnMessages());
  timeago.setLocaleMessages('ms_MY', timeago.MsMyMessages());
  timeago.setLocaleMessages('nb_NO', timeago.NbNoMessages());
  timeago.setLocaleMessages('nl', timeago.NlMessages());
  timeago.setLocaleMessages('nn_NO', timeago.NnNoMessages());
  timeago.setLocaleMessages('pl', timeago.PlMessages());
  timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
  timeago.setLocaleMessages('ro', timeago.RoMessages());
  timeago.setLocaleMessages('ru', timeago.RuMessages());
  timeago.setLocaleMessages('sv', timeago.SvMessages());
  timeago.setLocaleMessages('ta', timeago.TaMessages());
  timeago.setLocaleMessages('th', timeago.ThMessages());
  timeago.setLocaleMessages('tr', timeago.TrMessages());
  timeago.setLocaleMessages('uk', timeago.UkMessages());
  timeago.setLocaleMessages('vi', timeago.ViMessages());
  timeago.setLocaleMessages('zh_CN', timeago.ZhCnMessages());
  timeago.setLocaleMessages('zh', timeago.ZhMessages());
}

// One-time split of the former single "media size" pref into separate image and
// video quality settings, plus a data-saver toggle for its old "disabled" value.
Future<void> _migrateMediaQualityPrefs(BasePrefService prefs) async {
  if (prefs.get<bool>(optionMediaQualitySplitMigrated) ?? false) {
    return;
  }

  final previous = prefs.get<String>(optionImageQuality);
  final disabled = previous == 'disabled';
  // The old "disabled" value carried no real quality, so fall back to Maximum.
  final quality = disabled ? 'large' : (previous ?? 'medium');

  await prefs.set(optionMediaDisableAutoload, disabled);
  await prefs.set(optionImageQuality, quality);
  await prefs.set(optionMediaVideoQuality, quality);
  await prefs.set(optionMediaQualitySplitMigrated, true);
}

// Decided on the first launch only, so that a newcomer who logs in, then leaves, gets the onboarding back
Future<void> _decideOnboarding(BasePrefService prefs, SubscriptionsModel subscriptionsModel) async {
  if (prefs.get<bool>(optionOnboardingDone) != null) {
    return;
  }
  final setUp = subscriptionsModel.state.isNotEmpty || (await getAccounts()).isNotEmpty;
  await prefs.set(optionOnboardingDone, setUp);
}

Future<void> main() async {
  Logger.root.level = defaultLogLevel(release: kReleaseMode || kProfileMode);
  Logger.root.onRecord.listen((event) async {
    log(event.message, error: event.error, stackTrace: event.stackTrace);
  });

  if (Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  WidgetsFlutterBinding.ensureInitialized();

  setTimeagoLocales();

  final prefService = await PrefServiceShared.init(prefix: 'pref_', defaults: {
    optionConfirmClose: true,
    optionDisableAnimations: false,
    optionTextScaleFactor: 1.1,
    optionDisableScreenshots: false,
    optionDownloadPath: '',
    optionDownloadType: optionDownloadTypeAsk,
    optionHomePages: defaultHomePages.map((e) => e.id).toList(),
    optionLocale: optionLocaleDefault,
    optionHomeInitialTab: 'feed',
    optionHomeDefaultFeedTab: feedTabs[0].id.name,
    optionImageQuality: 'medium',
    optionMediaVideoQuality: 'medium',
    optionMediaDisableAutoload: false,
    optionMediaQualitySplitMigrated: false,
    optionMediaGridColumns: 3,
    optionMediaDefaultMute: true,
    optionMediaDefaultLoop: false,
    optionMediaDefaultAutoPlay: false,
    optionMediaBackgroundPlayback: true,
    optionMediaAllowBackgroundPlayOtherApps: false,
    optionMediaVideoPrefetchSeconds: 0,
    optionNonConfirmationBiasMode: false,
    optionShouldCheckForUpdates: true,
    optionOpenLinksInEmbeddedBrowser: false,
    optionDiscordPopupDismissed: false,
    optionSubscriptionGroupsOrderByAscending: true,
    optionDisableWarningsForUnrelatedPostsInFeed: false,
    alwaysShowFullTweetContents: false,
    optionSubscriptionGroupsOrderByField: 'name',
    optionSubscriptionOrderByAscending: true,
    optionSubscriptionOrderByField: 'name',
    optionSubscriptionOrderCustom: '',
    optionThemeMode: 'system',
    optionThemeColor: 'accent',
    optionThemeTrueBlack: false,
    optionThemeTrueBlackTweetCards: false,
    optionShowNavigationLabels: false,
    optionTweetsHideSensitive: true,
    optionSavedShowAllTab: true,
    optionSavedShowUnfiledTab: true,
    optionSavedShowFavoritesTab: true,
    optionSavedTabOrder: '',
    optionSavedFolderHintShown: false,
    optionLikedFirstToastShown: false,
    optionUseAbsoluteTimestamp: false,
    optionDefaultProfileTab: profileTabs[0].id.name,
    optionUserTrendsLocations: jsonEncode({
      'active': {'name': 'Worldwide', 'woeid': 1},
      'locations': [
        {'name': 'Worldwide', 'woeid': 1}
      ]
    }),
  });

  await _migrateMediaQualityPrefs(prefService);

  try {
    // Run the migrations early, so models work. We also do this later on so we can display errors to the user
    try {
      await Repository().migrate();
    } catch (_) {
      // Ignore, as we'll catch it later instead
    }

    var importDataModel = ImportDataModel();

    var groupsModel = GroupsModel(prefService);
    await groupsModel.reloadGroups();

    var homeModel = HomeModel(prefService, groupsModel);
    await homeModel.loadPages();

    var subscriptionsModel = SubscriptionsModel(prefService, groupsModel);
    await subscriptionsModel.reloadSubscriptions();

    await _decideOnboarding(prefService, subscriptionsModel);

    var feedSessionCache = FeedSessionCache();
    // Registration order matters: invalidateAll must run before any
    // GroupFeedShell reload listener, so by the time the shell remounts the
    // body via KeyedSubtree, the inner feed reads fresh controllers from the
    // cache. LinkedHashMap iterates in insertion order, and registering here
    // (before any shell exists) guarantees we win.
    groupsModel.addReloadListener('FeedSessionCache', feedSessionCache.invalidateAll);
    subscriptionsModel.addReloadListener('FeedSessionCache', feedSessionCache.invalidateAll);

    var trendLocationModel = UserTrendLocationModel(prefService);

    var videoPlayerBudget = await loadVideoPlayerBudget();

    runApp(PrefService(
        service: prefService,
        child: MultiProvider(
          providers: [
            Provider(create: (context) => groupsModel),
            Provider(create: (context) => feedSessionCache),
            Provider(create: (context) => VideoControllerPool(maxSize: videoPlayerBudget)),
            Provider(create: (context) => homeModel),
            ChangeNotifierProvider(create: (context) => importDataModel),
            Provider(create: (context) => subscriptionsModel),
            Provider(create: (context) => SavedTweetModel()),
            Provider(create: (context) => SavedTweetFolderModel()),
            Provider(create: (context) => LikedTweetModel()),
            Provider(create: (context) => SearchUsersModel()),
            Provider(create: (context) => trendLocationModel),
            Provider(create: (context) => TrendLocationsModel()),
            Provider(create: (context) => TrendsModel(trendLocationModel)),
            ChangeNotifierProvider(create: (_) => VideoContextState(prefService.get(optionMediaDefaultMute))),
          ],
          child: FritterApp(onboarding: !prefService.get<bool>(optionOnboardingDone)!),
        )));
  } catch (e, stackTrace) {
    log('Unable to start Fritter', error: e, stackTrace: stackTrace);
  }
}

Level defaultLogLevel({required bool release}) => release ? Level.WARNING : Level.INFO;

Locale? localeFromPref(String? locale) {
  if (locale == null || locale == optionLocaleDefault) {
    return null;
  }
  final splitLocale = locale.split(RegExp(r'[-_]'));
  if (splitLocale.length == 1) {
    return Locale(splitLocale[0]);
  }
  if (splitLocale[1].length == 4) {
    // 4 characters -> unicode_script_subtag
    return Locale.fromSubtags(languageCode: splitLocale[0], scriptCode: splitLocale[1]);
  }
  // Other than 4 characters -> unicode_region_subtag (country)
  return Locale(splitLocale[0], splitLocale[1]);
}

class AppThemes {
  final ThemeData light;
  final ThemeData dark;

  const AppThemes(this.light, this.dark);
}

/// Builds the light and dark themes only when one of their inputs changed
class AppThemeCache {
  ({String themeColor, bool trueBlack, bool disableAnimations, ColorScheme? lightDynamic, ColorScheme? darkDynamic})?
      _inputs;
  AppThemes? _themes;

  AppThemes resolve({
    required String themeColor,
    required bool trueBlack,
    required bool disableAnimations,
    required ColorScheme? lightDynamic,
    required ColorScheme? darkDynamic,
  }) {
    final inputs = (
      themeColor: themeColor,
      trueBlack: trueBlack,
      disableAnimations: disableAnimations,
      lightDynamic: lightDynamic,
      darkDynamic: darkDynamic,
    );
    final cached = _themes;
    if (cached != null && inputs == _inputs) {
      return cached;
    }
    _inputs = inputs;
    return _themes = AppThemes(
      _buildLightTheme(themeColor, disableAnimations, lightDynamic),
      _buildDarkTheme(themeColor, trueBlack, disableAnimations, darkDynamic),
    );
  }
}

ColorScheme? _colorScheme(String themeColor, ColorScheme? dynamicScheme, Brightness brightness) {
  if (themeColor == 'accent') {
    return dynamicScheme;
  }
  return ColorScheme.fromSeed(
      seedColor: themeColors[themeColor]!.harmonizeWith(dynamicScheme?.primary ?? Colors.transparent),
      brightness: brightness);
}

ThemeData _buildLightTheme(String themeColor, bool disableAnimations, ColorScheme? lightDynamic) {
  return ThemeData(
    colorScheme: _colorScheme(themeColor, lightDynamic, Brightness.light),
    pageTransitionsTheme: disableAnimations ? _noAnimationPageTransitionsTheme : null,
    useMaterial3: true,
  );
}

ThemeData _buildDarkTheme(String themeColor, bool trueBlack, bool disableAnimations, ColorScheme? darkDynamic) {
  final scheme = _colorScheme(themeColor, darkDynamic, Brightness.dark);
  return ThemeData(
    colorScheme: trueBlack ? scheme?.copyWith(surface: Colors.black) : scheme,
    navigationBarTheme: (trueBlack ? NavigationBarThemeData(backgroundColor: Colors.black) : null),
    scaffoldBackgroundColor: (trueBlack ? Colors.black : null),
    appBarTheme: (trueBlack ? AppBarThemeData(backgroundColor: Colors.black) : null),
    pageTransitionsTheme: disableAnimations ? _noAnimationPageTransitionsTheme : null,
    useMaterial3: true,
  );
}

class FritterApp extends StatefulWidget {
  /// Whether the app opens on the onboarding, which then replaces the dialogs shown at launch
  final bool onboarding;

  /// Replaces the home route, so tests do not need the whole app behind it
  @visibleForTesting
  final WidgetBuilder? homeBuilder;

  /// Called on every build of the app root
  @visibleForTesting
  final VoidCallback? onBuild;

  const FritterApp({super.key, required this.onboarding, this.homeBuilder, this.onBuild});

  @override
  State<FritterApp> createState() => _FritterAppState();
}

class _FritterAppState extends State<FritterApp> {
  static final log = Logger('_MyAppState');

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>(); // NEW: Navigator key

  static const _watchedPrefs = [
    optionShouldCheckForUpdates,
    optionLocale,
    optionThemeTrueBlack,
    optionThemeMode,
    optionThemeColor,
    optionDisableScreenshots,
    optionTextScaleFactor,
    optionDisableAnimations,
  ];

  final AppThemeCache _themeCache = AppThemeCache();
  SystemUiOverlayStyle? _appliedOverlayStyle;
  BasePrefService? _prefs;

  String _themeMode = 'system';
  String _themeColor = 'accent';
  bool _disableAnimations = false;
  bool _trueBlack = true;
  bool _checkUpdates = false;
  bool _updateDialogShown = false;
  bool _discordDialogShown = false;
  bool _isSecure = false;
  double _textScaleFactor = 1.0;
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_prefs != null) {
      return;
    }

    // Not listening to the service: it notifies on every preference change, and the watched ones are handled below
    final prefs = _prefs = PrefService.of(context, listen: false);
    _readPrefs(prefs);
    for (final key in _watchedPrefs) {
      prefs.addKeyListener(key, _onWatchedPrefChanged);
    }
  }

  @override
  void dispose() {
    final prefs = _prefs;
    if (prefs != null) {
      for (final key in _watchedPrefs) {
        prefs.removeKeyListener(key, _onWatchedPrefChanged);
      }
    }
    super.dispose();
  }

  void _onWatchedPrefChanged() {
    setState(() => _readPrefs(_prefs!));
  }

  void _readPrefs(BasePrefService prefs) {
    _locale = localeFromPref(prefs.get<String>(optionLocale));
    _themeMode = prefs.get(optionThemeMode);
    _themeColor = prefs.get(optionThemeColor);
    _trueBlack = prefs.get(optionThemeTrueBlack);
    _disableAnimations = prefs.get(optionDisableAnimations);
    _checkUpdates = prefs.get(optionShouldCheckForUpdates);
    _isSecure = prefs.get(optionDisableScreenshots);
    _textScaleFactor = prefs.get<double?>(optionTextScaleFactor) ?? 1.0;
  }

  void _applySystemOverlayStyle() {
    final style = SystemUiOverlayStyle.dark.copyWith(systemNavigationBarColor: Colors.transparent);
    if (style != _appliedOverlayStyle) {
      _appliedOverlayStyle = style;
      SystemChrome.setSystemUIOverlayStyle(style);
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();

    ThemeMode themeMode;
    switch (_themeMode) {
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'system':
        themeMode = ThemeMode.system;
        break;
      default:
        log.warning('Unknown theme mode preference: $_themeMode');
        themeMode = ThemeMode.system;
        break;
    }

    _applySystemOverlayStyle();

    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      final themes = _themeCache.resolve(
        themeColor: _themeColor,
        trueBlack: _trueBlack,
        disableAnimations: _disableAnimations,
        lightDynamic: lightDynamic,
        darkDynamic: darkDynamic,
      );

      return Portal(
              child: MaterialApp(
                  navigatorKey: _navigatorKey,
                  localizationsDelegates: const [
                    L10n.delegate,
                    ...GlobalMaterialLocalizations.delegates,
                    flutter_l10n.GlobalMaterialLocalizations.delegate,
                    flutter_l10n.GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: L10n.delegate.supportedLocales,
                  locale: _locale,
                  title: 'QuaX',
                  theme: themes.light,
                  darkTheme: themes.dark,
                  themeMode: themeMode,
                  initialRoute: '/',
                  routes: {
                    routeHome: widget.homeBuilder ??
                        (context) => PrefService.of(context, listen: false).get<bool>(optionOnboardingDone)!
                            ? const DefaultPage()
                            : const OnboardingWizard(),
                    routeGroup: (context) => const GroupScreen(),
                    routeProfile: (context) => const ProfileScreen(),
                    routeSearch: (context) => const ResultsScreen(),
                    routeSavedFolders: (context) => const SavedFoldersScreen(),
                    routeSettings: (context) => const SettingsScreen(),
                    routeSettingsExport: (context) => const SettingsExportScreen(),
                    routeSettingsHome: (context) => const SettingsHomeFragment(),
                    routeStatus: (context) => const StatusScreen(),
                  },
                  builder: (context, child) {
                    if (widget.onboarding) {
                      _updateDialogShown = _discordDialogShown = true;
                    }

                    if (_checkUpdates && !_updateDialogShown) {
                      _updateDialogShown = true;
                      // Use navigatorKey's context for showDialog
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        checkForUpdates(_navigatorKey.currentContext!);
                      });
                    }

                    if (!_discordDialogShown) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _discordDialogShown = true;
                        checkForDiscord(_navigatorKey.currentContext!);
                      });
                    }

                    // Replace the default red screen of death with a slightly friendlier one
                    ErrorWidget.builder = (FlutterErrorDetails details) => FullPageErrorWidget(
                          error: details.exception,
                          stackTrace: details.stack,
                          prefix: (l10n) => l10n.something_broke_in_fritter,
                        );

                    return _TextScaleScope(
                      factor: _textScaleFactor,
                      // ignore: deprecated_member_use
                      child: MaterialUiCompatibilityBridge(
                        child: SecureContentScope(
                          enabled: _isSecure,
                          child: child ?? Container(),
                        ),
                      ),
                    );
                  },
                ));
    });
  }
}

/// Applies the text scale preference on top of the system one. It is the only widget that follows
/// the whole [MediaQuery], so the app root is not rebuilt on every keyboard animation frame.
class _TextScaleScope extends StatelessWidget {
  final double factor;
  final Widget child;

  const _TextScaleScope({required this.factor, required this.child});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(factor * mediaQuery.textScaler.scale(1.0))),
      child: child,
    );
  }
}

class DefaultPage extends StatefulWidget {
  const DefaultPage({super.key});

  @override
  State<StatefulWidget> createState() => _DefaultPageState();
}

class _DefaultPageState extends State<DefaultPage> {
  Object? _migrationError;
  StackTrace? _migrationStackTrace;
  StreamSubscription<Uri>? _sub;

  void handleInitialLink(Uri link) async {
    final parsed = await parseUri(link);
    if (!mounted) {
      return;
    }
    switch (parsed) {
      case ProfileUriInfo(screenName: final screenName, profileTabIndex: final tab):
        Navigator.pushNamed(context, routeProfile,
            arguments: ProfileScreenArguments.fromScreenName(screenName, tab));
        return;
      case PostUriInfo(screenName: final screenName, id: final id, direct: final direct, photoNumber: final photoNumber):
        Navigator.pushNamed(context, routeStatus,
            arguments: StatusScreenArguments(
              id: id,
              username: screenName,
              initialMediaIndex: photoNumber == null || photoNumber < 1 ? 0 : photoNumber - 1,
              openMediaFullScreen: direct || photoNumber != null,
            ));
        return;
      case UnknownResult():
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              icon: Icon(Icons.error),
              title: Text(L10n.of(context).unable_to_open_link),
              content: Text(L10n.of(context).unable_to_open_link_details),
              actions: [
                TextButton(
                  child: Text(L10n.of(context).report),
                  onPressed:  () => openUri(context, issuesUrl),
                ),
                TextButton(
                  child: Text(L10n.of(context).open_in_browser),
                  onPressed: () {
                    openInDefaultBrowser(link.toString());
                    if(context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );

        return;
    }
  }

  @override
  void initState() {
    super.initState();

    // Run the database migrations
    Repository().migrate().catchError((e, s) {
      setState(() {
        _migrationError = e;
        _migrationStackTrace = s;
      });
      return e;
    });

    final appLinks = AppLinks();

    // Attach a listener to the stream
    _sub = appLinks.uriLinkStream.listen((link) => handleInitialLink(link), onError: (err) {
      // TODO: Handle exception by warning the user their action did not succeed
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_migrationError != null || _migrationStackTrace != null) {
      return ScaffoldErrorWidget(
          error: _migrationError,
          stackTrace: _migrationStackTrace,
          prefix: (l10n) => l10n.unable_to_run_the_database_migrations);
    }

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          var prefService = PrefService.of(context);
          if (!prefService.get(optionConfirmClose)) {
            SystemNavigator.pop();
            return;
          }

          final confirmed = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(L10n.current.are_you_sure),
              content: Text(L10n.current.confirm_close_fritter),
              actions: [
                TextButton(
                  child: Text(L10n.current.no),
                  onPressed: () => Navigator.pop(c, false),
                ),
                TextButton(
                  child: Text(L10n.current.yes),
                  onPressed: () => Navigator.pop(c, true),
                ),
              ],
            ),
          );

          if (confirmed == true && context.mounted) {
            SystemNavigator.pop();
          }
        },
        child: const HomeScreen());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

const _noAnimationPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
  },
);

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // No animation, simply return the child
    return child;
  }
}
