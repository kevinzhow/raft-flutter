# Custom mobile app icons

Android and iOS expose **App settings → Appearance → App icon**. Five packaged presets keep the original Raft mark: yellow (default), blue, green, white and pink. The setting belongs to this device and is independent of the page theme and server/account. Returning to Appearance, including after resuming the app, reads the operating system's current choice.

The approved design uses the existing settings section and card, with a current-icon preview and five compact choices. `raft_ui` owns rendering, tokens, pointer/keyboard interaction and selection semantics; `NativeAppIcon` owns platform calls, OS readback, busy/error states and retry. The section is shown only on Android/iOS. SDK previews include all three themes and an error state; previews do not establish native launcher or screen-reader acceptance.

## Source and assets

| Preset | Background | iOS asset | Android alias |
| --- | --- | --- | --- |
| Yellow | `#FFD440` | `AppIcon` (primary) | `app.raft.raft_flutter.IconYellow` |
| Blue | `#27CCF3` | `AppIconBlue` | `app.raft.raft_flutter.IconBlue` |
| Green | `#A9D877` | `AppIconGreen` | `app.raft.raft_flutter.IconGreen` |
| White | `#FFFFFF` | `AppIconWhite` | `app.raft.raft_flutter.IconWhite` |
| Pink | `#FE7DA8` | `AppIconPink` | `app.raft.raft_flutter.IconPink` |

`python3 tool/gen-mobile-icons` reads the existing Android brand vector and product color tokens, then generates opaque iOS phone/iPad icons, Android legacy/adaptive/monochrome references, launch resources and the SDK icon mark. Rendering requires `rsvg-convert` (librsvg); the Python code has no third-party Python dependencies. Asset checks validate dimensions, opacity, palette agreement and the launch mark. Repeated generation produced identical hashes. System masking and Android themed icons can override the visible shape/colors; see [Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).

## Vendored library

