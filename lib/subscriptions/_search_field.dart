import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';

class CompactSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  const CompactSearchField({super.key, required this.onChanged, this.controller, this.autofocus = false});

  @override
  State<CompactSearchField> createState() => _CompactSearchFieldState();
}

class _CompactSearchFieldState extends State<CompactSearchField> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l10n.search_your_subscriptions,
        isDense: true,
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: ListenableBuilder(
          listenable: _controller,
          builder: (_, _) => _controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(icon: const Icon(Icons.clear, size: 20), tooltip: l10n.clear, onPressed: _clear),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
      ),
    );
  }
}
