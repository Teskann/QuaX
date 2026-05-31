import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/_video.dart';

/// Provides the [TweetContextState] and [VideoContextState] that tweet tiles
/// read from context. Any subtree rendering [TweetConversation]/[TweetTile] must
/// sit under this scope, otherwise those reads throw ProviderNotFoundException.
class TweetContextScope extends StatelessWidget {
  final Widget child;

  const TweetContextScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context, listen: false);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TweetContextState>(
            create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive))),
        ChangeNotifierProvider<VideoContextState>(
            create: (_) => VideoContextState(prefs.get(optionMediaDefaultMute))),
      ],
      child: child,
    );
  }
}
