import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/client/client.dart';
import 'package:quax/user.dart';

class SearchTweetsModel extends Store<List<TweetWithCard>> {
  SearchTweetsModel() : super([]);

  Future<void> searchTweets(String query, String product) async {
    await execute(() async {
      if (query.isEmpty) {
        return [];
      } else {
        // TODO: Is this right?
        return (await Twitter.searchTweets(query, true, product: product))
            .chains
            .map((e) => e.tweets)
            .expand((element) => element)
            .toList();
      }
    });
  }
}

class SearchUsersModel extends Store<List<UserWithExtra>> {
  SearchUsersModel() : super([]);

  Future<void> searchUsers(String query, BuildContext context) async {
    await execute(() async {
      if (query.isEmpty) {
        return [];
      } else {
        return await Twitter.searchUsers(query);
      }
    });
  }
}
