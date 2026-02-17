import 'package:quax/profile/profile.dart' show profileTabs;
import 'package:url_launcher/url_launcher_string.dart';

import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';

const _channel = MethodChannel('browser_resolver');

Future<void> openInDefaultBrowser(String url) async {
  final packageName = await _channel.invokeMethod<String>('getDefaultBrowser');
  final intent = AndroidIntent(
    action: 'android.intent.action.VIEW',
    data: url,
    package: packageName,
  );
  await intent.launch();
}

Future<void> openUri(String uri) async {
  await launchUrlString(uri, mode: LaunchMode.externalApplication);
}

sealed class UriParseResult {}

enum ProfileTabs { posts, postsAndReplies, media, saved }

class ProfileUriInfo extends UriParseResult {
  String screenName;
  int? profileTabIndex;

  ProfileUriInfo(this.screenName, ProfileTabs? tab) {
    if (tab != null) {
      profileTabIndex = profileTabs.indexWhere((e) => e.id == tab);
    }
  }
}

ProfileUriInfo? _parseAsProfileLink(List<String> parts) {
  if (parts.isEmpty) return null;

  // https://x.com/DogsTrust
  if (parts.length == 1) {
    return ProfileUriInfo(parts.first, null);
  }

  const Map<String, ProfileTabs?> supportedProfileSubpaths = {
    "with_replies": ProfileTabs.postsAndReplies, // https://x.com/DogsTrust/with_replies
    "media": ProfileTabs.media, // https://x.com/DogsTrust/media
    // All following sublinks are not supported by QuaX, but remain valid for an account link
    "highlights": null, // https://x.com/DogsTrust/highlights
    "affiliates": null, // https://x.com/DogsTrust/affiliates
    "about": null, // https://x.com/DogsTrust/about
    "topics": null, // https://x.com/DogsTrust/topics
    "lists": null, // https://x.com/DogsTrust/lists
  };

  if (supportedProfileSubpaths.containsKey(parts[1])) {
    return ProfileUriInfo(parts.first, supportedProfileSubpaths[parts[1]]);
  }

  // The URI is not an account link
  return null;
}

class PostUriInfo extends UriParseResult {
  String? screenName;
  String id;
  bool direct = false;
  int? photoNumber;

  PostUriInfo(this.screenName, this.id, {this.photoNumber}) {
    direct = id.endsWith(".jpg") || id.endsWith(".mp4");
    // In case of FX Twitter links
    // https://github.com/FxEmbed/FxEmbed?tab=readme-ov-file#direct-media-links
    id = id.replaceAll(RegExp(r'\.(?:jpg|mp4)$'), '');
  }
}

int? extractPhotoNumber(List<String> parts, int index) {
  if (parts.length < index + 2) return null;
  if (parts[index] != "photo") return null;
  return int.tryParse(parts[index + 1]);
}

PostUriInfo? _parseAsPostLink(List<String> parts) {
  if (parts.length < 3) return null;

  if (parts[1] == "status") {
    return PostUriInfo(parts[0], parts[2], photoNumber: extractPhotoNumber(parts, 3));
  }

  if (parts.length < 4) return null;

  if (parts[0] == "i" && parts[1] == "topics" && parts[2] == "tweet") {
    return PostUriInfo(null, parts[3], photoNumber: extractPhotoNumber(parts, 4));
  }

  // The URI is not a post link
  return null;
}

class UnknownResult extends UriParseResult {}

UriParseResult parseUri(Uri link) {
  link = link.replace(path: link.path.replaceAll(RegExp(r'/$'), ''));
  final parts = link.pathSegments;

  final profileInfo = _parseAsProfileLink(parts);
  if (profileInfo != null) {
    return profileInfo;
  }
  final postInfo = _parseAsPostLink(parts);
  if (postInfo != null) {
    return postInfo;
  }
  return UnknownResult();
}
