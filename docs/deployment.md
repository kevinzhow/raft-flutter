# Self-deploy

This repository builds the **client**. You need a Raft server for it to talk to; run your own from [raft-source](https://github.com/botiverse/raft-source) (`pnpm install && ./raftdev start`, which needs Node 24, pnpm and Docker; see that repository). The client does not need a server-side change.

## Point the client at your server

- Login screen: the server origin is editable (scheme `http` or `https` and host only, no path, such as `https://raft.example.com`). Prefer HTTPS.
- Compile-time default: `--dart-define=RAFT_ORIGIN=<origin>` (default `https://api.raft.build`, the official API). Related defines: `RAFT_FRONTEND_ORIGIN` (the Web frontend origin used for browser hand-off and content links; only honoured for the API named by `RAFT_ORIGIN`. Without it, the official API `https://api.raft.build` links to `https://app.raft.build` (`ContentLinks.officialWebOrigins`) and any other server links to its own origin), `RAFT_DEPLOYMENT_ENV` (`production` default; `staging` and `slockdev` switch the Raft Computer install commands), `RAFT_APP_VERSION` (label shown in settings). `tool/release.py` passes `RAFT_ORIGIN`, `RAFT_FRONTEND_ORIGIN`, `RAFT_DEPLOYMENT_ENV=production`, `RAFT_COMMIT_SHA` and the version/build number to every release build, and refuses to build when one is missing or not the official value; the optional repository variable `RAFT_FEEDBACK_EXPORT_URL` enables Report Issue. Do not pass credentials or test fixtures as defines.
- Android blocks cleartext HTTP except for three development hosts (`network_security_config.xml`); a public deployment must use HTTPS. Android backup is disabled and local state is excluded from cloud and device-transfer backups.
- The `raft:` URL scheme (OAuth callback and content links) is registered on Android, macOS, iOS and in the Linux desktop entry.

## Raft https links open the app (not enabled)

Today a tapped `https://app.raft.build/...` link opens the browser: only the `raft:` scheme is registered. The app-side handling for https links is in the code but **off** (`lib/platform/raft_app_links.dart`, compile-time `--dart-define=RAFT_APP_LINKS=true`, default false), and no intent filter or entitlement is enabled, because it cannot work without files served by the Raft domain, which this repository does not own. What the domain has to host (served over HTTPS as `application/json`, with **no redirects**, at the exact paths):

- **Android App Links**: `https://app.raft.build/.well-known/assetlinks.json` with one statement `{"relation": ["delegate_permission/common.handle_all_urls"], "target": {"namespace": "android_app", "package_name": "app.raft.raft_flutter", "sha256_cert_fingerprints": [<SHA-256 of the release signing certificate, uppercase hex with colons>]}}`. The debug key must not be listed. The release certificate is the CI keystore ([Release CI](release-ci.md)); `tool/android-install --check-only` prints an APK's certificate digest.
- **iOS Universal Links and macOS associated domains**: `https://app.raft.build/.well-known/apple-app-site-association` (no file extension) with `{"applinks": {"details": [{"appIDs": ["<TEAM_ID>.app.raft.raftFlutter"], "components": [{"/": "/s/*/channel/*"}, {"/": "/s/*/dm/*"}, {"/": "/join/*"}]}]}}`. The apps then need the `com.apple.developer.associated-domains` entitlement `applinks:app.raft.build` (`ios/Runner/Runner.entitlements`, the macOS entitlements) and a signing team; neither exists yet.
- The legacy production host `app.slock.ai` needs the same two files if it should open the app too; staging never claims links.

Then, in one change: uncomment the `autoVerify` filter in `AndroidManifest.xml`, add the entitlements, and build with `RAFT_APP_LINKS=true`. The app takes `/s/<slug>/channel|dm/<id>` (with `?msg=` and `?thread=`) and `/join/<token>` of those hosts; a message link goes through the same authorization as a notification tap, an invite opens the invite page, and a link that arrives before the account is restored waits for it. A link into another workspace of the same account reports "unavailable" (the app does not switch workspace for a link), and any other path stays in the browser. Status: waiting on the platform owner for the domain files (owner decision 6 is still open).

## Build release artifacts

Run from `apps/raft_flutter` with `../../tool/flutter` and the pinned SDK. Release builds use `--target=lib/main.dart` (the default) and must not include the test defines used by the native test scripts.

```sh
../../tool/flutter build apk --release --dart-define=RAFT_ORIGIN=https://raft.example.com           # Android universal APK
../../tool/flutter build apk --release --split-per-abi --target-platform android-arm64 --build-number <n>  # ARM64 split APK
../../tool/prepare-media-linux && ../../tool/flutter build linux --release                          # Linux (x86_64 bundle)
../../tool/flutter build macos --release                                                            # macOS app Raft.app (arm64)
```

## Signing and packaging

GitHub-hosted automatic builds and version-tag releases are described in
[Release CI](release-ci.md). Windows x64 is enabled first; Android, Linux and macOS
builders can be tested manually and enabled through a shared platform configuration.

- **Android**: local acceptance builds still use the **debug key**. CI uses the environment-based release signing configuration and requires a persistent keystore through GitHub secrets (see [Release CI](release-ci.md)); those secrets stay outside the repository. The application id is `app.raft.raft_flutter`. Updating an installed app needs the same signing key and a higher version code; use `tool/android-install --device <serial> --apk <arm64.apk> --check-only` and then `--launch`, which checks identity, architecture, version and signature and never uninstalls or clears data. CI does not perform store submission.
- **Linux**: `tool/build-deliverables` is the local acceptance packager. It requires a passing `tool/check-project` and native runs for the same source hash, then builds the Linux bundle and APK, rewrites ELF RPATHs to be relocatable with a pinned local `patchelf`, checks dependencies, and writes `build/deliverables/raft-flutter-linux-x64.tar.gz`, `raft-flutter-android.apk`, `CHECKSUMS.txt` and `build-manifest.json`. The bundle needs a compatible glibc, GTK and graphics drivers, and `poppler-utils` for PDF preview. An example desktop entry for the `raft:` scheme is in `linux/packaging/`. Media libraries include GPL components; read [Linux media runtime](linux-media-runtime.md) before redistributing.
- **macOS**: sandboxed (entitlements in `macos/Runner/`), local development signing only. Developer ID signing, notarization and DMG/store packaging are not set up ([macOS evidence](macos-evidence.md)).
- **iOS**: no signing team, provisioning, push or release setup; configure signing in Xcode on a Mac. Compilation has never been verified.
- **Windows**: x64 Release builds produce the complete `apps/raft_flutter/build/windows/x64/runner/Release` directory, a portable ZIP and a per-user setup executable. Keep its DLLs, `data/`, `raft.ico` and `notification_icon.png` together. The bundle includes the MSVC runtime; notifications use the Windows system Toast API without Windows App Runtime. Run the app once from its final folder to register its current-user identity and protocol. No Authenticode signature or store package is configured. See [Windows development setup](development.md#windows) and [notification behavior](windows-notifications.md).

Verification of the delivered Android and Linux artifacts (hashes, install and relocation smoke tests, what they do not prove): [release evidence](release-evidence.md).
