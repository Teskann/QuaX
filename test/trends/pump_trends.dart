import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/trends/trends_model.dart';
import 'package:quax/trends/trends_screen.dart';

/// The trends screen with the models it reads.
Widget trendsScreenWithModels() => Builder(
    builder: (context) => MultiProvider(providers: [
          Provider(create: (_) => UserTrendLocationModel(PrefService.of(context, listen: false))),
          Provider(create: (context) => TrendsModel(context.read<UserTrendLocationModel>())),
          Provider(create: (_) => TrendLocationsModel()),
        ], child: TrendsScreen(scrollController: ScrollController(), focusNode: FocusNode())));
