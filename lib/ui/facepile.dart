import 'package:material_ui/material_ui.dart';
import 'package:quax/user.dart';

/// The small round photos of a few accounts, such as members or followers, a little over each other.
class Facepile extends StatelessWidget {
  final List<String> urls;

  const Facepile({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: urls
            .take(5)
            .map((url) => Align(widthFactor: 0.7, child: UserAvatar(uri: url, size: 24)))
            .toList(growable: false),
      ),
    );
  }
}
