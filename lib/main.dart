import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/client/login_webview.dart';

import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/home/home_model.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_model.dart';
import 'package:quax/settings/_data.dart';
import 'package:quax/settings/_home.dart';
import 'package:quax/settings/settings.dart';
import 'package:quax/settings/settings_export_screen.dart';
import 'package:quax/status.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/trends/trends_model.dart';
import 'package:quax/tweet/_video.dart';
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

Future checkForUpdates(context) async {
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
                    await openUri(map['html_url']);
                    Navigator.of(context).pop();
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

Future checkForAccounts(context) async {
  Logger.root.info('Checking for accounts');

  final accounts = await getAccounts();
  if (accounts.isEmpty) {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("⚠️ ${L10n.of(context).not_logged_in}"),
          content: Text(L10n.of(context).quax_doesnt_work_without_account_please_login),
          actions: [
            TextButton(
              child: Text(L10n.of(context).import_backup),
              onPressed: () async {
                await importBackup(context);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              child: Text(L10n.of(context).login),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TwitterLoginWebview()));
              },
            ),
          ],
        );
      },
    );
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

setTimeagoLocales() {
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

Future<void> main() async {
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
    optionTextScaleFactor: 1.0,
    optionDisableScreenshots: false,
    optionDownloadPath: '',
    optionDownloadType: optionDownloadTypeAsk,
    optionHomePages: defaultHomePages.map((e) => e.id).toList(),
    optionLocale: optionLocaleDefault,
    optionHomeInitialTab: 'feed',
    optionMediaSize: 'medium',
    optionMediaDefaultMute: true,
    optionMediaDefaultLoop: false,
    optionMediaDefaultAutoPlay: false,
    optionMediaBackgroundPlayback: true,
    optionMediaAllowBackgroundPlayOtherApps: false,
    optionNonConfirmationBiasMode: false,
    optionShouldCheckForUpdates: const String.fromEnvironment('app.flavor') == "fdroid" ? false : true,
    optionSubscriptionGroupsOrderByAscending: true,
    optionDisableWarningsForUnrelatedPostsInFeed: false,
    optionSubscriptionGroupsOrderByField: 'name',
    optionSubscriptionOrderByAscending: true,
    optionSubscriptionOrderByField: 'name',
    optionSubscriptionOrderCustom: '',
    optionThemeMode: 'system',
    optionThemeColor: 'accent',
    optionThemeTrueBlack: true,
    optionThemeTrueBlackTweetCards: true,
    optionShowNavigationLabels: false,
    optionTweetsHideSensitive: true,
    optionUseAbsoluteTimestamp: false,
    optionUserTrendsLocations: jsonEncode({
      'active': {'name': 'Worldwide', 'woeid': 1},
      'locations': [
        {'name': 'Worldwide', 'woeid': 1}
      ]
    }),
  });

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

    var trendLocationModel = UserTrendLocationModel(prefService);

    runApp(PrefService(
        service: prefService,
        child: MultiProvider(
          providers: [
            Provider(create: (context) => groupsModel),
            Provider(create: (context) => homeModel),
            ChangeNotifierProvider(create: (context) => importDataModel),
            Provider(create: (context) => subscriptionsModel),
            Provider(create: (context) => SavedTweetModel()),
            Provider(create: (context) => SearchTweetsModel()),
            Provider(create: (context) => SearchUsersModel()),
            Provider(create: (context) => trendLocationModel),
            Provider(create: (context) => TrendLocationsModel()),
            Provider(create: (context) => TrendsModel(trendLocationModel)),
            ChangeNotifierProvider(create: (_) => VideoContextState(prefService.get(optionMediaDefaultMute))),
          ],
          child: FritterApp(),
        )));
  } catch (e, stackTrace) {
    log('Unable to start Fritter', error: e, stackTrace: stackTrace);
  }
}

class FritterApp extends StatefulWidget {
  const FritterApp({super.key});

  @override
  State<FritterApp> createState() => _FritterAppState();
}

class _FritterAppState extends State<FritterApp> {
  static final log = Logger('_MyAppState');

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>(); // NEW: Navigator key

