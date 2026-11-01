part of 'entity_value.dart';

class LinkEntity extends EntityValue {
  final String url;

  const LinkEntity({required this.url});

  @override
  Widget toWidget(BuildContext context) {
    return Text(
      url,
      style: linkStyle(context).copyWith(decoration: TextDecoration.underline),
    );
  }
}
