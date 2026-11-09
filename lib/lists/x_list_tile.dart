import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/lists/x_list.dart';
import 'package:quax/lists/x_list_screen.dart';
import 'package:quax/ui/banner_tile.dart';
import 'package:quax/ui/count_label.dart';

/// A list: its name, how many accounts it has and who made it.
class XListTile extends StatelessWidget {
  final XList list;

  const XListTile({super.key, required this.list});

  @override
  Widget build(BuildContext context) {
    final members = formatCount(list.memberCount);
    final owner = list.owner;
    return BannerTile(
      bannerUrl: list.bannerUrl,
      icon: Icons.list_alt,
      title: list.name,
      subtitle: [
        '$members ${L10n.of(context).members_after_count(list.memberCount)}',
        if (owner != null) '@${owner.screenName}',
      ].join(' · '),
      onTap: () => Navigator.pushNamed(context, routeList, arguments: XListScreenArguments(list.id)),
    );
  }
}
