## QuaX v4.5.0

What's new in QuaX v4.5.0:
  - Upgraded Flutter and packages <sup>[[view modified code]](https://github.com/teskann/quax/commit/4e46170054a12a55d6496d74ca2701e859c1e99e)</sup>
  - Added support for articles. Supported article content: text, images, videos, code blocks, quotes, links, mentions, titles, ordered lists, unordered lists, bold text, italic text, dividers. Translation is not supported in articles, so "Translate" button is removed on tweets that contain an article. The same way, "Share tweet content" options are not available for articles (text remains selectable). Articles are displayed as a preview when the tweet is not opened. Open the tweet to see the full content. Articles can be saved, but for complexity reasons, only the preview is saved for offline access, network is required to read the full content of a saved article. Please report any issue related to this new feature. It has been implemented by reverse-engineering x.com's APIs based on examples I had access to, some contents might not be parsed correctly. (#53) <sup>[[view modified code]](https://github.com/teskann/quax/commit/a2b47a7b9ede7fe150a0c4207535aea1fa970451)</sup>
  - Updated Vietnamese translation (#124) (by @chemchetchagio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/4f4d03f53bbdc1a34024bc7a7a0f34a9af9e2cf2)</sup>


APK Certificate fingerprints:
```text
SHA1: B4:8C:12:75:81:4D:94:8D:84:00:32:D5:45:EE:06:A9:3E:0A:2D:BE
SHA256: 5E:39:1A:AA:89:9A:0B:21:A5:29:6A:4C:26:DB:50:12:7E:B8:40:63:6A:2A:35:18:14:16:75:3F:AB:1C:17:C3
```

Missed an update ? See [full changelog](https://github.com/teskann/quax/blob/master/changelog.md) for more details.
    