import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';

/// Inter (SIL OFL), the closest open font to Chirp, which X does not release
const xFontFamily = 'Inter';

/// The palette of the official X app, in its light and "Lights out" variants.
@immutable
class XStyleColors {
  final Color background;
  final Color primaryText;
  final Color secondaryText;
  final Color divider;
  final Color accent;

  const XStyleColors({
    required this.background,
    required this.primaryText,
    required this.secondaryText,
    required this.divider,
    required this.accent,
  });

  static const light = XStyleColors(
    background: Color(0xFFFFFFFF),
    primaryText: Color(0xFF0F1419),
    secondaryText: Color(0xFF536471),
    divider: Color(0xFFEFF3F4),
    accent: Color(0xFF1D9BF0),
  );

  static const dark = XStyleColors(
    background: Color(0xFF000000),
    primaryText: Color(0xFFE7E9EA),
    secondaryText: Color(0xFF71767B),
    divider: Color(0xFF2F3336),
    accent: Color(0xFF1D9BF0),
  );

  static const like = Color(0xFFF91880);
  static const repost = Color(0xFF00BA7C);
  static const verified = Color(0xFF1D9BF0);

  static XStyleColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  static XStyleColors of(BuildContext context) =>
      forBrightness(Theme.of(context).brightness);
}

/// Whether the user asked for the interface to look like the official X app.
bool isXStyle(BuildContext context) =>
    PrefService.of(context).get<bool>(optionXStyle) ?? false;

/// The color of the verified badge: X blue in the X design, the theme's primary color otherwise.
Color verifiedColor(BuildContext context) => isXStyle(context)
    ? XStyleColors.verified
    : Theme.of(context).colorScheme.primary;

ThemeData buildXTheme(Brightness brightness) {
  final colors = XStyleColors.forBrightness(brightness);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
      ).copyWith(
        primary: colors.accent,
        surface: colors.background,
        surfaceTint: Colors.transparent,
        onSurface: colors.primaryText,
        onSurfaceVariant: colors.secondaryText,
        outlineVariant: colors.divider,
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: xFontFamily,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 1,
      space: 1,
      indent: 0,
      endIndent: 0,
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: colors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(),
    ),
    tabBarTheme: _buildXTabBarTheme(colors),
    navigationBarTheme: _buildXNavigationBarTheme(colors),
  );
}

/// The text scale of the app. X ignores the scale chosen inside the app and follows the system one only.
TextScaler appTextScaler({required bool xStyle, required double appFactor, required double systemFactor}) =>
    TextScaler.linear((xStyle ? 1.0 : appFactor) * systemFactor);

const xTabLabelStyle = TextStyle(fontFamily: xFontFamily, fontSize: 15, fontWeight: FontWeight.w700);

TabBarThemeData _buildXTabBarTheme(XStyleColors colors) => TabBarThemeData(
  indicator: UnderlineTabIndicator(
    borderSide: BorderSide(width: 2.5, color: colors.primaryText),
    borderRadius: BorderRadius.circular(2),
  ),
  indicatorSize: TabBarIndicatorSize.tab,
  labelColor: colors.primaryText,
  unselectedLabelColor: colors.secondaryText,
  labelStyle: xTabLabelStyle,
  unselectedLabelStyle: xTabLabelStyle,
  dividerColor: colors.divider,
  dividerHeight: 1,
);

NavigationBarThemeData _buildXNavigationBarTheme(XStyleColors colors) =>
    NavigationBarThemeData(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      elevation: 0,
      height: 52,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: colors.primaryText, size: 24),
      ),
    );
