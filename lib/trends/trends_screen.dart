import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_filter_labels.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/search/search_filters_button.dart';
import 'package:quax/search/search_filters_screen.dart';
import 'package:quax/search/search_query.dart';
import 'package:quax/trends/_list.dart';
import 'package:quax/trends/_settings.dart';
import 'package:quax/trends/_tabs.dart';

class TrendsScreen extends StatefulWidget {
  final ScrollController scrollController;
  final FocusNode focusNode;

  const TrendsScreen({super.key, required this.scrollController, required this.focusNode});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> with AutomaticKeepAliveClientMixin<TrendsScreen> {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _queryController = TextEditingController();

  void _openResults(String query, [SearchFilters filters = SearchFilters.none]) {
    Navigator.pushNamed(
      context,
      routeSearch,
      arguments: SearchArguments(SearchTab.top, focusInputOnOpen: false, query: query, filters: filters),
    );
  }

  /// Opens the filters with the operators typed in the bar, then the results once they are set.
  Future<void> _openFilters() async {
    final typed = SearchQuery.parse(_queryController.text, appSearchLanguage());
    final filters = await SearchFiltersScreen.open(context, typed.filters);
    if (filters != null && mounted) {
      _openResults(typed.text, filters);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: kToolbarHeight + 16,
        titleSpacing: 8,
        title: SearchBar(
          controller: _queryController,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.search,
          hintText: L10n.of(context).search,
          leading: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.search)),
          onSubmitted: _openResults,
          trailing: [SearchFiltersButton(count: 0, onPressed: _openFilters)],
        ),
        bottom: TrendsTabBar(),
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add, semanticLabel: L10n.of(context).add_location),
          onPressed: () async => showModalBottomSheet(
                context: context,
                builder: (context) => const TrendsSettings(),
              )),
      body: TrendsList(
        scrollController: widget.scrollController,
      ),
    );
  }
}
