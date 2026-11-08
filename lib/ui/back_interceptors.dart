import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Lets the pages of the home screen use the back button first.
/// A [PopScope] in a page would not do: the one that closes the app would run too.
class BackInterceptors {
  final Map<String, bool Function()> _byPage = {};

  /// The id of the home page on screen. Only its interceptor gets the back button.
  String? shownPage;

  void add(String pageId, bool Function() interceptor) => _byPage[pageId] = interceptor;

  void remove(String pageId) => _byPage.remove(pageId);

  /// Whether the page on screen used the back button.
  bool handleBack() => _byPage[shownPage]?.call() ?? false;
}

/// Gives the back button to the pages first, and to [onBackNotUsed] when none of them used it.
class BackInterceptorsScope extends StatelessWidget {
  final void Function(BuildContext context) onBackNotUsed;
  final Widget child;

  const BackInterceptorsScope({super.key, required this.onBackNotUsed, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !context.read<BackInterceptors>().handleBack()) {
          onBackNotUsed(context);
        }
      },
      child: child,
    );
  }
}
