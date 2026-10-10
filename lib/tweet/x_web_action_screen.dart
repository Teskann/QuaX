import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/client/x_web_session.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/x_web_action_model.dart';
import 'package:quax/tweet/x_web_page.dart';

/// X's own page for an action QuaX cannot do by itself (replying, reposting), shown in QuaX and signed in with the
/// account saved first. It closes by itself once X leaves the intent page because the action was sent.
class XWebActionScreen extends StatefulWidget {
  final String uri;
  final String title;
  final Future<Account?> Function() loadAccount;
  final WebCookieSetter setCookies;
  final XWebPage Function() createPage;

  const XWebActionScreen({
    super.key,
    required this.uri,
    required this.title,
    this.loadAccount = firstAccount,
    this.setCookies = setWebCookies,
    this.createPage = PlatformXWebPage.new,
  });

  @override
  State<XWebActionScreen> createState() => _XWebActionScreenState();
}

class _XWebActionScreenState extends State<XWebActionScreen> {
  final _model = XWebActionModel();
  late final XWebPage _page = widget.createPage();

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _model.destroy();
    super.dispose();
  }

  Future<void> _open() async {
    await _page.setUp(
      userAgent: userAgentHeader.toString(),
      events: (
        onProgress: _whenMounted(_model.onProgress),
        onPageFinished: _whenMounted(_model.onPageFinished),
        onUrlChange: _whenMounted(_onUrlChange),
      ),
    );
    final account = await widget.loadAccount();
    if (account != null) {
      await widget.setCookies(xAccountCookies(account), origin: xWebOrigin);
    }
    if (mounted) await _page.load(Uri.parse(widget.uri));
  }

  /// The page can still report for a moment after the screen closed
  ValueChanged<T> _whenMounted<T>(ValueChanged<T> listener) => (value) {
    if (mounted) listener(value);
  };

  /// X can report leaving the intent page several times in a row. A page already closing must not pop again, which
  /// would also close the screen under it.
  void _onUrlChange(Uri url) {
    if (ModalRoute.of(context)?.isActive != true || !_model.hasLeftIntent(url)) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = L10n.of(context).x_web_done;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: ScopedBuilder<XWebActionModel, XWebActionState>(
            store: _model,
            onState: (_, state) => state.loading
                ? LinearProgressIndicator(minHeight: 2, value: state.progress > 0 ? state.progress / 100 : null)
                : const SizedBox(height: 2),
          ),
        ),
      ),
      body: SafeArea(top: false, child: _page.build()),
    );
  }
}