  String _themeMode = 'system';
  String _themeColor = 'accent';
  bool _disableAnimations = false;
  bool _trueBlack = true;
  bool _checkUpdates = false;
  bool _updateDialogShown = false;
  bool _accountDialogShown = false;
  bool _isSecure = false;
  double _textScaleFactor = 1.0;
  Locale? _locale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    var prefService = PrefService.of(context);

    void setLocale(String? locale) {
      if (locale == null || locale == optionLocaleDefault) {
        _locale = null;
      } else {
        var splitLocale = locale.split(RegExp(r'[-_]'));
        if (splitLocale.length == 1) {
          _locale = Locale(splitLocale[0]);
        } else {
          if (splitLocale[1].length == 4) {
            // 4 characters -> unicode_script_subtag
            _locale = Locale.fromSubtags(languageCode: splitLocale[0], scriptCode: splitLocale[1]);
          } else {
            // Other than 4 characters -> unicode_region_subtag (country)
            _locale = Locale(splitLocale[0], splitLocale[1]);
          }
        }
      }
    }

    // Set any already-enabled preferences
    setState(() {
      setLocale(prefService.get<String>(optionLocale));
      _themeMode = prefService.get(optionThemeMode);
      _themeColor = prefService.get(optionThemeColor);
      _trueBlack = prefService.get(optionThemeTrueBlack);
      _disableAnimations = prefService.get(optionDisableAnimations);
      _checkUpdates = prefService.get(optionShouldCheckForUpdates);
      _isSecure = prefService.get(optionDisableScreenshots);
      _textScaleFactor = prefService.get(optionTextScaleFactor);
    });

    prefService.addKeyListener(optionShouldCheckForUpdates, () {
      setState(() {});
    });

    prefService.addKeyListener(optionLocale, () {
      setState(() {
        setLocale(prefService.get<String>(optionLocale));
      });
    });

    // Whenever the "true black" preference is toggled, apply the toggle
    prefService.addKeyListener(optionThemeTrueBlack, () {
      setState(() {
        _trueBlack = prefService.get(optionThemeTrueBlack);
      });
    });

    prefService.addKeyListener(optionThemeMode, () {
      setState(() {
        _themeMode = prefService.get(optionThemeMode);
      });
    });

    prefService.addKeyListener(optionThemeColor, () {
      setState(() {
        _themeColor = prefService.get(optionThemeColor);
      });
    });

    prefService.addKeyListener(optionDisableScreenshots, () {
      setState(() {
        _isSecure = prefService.get(optionDisableScreenshots);
      });
    });

