<div align="center">
<img src="assets/readme/icon.png" height="100">

# QuaX

[![GitHub release](https://img.shields.io/github/v/release/teskann/quax?style=flat&logo=github&color=2dba4e)](https://github.com/teskann/quax/releases)
[![License: MIT](https://img.shields.io/github/license/teskann/quax?logo=opensourceinitiative&logoColor=FFFFFF&color=750014)](/LICENSE)
[![Build Status](https://github.com/teskann/quax/workflows/ci/badge.svg)](https://github.com/teskann/quax/actions)
![Minimum Android version](https://img.shields.io/badge/Android-7.0%2B-blue)

**QuaX** is a free, open-source, privacy-focused client for X (formerly Twitter). It is forked
from [Quacker](https://github.com/TheHCJ/Quacker)
and [Fritter](https://github.com/jonjomckay/fritter), and serves as an alternative
to [Squawker](https://github.com/j-fbriere/squawker).

[![Get it on GitHub](assets/readme/get-it-on-github.png)](https://github.com/teskann/quax/releases)
[![Get it on Obtainium](assets/readme/get-it-on-obtainium.png)](https://apps.obtainium.imranr.dev/redirect.html?r=obtainium://add/https://github.com/Teskann/QuaX)

To verify the downloaded APK, use [these signing certificate fingerprints](./certificate-fingerprints.txt).

</div>

## Features

> [!IMPORTANT]
> An X account is needed to use QuaX. Subscriptions, saved posts and all other QuaX settings are
> independent from the account you're logged into. Everything is local to the app.

- ✅ Customizable feeds
- ✅ Follow anybody
- ✅ Trending topics from anywhere in the world
- ✅ Search anything on X
- ✅ Save posts offline
- ✅ Download any media (image, gif, video)
- ✅ Modern Material 3 design
- ✅ No trackers

## Screenshots

<p float="left">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1.png" width="32%"/>
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2.png" width="32%"/>
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3.png" width="32%"/>
</p>

## Contribute

If you'd like to help make QuaX even better, here are a few ways you can contribute:

- **Report a bug:** If you've found a bug in QuaX, open
  a [new issue](https://github.com/teskann/quax/issues/new) (please check that someone else hasn't
  reported it first).
- **Request a feature:** Feel like something is
  missing? [Open an issue](https://github.com/teskann/quax/issues/new) detailing exactly what you're
  looking for.
- **Fix a bug:** To contribute to the codebase, check for issues labeled "good first issue".
  Otherwise, feel free to tackle any issue, fork the repository, push to a branch, and create a pull
  request.

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