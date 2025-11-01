import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/search/search.dart';
import 'package:quax/trends/trends_model.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/physics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TrendsList extends StatefulWidget {
  final ScrollController scrollController;

  const TrendsList({super.key, required this.scrollController});

  @override
  State<TrendsList> createState() => _TrendsListState();
}

class _TrendsListState extends State<TrendsList> {
  @override
  Widget build(BuildContext context) {
    var model = context.read<TrendsModel>();

    return ScopedBuilder<TrendsModel, List<Trends>>.transition(
      store: model,
      onError: (context, e) => TripleBuilder<UserTrendLocationModel, UserTrendLocations>(
        store: context.read<UserTrendLocationModel>(),
        builder: (context, triple) {
          return FullPageErrorWidget(
            error: e,
            stackTrace: null,
            prefix: L10n.of(context).unable_to_load_the_trends_for_widget_place_name(""),
            // triple.state.name!,
            onRetry: () => model.loadTrends(),
          );
        },
      ),
      onLoading: (context) => const Center(child: CircularProgressIndicator()),
      onState: (context, state) {
        if (state.isEmpty) {
          // TODO: Empty state
          return Container();
        }

        var trends = state[0].trends;
        if (trends == null) {
          return Text(
            L10n.of(context).there_were_no_trends_returned_this_is_unexpected_please_report_as_a_bug_if_possible,
          );
        }

        var numberFormat = NumberFormat.compact();

        return RefreshIndicator(
            onRefresh: () async {
              model.loadTrends();
            },
            child: ListView.builder(
              controller: widget.scrollController,
              physics: const LessSensitiveScrollPhysics(),
              itemCount: trends.length,
              itemBuilder: (context, index) {
                var trend = trends[index];

                return ListTile(
                    dense: true,
                    leading: Text('${++index}'),
                    title: Text(trend.name!),
                    subtitle: trend.tweetVolume == null
                        ? null
                        : Text(
                            L10n.of(context).tweets_number(
                              trend.tweetVolume!,
                              numberFormat.format(trend.tweetVolume),
                            ),
                          ),
                    onTap: () => Navigator.pushNamed(context, routeSearch,
                        arguments: SearchArguments(0,
                            focusInputOnOpen: false, query: Uri.decodeQueryComponent(trend.query!))));
              },
            ));
      },
    );
  }
}
