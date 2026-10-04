import 'package:material_ui/material_ui.dart';
import 'package:quax/utils/urls.dart';

/// Outlined frame shared by the cards of a tweet, opening [url] when tapped
class CardFrame extends StatelessWidget {
  final String? url;
  final Widget child;

  const CardFrame({super.key, required this.url, required this.child});

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: double.infinity,
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).colorScheme.surfaceBright.withAlpha(180)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(onTap: url == null ? null : () => openUri(context, url), child: child),
      ),
    );
  }
}

/// Title, description and link of a card
class CardDetails extends StatelessWidget {
  final String title;
  final String? description;
  final String? uri;

  const CardDetails({super.key, required this.title, this.description, this.uri});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final description = this.description;
    final uri = this.uri;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: theme.textTheme.titleSmall!.copyWith(color: colors.onSurface, fontWeight: FontWeight.w600)),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(description,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: theme.textTheme.bodyMedium!.copyWith(color: colors.onSurfaceVariant)),
            ),
          if (uri != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14, color: colors.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(uri,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium!.copyWith(color: colors.primary)),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }
}

/// A [media] above the title and description of the page the card leads to
class WebsiteCard extends StatelessWidget {
  final String uri;
  final Widget media;
  final String title;
  final String? subtitle;

  const WebsiteCard({super.key, required this.uri, required this.media, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return CardFrame(
      url: uri,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          media,
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: CardDetails(title: title, description: subtitle),
          ),
        ],
      ),
    );
  }
}