    prefService.addKeyListener(optionTextScaleFactor, () {
      setState(() {
        _textScaleFactor = prefService.get<double?>(optionTextScaleFactor) ?? 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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

    final systemOverlayStyle = SystemUiOverlayStyle.dark.copyWith(systemNavigationBarColor: Colors.transparent);
    SystemChrome.setSystemUIOverlayStyle(systemOverlayStyle);
    final systemScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);

    return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_textScaleFactor * systemScaleFactor),
        ),
        child: DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
          return Portal(
              child: SecureWidget(
                  isSecure: _isSecure,
                  builder: (BuildContext context, a, b) => MaterialApp(
                        navigatorKey: _navigatorKey,
                        localizationsDelegates: const [
                          L10n.delegate,
                          GlobalMaterialLocalizations.delegate,
                          GlobalWidgetsLocalizations.delegate,
                          GlobalCupertinoLocalizations.delegate,
                        ],
                        supportedLocales: L10n.delegate.supportedLocales,
                        locale: _locale,
                        title: 'QuaX',
                        theme: ThemeData(
                          colorScheme: _themeColor == 'accent'
                              ? lightDynamic
                              : ColorScheme.fromSeed(
                                  seedColor: themeColors[_themeColor]!
                                      .harmonizeWith(lightDynamic?.primary ?? Colors.transparent),
                                  brightness: Brightness.light),
                          pageTransitionsTheme: _disableAnimations == true
                              ? PageTransitionsTheme(
                                  builders: {
                                    TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
                                    TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                                  },
                                )
                              : null,
                          useMaterial3: true,
                        ),
                        darkTheme: ThemeData(
                          colorScheme: (_trueBlack == true
                              ? (_themeColor == 'accent'
                                      ? darkDynamic
                                      : ColorScheme.fromSeed(
                                          seedColor: themeColors[_themeColor]!
                                              .harmonizeWith(darkDynamic?.primary ?? Colors.transparent),
                                          brightness: Brightness.dark))
                                  ?.copyWith(surface: Colors.black)
                              : (_themeColor == 'accent'
                                  ? darkDynamic
                                  : ColorScheme.fromSeed(
                                      seedColor: themeColors[_themeColor]!
                                          .harmonizeWith(darkDynamic?.primary ?? Colors.transparent),
                                      brightness: Brightness.dark))),
                          navigationBarTheme:
                              (_trueBlack == true ? NavigationBarThemeData(backgroundColor: Colors.black) : null),
                          scaffoldBackgroundColor: (_trueBlack == true ? Colors.black : null),
                          appBarTheme: (_trueBlack == true ? AppBarThemeData(backgroundColor: Colors.black) : null),
                          pageTransitionsTheme: _disableAnimations == true
                              ? PageTransitionsTheme(
                                  builders: {
                                    TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
                                    TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
                                  },
                                )
                              : null,
                          useMaterial3: true,
                        ),
                        themeMode: themeMode,
                        initialRoute: '/',
                        routes: {
                          routeHome: (context) => const DefaultPage(),
                          routeGroup: (context) => const GroupScreen(),
                          routeProfile: (context) => const ProfileScreen(),
                          routeSearch: (context) => const ResultsScreen(),
                          routeSettings: (context) => const SettingsScreen(),
                          routeSettingsExport: (context) => const SettingsExportScreen(),
                          routeSettingsHome: (context) => const SettingsHomeFragment(),
                          routeStatus: (context) => const StatusScreen(),
                        },
                        builder: (context, child) {
                          if (_checkUpdates && !_updateDialogShown) {
                            _updateDialogShown = true;
                            // Use navigatorKey's context for showDialog
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              checkForUpdates(_navigatorKey.currentContext!);
                            });
                          }

                          if (!_accountDialogShown) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _accountDialogShown = true;
                              checkForAccounts(_navigatorKey.currentContext!);
                            });
                          }

                          // Replace the default red screen of death with a slightly friendlier one
                          ErrorWidget.builder = (FlutterErrorDetails details) => FullPageErrorWidget(
                                error: details.exception,
                                stackTrace: details.stack,
                                prefix: L10n.of(context).something_broke_in_fritter,
                              );

                          return child ?? Container();
                        },
                      )));
        }));
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

  void handleInitialLink(Uri link) {
    // Assume it's a username if there's only one segment (or two segments with the second empty, meaning the URI ends with /)
    if (link.pathSegments.length == 1 || (link.pathSegments.length == 2 && link.pathSegments.last.isEmpty)) {
      Navigator.pushNamed(context, routeProfile,
          arguments: ProfileScreenArguments.fromScreenName(link.pathSegments.first));
      return;
    }

    if (link.pathSegments.length == 2) {
      var secondSegment = link.pathSegments[1];

      // https://twitter.com/i/redirect?url=https%3A%2F%2Ftwitter.com%2Fi%2Ftopics%2Ftweet%2F1447290060123033601
      if (secondSegment == 'redirect') {
        // This is a redirect URL, so we should extract it and use that as our initial link instead
        var redirect = link.queryParameters['url'];
        if (redirect == null) {
          // TODO
          return;
        }

        handleInitialLink(Uri.parse(redirect));
        return;
      }
    }

    if (link.pathSegments.length == 3) {
      var segment2 = link.pathSegments[1];
      if (segment2 == 'status') {
        // Assume it's a tweet
        var username = link.pathSegments[0];
        var statusId = link.pathSegments[2];

        Navigator.pushNamed(context, routeStatus,
            arguments: StatusScreenArguments(
              id: statusId,
              username: username,
            ));
        return;
      }
    }

    if (link.pathSegments.length == 4) {
      var segment2 = link.pathSegments[1];
      var segment3 = link.pathSegments[2];
      var segment4 = link.pathSegments[3];

      // https://twitter.com/i/topics/tweet/1447290060123033601
      if (segment2 == 'topics' && segment3 == 'tweet') {
        Navigator.pushNamed(context, routeStatus, arguments: StatusScreenArguments(id: segment4, username: null));
        return;
      }
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
          prefix: L10n.of(context).unable_to_run_the_database_migrations);
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

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
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
