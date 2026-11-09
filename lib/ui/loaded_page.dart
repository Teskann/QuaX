import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/loaded_store.dart';

/// A page that first loads what it shows, such as a community or a list. It shows a spinner while it loads,
/// and an error with a retry button when it fails.
class LoadedPage<T extends Object> extends StatefulWidget {
  final LoadedStore<T> Function() create;
  final ErrorPrefix errorPrefix;
  final Widget Function(BuildContext context, T loaded) builder;

  const LoadedPage({super.key, required this.create, required this.errorPrefix, required this.builder});

  @override
  State<LoadedPage<T>> createState() => _LoadedPageState<T>();
}

class _LoadedPageState<T extends Object> extends State<LoadedPage<T>> {
  late final LoadedStore<T> _store = widget.create()..load();

  @override
  void dispose() {
    _store.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScopedBuilder<LoadedStore<T>, T>.transition(
        store: _store,
        onLoading: (_) => const Center(child: CircularProgressIndicator()),
        onError: (_, error) =>
            FullPageErrorWidget(error: error, stackTrace: null, prefix: widget.errorPrefix, onRetry: _store.load),
        onState: (context, loaded) => widget.builder(context, loaded),
      ),
    );
  }
}
