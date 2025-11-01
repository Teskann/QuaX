import 'dart:convert';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/user.dart';
import 'package:provider/provider.dart';

Future openSubscriptionGroupDialog(BuildContext context, String? id, String name, String icon) {
  return showDialog(
      context: context,
      builder: (context) {
        return SubscriptionGroupEditDialog(id: id, name: name, icon: icon);
      });
}

class SubscriptionGroups extends StatefulWidget {
  final ScrollController scrollController;

  const SubscriptionGroups({super.key, required this.scrollController});

  @override
  State<SubscriptionGroups> createState() => _SubscriptionGroupsState();
}

class _SubscriptionGroupsState extends State<SubscriptionGroups> {
  Widget _createGroupCard(
      String id, String name, String icon, Color? color, int? numberOfMembers, void Function()? onLongPress) {
    var title = numberOfMembers == null ? name : '$name ($numberOfMembers)';

    return Card(
      color: color?.harmonizeWith(Theme.of(context).colorScheme.primary),
      child: InkWell(
        onTap: () {
          // Open page with the group's feed
          Navigator.pushNamed(context, routeGroup, arguments: GroupScreenArguments(id: id, name: name));
        },
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(deserializeIconData(icon), size: 24),
            Text(title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<GroupsModel, List<SubscriptionGroup>>.transition(
      store: context.read<GroupsModel>(),
      // TODO: Error
      onState: (_, state) {
        return GridView.builder(
          shrinkWrap: true,
          controller: widget.scrollController,
          padding: const EdgeInsets.only(top: 4),
          gridDelegate:
              const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 100, childAspectRatio: 20 / 15),
          itemCount: state.length + 1,
          itemBuilder: (context, index) {
            var actualIndex = index;

            if (actualIndex < state.length) {
              var e = state[actualIndex];

              return _createGroupCard(e.id, e.name, e.icon, e.color, e.numberOfMembers,
                  () => openSubscriptionGroupDialog(context, e.id, e.name, e.icon));
            }

            return null;
          },
        );
      },
    );
  }
}

class SubscriptionGroupEditDialog extends StatefulWidget {
  final String? id;
  final String name;
  final String icon;

  const SubscriptionGroupEditDialog({super.key, required this.id, required this.name, required this.icon});

  @override
  State<SubscriptionGroupEditDialog> createState() => _SubscriptionGroupEditDialogState();
}

class _SubscriptionGroupEditDialogState extends State<SubscriptionGroupEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  SubscriptionGroupEdit? _group;

  late String? id;
  late String? name;
  late String icon;
  Color? color;
  Set<String> members = <String>{};
  double breakpointScreenWidth1 = 200;
  double breakpointScreenWidth2 = 400;

  @override
  void initState() {
    super.initState();

    setState(() {
      icon = widget.icon;
    });

    context.read<GroupsModel>().loadGroupEdit(widget.id).then((group) => setState(() {
          _group = group;

          id = group.id;
          name = group.name;
          icon = group.icon;
          color = group.color;
          members = group.members;
        }));
  }

  void openDeleteSubscriptionGroupDialog(String id, String name) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(L10n.of(context).no),
              ),
              TextButton(
                onPressed: () async {
                  await context.read<GroupsModel>().deleteGroup(id);

                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(L10n.of(context).yes),
              ),
            ],
            title: Text(L10n.of(context).are_you_sure),
            content: Text(
              L10n.of(context).are_you_sure_you_want_to_delete_the_subscription_group_name_of_group(name),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    var subscriptionsModel = context.read<SubscriptionsModel>();

    var group = _group;
    if (group == null) {
      return const Center(child: CircularProgressIndicator());
    }

    List<Widget> buttonsLst1 = [
      TextButton(
        onPressed: () {
          setState(() {
            if (members.isEmpty) {
              members = subscriptionsModel.state.map((e) => e.id).toSet();
            } else {
              members.clear();
            }
          });
        },
        child: Text(L10n.of(context).toggle_all),
      ),
      TextButton(
        onPressed: id == null ? null : () => openDeleteSubscriptionGroupDialog(id!, name!),
        child: Text(L10n.of(context).delete),
      ),
    ];
    List<Widget> buttonsLst2 = [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(L10n.of(context).cancel),
      ),
      Builder(builder: (context) {
        onPressed() async {
          if (_formKey.currentState!.validate()) {
            await context.read<GroupsModel>().saveGroup(id, name!, icon, color, members);

            Navigator.pop(context);
          }
        }

        return TextButton(
          onPressed: onPressed,
          child: Text(L10n.of(context).ok),
        );
      }),
    ];
    double screenWidth = MediaQuery.of(context).size.width;

    return AlertDialog(
      actions: [
        SizedBox(
            width: screenWidth,
            child: screenWidth >= breakpointScreenWidth2
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ...buttonsLst1,
                    ...buttonsLst2,
                  ])
                : screenWidth >= breakpointScreenWidth1
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          ...buttonsLst1,
                        ]),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          ...buttonsLst2,
                        ]),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        ...buttonsLst1,
                        ...buttonsLst2,
                      ])),
      ],
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: group.name,
                      decoration: InputDecoration(
                        border: const UnderlineInputBorder(),
                        hintText: L10n.of(context).name,
                      ),
                      onChanged: (value) => setState(() {
                        name = value;
                      }),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return L10n.of(context).please_enter_a_name;
                        }

                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.palette, color: color),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            var selectedColor = color;

                            return AlertDialog(
                              title: Text(L10n.of(context).pick_a_color),
                              content: SingleChildScrollView(
                                child: MaterialColorPicker(
                                  selectedColor: color ?? Colors.grey,
                                  onColorChange: (value) => setState(() {
                                    selectedColor = value;
                                  }),
                                ),
                              ),
                              actions: <Widget>[
                                TextButton(
                                  child: Text(L10n.of(context).cancel),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                TextButton(
                                  child: Text(L10n.of(context).ok),
                                  onPressed: () {
                                    setState(() {
                                      color = selectedColor;
                                    });
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            );
                          });
                    },
                  ),
                  IconButton(
                    icon: Icon(deserializeIconData(icon)),
                    onPressed: () async {
                      var selectedIcon = await showIconPicker(
                        context,
                        configuration: SinglePickerConfiguration(
                            iconPackModes: [IconPack.material],
                            title: Text(L10n.of(context).pick_an_icon),
                            closeChild: Text(L10n.of(context).close),
                            searchHintText: L10n.of(context).search,
                            noResultsText: L10n.of(context).no_results_for),
                      );
                      if (selectedIcon != null) {
                        setState(() {
                          icon = jsonEncode(serializeIcon(selectedIcon));
                        });
                      }
                    },
                  )
                ],
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: subscriptionsModel.state.length,
                  itemBuilder: (context, index) {
                    var subscription = subscriptionsModel.state[index];

                    var subtitle =
                        subscription is SearchSubscription ? L10n.current.search_term : '@${subscription.screenName}';

                    var icon = subscription is SearchSubscription
                        ? const SizedBox(width: 48, child: Icon(Icons.search))
                        : UserAvatar(uri: subscription.profileImageUrlHttps);

                    return CheckboxListTile(
                      dense: true,
                      secondary: icon,
                      title: Text(subscription.name),
                      subtitle: Text(subtitle),
                      selected: members.contains(subscription.id),
                      value: members.contains(subscription.id),
                      onChanged: (v) => setState(() {
                        if (v == null || v == false) {
                          members.remove(subscription.id);
                        } else {
                          members.add(subscription.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
