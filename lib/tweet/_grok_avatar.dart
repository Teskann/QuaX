import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/user.dart';

/// Profile picture of Grok, which opens its profile. An icon stands in when the card gives no picture
class GrokAvatar extends StatelessWidget {
  static const _size = 32.0;

  final String? imageUrl;
  final String screenName;

  const GrokAvatar({super.key, required this.imageUrl, required this.screenName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl = this.imageUrl;
    return InkResponse(
      onTap: () => Navigator.pushNamed(context, routeProfile,
          arguments: ProfileScreenArguments.fromScreenName(screenName, null)),
      child: imageUrl == null
          ? CircleAvatar(
              radius: _size / 2,
              backgroundColor: colors.tertiaryContainer,
              child: Icon(Icons.auto_awesome, size: 18, color: colors.onTertiaryContainer),
            )
          : UserAvatar(uri: imageUrl, size: _size),
    );
  }
}
