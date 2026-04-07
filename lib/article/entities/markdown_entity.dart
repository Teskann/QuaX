part of 'entity_value.dart';

class MarkdownEntity extends EntityValue {
  final String language;
  final String code;

  MarkdownEntity._({required this.language, required this.code});

  factory MarkdownEntity({required String markdown}) {
    final (language, code) = _parse(markdown);
    return MarkdownEntity._(language: language, code: code);
  }

  static (String, String) _parse(String markdown) {
    final trimmed = markdown.trim();
    final firstNewline = trimmed.indexOf('\n');
    if (!trimmed.startsWith('```') || firstNewline == -1) {
      return ('', trimmed);
    }
    final language = trimmed.substring(3, firstNewline).trim();
    final withoutOpen = trimmed.substring(firstNewline + 1);
    final code = withoutOpen.endsWith('```')
        ? withoutOpen.substring(0, withoutOpen.length - 3).trimRight()
        : withoutOpen;
    return (language, code);
  }

  @override
  Widget toWidget(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Container(
              color: Color.alphaBlend(colorScheme.onSurface.withValues(alpha: 0.08), colorScheme.surfaceContainer),
              padding: const EdgeInsets.only(left: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      language,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Copy',
                    child: InkWell(
                      onTap: () => Clipboard.setData(ClipboardData(text: code)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Icon(Icons.copy, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            color: colorScheme.surfaceContainer,
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
