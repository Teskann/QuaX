import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/search/search.dart';
import 'package:quax/trends/_list.dart';
import 'package:quax/trends/_settings.dart';
import 'package:quax/trends/_tabs.dart';

class TrendsScreen extends StatefulWidget {
  final ScrollController scrollController;

  const TrendsScreen({super.key, required this.scrollController});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> with AutomaticKeepAliveClientMixin<TrendsScreen> {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Padding(
          padding: EdgeInsets.fromLTRB(8, 36, 8, 8),
          child: SearchBar(
            controller: _queryController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            leading: IconButton(icon: const Icon(Icons.search), onPressed: () => {}),
            onSubmitted: (query) {
              Navigator.pushNamed(
                context,
                routeSearch,
                arguments: SearchArguments(
                  0,
                  focusInputOnOpen: false,
                  query: query,
                ),
              );
            },
          ),
        ),
        bottom: TrendsTabBar(),
      ),
      floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.add),
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
