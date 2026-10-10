import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/x_style.dart';

const _regular = 'PhosphorRegular';
const _fill = 'PhosphorFill';
const _bold = 'PhosphorBold';

/// The icons of the X design, drawn with Phosphor Icons (MIT, https://phosphoricons.com), whose fonts are bundled
/// in assets/fonts/phosphor and whose code points come from the phosphor_flutter package. The default design keeps
/// its Material icons.
abstract final class XIcons {
  static const reply = IconData(0xe168, fontFamily: _regular); // chatCircle
  static const repost = IconData(0xe3f6, fontFamily: _regular); // repeat
  static const like = IconData(0xe2a8, fontFamily: _regular); // heart
  static const liked = IconData(0xe2a8, fontFamily: _fill);
  static const views = IconData(0xe150, fontFamily: _regular); // chartBar
  static const bookmark = IconData(0xe0ea, fontFamily: _regular); // bookmarkSimple
  static const bookmarked = IconData(0xe0ea, fontFamily: _fill);
  static const share = IconData(0xe408, fontFamily: _regular); // shareNetwork
  static const translate = IconData(0xe4a2, fontFamily: _regular);
  static const verified = IconData(0xe606, fontFamily: _fill); // sealCheck
  static const retweetBanner = repost;
  static const pinned = IconData(0xe3e2, fontFamily: _fill); // pushPin
  static const userCircle = IconData(0xe4c4, fontFamily: _regular);
  static const profile = IconData(0xe4c2, fontFamily: _regular); // user
  static const dotsThree = IconData(0xe1fe, fontFamily: _regular);
  static const dotsThreeVertical = IconData(0xe208, fontFamily: _regular);
  static const plus = IconData(0xe3d4, fontFamily: _regular);
  static const sun = IconData(0xe472, fontFamily: _regular);
  static const moonStars = IconData(0xe58e, fontFamily: _regular);
  static const lists = IconData(0xe2f2, fontFamily: _regular); // listBullets
  static const settings = IconData(0xe270, fontFamily: _regular); // gear
  static const timelines = IconData(0xebe0, fontFamily: _regular); // listMagnifyingGlass
  static const hash = IconData(0xe2a2, fontFamily: _regular);
  static const topicNews = IconData(0xe344, fontFamily: _regular); // newspaper
  static const topicSports = IconData(0xe724, fontFamily: _regular); // basketball
  static const topicFootball = IconData(0xe716, fontFamily: _regular); // soccerBall
  static const topicTechnology = IconData(0xe610, fontFamily: _regular); // cpu
  static const topicAi = IconData(0xe762, fontFamily: _regular); // robot
  static const topicScience = IconData(0xe79e, fontFamily: _regular); // flask
  static const topicGaming = IconData(0xe26e, fontFamily: _regular); // gameController
  static const topicMusic = IconData(0xe340, fontFamily: _regular); // musicNotes
  static const topicMovies = IconData(0xe8c2, fontFamily: _regular); // filmSlate
  static const topicAnime = IconData(0xe6a2, fontFamily: _regular); // sparkle
  static const topicBusiness = IconData(0xe156, fontFamily: _regular); // chartLineUp
  static const topicCrypto = IconData(0xe618, fontFamily: _regular); // currencyBtc
  static const topicPolitics = IconData(0xe0b4, fontFamily: _regular); // bank
  static const topicHealth = IconData(0xe2ac, fontFamily: _regular); // heartbeat
  static const topicSpace = IconData(0xe3fe, fontFamily: _regular); // rocketLaunch

  static const _house = IconData(0xe2c2, fontFamily: _regular);
  static const _houseFill = IconData(0xe2c2, fontFamily: _fill);
  static const _users = IconData(0xe4d6, fontFamily: _regular);
  static const _usersFill = IconData(0xe4d6, fontFamily: _fill);
  static const _search = IconData(0xe30c, fontFamily: _regular); // magnifyingGlass
  static const _searchBold = IconData(0xe30c, fontFamily: _bold);
  static const search = _search;

  static const navSize = 26.0;

  /// The icons of the bottom navigation by page id, as (icon, selected icon). Pages not listed keep their own icons.
  static const navigation = <String, (IconData, IconData)>{
    'feed': (_house, _houseFill),
    'subscriptions': (_users, _usersFill),
    'trending': (_search, _searchBold),
    'saved': (bookmark, bookmarked),
  };

  /// Every icon of the design, to check them as a whole.
  static const all = <IconData>[
    reply, repost, like, liked, views, bookmark, bookmarked, share, translate, verified, retweetBanner, pinned,
    userCircle, profile, dotsThree, dotsThreeVertical, plus, sun, moonStars, lists, settings, timelines, search,
    _house, _houseFill, _users, _usersFill, _search, _searchBold, hash, topicNews, topicSports, topicFootball,
    topicTechnology, topicAi, topicScience, topicGaming, topicMusic, topicMovies, topicAnime, topicBusiness,
    topicCrypto, topicPolitics, topicHealth, topicSpace,
  ];
}

/// The verified badge: the X seal in the X design, the Material one otherwise.
IconData verifiedIcon(BuildContext context) => isXStyle(context) ? XIcons.verified : Icons.verified;
