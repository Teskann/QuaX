## QuaX v4.12.0

What's new in QuaX v4.12.0:
  - 🔗 Added intent filters for fixupx.com URLs (#164) (by @uptivuptiz) <sup>[[view modified code]](https://github.com/teskann/quax/commit/8ccdcd2ee57708318127a9f832fd0f7c0077fa22)</sup>
  - 📶🎬 You can now save data by customizing the video pre-fetching duration. ➡️ `Settings` > `Medias` > `Video prefetch duration` <sup>[[view modified code]](https://github.com/teskann/quax/commit/88057e0ed7bffc13828e329d21d3be10ccf6cbe9)</sup>
  - 🎬 Improved video player stability and limited the number of GIFs that can be played simultaneously on a media grid to avoid lags and freezes <sup>[[view modified code]](https://github.com/teskann/quax/commit/5b2328ea83e4b61dc860d335471ad481f1f64f3c)</sup>
  - 🔖📁 Introducing folders for saved posts ! Long press on the "save" button of a post to select a folder. <sup>[[view modified code]](https://github.com/teskann/quax/commit/6403a1ba157c892bd263e0f22abc610d45a62210)</sup>
  - ❤️ You can now like posts ! Likes stay on your device. X cannot know what you like. You can find liked posts in the "Likes" folder of the *Saved* tab. (Fixed #143) <sup>[[view modified code]](https://github.com/teskann/quax/commit/8921f4024ff26804cdee9b4e3011a73135e6bb30)</sup>
  - ⚙️ Split options to select the media quality for images and videos. Now they are independent <sup>[[view modified code]](https://github.com/teskann/quax/commit/4984b4e0a254b6839d0b8b0463faf5e8cccdffa5)</sup>

## QuaX v4.11.0

What's new in QuaX v4.11.0:
  - 👤 You can now **import more than 70 subscriptions** per account (fixed #153, #109, #37). ⚠️ Be careful that too many subscriptions might lead to rate limitations ! <sup>[[view modified code]](https://github.com/teskann/quax/commit/787906b3a6ea165b64d57c547d507a2e75034824)</sup>
  - 📜 Infinite scroll is now supported for *Followers* / *Following* lists (fixed #150) <sup>[[view modified code]](https://github.com/teskann/quax/commit/71367f3caf1258aa9a43c08f9544f0713e75d4c1)</sup>
  - ⚙️ Added an option to select the default tab for the home feed (*Following* / *For You*). Defaults to *Following* <sup>[[view modified code]](https://github.com/teskann/quax/commit/21404ad8e0d53bd7946b4dcd68bfbfea9ade1c5e)</sup>
  - 📱 Fixed UI components being hidden behind the Android navigation bar (fixed #161) <sup>[[view modified code]](https://github.com/teskann/quax/commit/aa897da608633c1d2237e96407253792e44a4292)</sup>
  - ⚙️ You can now customize the number of columns in the media grids (for both search & profile medias) ➡️ `Settings` > `Media` > `Media grid columns` (addressed #151) <sup>[[view modified code]](https://github.com/teskann/quax/commit/409dba6a35290f5c3983ed5377f75201ba6e2ea1)</sup>
  - 🎬 Fixed an issue in GIFs that introduced a small lag before looping (regression from 4.10.0) <sup>[[view modified code]](https://github.com/teskann/quax/commit/abca5d833a5680a5de0fc8a545f52e7a9760d7c5)</sup>

## QuaX v4.10.0

What's new in QuaX v4.10.0:
  - 🎬 Fully reimplemented the **video player**. This should address most of video-related issues, especially the unability to replay videos. This should also fix video playback on some devices without system codecs (#140, #126) as now ffmpeg is embedded in the apk. This implements subtitles support, an option to select video quality, better stability for background playing and double tap to go forward/backward. Technically, it now depends on <sup>[[view modified code]](https://github.com/teskann/quax/commit/c8e33d90f3f588fdad06fb02db2316724b3ec0a6)</sup>
  - Fixed an issue when some tweets are sometimes truncated <sup>[[view modified code]](https://github.com/teskann/quax/commit/649d0d2a9434fe2649f61ef9ca6d8ce4bd1e9985)</sup>
  - 🧵 Redesigned how threads look. The thick-colored band on the left is gone. Tweets of a thread now sit in a single card, linked by a subtle connector line between profile pictures (like on X). Threads are much cleaner to read,   and two threads following each other in the timeline are no longer mistaken for one. <sup>[[view modified code]](https://github.com/teskann/quax/commit/3fc4b81eae1cdfb9bf1da3a887997e1ab9c00472)</sup>
  - Added a **"Media"** tab to search <sup>[[view modified code]](https://github.com/teskann/quax/commit/4c3ade6b5a296cb3cb5612a6e67438e0f1825acf)</sup>
  - ⚙️ Reorganized and classified settings more precisely <sup>[[view modified code]](https://github.com/teskann/quax/commit/0f30df264dde5c601cccd0cde2fa0f9bbde7d345)</sup>

## QuaX v4.9.3

What's new in QuaX v4.9.3:
  - Upgraded Flutter to 3.44.4, upgraded dependencies and fixed Dart issues <sup>[[view modified code]](https://github.com/teskann/quax/commit/24d80713fd142338b5abd2fe6208214cc3c49de7)</sup>
  - Added health-aware account selection to mitigate 404/429 errors. Replaced the random per-request account selection with a strategy that tracks each account's health and retries on another account when X returns an error. This addresses #147, #148, #149, #156 and #154 <sup>[[view modified code]](https://github.com/teskann/quax/commit/9debe26101269342edba3bb467984ffe6a7bfbae)</sup>
  - Fixed #154 - `"type 'Null' is not a subtype of type 'Map<String, dynamic>'"` <sup>[[view modified code]](https://github.com/teskann/quax/commit/cde65d107637b4d5174d26ac546d8e5282f133bd)</sup>

## QuaX v4.9.2

What's new in QuaX v4.9.2:
  - Fixed on demand file issues regarding x-client-transaction-id (many thanks you @clintonalee for the solution) (#155) <sup>[[view modified code]](https://github.com/teskann/quax/commit/861f8048165444baf048544846f399020a687a9d)</sup>

## QuaX v4.9.1

What's new in QuaX v4.9.1:
  - Upgraded Flutter to 3.44.1 and updated dependencies. Migrated to infinite_scroll_pagination v5. This is a major change in terms of implementation. Please report any issue with infinite scroll you could face with this release. <sup>[[view modified code]](https://github.com/teskann/quax/commit/16ccde98d3a54beb3e1f01a5f588ca71c0cb6d5d)</sup>

## QuaX v4.9.0

What's new in QuaX v4.9.0:
  - Fixed #141 - Some tweets don't appear in feeds and search results <sup>[[view modified code]](https://github.com/teskann/quax/commit/327114fe16ae2cba50bb8e9eb64b65acd01fd148)</sup>
  - Feeds now stay visible while they are being refreshed <sup>[[view modified code]](https://github.com/teskann/quax/commit/f41fcb7a9d70b433d4afc3acd681af13073a248b)</sup>
  - Seamless tweet opening: show opened tweet instantly while loading replies <sup>[[view modified code]](https://github.com/teskann/quax/commit/b1e47d605a8987ff7f3667471cbdadad7a6d8e74)</sup>
  - Fixed content being hidden behind the Android Navigation Bar when opening a tweet <sup>[[view modified code]](https://github.com/teskann/quax/commit/9e949cbff6d25705367c495f85652ed5e1ecf6f1)</sup>
  - Added video support for seamless tweet opening <sup>[[view modified code]](https://github.com/teskann/quax/commit/5ad1efa4ec67c1d8195ad2e8bf6018ab7833dd49)</sup>

## QuaX v4.8.2

What's new in QuaX v4.8.2:
  - Fixed #144 - Can't load posts on 4.8.1 <sup>[[view modified code]](https://github.com/teskann/quax/commit/16c851d33a5ef92650650660e212849439f81897)</sup>

## QuaX v4.8.1

What's new in QuaX v4.8.1:
  - Display impressions count on posts (by @lebakassemmerl) <sup>[[view modified code]](https://github.com/teskann/quax/commit/75fd7f8ea288c5535a6147cb398e903859645ab7)</sup>

## QuaX v4.8.0

What's new in QuaX v4.8.0:
  - Search results in the *Top* and *Latest* tabs **now support infinite scroll**, instead of stopping after the first results (implemented #44) <sup>[[view modified code]](https://github.com/teskann/quax/commit/409570115425c4ed7b66577b16e6c0746f96b455)</sup>

## QuaX v4.7.1

What's new in QuaX v4.7.1:
  - Removed all unused strings from translation files. Translation files are now sorted by key and are fully covered. <sup>[[view modified code]](https://github.com/teskann/quax/commit/b4034a251ea55ae58eac8866d6056bb2fbb3b7db)</sup>
  - Implemented #17 - Keep position in group feeds after actions <sup>[[view modified code]](https://github.com/teskann/quax/commit/d801551137d38cc1f3d1d6052ef7c798e38b6b04)</sup>
  - Upgraded Flutter to 3.41.9, updated dependencies <sup>[[view modified code]](https://github.com/teskann/quax/commit/d4cf1bac40a976810bf0a8b27cc9d1842c024b06)</sup>
  - Fixed posts not being shown on some profiles (Tweets / Tweets & Replies tabs) <sup>[[view modified code]](https://github.com/teskann/quax/commit/c9ec545020db0b07bc72f48950fa4ffcca157a8c)</sup>
  - Added a search bar to the subscriptions list, making it easier to find a followed account when you have many of them <sup>[[view modified code]](https://github.com/teskann/quax/commit/c9d40f2e3d70654d122e824370a11f1f280020a1)</sup>

## QuaX v4.7.0

What's new in QuaX v4.7.0:
  - Cleaned repository, removed unused files <sup>[[view modified code]](https://github.com/teskann/quax/commit/52076e4cd19f3ee48cc6b8e8816fd735d26ac808)</sup>
  - Prepare reproducible build for future F-Droid publication. QuaX now recommends using `fvm` instead of raw `flutter` to force a specific flutter version for the build. Removed flavor-based behavior that led to differences between GitHub builds and F-Droid builds. <sup>[[view modified code]](https://github.com/teskann/quax/commit/cf3732208ed933b8e84011bd70cc0158ecf0e337)</sup>
  - Fixed #92 - Media tab stops loading new posts at one point - Inspired by @j-fbriere's fix on Squawker <sup>[[view modified code]](https://github.com/teskann/quax/commit/125f1a518fd99e8c83970c2d98b8979981186d7a)</sup>
  - [UI Improvement] Brand new view for the "Media" tab on profiles ! Now, medias are displayed in a staggered grid. This fully completed #20. <br/> <img width="360" height="800" alt="image" src="https://github.com/user-attachments/assets/2fe7ba1f-2306-4369-a90c-f5fd3dd137e6" /> <sup>[[view modified code]](https://github.com/teskann/quax/commit/4a0f803b13f9a1e5d48b03e841729bd8ae2289ee)</sup>

## QuaX v4.6.1

What's new in QuaX v4.6.1:
  - Updated readme and documentation <sup>[[view modified code]](https://github.com/teskann/quax/commit/0fdef571759745e852aa54bd0b95a20080958379)</sup>
  - Upgraded Android SDK to 37 (Android 17) and upgraded android NDK to 29.0.14206865. <sup>[[view modified code]](https://github.com/teskann/quax/commit/ae2b8855f7ef1e1508e90ed544ef6a86f2121216)</sup>
  - Upgraded Flutter to 3.41.7, upgraded dependencies <sup>[[view modified code]](https://github.com/teskann/quax/commit/c5b264b34ac6177488ab5cd0421d990b05df895e)</sup>
  - Fixed medias not appearing in the gallery after download <sup>[[view modified code]](https://github.com/teskann/quax/commit/fc471839cac5394fa56fbf18a35967ee1ade03bc)</sup>
  - QuaX is now fully translated in the following languages: 🇸🇦 Arabic, 🇧🇾 Belarusian, 🇧🇾 Belarusian Latin, 🇪🇸 Catalan, 🇨🇿 Czech, 🇩🇪 German, 🇬🇧 English, Esperanto, 🇪🇸 Spanish, 🇪🇪 Estonian, 🇪🇸 Basque, 🇫🇷 French, 🇮🇳 Hindi, 🇮🇩 Indonesian, 🇮🇹 Italian, 🇯🇵 Japanese, 🇰🇷 Korean, 🇮🇳 Malayalam, 🇳🇴 Norwegian Bokmål, 🇳🇱 Dutch, 🇵🇱 Polish, 🇵🇹 Portuguese, 🇧🇷 Portuguese (Brazil), 🇷🇴 Romanian, 🇷🇺 Russian, 🇹🇷 Turkish, 🇺🇦 Ukrainian, 🇻🇳 Vietnamese, 🇨🇳 Chinese (Simplified), 🇹🇼 Chinese (Traditional). The missing translations have been generated with AI, feel free to fix them if they are inaccurate. <sup>[[view modified code]](https://github.com/teskann/quax/commit/a22b2975bf071ef553564adbb6e2eac0bab30480)</sup>

## QuaX v4.6.0

What's new in QuaX v4.6.0:
  - [PRIVACY IMPROVEMENT] Removed dependency on external [x-client-transaction-id generator](https://github.com/Teskann/x-client-transaction-id-generator) to compute `x-client-transaction-id` HTTPS headers. Now, everything is computed locally, inside QuaX itself. Done porting [XClientTransaction](https://github.com/iSarabjitDhiman/XClientTransaction/) to Dart. <sup>[[view modified code]](https://github.com/teskann/quax/commit/95ed1684bbd35690ebb8aee1972fd2d9189b2ca7)</sup>
  - Fixed #134 - "Oops! Something went wrong 🥲" when opening some profiles <sup>[[view modified code]](https://github.com/teskann/quax/commit/40a975ca06fafdfc52cbeff72140e9d418e2e7a2)</sup>
  - Fixed #95 - Prevented fetching videos automatically before playing if autoplay is disabled <sup>[[view modified code]](https://github.com/teskann/quax/commit/f0d68cc21c985fa54b5bf152ff19d024d84a7c10)</sup>

## QuaX v4.5.0

What's new in QuaX v4.5.0:
  - Upgraded Flutter and packages <sup>[[view modified code]](https://github.com/teskann/quax/commit/4e46170054a12a55d6496d74ca2701e859c1e99e)</sup>
  - Added support for articles. Supported article content: text, images, videos, code blocks, quotes, links, mentions, titles, ordered lists, unordered lists, bold text, italic text, dividers. Translation is not supported in articles, so "Translate" button is removed on tweets that contain an article. The same way, "Share tweet content" options are not available for articles (text remains selectable). Articles are displayed as a preview when the tweet is not opened. Open the tweet to see the full content. Articles can be saved, but for complexity reasons, only the preview is saved for offline access, network is required to read the full content of a saved article. Please report any issue related to this new feature. It has been implemented by reverse-engineering x.com's APIs based on examples I had access to, some contents might not be parsed correctly. (#53) <sup>[[view modified code]](https://github.com/teskann/quax/commit/a2b47a7b9ede7fe150a0c4207535aea1fa970451)</sup>
  - Updated Vietnamese translation (#124) (by @chemchetchagio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/4f4d03f53bbdc1a34024bc7a7a0f34a9af9e2cf2)</sup>

## QuaX v4.4.1

What's new in QuaX v4.4.1:
  - Fixed #115 replies being included when they shouldn't (by @AdNenio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/1570379868eb929e1c5c0bed7bc1b067add89410)</sup>

## QuaX v4.4.0

What's new in QuaX v4.4.0:
  - Ported "share tweet as image" feature from Squawker with higher quality rendering (implemented #64) (#118) (by @AdNenio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/7353e6ae05f20d7a0d28d48d0be5ecebe5f3886f)</sup>
  - Improved the "share" menu (when sharing a tweet) <sup>[[view modified code]](https://github.com/teskann/quax/commit/29e5a2c45356c4b0c9cb16b242566df8f4f90e3e)</sup>
  - Rolled back `webview_flutter` version to fix login issues on some devices (fixed #106) <sup>[[view modified code]](https://github.com/teskann/quax/commit/07f7b1906c7e554244260f32ece5b13803546aec)</sup>
  - Added an option to hide subscriptions from main feed (implemented #54) <sup>[[view modified code]](https://github.com/teskann/quax/commit/7ba60b0a49cc91d75017ea950350c4ea4c7ae3d1)</sup>

## QuaX v4.3.0

What's new in QuaX v4.3.0:
  - Added support of community notes (#114) <sup>[[view modified code]](https://github.com/teskann/quax/commit/769b2bc850c4d166df3ecfcca3d7027f5bffbfa5)</sup>

## QuaX v4.2.8

What's new in QuaX v4.2.8:
  - Added the possibility to view and save user profile picture and banner (fixed #94) <sup>[[view modified code]](https://github.com/teskann/quax/commit/f4f5fcd58f2fdaaff19bde182436e44ba5b0293d)</sup>

## QuaX v4.2.7

What's new in QuaX v4.2.7:
  - Fixed a bug leading to stack traces appearing in app and improved display of quoted tweets (PR #108) (by @AdNenio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/ec527cdb026cd63df904ec1605fbb55b6a422d17)</sup>
  - Enabled text selection within tweets (fixed #107) <sup>[[view modified code]](https://github.com/teskann/quax/commit/e9d549dd113ae53a963b3569710c8f8c5e1e1a34)</sup>

## QuaX v4.2.6

What's new in QuaX v4.2.6:
  - Re-enabled Impeller, as Flutter 3.41.1 [fixed the /e/OS issue with the WebView](https://github.com/flutter/flutter/issues/172622) (see #45) <sup>[[view modified code]](https://github.com/teskann/quax/commit/389fc2bd88d474730f1a5d781f5b8de4beee0bcb)</sup>
  - Added an option to open the link in the default browser in case it could not be opened by QuaX <sup>[[view modified code]](https://github.com/teskann/quax/commit/9a327d49403670d92596205caebd2a8780b2d47b)</sup>
  - Fixed issues with event posts (fixed #105) <sup>[[view modified code]](https://github.com/teskann/quax/commit/4b9bf10b9b68bbd96dce2d6ba5d7c111197f2b20)</sup>
  - Fixed support of `t.co` links <sup>[[view modified code]](https://github.com/teskann/quax/commit/737291c6ae99a207514ec2ccc0a2c6b711f2e2f8)</sup>

## QuaX v4.2.5

What's new in QuaX v4.2.5:
  - Updated Vietnamese (#97) (by @chemchetchagio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/3e4d2bbaa4aab54db9888c069fb6647594de8ab1)</sup>
  - Fixed #103 - Broadcast posts errors <sup>[[view modified code]](https://github.com/teskann/quax/commit/022ef84b07a097f8a5d9aafdafaa5152d7f22e57)</sup>
  - Removed "refresh subscriptions" button, as it relied on an X API that is not accessible without authentification, closing #14 and #102 <sup>[[view modified code]](https://github.com/teskann/quax/commit/98379427782d6dc370c79c09ba97962e65d1f183)</sup>
  - Added popups to explain why logging in is required. Inform users that this does not enable interacting with posts, which is misleading for newcomers (see #99 and forum posts) <sup>[[view modified code]](https://github.com/teskann/quax/commit/081d7725854b70479c49efc645a65df6957086fd)</sup>
  - Updated Flutter to 3.41.1 and updated dependencies <sup>[[view modified code]](https://github.com/teskann/quax/commit/aac070531fd8f80cacf0315fa62e8386cff21e34)</sup>
  - Fixed and improved changelog and release notes generation <sup>[[view modified code]](https://github.com/teskann/quax/commit/b81d765f60ef3bfddad19aff55a15a3caa8fc494)</sup>

## QuaX v4.2.4

What's new in QuaX v4.2.4:
  - Fixed #91 - Opening the x.com post/profile link with QuaX redirects to main menu <sup>[[view modified code]](https://github.com/teskann/quax/commit/5933535307cb35decca53ed251e9bc8fa53539b3)</sup>

## QuaX v4.2.3

What's new in QuaX v4.2.3:
  - Updated dependencies <sup>[[view modified code]](https://github.com/teskann/quax/commit/7ce5620e2127d76d63bc533296f101624fec2e54)</sup>
  - Improved link handling (fixed #89 and fixed #67) and added an option to set the default tab for profiles (fixed #62) <sup>[[view modified code]](https://github.com/teskann/quax/commit/c0642f908a850dc90a2b533f9aee7c00749bb5ef)</sup>
  - Implemented a more robust way to tag contributors in release notes <sup>[[view modified code]](https://github.com/teskann/quax/commit/a399d4b50ff797ed6c5cd7d2fe0fdafcce6893e1)</sup>

## QuaX v4.2.2

What's new in QuaX v4.2.2:
  - Untracked files that could be generated, updated the documentation <sup>[[view modified code]](https://github.com/teskann/quax/commit/afe396ab73713908a77d0bfe98640c6e43e27978)</sup>
  - Untracked files that could be generated, updated the documentation <sup>[[view modified code]](https://github.com/teskann/quax/commit/36ad1ae28282e8e4e200e2771650480fc1d58469)</sup>
  - Added an option to always show full tweet content (#85) (by @micahmo) <sup>[[view modified code]](https://github.com/teskann/quax/commit/5f3590caa249465f833c9f88e0d8516101aab705)</sup>
  - Fixed a bug with how entities are handled that was sometimes deleting text in the middle of a tweet (#87) (by @AdNenio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/98b97694edd12433b850f1e2767a4f8dc3632371)</sup>

## QuaX v4.2.1

What's new in QuaX v4.2.1:
  - Added APK certificate fingerprints to repository and to release notes. (Fixed #83) <sup>[[view modified code]](https://github.com/teskann/quax/commit/3c8443aa28d1c63f16033302667362453145c3da)</sup>
  - Fixed a bug preventing translation of tweet replies (#82) (by @AdNenio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/06007fe61a4a1ac32d22e1e5d1c8d354776948c3)</sup>

## QuaX v4.2.0

What's new in QuaX v4.2.0:
  - Fixed #20 - Re-implemented basic support for the media tab (#78) (by @lebakassemmerl) <sup>[[view modified code]](https://github.com/teskann/quax/commit/4b0f1b2d59fdfead00637b0aa6d9bc6d50ddc8f8)</sup>
  - Removed dependencies from git repositories that don't exist <sup>[[view modified code]](https://github.com/teskann/quax/commit/a43fd16bbd1f8c1b530c2d557e991a19353a2398)</sup>
  - Fixed error when tweets are hidden due to local laws and age estimation <sup>[[view modified code]](https://github.com/teskann/quax/commit/c407789c4ae7798e79fde4cc4eca7112310bae64)</sup>
  - Simplified release notes <sup>[[view modified code]](https://github.com/teskann/quax/commit/30924fd64faf0f87e9521e65d7525163197a7f4c)</sup>
  - Updated vietnamese and fixed some typos (#79) (by @giua1nganvisaoanhchithayminhemtrongbongdem) <sup>[[view modified code]](https://github.com/teskann/quax/commit/c331fee9283cc2c1c5a3cfcb887ad168be08afd7)</sup>
  - Made links in bio clickable (fixed #23) (#56) (by @AdNenio) <sup>[[view modified code]](https://github.com/teskann/quax/commit/dfe05d4b45f7ccfa84a74fd1483d5b926832bbce)</sup>
  - Added settings button on groups, subscriptions and saved tabs (fixed #70) <sup>[[view modified code]](https://github.com/teskann/quax/commit/facf9340f55f1e35d1ea6902906d63fe8b7b8479)</sup>
  - Fixed issues when loading some tweets <sup>[[view modified code]](https://github.com/teskann/quax/commit/79f375b8254290e81ad24e1e6344db9f48df605d)</sup>
  - Upgraded Flutter to 3.38.5 <sup>[[view modified code]](https://github.com/teskann/quax/commit/b4cf6711397c96b1fdd3b49bd06f8ac6d80c7383)</sup>

## QuaX 4.1.0

What's new in QuaX 4.1.0:
  - Updated Japanese translation (#76) (by @ScratchBuild) <sup>[[view modified code]](https://github.com/teskann/quax/commit/43c769d16fdad197f1a29fbedb92a5a68362be91)</sup>
  - Fixed #74 - Display absolute timestamp of tweets in local timezone (#77) (by @lebakassemmerl) <sup>[[view modified code]](https://github.com/teskann/quax/commit/22e0d70824fa6bed0c2cbe1cbf7e573345270dee)</sup>
  - Usernames are now available in the "Accounts" page in settings, instead of account ID. You need to log in again to see your username. <sup>[[view modified code]](https://github.com/teskann/quax/commit/74f16a2ae9c2110d78243dfe4eee88ec56a1d987)</sup>
  - Better management of "Show more" for long posts (fixed #39) <sup>[[view modified code]](https://github.com/teskann/quax/commit/de28bb9d9fb53414a8ba3e51c93ddd44f6454c45)</sup>
  - Subscriptions are now reorderable (ported from Squawker) - Fixed #63 <sup>[[view modified code]](https://github.com/teskann/quax/commit/d21c217e162cae828b67a81e4bc2fd283e25ad9b)</sup>
  - Added a badge to install QuaX with Obtainium <sup>[[view modified code]](https://github.com/teskann/quax/commit/1a824a8c048f96ef7ea0b53520ad31f7ffae3a4e)</sup>

## QuaX 4.0.20

What's new in QuaX 4.0.20:
  - Fixed opening a link in QuaX if QuaX is not running (#75) (by @micahmo) <sup>[[view modified code]](https://github.com/teskann/quax/commit/b4f91186fa070cafc60eaef3a26ffcb506061631)</sup>

## QuaX 4.0.19

What's new in QuaX 4.0.19:
  - Fix link handling (by @micahmo) <sup>[[view modified code]](https://github.com/teskann/quax/commit/e0194147b22cf9130f4e2e2fe245b34da14de8e2)</sup>
  - Added an option to display the absolute timestamp of all tweets (#73) (by @lebakassemmerl) <sup>[[view modified code]](https://github.com/teskann/quax/commit/f19666bade881c468607c7aaa736924107f5ec3f)</sup>
  - Automatic generation of release notes for new releases <sup>[[view modified code]](https://github.com/teskann/quax/commit/eadca45df9f5adff1690b867046a73ef6b478ebb)</sup>