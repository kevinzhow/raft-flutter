# Raft local changes

This is the published `flutter_dynamic_icon_plus` 1.4.1 source, vendored at Kevin's request. `UPSTREAM.json` preserves the source archive SHA-256, upstream commit, and original file hashes; `LICENSE` is unchanged. The upstream API and MethodChannel names remain compatible.

Android changes are concentrated in `ComponentUtil.kt` and `FlutterDynamicIconPlusPlugin.kt`:

- Apply the requested icon during the method call, then read the actual PackageManager state. Remove the task-removal service and its pending SharedPreferences state. The legacy blacklist arguments remain accepted, but do not force a restart.
- Discover only MAIN/LAUNCHER activity aliases. Optional application metadata `flutter_dynamic_icon_plus.allowed_aliases` fences this set; `flutter_dynamic_icon_plus.default_alias` defines a null reset. Raft supplies both. Never toggle the target activities, so MainActivity stays enabled for shares, OAuth, invitations and notification callbacks.
- API 33+ changes the alias set in one `setComponentEnabledSettings` call. Older versions enable the target first. All changes use `DONT_KILL_APP`, with readback and rollback on failure. This flag does not guarantee that every OEM launcher keeps the foreground task alive or refreshes instantly.
- Alias class names may use a fixed namespace while the application ID has a test suffix. Different alias targets can carry different splash themes; the plugin does not instantiate them.

The iOS icon setter retains the public UIKit call and dispatches completion onto the main queue. The private silent-selector implementation is removed; `isSilent: true` returns an explicit unsupported error. Raft always passes false. Existing unrelated badge methods are retained; Raft's icon setting does not call them.

The package participates in the Dart workspace and is nonpublishable. Android test dependencies use JUnit 4, Robolectric 4.16.1 and Mockito 5.20.0 for JDK 21 compatibility. Regressions exercise API 24/33, default restoration, partial failure rollback, and rejection of Activity or undeclared alias names. Dart tests cover the public MethodChannel envelope and forwarded native errors.

```sh
# From apps/raft_flutter/android, using an installed Android SDK and JDK 21:
./gradlew :flutter_dynamic_icon_plus:testDebugUnitTest
```

The plugin owns icon switching. Raft's packaged assets, appearance section and native splash handoff remain application code; the plugin does not add splash delays or manage account preferences.
