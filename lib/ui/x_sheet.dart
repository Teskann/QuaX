import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/x_style.dart';

const _sheetRadius = 16.0;
const _grabberSize = Size(36, 4);
const _rowHeight = 52.0;
const _rowIconSize = 22.0;
const _cancelHeight = 40.0;

/// Opens a bottom sheet whose look is all in [XSheet], so the route itself paints nothing.
Future<T?> showXSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(context: context, backgroundColor: Colors.transparent, elevation: 0, builder: builder);

/// The bottom sheet of the X design: a grabber, an optional [title], the [children] (usually [XSheetRow]s) and a
/// full-width "Cancel" button that closes it.
class XSheet extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const XSheet({super.key, this.title, required this.children});

  static ShapeDecoration _surface(Color color, double radius) => ShapeDecoration(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radius))),
      );

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    final title = this.title;
    // The 1px divider-colored border is the surface of the sheet showing around the background drawn inside it
    return DecoratedBox(
      decoration: _surface(colors.divider, _sheetRadius),
      child: Padding(
        padding: const EdgeInsets.only(top: 1),
        child: DecoratedBox(
          decoration: _surface(colors.background, _sheetRadius - 1),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Grabber(),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(title,
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: colors.primaryText)),
                  ),
                ...children,
                const _CancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          width: _grabberSize.width,
          height: _grabberSize.height,
          decoration: BoxDecoration(
            color: XStyleColors.of(context).secondaryText.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(_grabberSize.height / 2),
          ),
        ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton();

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: _cancelHeight,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primaryText,
            side: BorderSide(color: colors.secondaryText),
            shape: const StadiumBorder(),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: Text(L10n.of(context).cancel),
        ),
      ),
    );
  }
}

/// A row of an [XSheet]: an icon and a label.
class XSheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const XSheetRow({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: _rowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(icon, size: _rowIconSize, color: colors.primaryText),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.primaryText)),
            ),
          ]),
        ),
      ),
    );
  }
}
