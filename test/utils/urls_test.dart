import 'package:flutter_test/flutter_test.dart';
import 'package:quax/profile/profile.dart' show profileTabs;
import 'package:quax/utils/urls.dart';

void main() {
  Future<UriParseResult> parse(String url) => parseUri(Uri.parse(url));

  T parsedAs<T extends UriParseResult>(UriParseResult result, String reason) {
    expect(result, isA<T>(), reason: reason);
    return result as T;
  }

  ProfileTabs? tabOf(ProfileUriInfo info) {
    final index = info.profileTabIndex;
    if (index == null) {
      return null;
    }
    expect(index, inInclusiveRange(0, profileTabs.length - 1),
        reason: 'The tab index should point at a real entry of profileTabs. A -1 means the tab '
            'was not found and would be read as a position');
    return profileTabs[index].id;
  }

  group('parseUri()', () {
    group('profile links', () {
      test('Should read a plain profile link', () async {
        final profile = parsedAs<ProfileUriInfo>(await parse('https://x.com/DogsTrust'),
            'A link holding only a user name should be read as a profile link');

        expect(profile.screenName, 'DogsTrust',
            reason: 'The profile screen loads the account from this name, so it should be the '
                'single path part of the link');
        expect(tabOf(profile), isNull,
            reason: 'A plain profile link names no tab, so none should be preselected');
      });

      test('Should open the matching tab for a known sub path', () async {
        final replies = parsedAs<ProfileUriInfo>(
            await parse('https://x.com/DogsTrust/with_replies'),
            '/with_replies names an account, so it should be read as a profile link');
        expect(tabOf(replies), ProfileTabs.postsAndReplies,
            reason: 'X uses /with_replies for the posts and replies tab, so that tab should open');

        final media = parsedAs<ProfileUriInfo>(await parse('https://x.com/DogsTrust/media'),
            '/media names an account, so it should be read as a profile link');
        expect(tabOf(media), ProfileTabs.media,
            reason: 'X uses /media for the media tab, so that tab should open');
      });

      test('Should accept a sub path QuaX cannot show but open no tab', () async {
        final profile = parsedAs<ProfileUriInfo>(await parse('https://x.com/DogsTrust/lists'),
            '/lists is still a valid account link, so the profile should open instead of the '
                'link being handed to the browser');

        expect(tabOf(profile), isNull,
            reason: 'There is no Lists tab in QuaX, so no tab should be preselected');
      });

      test('Should ignore a slash at the end of the link', () async {
        final profile = parsedAs<ProfileUriInfo>(await parse('https://x.com/DogsTrust/'),
            'A slash at the end does not change what the link points to, so it should still be '
                'read as a profile');

        expect(profile.screenName, 'DogsTrust',
            reason: 'The trailing slash should not be read as an empty second path part');
      });
    });

    group('post links', () {
      test('Should read a status link', () async {
        final post = parsedAs<PostUriInfo>(await parse('https://x.com/DogsTrust/status/1729'),
            '/status/ is the normal shape of a link to one tweet, so it should be read as a post '
                'and not as a profile');

        expect(post.screenName, 'DogsTrust',
            reason: 'The author should be read from the link, so the tweet can be shown before '
                'it finishes loading');
        expect(post.id, '1729',
            reason: 'This id is sent to the API to load the tweet, so it should be the last path '
                'part and nothing else');
        expect(post.photoNumber, isNull,
            reason: 'This link points at the tweet and not at one of its images, so no image '
                'number should be set');
        expect(post.direct, isFalse,
            reason: 'Only a link ending in .jpg or .mp4 points straight at a file, so this one '
                'should not be marked direct');
      });

      test('Should read a topic link, which has no user name', () async {
        final post = parsedAs<PostUriInfo>(await parse('https://x.com/i/topics/tweet/1729'),
            'This link points at one tweet, so it should be read as a post. Reading it as '
                'anything else sends the user to the wrong screen when they tap it');

        expect(post.id, '1729',
            reason: 'The id should be the last path part, the one after "tweet"');
        expect(post.screenName, isNull,
            reason: 'This kind of link carries no user name, so none should be invented. A made '
                'up one would open the wrong profile when the user taps it');
      });

      test('Should read the photo number of a media link', () async {
        final post = parsedAs<PostUriInfo>(
            await parse('https://x.com/DogsTrust/status/1729/photo/2'),
            'A /photo/ link still points at a tweet, so it should be read as a post');

        expect(post.photoNumber, 2,
            reason: 'This number decides which image of the tweet opens in full screen, so it '
                'should be read from the link');
      });

      test('Should remove the FxEmbed file ending and mark the link as direct', () async {
        final post = parsedAs<PostUriInfo>(await parse('https://x.com/DogsTrust/status/1729.jpg'),
            'The .jpg ending does not stop this from being a link to a tweet, so it should be '
                'read as a post');

        expect(post.id, '1729',
            reason: 'The id is sent to the API, so the .jpg ending should be stripped first');
        expect(post.direct, isTrue,
            reason: 'This link should open the image rather than the tweet, and direct is the '
                'flag that says so');
      });
    });

    group('unknown links', () {
      test('Should return UnknownResult for the site root', () async {
        expect(await parse('https://x.com/'), isA<UnknownResult>(),
            reason: 'The site root names no account and no tweet, so nothing should be opened');
      });

      test('Should return UnknownResult for a path that is neither a profile nor a post', () async {
        expect(await parse('https://x.com/i/flow/login'), isA<UnknownResult>(),
            reason: 'An x.com path we do not handle should go to the browser rather than open an '
                'empty profile called "i"');
      });
    });

    // TODO(test): parseUri follows t.co links over the network before reading them again. Testing
    // that needs the fake http client from the mock server work, so it is not covered here.
  });

  group('extractPhotoNumber()', () {
    test('Should read the number after a "photo" part', () {
      expect(extractPhotoNumber(['user', 'status', '1', 'photo', '3'], 3), 3,
          reason: 'The index points at the "photo" part, so the number right after it should be '
              'the one that comes back');
    });

    test('Should return null when the part is not "photo"', () {
      expect(extractPhotoNumber(['user', 'status', '1', 'video', '3'], 3), isNull,
          reason: 'Only "photo" links carry an image number, so any other word should give null '
              'rather than the number that follows it');
    });

    test('Should return null when the number is missing or not a number', () {
      expect(extractPhotoNumber(['user', 'status', '1', 'photo'], 3), isNull,
          reason: 'A link that stops too early should give null and should not throw a RangeError');
      expect(extractPhotoNumber(['user', 'status', '1', 'photo', 'x'], 3), isNull,
          reason: 'Text that is not a number should give null rather than throw');
    });
  });

  group('parsePostLink()', () {
    test('Should read the handle and id of a quoted post permalink', () {
      final post = parsePostLink(Uri.parse('https://twitter.com/quax_tests/status/2095934459606376826'));

      expect(post?.screenName, 'quax_tests',
          reason: 'The handle is needed to open the post and to search it in the Wayback Machine');
      expect(post?.id, '2095934459606376826', reason: 'The id should be the path part after /status/');
    });

    test('Should give null for a link that is not a post', () {
      expect(parsePostLink(Uri.parse('https://x.com/quax_tests')), isNull,
          reason: 'A profile link holds no post, so nothing should be read from it');
    });
  });

  group('waybackSearchUri()', () {
    test('Should list the captures of the post under its twitter.com address', () {
      expect(waybackSearchUri('quax_tests', '2095934459606376826').toString(),
          'https://web.archive.org/web/*/twitter.com/quax_tests/status/2095934459606376826*',
          reason: 'Most captures predate x.com, and the trailing star also matches the variants with a query');
    });
  });
}
