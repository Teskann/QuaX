<div align="center">
<img src="assets/readme/icon.png" height="100">

# QuaX

[![GitHub release](https://img.shields.io/github/v/release/teskann/quax?style=for-the-badge&logo=github&color=2dba4e)](https://github.com/teskann/quax/releases)
[![License: MIT](https://img.shields.io/github/license/teskann/quax?style=for-the-badge&logo=opensourceinitiative&logoColor=FFFFFF&color=750014)](/LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/teskann/quax/ci.yml?style=for-the-badge&logo=github)](https://github.com/teskann/quax/actions)
![Minimum Android version](https://img.shields.io/badge/Android-7.0+-3DDC84?style=for-the-badge&logo=android&logoColor=white)
[![Downloads](https://img.shields.io/github/downloads/teskann/quax/total?style=for-the-badge&logo=github)](https://github.com/teskann/quax/releases)
![Flutter version](https://img.shields.io/badge/Flutter-3.41.6-54C5F8?style=for-the-badge&logo=flutter&logoColor=white)
![Target SDK](https://img.shields.io/badge/Target%20SDK-36-3DDC84?style=for-the-badge&logo=android&logoColor=white)

**QuaX** is a free, open-source, privacy-focused client for X (formerly Twitter). It is forked
from [Quacker](https://github.com/TheHCJ/Quacker)
and [Fritter](https://github.com/jonjomckay/fritter), and serves as an alternative
to [Squawker](https://github.com/j-fbriere/squawker).

[![Get it on GitHub](assets/readme/get-it-on-github.png)](https://github.com/teskann/quax/releases)
[![Get it on Obtainium](assets/readme/get-it-on-obtainium.png)](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Teskann/QuaX)

To verify the downloaded APK, use [these signing certificate fingerprints](./certificate-fingerprints.txt).

[Why isn't QuaX available on F-Droid?](./docs/QuaX.md#why-isnt-quax-available-on-f-droid)

</div>

## Features

> [!IMPORTANT]
> An X account is needed to use QuaX. Subscriptions, saved posts, and all other QuaX settings are
> independent from the account you're logged into. Everything is local to the app.

- ✅ Follow anybody
- ✅ Group your subscriptions in feeds to organize your timeline
- ✅ Trending topics from anywhere in the world
- ✅ Search anything on X
- ✅ Save posts offline
- ✅ Download any media (image, gif, video)
- ✅ Read X articles
- ✅ Modern Material 3 design
- ✅ No trackers

## Screenshots

<p float="left">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" width="32%"/>
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" width="32%"/>
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3.png" width="32%"/>
</p>

## More information

- [FAQ](./docs/QuaX.md)
- [LICENSE](./LICENSE)
- [Contributing](./CONTRIBUTING.md)
- [Changelog](./changelog.md)

## Build locally

Prerequisites:

- Python
- Dart
- Flutter ([get version here](./pubspec.yaml))

```bash
python -mvenv .venv
source ./.venv/bin/activate
pip install -r requirements.txt
python generate_icons.py
deactivate

flutter pub get
dart run flutter_launcher_icons
dart run dart_pubspec_licenses:generate
dart run intl_utils:generate
dart run flutter_iconpicker:generate_packs --packs material
flutter build apk --debug
```

Of course, you can work with this app on Android Studio.

## Star History
<a href="https://www.star-history.com/#teskann/quax&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=teskann/quax&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=teskann/quax&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=teskann/quax&type=date&legend=top-left" />
 </picture>
</a>