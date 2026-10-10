import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/utils/x_post_url.dart';

class XWebActionState {
  static const _loaded = 100;

  final int progress;

  /// Where the first page that finished loading ended up: the intent page, or what X redirected to
  final Uri? landedOn;

  const XWebActionState({this.progress = 0, this.landedOn});

  bool get loading => progress < _loaded;

  XWebActionState finished(Uri url) => XWebActionState(progress: _loaded, landedOn: landedOn ?? url);
}

/// Follows the page of an X action (reply, repost) and tells when the action is over.
class XWebActionModel extends Store<XWebActionState> {
  XWebActionModel() : super(const XWebActionState());

  void onProgress(int progress) => update(XWebActionState(progress: progress, landedOn: state.landedOn));

  void onPageFinished(Uri url) => update(state.finished(url));

  /// Whether X moved on from the intent page, which only counts once the first page finished loading
  bool hasLeftIntent(Uri current) {
    final landedOn = state.landedOn;
    return landedOn != null && xIntentFinished(landedOn, current);
  }
}
