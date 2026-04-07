part of 'entity_value.dart';

class DividerEntity extends EntityValue {
  @override
  Widget toWidget(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Divider(
        thickness: 1.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
      ),
    );
  }
}
