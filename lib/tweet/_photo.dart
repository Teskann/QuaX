import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/formats.dart';

List<double> _doubleTapScales = <double>[1.0, 4.0];

class TweetPhoto extends StatefulWidget {
  final String uri;
  final BoxFit fit;
  final String? size;
  final bool pullToClose;
  final bool inPageView;

  /// Whether the photo is shown by the full-screen viewer, the only place that zooms and slides out. In a feed it is a
  /// plain image decoded at the size it is laid out
  final bool fullscreen;

  const TweetPhoto(
      {super.key,
      required this.uri,
      this.fit = BoxFit.fitWidth,
      required this.size,
      required this.pullToClose,
      required this.inPageView,
      this.fullscreen = false});

  @override
  State<TweetPhoto> createState() => _TweetPhotoState();
}

class _TweetPhotoState extends State<TweetPhoto> with SingleTickerProviderStateMixin {
  Animation<double>? _doubleClickAnimation;
  late void Function() _doubleClickAnimationListener;
  late final AnimationController _doubleClickAnimationController =
      AnimationController(duration: const Duration(milliseconds: 150), vsync: this);

  String get _url => widget.size != null ? '${widget.uri}:${widget.size}' : widget.uri;

  @override
  Widget build(BuildContext context) {
    return widget.fullscreen ? _buildFullscreen(context) : _buildFeedImage(context);
  }

  Widget _buildFeedImage(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => ExtendedImage.network(
        _url,
        cache: true,
        fit: widget.fit,
        cacheWidth: decodeWidthFor(constraints, devicePixelRatio),
      ),
    );
  }

  Widget _buildFullscreen(BuildContext context) {
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.vertical,
      slidePageBackgroundHandler: (offset, pageSize) => defaultSlidePageBackgroundHandler(
        offset: offset,
        pageSize: pageSize,
        color: Theme.of(context).scaffoldBackgroundColor,
        pageGestureAxis: SlideAxis.vertical,
      ),
      child: ExtendedImage.network(
        _url,
        cache: true,
        width: 5000,
        height: 5000,
        fit: widget.fit,
        mode: ExtendedImageMode.gesture,
        enableSlideOutPage: widget.pullToClose,
        initGestureConfigHandler: (state) {
          return GestureConfig(
            inPageView: widget.inPageView,
            minScale: 0.9,
            animationMinScale: 0.7,
            maxScale: 4.0,
            animationMaxScale: 4.0,
            speed: 1.0,
            inertialSpeed: 100.0,
            initialScale: 1.0,
            initialAlignment: InitialAlignment.center,
          );
        },
        onDoubleTap: (ExtendedImageGestureState state) {
          final Offset? pointerDownPosition = state.pointerDownPosition;
          final double? begin = state.gestureDetails!.totalScale;
          double end;

          // Remove and stop any old animation
          _doubleClickAnimation?.removeListener(_doubleClickAnimationListener);
          _doubleClickAnimationController.stop();
          _doubleClickAnimationController.reset();

          if (begin == _doubleTapScales[0]) {
            end = _doubleTapScales[1];
          } else {
            end = _doubleTapScales[0];
          }

          _doubleClickAnimationListener = () {
            state.handleDoubleTap(scale: _doubleClickAnimation!.value, doubleTapPosition: pointerDownPosition);
          };

          _doubleClickAnimation = _doubleClickAnimationController.drive(Tween<double>(begin: begin, end: end));
          _doubleClickAnimation!.addListener(_doubleClickAnimationListener);
          _doubleClickAnimationController.forward();
        },
      ),
    );
  }
}
