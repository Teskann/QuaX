import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';

/// A tile with a banner, such as a community or a list. With no banner, it shows [icon].
class BannerTile extends StatelessWidget {
  final String? bannerUrl;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const BannerTile({
    super.key,
    required this.bannerUrl,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final banner = bannerUrl;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 48,
          child: banner == null ? Icon(icon) : ExtendedImage.network(banner, fit: BoxFit.cover),
        ),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
