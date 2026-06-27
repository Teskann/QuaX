import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/media_grid/media_grid.dart';
import 'package:quax/search/search_model.dart';

class SearchMediaGrid extends StatelessWidget {
  final SearchMediaPagination model;

  const SearchMediaGrid({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return MediaGrid(
      controller: model.pagingController,
      firstPageErrorPrefix: L10n.of(context).unable_to_load_the_search_results,
      newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
      emptyMessage: L10n.of(context).no_results,
    );
  }
}
