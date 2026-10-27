## 1.3.5

fix(android): remove trailing space in Honor CHANGE_BADGE permission name. (Merge pull request #48 from shihoyoko:fix/honor-permission-trailing-space)

## 1.3.4

* Fix: Notification will be triggered multiple times when updateBadge.

## 1.3.3

* Fix: POCO / HyperOS (`com.mi.android.globallauncher`) numeric badge count (no `extraNotification` API). (Merge pull request #46 from khlebobul/poco_and_hyperos_fix)

## 1.3.2

* fix(ios): place PrivacyInfo.xcprivacy inside SPM target source directory (Merge pull request #42 from qkdflrgs)

## 1.3.1

* Fix: Android build with AGP 9 when `android.builtInKotlin=false` by applying `kotlin-android` whenever built-in Kotlin is disabled.

## 1.3.0

* Breaking change bumped minimum Flutter SDK requirement to 3.32.0 and Dart SDK requirement to 3.8.0
* Migrates to built-in Kotlin for AGP 9.0+ compatibility.
* Fix: macOS build warning by narrowing podspec source_files to exclude PrivacyInfo.xcprivacy.

# 1.2.10

* Fix: Add support for POCO Global Launcher badge detection (Merge pull request #38 from khlebobul/poco_detection)

## 1.2.9

* Fix: missing null check error with Kotlin 2.2.20

## 1.2.8

* Fix: improve Android launcher detection for Nexus launcher

## 1.2.7

* feat: add support for HiHonor Launcher

## 1.2.6

* Fix: vivo funtouch os no showing badge num

## 1.2.5

* Upgrade android gradle

## 1.2.4

* Fix: Move PrivacyInfo resource file (Merge pull request #26 from AlexVegner/xcode_26_fix)

## 1.2.3

* feat: Add support to Swift Package Manager

## 1.2.2

* Fix: Badge counter stops updating with minifyEnabled true on Android (Merge pull request #22 from waleedf112/main)
* feat: add support for Asus Launcher

## 1.2.1

* Fix: permission request failed.
* Fix: Fails the android test #18

## 1.2.0

* Updates minimum supported SDK version to Flutter 3.10.0/Dart 3.0.
* Add badges support for macos

## 1.1.6

* update README.md

## 1.1.5

* update README.md (Merge pull request #9 from amlzq/main Add permission to AndroidManifest)

## 1.1.4

* update README.md

## 1.1.3

* update README.md (Merge pull request #7 from emilypriddy/patch-1)

## 1.1.2

* Remove `enableNotification` method in iOS
* update README.md

## 1.1.1

* Fix `When generating Privacy Manifest Report getting the following error [ iOS ]`

## 1.1.0

* add 'isSupport' method to check if the launcher supports the feature

## 1.0.1

* Fix Sdk constrain - support '>=3.0.0 <4.0.0' now (Merge pull request #1 from venbrinoDev/main)

## 1.0.0

* adding badges to app icon
