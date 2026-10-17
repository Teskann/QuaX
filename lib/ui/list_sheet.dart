import 'package:material_ui/material_ui.dart';

const listSheetTilePadding = EdgeInsets.symmetric(horizontal: 24);

Future<T?> showListSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: builder,
);

class ListSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget footer;

  const ListSheet({super.key, required this.icon, required this.title, required this.children, required this.footer});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
          const Divider(),
          footer,
        ],
      ),
    );
  }
}
