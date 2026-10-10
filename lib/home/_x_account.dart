import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/home/x_account_model.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/user.dart';

/// Rebuilds with the account of the X design, asking [XAccountModel] to load it the first time a widget needs it.
class XAccountBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, XAccountState state) builder;

  const XAccountBuilder({super.key, required this.builder});

  @override
  State<XAccountBuilder> createState() => _XAccountBuilderState();
}

class _XAccountBuilderState extends State<XAccountBuilder> {
  late final XAccountModel _model = context.read<XAccountModel>();

  @override
  void initState() {
    super.initState();
    // The store notifies as soon as it loads, which must not happen while the tree is building
    Future.microtask(_model.loadOnce);
  }

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<XAccountModel, XAccountState>(
      store: _model,
      onState: (context, state) => widget.builder(context, state),
    );
  }
}

/// The avatar of the current account, or a generic user icon while it is unknown.
class XAccountAvatar extends StatelessWidget {
  final double size;

  const XAccountAvatar({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return XAccountBuilder(builder: (context, state) {
      final url = state.account?.avatarUrl;
      return url == null ? Icon(XIcons.userCircle, size: size) : UserAvatar(uri: url, size: size);
    });
  }
}