At Kevin's request, the app uses the repository copy of [flutter_dynamic_icon_plus 1.4.1](https://pub.dev/packages/flutter_dynamic_icon_plus), rather than a separate app-specific icon setter. The package's public Dart interface and MethodChannel names remain intact. [UPSTREAM.json](../packages/flutter_dynamic_icon_plus/UPSTREAM.json) records the archive SHA-256, [upstream commit](https://github.com/chandrabezzo/flutter_dynamic_icon_plus/tree/852b1c5b84d31132ec2067c3421d7d0884e2bf28), original hashes and modified-file hashes. Its MIT license is preserved; [RAFT_PATCHES.md](../packages/flutter_dynamic_icon_plus/RAFT_PATCHES.md) and [third-party notices](../THIRD_PARTY_NOTICES.md) describe the local scope.

Android applies the alias change during the method call; the upstream task-removal service and pending preference are removed. There is no requirement to swipe the app out of recent tasks. Only the declared launcher aliases may be toggled, with actual-state readback and rollback. API 33+ uses the [atomic PackageManager operation](https://developer.android.com/reference/android/content/pm/PackageManager#setComponentEnabledSettings(java.util.List)); older versions enable the target before disabling other aliases. `DONT_KILL_APP` is used, but OEM launcher refresh timing and task behavior still require device testing. The fixed class namespace works with a suffixed test application ID.

On iOS the package uses the [public alternate-icon API](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:)) and keeps its system confirmation. The upstream private silent selector is removed; a silent request returns an explicit unsupported error. The app always requests the public flow. OS state is authoritative; a failed or mismatched readback does not display an optimistic saved choice.

## Native startup and permanent entry points

Each Android alias targets a small native routing Activity with its own matching launch theme. It transfers the launch intent and splash to the single permanent `MainActivity`, then finishes; it has no Flutter engine, extra application page or artificial timer. This follows the [Android splash routing recipe](https://developer.android.com/develop/ui/views/launch/splash-screen/migrate). MainActivity remains enabled and retains shares, OAuth, server and invitation deep links.

MainActivity additionally handles MAIN/CATEGORY_INFO. Android's [getLaunchIntentForPackage](https://developer.android.com/reference/android/content/pm/PackageManager#getLaunchIntentForPackage(java.lang.String)) prefers that category before LAUNCHER. Because the notification plugin uses this API, this configuration is intended to keep new notification PendingIntents bound to MainActivity while an icon alias changes. Source and compiled Manifest checks verify the configuration; real notification clicks after switching are still pending.

## Launch screen: theme canvas + chosen icon

The launch screen is the **page body colour of the stored theme** with the **chosen app icon** as a centred tile. It is no longer a full-screen icon colour, so there is no colour jump into the first Flutter frame (the old jump was the icon-colour splash cross-fading into the theme, see [theme-flash.md](theme-flash.md)). The colour is `layer-canvas-muted` of [docs/theme-tokens](theme-tokens) (what the mobile home paints, not the scaffold `layer-canvas`): Brutal light `#FFFFFF`, Elegant light `#F8F8F7`, Elegant dark `#0D0D0B`; `system` mode follows the device day/night setting (light family canvas by day, Elegant dark at night). `tool/tests/test_launch_theme.py` keeps Android resources, iOS colour sets and tokens in agreement.

| Platform | Canvas | Icon | Limits |
| --- | --- | --- | --- |
| Android 13+ (API 33) | The app persists one splash theme with `SplashScreen.setSplashScreenTheme` (`LaunchTheme.kt`): `RaftSplash_<theme>_<icon>` from `res/values-v33/raft_splash_themes.xml`. The system applies it to every later launch (launcher, share, notification, link) before the process draws, so it knows the stored appearance (light/dark/system, Brutal/Elegant). | The enabled alias's adaptive icon, drawn and masked by the system. | The theme is updated when Dart reports a change (`app.raft/launch-theme`, called from `setAppearance`, at every start and after an icon change) and re-applied in `MainActivity.onCreate`. The first launch after installing or updating uses the system-day/night default. |
| Android 12 / 12L (API 31-32) | The entry theme's `windowSplashScreenBackground`: device day/night only. | The alias icon (explicit `windowSplashScreenAnimatedIcon`). | No runtime theme API: if the app is forced light or dark against the device setting, the splash shows the device's side. |
| Android 11 and older | Entry Activity `windowBackground` layer list (`launch_<icon>.xml`): canvas + 112 dp rounded tile in the icon colour with the mark. | The tile. | Static theme: device day/night only. A cold start through MainActivity (shares/notifications) shows the canvas without a tile. |
| iOS | `LaunchScreen.storyboard`: the adaptive `LaunchBackground` colour (white / `#0D0D0B`) with nothing on it, because iOS cannot change the system LaunchScreen per user choice. | `SceneDelegate` installs `FlutterViewController.splashScreenView` as soon as the scene connects: the stored theme's canvas (`flutter.raft.mode`/`flutter.raft.light` from `UserDefaults`, `LaunchBackgroundElegant` for Elegant) and a 112 pt rounded tile in the selected icon colour with the mark; Flutter removes it at the first rendered frame. | The system LaunchScreen follows the system appearance only: with a forced light/dark choice against the system, or Elegant light (`#F8F8F7`) against the white system light screen, the canvas changes once when the native view takes over. The tile appears at that hand-off, not on the system screen. |

On Android 12+ a notification or share entry that starts MainActivity directly now also shows the stored canvas and the chosen icon (13+) because the persisted theme applies to the whole package; 12/12L show the day/night canvas and the application icon.

The iOS system LaunchScreen is fixed, as approved. The native view using the stored theme then covers Flutter initialization; the public `FlutterViewController.splashScreenView` removes it at the first rendered frame. There is no timer, replacement display callback or extra UIWindow. This is an initialization handoff, not a claim that the [system LaunchScreen](https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen) changes with a user preference.

`python3 tool/gen-mobile-icons` writes the launch resources (`--no-raster` rewrites only the text resources and does not need `rsvg-convert`).

## Verification and remaining acceptance

On 2026-10-12 the implementation incorporated `cindy/batch-25` at `606c6d29`, retaining its `raft://v1/join/` entry and translations. Engineering checks and build receipts are archived with the task handoff:

- 103 focused Flutter tests pass and cover native store state/errors/concurrent refresh, Android/iOS Appearance navigation, all three themes, keyboard/selection/busy semantics, the vendored channel envelope, existing settings paint/header contracts, notifications, shares and invitation/public-server routing.
- Six Android native tests pass under Robolectric API 24/33: switch/default restoration, partial-error rollback and rejection of non-alias targets. These are native code tests with a mocked PackageManager, not real launcher tests.
- Three cross-platform asset and permanent-entry protocol tests, static analysis and design-system audit pass.
- Android ARM64 debug APK and iOS Simulator debug app compile. The compiled Android Manifest contains the fixed notification owner and five aliases; the iOS Info.plist packages four alternates for phone and iPad. Builds were not installed or launched.

The existing `settings_page_test.dart` case “inline profile keeps an edit made during save acknowledgement” did not complete within an independent 30-second watchdog on either unchanged baseline `385b226` or this branch. Both receipts and original logs are preserved. This case is excluded from the 103 passing focused checks and has been handed to the batch reviewer; no assertion was weakened to mask it.

The vendored iOS plugin uses CocoaPods, like the existing `media_kit_video` fallback; it has no Swift Package Manager support. Android's existing legacy Kotlin plugin warnings remain. Device signing/release distribution, iOS media playback, OEM launcher refresh, actual relaunch persistence, cold/warm notification/share/deep-link entry, VoiceOver/TalkBack and native launch-frame transitions are **not accepted** by these compilation/widget checks. Run those on authorized isolated builds before platform acceptance; do not treat a settings preview as a substitute.
