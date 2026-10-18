import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/locale_fallback.dart';

List<String> splitWords(String text, {String prefix = ''}) => text
    .split(RegExp(r'\s+'))
    .map((word) => word.startsWith(prefix) ? word.substring(prefix.length) : word)
    .where((word) => word.isNotEmpty)
    .toList();

final _accountPattern = RegExp(r'^@?(\w{1,50})$');

/// A text field bound to [value], which keeps what is typed even when [value] reads it differently.
class FilterTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  const FilterTextField(
      {super.key, required this.label, required this.value, required this.onChanged, this.keyboardType});

  @override
  State<FilterTextField> createState() => _FilterTextFieldState();
}

class _FilterTextFieldState extends State<FilterTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(FilterTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value.isEmpty && _controller.text.trim().isNotEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder()),
      onChanged: widget.onChanged,
    );
  }
}

/// Accounts typed one by one, each shown as a chip that removes it.
class AccountsField extends StatefulWidget {
  final String label;
  final List<String> accounts;
  final ValueChanged<List<String>> onChanged;

  const AccountsField({super.key, required this.label, required this.accounts, required this.onChanged});

  @override
  State<AccountsField> createState() => _AccountsFieldState();
}

class _AccountsFieldState extends State<AccountsField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(String text) {
    final account = _accountPattern.firstMatch(text.trim())?.group(1);
    if (account == null) {
      return;
    }
    _controller.clear();
    if (!widget.accounts.contains(account)) {
      widget.onChanged([...widget.accounts, account]);
    }
  }

  void _addAndKeepTyping(String text) {
    _add(text);
    _focusNode.requestFocus();
  }

  void _onChanged(String text) {
    if (text.endsWith(' ') || text.endsWith(',')) {
      _add(text.substring(0, text.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_focusNode, _controller]),
      builder: (context, _) {
        // An empty field shows its label in place of the hint, as a plain text field does
        final labelInside = widget.accounts.isEmpty && _controller.text.isEmpty && !_focusNode.hasFocus;
        return InputDecorator(
          decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder()),
          isFocused: _focusNode.hasFocus,
          isEmpty: labelInside,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.accounts.map((account) => InputChip(
                    label: Text('@$account'),
                    onDeleted: () => widget.onChanged(widget.accounts.where((e) => e != account).toList()),
                  )),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 140),
                child: IntrinsicWidth(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration.collapsed(
                        hintText: labelInside ? null : L10n.of(context).search_filters_add_account),
                    onChanged: _onChanged,
                    onSubmitted: _addAndKeepTyping,
                    onTapOutside: (_) => _add(_controller.text),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A date picked from a calendar, which can be cleared.
class FilterDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const FilterDateField({super.key, required this.label, required this.value, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: DateTime(2006, 3, 21),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = value;
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: date == null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: date == null
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  icon: Icon(Icons.clear, semanticLabel: L10n.of(context).clear), onPressed: () => onChanged(null)),
        ),
        child: date == null ? null : Text(DateFormat.yMd(formattingLocale()).format(date)),
      ),
    );
  }
}
