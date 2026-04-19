# QuaX Wiki

[](mdtoc)
### Table of contents

* [History – Forks & compatibility](#history--forks--compatibility)
	* [Compatibility with Squawker](#compatibility-with-squawker)
* [Reaching X: API Usage](#reaching-x-api-usage)
	* [X Account](#x-account)
	* [x-client-transaction-id](#x-client-transaction-id)
		* [Since v4.6.0](#since-v460)
		* [Before v4.6.0](#before-v460)
* [Subscriptions in QuaX](#subscriptions-in-quax)
* [Privacy & Security](#privacy--security)
	* [Why isn't QuaX available on F-Droid?](#why-isnt-quax-available-on-f-droid)
[](/mdtoc)

## History – Forks & compatibility

[![](https://mermaid.ink/img/pako:eNpVj01OwzAQha8SzTpNk9j5qRdINBFC7BBdIJIuTDJpfogdXEdQ2p6FHYuejiPgVi1SZzVv9L03M1soZInAYKX4UFuLNBeWqduslaKVfdHxzfRONVqjsn6_Dz9LazK52VVSdVjurHm2qPE-eZg-jrzoLsg54opMs3ZSvaoGFU6f3kf-YegzOL8Ck0zjuuNCHDOfl2Cby5oSmFYj2tCj6vlRwvZozkHX2GMOzLQlV10Oudgbz8DFi5T9xabkuKqBVfxtbdQ4lFxj2nDzc_8_VShKVIkchQZGXHIKAbaFT2B0FjsxDYlHaBQGoR_YsAHmu67jesSPAo-GNKYk3tvwdVrrOgEJCaF-HHgzl0RxtP8DogFzzw?type=png)](https://mermaid.live/edit#pako:eNpVj01OwzAQha8SzTpNk9j5qRdINBFC7BBdIJIuTDJpfogdXEdQ2p6FHYuejiPgVi1SZzVv9L03M1soZInAYKX4UFuLNBeWqduslaKVfdHxzfRONVqjsn6_Dz9LazK52VVSdVjurHm2qPE-eZg-jrzoLsg54opMs3ZSvaoGFU6f3kf-YegzOL8Ck0zjuuNCHDOfl2Cby5oSmFYj2tCj6vlRwvZozkHX2GMOzLQlV10Oudgbz8DFi5T9xabkuKqBVfxtbdQ4lFxj2nDzc_8_VShKVIkchQZGXHIKAbaFT2B0FjsxDYlHaBQGoR_YsAHmu67jesSPAo-GNKYk3tvwdVrrOgEJCaF-HHgzl0RxtP8DogFzzw)

> [!NOTE]
> QuaX and Squawker sometimes share patches.

### Compatibility with Squawker

QuaX and Squawker share a lot in common, since both apps stem from the same
codebase. Because of this, importing a Squawker backup into QuaX will likely
work to some extent, but it's not guaranteed. Some settings may be lost along
the way, and you may run into bugs. It's not something we'd recommend.

## Reaching X: API Usage

X provides APIs that require credentials for access, but they
are [very expensive](https://developer.x.com/#pricing) to use. To work around
this, QuaX uses unofficial X GraphQL APIs, which are the same ones used by web
browsers when accessing X.

The advantage of these APIs is that they are free and should remain so. Without
them, navigating X from a web browser would not be possible for free.

However, these APIs are neither official nor documented, and their use requires
reverse-engineering. This is why QuaX may stop working occasionally. X can
change its APIs at any time, and we will only be informed when we see the app
stop functioning. That being said, major changes to these APIs are rare, and the
application has been relatively stable since its launch in 2025.

> [!TIP]
> Essentially, QuaX makes X believe that the access is coming from a web browser.

### X Account

QuaX is forked
from [@jonjomckay Fritter](https://github.com/jonjomckay/fritter). Originally,
no Twitter account was required to use Fritter. It was **fully designed to work
without any login.** In 2023, Twitter changed its policies and required
authentication to use their APIs. As a consequence, Fritter became unusable and
was progressively abandoned.

This is why QuaX requires you to be logged into an account to work properly. But
it doesn't have to be *your* account. It needs any account.

**All settings are independent of the account you're logged into.**
This is why **we recommend logging into an account that has been created
specifically for the use of QuaX**. You can then import the subscriptions from
your real account,
although [this is limited](https://github.com/Teskann/QuaX/issues/37).

> [!TIP]
> It's also possible to log into several accounts. In this case, an
> account is selected randomly before sending any request to X.

### x-client-transaction-id

In July 2025, X introduced a requirement for the `x-client-transaction-id`
header in all HTTP requests. Without a valid header, the server would return a
404 error. To address this, a team developed
the [XClientTransaction](https://github.com/iSarabjitDhiman/XClientTransaction/)
project to enable computation of this header in Python.

#### Since v4.6.0

XClientTransaction [has been ported to Dart](https://github.com/Teskann/QuaX/commit/95ed1684bbd35690ebb8aee1972fd2d9189b2ca7)
and fully integrated into QuaX. The `x-client-transaction-id` header is computed
directly within the app, ensuring better performance and privacy.

#### Before v4.6.0

Initially, QuaX relied on XClientTransaction, which was wrapped into
a [server](https://github.com/Teskann/x-client-transaction-id-generator) by the
developers, simplifying integration since it was implemented in Python. By
default, this external service pointed to the developer's instance, but users
could configure a different endpoint in the settings.

This server was contacted before each request to generate a valid header.

## Subscriptions in QuaX

Subscriptions are completely unrelated to the subscriptions of the account you
are logged into. They are stored on the device. Subscribing to a profile in QuaX
won't impact the subscriptions of your X account.

To fetch feeds, QuaX runs an advanced searched request with special keywords to
filter results on people you follow.

Though X cannot know exactly who you follow in QuaX, it could deduce it from the
requests that are made everytime you refresh your feed.

## Privacy & Security

QuaX collects no data and contains no trackers. Compared to using X in a web
browser, QuaX only sends the strictly necessary requests and ignores all
tracking when opening a link.

The source code is 100% open source, and official APKs are built using GitHub
Actions workflows that are also fully open source and publicly auditable. APK
signing certificate fingerprints are published alongside each release so users
can independently verify the authenticity and origin of every build.

QuaX checks for available updates on every startup. It also regularly updates
its dependencies and Flutter/Dart toolchain, and targets the latest Android SDK
to benefit from the most recent platform security improvements. You can check
the required Flutter
[here](https://github.com/Teskann/QuaX/blob/master/pubspec.yaml#L23) and the
targeted SDK
[here](https://github.com/Teskann/QuaX/blob/master/android/app/build.gradle#L63).

QuaX requires
[very few Android permissions](https://github.com/search?q=repo%3ATeskann%2FQuaX%20android.permission&type=code)
to operate:

- Required permission for the app to work:
    - `android.permission.INTERNET`
- **Optional** permissions to download medias (legacy, you can download without
  them):
    - `android.permission.READ_EXTERNAL_STORAGE` (for Android <= 10)
    - `android.permission.WRITE_EXTERNAL_STORAGE` (for Android <= 10)
    - `android.permission.MANAGE_EXTERNAL_STORAGE` (for Android 11 and above)

> [!NOTE]
> QuaX has never undergone a formal security audit. The project is far too 
> small to justify the cost of one. Use it with that in mind.

### Why isn't QuaX available on F-Droid?

F-Droid builds apps from source using its own infrastructure and signs them with
its own keys, meaning the APK you'd download wouldn't be signed with the
developer's keys. This creates a security concern: users would have no way to
verify that the build actually comes from this project's maintainer. On top of
that, F-Droid updates tend to lag behind releases by days or even weeks, which
is particularly problematic for an app like QuaX that may need quick fixes when
X changes its APIs.

The only way QuaX could be on F-Droid without these drawbacks is through a
reproducible build — a process that lets F-Droid build the app from source while
still producing a binary identical to the one signed by the developer. This is
something we haven't gotten around to setting up yet.

Even if QuaX were eventually available on F-Droid via a reproducible build, the
recommended way to install and keep the app up to date would still be through 
**[Obtainium](https://github.com/ImranR98/Obtainium)** combined with 
**[App Verifier](https://github.com/soupslurpr/AppVerifier)**, which lets you
pull releases directly from GitHub and independently verify the APK signature.
