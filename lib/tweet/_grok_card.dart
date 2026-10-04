import 'package:material_ui/material_ui.dart';
import 'package:quax/tweet/_card_frame.dart';
import 'package:quax/tweet/_expandable_tweet_text.dart';
import 'package:quax/tweet/_grok_avatar.dart';
import 'package:quax/utils/urls.dart';

final _renderTags = RegExp(r'<grok:render[^>]*>.*?</grok:render>', dotAll: true);

/// What a unified card without type shows of a shared Grok conversation, eg
/// https://x.com/elonmusk/status/2098507671083036843
class GrokShare {
  final String uri;
  final String question;
  final String answer;
  final String? grokImageUrl;
  final String grokScreenName;

  const GrokShare(
      {required this.uri,
      required this.question,
      required this.answer,
      required this.grokImageUrl,
      required this.grokScreenName});

  /// Null when the card lacks what it takes to be drawn
  static GrokShare? fromUnifiedCard(Map<String, dynamic> unifiedCard) {
    final data = unifiedCard['component_objects']?['details_1']?['data'];
    final String? uri = unifiedCard['destination_objects']?[data?['destination']]?['data']?['url_data']?['url'];
    final preview = data?['conversation_preview'];
    if (uri == null || preview is! List) {
      return null;
    }
    final grokUser = data['grok_user'];
    return GrokShare(
      uri: uri,
      question: _firstMessage(preview, 'USER'),
      answer: _firstMessage(preview, 'AGENT').replaceAll(_renderTags, '').trim(),
      grokImageUrl: grokUser?['profile_image_url_https'],
      grokScreenName: grokUser?['screen_name'] ?? 'grok',
    );
  }

  static String _firstMessage(List<dynamic> preview, String sender) => preview
      .whereType<Map>()
      .where((e) => e['sender'] == sender)
      .map((e) => e['message'] as String?)
      .nonNulls
      .firstOrNull ?? '';
}

class GrokShareCard extends StatelessWidget {
  final GrokShare share;

  const GrokShareCard({super.key, required this.share});

  @override
  Widget build(BuildContext context) {
    return CardFrame(
      url: share.uri,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GrokQuestion(message: share.question),
            const SizedBox(height: 12),
            _GrokAnswer(share: share),
          ],
        ),
      ),
    );
  }
}

class _GrokQuestion extends StatelessWidget {
  final String message;

  const _GrokQuestion({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: colors.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}

class _GrokAnswer extends StatelessWidget {
  final GrokShare share;

  const _GrokAnswer({required this.share});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GrokAvatar(imageUrl: share.grokImageUrl, screenName: share.grokScreenName),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium,
              child: ExpandableTweetText(
                textSpans: [TextSpan(text: share.answer)],
                onTap: () => openUri(context, share.uri),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
