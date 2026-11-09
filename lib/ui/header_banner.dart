import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/_media.dart';

/// The app bar of a community or a list. It shows the banner. When the banner scrolls away, it shows the name.
class BannerAppBar extends StatelessWidget {
  static const _bannerHeight = 160.0;

  final String name;
  final String? bannerUrl;
  final bool innerBoxIsScrolled;

  const BannerAppBar({super.key, required this.name, required this.bannerUrl, required this.innerBoxIsScrolled});

  @override
  Widget build(BuildContext context) {
    final url = bannerUrl;
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverAppBar(
        pinned: true,
        expandedHeight: _bannerHeight,
        forceElevated: innerBoxIsScrolled,
        title: constraints.scrollOffset > _bannerHeight - kToolbarHeight ? Text(name) : null,
        flexibleSpace: url == null
            ? null
            : FlexibleSpaceBar(
                background: HeaderBanner(url: url, name: name),
              ),
      ),
    );
  }
}

/// A banner that opens full screen when tapped.
class HeaderBanner extends StatelessWidget {
  final String url;
  final String name;

  const HeaderBanner({super.key, required this.url, required this.name});

  void _openFullScreen(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          TweetMediaView(initialIndex: 0, media: [createMediaFromUrl(url, null)], username: name, tweetMedia: false),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: L10n.of(context).profile_banner,
    child: GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ExtendedImage.network(url, fit: BoxFit.cover),
    ),
  );
}
