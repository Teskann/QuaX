## QuaX v4.6.0

What's new in QuaX v4.6.0:
  - [PRIVACY IMPROVEMENT] Removed dependency on external [x-client-transaction-id generator](https://github.com/Teskann/x-client-transaction-id-generator) to compute `x-client-transaction-id` HTTPS headers. Now, everything is computed locally, inside QuaX itself. Done porting [XClientTransaction](https://github.com/iSarabjitDhiman/XClientTransaction/) to Dart. <sup>[[view modified code]](https://github.com/teskann/quax/commit/95ed1684bbd35690ebb8aee1972fd2d9189b2ca7)</sup>
  - Fixed #134 - "Oops! Something went wrong 🥲" when opening some profiles <sup>[[view modified code]](https://github.com/teskann/quax/commit/40a975ca06fafdfc52cbeff72140e9d418e2e7a2)</sup>
  - Fixed #95 - Prevented fetching videos automatically before playing if autoplay is disabled <sup>[[view modified code]](https://github.com/teskann/quax/commit/f0d68cc21c985fa54b5bf152ff19d024d84a7c10)</sup>


APK Certificate fingerprints:
```text
SHA1: B4:8C:12:75:81:4D:94:8D:84:00:32:D5:45:EE:06:A9:3E:0A:2D:BE
SHA256: 5E:39:1A:AA:89:9A:0B:21:A5:29:6A:4C:26:DB:50:12:7E:B8:40:63:6A:2A:35:18:14:16:75:3F:AB:1C:17:C3
```

Missed an update ? See [full changelog](https://github.com/teskann/quax/blob/master/changelog.md) for more details.
    