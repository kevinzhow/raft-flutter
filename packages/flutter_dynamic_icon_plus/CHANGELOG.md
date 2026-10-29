## 1.4.1 - June 2, 2026
* [26](https://github.com/chandrabezzo/flutter_dynamic_icon_plus/pull/26) Remove SwiftTryCatch
  
## 1.4.0 - October 6, 2025
* [21](https://github.com/chandrabezzo/flutter_dynamic_icon_plus/pull/21) Updated all related stuff for AGP 8.13.

## 1.3.1 - February 20, 2025
* [16](https://github.com/chandrabezzo/flutter_dynamic_icon_plus/pull/16) Smart Case Issue on Android.

## 1.3.0 - January 31, 2025
* [10](https://github.com/chandrabezzo/flutter_dynamic_icon_plus/pull/10) Add Silent App Icon Change on iOS.
* [13](https://github.com/chandrabezzo/flutter_dynamic_icon_plus/pull/13) Support higher kotlin version.

## 1.2.1 - April 3, 2024
* Fix crash issue when fill icon name with empty string or null

## 1.2.0 - April 2, 2024
* Fix [Issue 1](https://github.com/chandrabezzo/flutter_dynamic_icon_plus/issues/1), after check more detail found [problem](https://stackoverflow.com/questions/40660216/ontaskremoved-not-getting-called-in-huawei-and-xiaomi-devices) for specific device/brand. So, need to add parameters `blacklistBrands`, `blacklistManufactures`, and `blacklistModels` on `setAlternateIconName` to add blacklist brand that can't works with Service.
* For blacklist brands, manufactures, and models will use approach force restart app to change the app icon with alternative icon on Android

## 1.1.2 - February 21, 2024
* Update Readme

## 1.1.1 - February 21, 2024
* To decrease bad experience user in Android, just change app icon on app closed via [Service](https://developer.android.com/develop/background-work/services)


## 1.1.0 - February 21, 2024
* To decrease bad experience user in Android, just change app icon on app closed via [Service](https://developer.android.com/develop/background-work/services)

## 1.0.0 - February 19, 2024
* Dynamic App Icon on Android and iOS
