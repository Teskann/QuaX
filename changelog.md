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