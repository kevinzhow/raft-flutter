# In-app auto-update (macOS, Windows and Linux AppImage)

macOS installs updates with **Sparkle 2**, Windows with **WinSparkle 0.9**; a
Linux **AppImage** updates itself with a delta download in pure Dart (zsync
format, see [Linux AppImage](#linux-appimage-zsync-delta-update)). Android and
iOS have no in-app updater (see the end). Dart reaches Sparkle and WinSparkle
through one small local plugin, `packages/raft_updater` (`app.raft/updater`
method channel), and one facade:

```dart
import 'package:raft_updater/raft_updater.dart';

AppUpdater.instance.available;          // bool: can update in place here
AppUpdater.instance.availability;       // ValueListenable<bool>
await AppUpdater.instance.checkAndInstall();
// -> AppUpdateOutcome.started          native Sparkle/WinSparkle UI took over
//    AppUpdateOutcome.openedReleasePage in-place update unavailable; browser opened
//    AppUpdateOutcome.failed           neither worked
```

This is separate from the lightweight update check (`build-manifest-<platform>-<arch>.json`
`buildNumber` comparison, which drives the red dot). The dot decides *when* to
show an update; on macOS/Windows, when `available` is true, the About card's button
reads "Update now" and calls `checkAndInstall()` (a `failed` outcome falls back to
opening the release page; `openedReleasePage` already opened it). On Linux the card
drives `AppUpdater.appImage` itself (progress, restart, failure reasons; below).
Elsewhere, or when `available` is false, it reads "View release" and opens the release page. The updater does no
scheduled or startup checks and never prompts by itself.
About's "Check for updates" button runs only the lightweight manifest check (forced, ignoring the 6 h
throttle); it never calls `checkForUpdates`, because Sparkle/WinSparkle's own dialog would answer the same
question a second time next to the card. Only "Update now" (shown when the manifest has a newer build) starts
the native flow.

## Decision: why a local plugin and not `auto_updater`

The `auto_updater` plugin (leanflutter 1.0.0, Oct 2024) was evaluated and not used:

- Its Windows half bundles **WinSparkle 0.8.1, which has no EdDSA**. The Sparkle
  signing key is ed25519, so updates could not be verified. 0.9.0 added it.
- Its macOS half is CocoaPods-only (unpinned `Sparkle` pod, a hand-edited
  `Podfile.lock` would be needed) while this app builds plugins with Swift
  Package Manager, starts the updater unconditionally at launch, and has no way
  to say "this build has no key".
- Neither half can report "unavailable", reads the key from the right place, or
  closes the app for the installer cleanly.

`packages/raft_updater` is ~150 lines of native code per platform on the same
frameworks: Swift + Sparkle 2.10.0 (Swift package, pinned exact, podspec
fallback) and C++ + WinSparkle 0.9.4 (downloaded by CMake, pinned by SHA-256).

## Feeds

| Platform | Feed (baked into the app) | Archive Sparkle fetches |
| --- | --- | --- |
| macOS ARM64 | `https://github.com/kevinzhow/raft-flutter/releases/latest/download/appcast-macos.xml` | the existing `raft-flutter-<tag>-macos-arm64.zip` |
| Windows x64 | `https://github.com/kevinzhow/raft-flutter/releases/latest/download/appcast-windows.xml` | `raft-flutter-<tag>-windows-x64-setup.exe` (new) |

`sparkle:version` is the **build number** (`GITHUB_RUN_NUMBER`, equals
`CFBundleVersion` on macOS and the `RAFT_BUILD_NUMBER` define on Windows),
`sparkle:shortVersionString` the app version. Enclosure URL is the tagged release
asset; `length` and `sparkle:edSignature` come from the exact published bytes.
Windows enclosures also carry `sparkle:os="windows-x64"` and
`sparkle:installerArguments="/SILENT /SP- /NOICONS /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS"`.
`tool/appcast.py` renders them; appcast bytes are deterministic (the date is the
commit date), so publisher retries stay idempotent.

`releases/latest` ignores prereleases and drafts. Each platform publishes
independently, so for a short time (or permanently, if a platform job fails) the
latest release may lack its `appcast-<platform>.xml`; clients then get a 404, see
"no update" and retry the next time the user presses the button. Nothing is
overwritten to repair that: fix and rerun the failed publisher, or cut a new tag.

## Keys and CI (names are fixed)

| Name | Kind | Used by |
| --- | --- | --- |
| `SPARKLE_ED_PUBLIC_KEY` | Actions **variable** (public) | build jobs: macOS Info.plist `SUPublicEDKey`; Windows and the Linux AppImage `--dart-define=RAFT_SPARKLE_ED_PUBLIC_KEY` -> `win_sparkle_set_eddsa_public_key` / the AppImage updater's signature check |
| `SPARKLE_ED_PRIVATE_KEY` | Actions **secret** | the tag-only publish job only, to sign the appcast enclosure (macOS, Windows) and the AppImage (`edSignature` in its build manifest) |

Flow (`tool/release.py`):

1. **Build** (read-only token, no secret). `appcast.read_public_key` validates the
   variable (base64, a real 32-byte Ed25519 point) and stops the build on garbage.
   Non-empty -> `--dart-define=RAFT_AUTO_UPDATE=true`, plus the key define on
   Windows and the AppImage; macOS packaging writes `SUPublicEDKey` into Info.plist before signing.
   **Empty -> auto-update off**: no key in the bundle, `AppUpdater.available` is
   false, buttons open the release page. The receipt records `autoUpdate`.
2. **Publish** (tag push only). Reads `SPARKLE_ED_PRIVATE_KEY` from the environment
   (never argv, never logged; GitHub also masks it), derives its public key and
   refuses to publish if it differs from the key built into the app, signs the
   archive with a stdlib-only Ed25519 (RFC 8032 vectors and the `cryptography`
   library cross-check it in tests) and uploads `appcast-<platform>.xml` with the
   other assets. The AppImage has no appcast: the same signer signs the AppImage
   bytes and the publisher writes the base64 signature into the
   `edSignature` field of `build-manifest-appimage-x64.json` (see
   "Signature" under Linux AppImage). A build that embeds a key but finds no secret fails loudly
   instead of shipping an app whose feed 404s.
3. The Windows build also produces the Inno Setup installer
   (`packaging/windows/raft.iss`, `tool/windows_installer.py`) as an extra
   artifact listed in the receipt, checksum file and manifest.

Pull requests and manual runs build with the variable but never publish and never
receive the secret.

### Generating or rotating the key (Kevin; commands only)

Done once already. On a Mac, with Sparkle's tools from
`https://github.com/sparkle-project/Sparkle/releases` (`Sparkle-2.10.0.tar.xz`, `bin/`):

```sh
./bin/generate_keys                         # new key in the login keychain; prints the public key
./bin/generate_keys -p                      # print the public key again
./bin/generate_keys -x sparkle_private.txt  # export the private key (base64 of the 32-byte seed)
gh secret set SPARKLE_ED_PRIVATE_KEY < sparkle_private.txt
gh variable set SPARKLE_ED_PUBLIC_KEY --body '<public key from generate_keys>'
rm -P sparkle_private.txt                   # keep only the keychain copy / your password manager
```

The same pair serves macOS and Windows (identical format). Only the 32-byte seed
export is supported; a legacy 96-byte key is rejected with a clear message.
**Rotation is not seamless**: an installed app only accepts updates signed by the
public key it shipped with (Sparkle checks the *old* key and, with no Apple
Developer ID, there is no second path). After changing the pair, existing installs
cannot update themselves and must reinstall once. If staged rotation is ever
needed, ship one release signed with the old key that already embeds the new
public key (needs a temporary publish override; not implemented).

Never commit a key. Local rehearsals use a throwaway pair:
`python3 tool/appcast.py keygen --out "$(mktemp -d)"`.

## macOS (Sparkle 2) in depth

Sandbox. The app is sandboxed, so Sparkle must install through its
`Installer.xpc` launcher service (`SUEnableInstallerLauncherService = YES` in
`Info.plist`) and the app needs the two mach-lookup names from
[Sparkle's sandboxing guide](https://sparkle-project.org/documentation/sandboxing/):
`app.raft.raftFlutter-spks` and `app.raft.raftFlutter-spki` under
`com.apple.security.temporary-exception.mach-lookup.global-name` in
`Release.entitlements` and `DebugProfile.entitlements`. They are literal strings,
not `$(PRODUCT_BUNDLE_IDENTIFIER)`: `codesign --entitlements` does not expand
build variables. `SUEnableDownloaderService` stays off because the app already
has `com.apple.security.network.client`. A temporary exception rules out the Mac
App Store, which is not a target.

Ad-hoc signing (no Developer ID, not notarized). From Sparkle's source
(`SUUpdateValidator`):

- The update is accepted when the archive's **EdDSA signature validates against the
  public key of the running (old) app**. Apple code-signing continuity is only an
  alternative path and cannot apply to ad-hoc signatures (designated requirement
  is a `cdhash`, different every build). Hence `SUPublicEDKey` is mandatory.
- If the update bundle is code signed (ad-hoc counts), its signature must be valid;
  removing a signature is rejected. Our packaging re-seals the whole app ad-hoc.
- Library validation is off: we never sign with `-o runtime`, so ad-hoc Sparkle
  loads into an ad-hoc app. **Do not add Hardened Runtime** without a real
  identity (Sparkle documents that ad-hoc + library validation cannot load it).
- Gatekeeper/quarantine: Sparkle downloads with its own session and its file
  manager strips `com.apple.quarantine` from the extracted update
  (`SUFileManager`), so the replaced app should not trigger "Open Anyway" again.
  Only the first manual install from the browser is quarantined.
- The replaced app must be where the user can write. `/Applications` is normal,
  but any writable folder works: CodexMac updated a copy extracted in
  `~/Downloads` in place (2026-10-13, build 500001 → 500002). Updating fails only
  when the app is on a read-only volume, in a folder the user cannot write
  (Sparkle then asks for an administrator password), or running under App
  Translocation (a quarantined app launched from where it was extracted, which
  macOS runs from a read-only random path). Moving it to `/Applications` avoids
  all three, which is why `READ-ME-FIRST.txt` still recommends it.
- **Largest risk: Keychain.** Each update has a new ad-hoc `cdhash`, so macOS may
  re-prompt for keychain access to the legacy-keychain session item created by the
  previous build (see [macos-evidence.md](macos-evidence.md); Data Protection
  Keychain needs a real team identity, unavailable here). If the user denies, the
  stored session is unreadable and they log in again. A stable signing identity
  (Developer ID, or at least a stable self-signed certificate) removes this and
  also gives Sparkle a second trust path. Treat auto-update as functional for
  ad-hoc but **not seamless** until that is decided.

Archive. Sparkle accepts `.zip`. Our ZIP is `ditto -c -k --keepParent` of a staged
folder holding `Raft.app` plus docs and `READ-ME-FIRST.txt`. Sparkle's installer
enumerates the extracted folder recursively and picks the app matching the running
app's bundle name (`Autoupdate/SUInstaller.m`, "Search subdirectories for the
application"), so this layout should work; confirm it on a Mac. If it does not,
publish a ZIP that contains only `Raft.app` for Sparkle.

Packaging (`tool/macos_release.py`). Sparkle.framework carries nested bundles the
old inventory rejected. They are now allowed only inside
`Contents/Frameworks/Sparkle.framework` (`Installer.xpc`, `Downloader.xpc`,
`Updater.app`), signed ad-hoc deepest-first as bundles (XPC services with
`--preserve-metadata=entitlements`), then the framework, then the app with
`Release.entitlements`. `verify` additionally checks: `SUPublicEDKey` equals the
release key (or is absent when the build has none), the launcher-service flag,
`Installer.xpc` present, nested bundle signatures.

### What CodexMac must verify on a real Mac

Unit tests here mock `codesign`/`ditto`; none of this has run on macOS.

1. `tool/flutter build macos --release` resolves Sparkle 2.10.0 through SwiftPM
   and `Raft.app/Contents/Frameworks/Sparkle.framework` exists (with
   `Versions/B/XPCServices/Installer.xpc`). If Xcode does not embed the xcframework
   transitively through `FlutterGeneratedPluginSwiftPackage`, add Sparkle to the
   Runner target's embedded frameworks (or disable SPM for this plugin so the
   podspec path runs, then commit `Podfile.lock` from `pod install` with CocoaPods 1.16.2).
2. `python3 tool/release.py build macos` with `SPARKLE_ED_PUBLIC_KEY=<throwaway
   public key>` passes its own verification; `codesign --verify --deep --strict`
   passes; `codesign -d --entitlements :- Raft.app` shows the `-spks`/`-spki` names;
   `plutil -p Raft.app/Contents/Info.plist` shows `SUPublicEDKey`,
   `SUEnableInstallerLauncherService`. Without the variable: no `SUPublicEDKey`.
3. Keyless build: app launches, `AppUpdater.instance.available == false`, button
   opens the release page, no Sparkle dialog, no console errors about Sparkle.
4. Rehearsal with a throwaway key: install build N (`/Applications`), build N+1
   (higher build number) with the same key, write `appcast.xml` with
   `python3 tool/appcast.py sign ... --url <https URL of the N+1 zip>`, point the old
   build at it (`--dart-define=RAFT_UPDATE_FEED_URL=...`; use HTTPS, or loopback
   `http://127.0.0.1` with a temporary `NSAllowsLocalNetworking`), press the
   button: Sparkle offers N+1, downloads, verifies, quits, replaces, relaunches
   as N+1. Check Console for `Sparkle` / `Installer` / `spks` errors; a sandbox
   denial for `mach-lookup` means the entitlement names are wrong.
5. Negative: tamper one byte of the archive, or sign with a different key: Sparkle
   must refuse ("improperly signed"). Appcast with a lower `sparkle:version`: "up to date".
6. After the update: Gatekeeper does not prompt again; `spctl -a -vv` result is
   unchanged from a fresh install; `xattr -l Raft.app` has no `com.apple.quarantine`.
7. Keychain: log in on N, update to N+1, record whether macOS prompts for keychain
   access and whether denying it logs the user out (the risk above).
8. Writable `~/Downloads` copy updates in place (verified). A translocated or
   read-only copy: the failure must be understandable, and the release-page
   fallback must be reachable.
9. Confirm the zip layout is accepted (see Archive) and that the ZIP still opens
   normally for first-time users.

## Windows (WinSparkle) in depth

WinSparkle downloads an **installer** (`.exe` / `.msi`) and runs it; it never unpacks
a ZIP. The portable ZIP stays for people who want it, and the minimal mature
addition is an **Inno Setup** per-user installer (`packaging/windows/raft.iss`):

- `PrivilegesRequired=lowest`, installs to `%LOCALAPPDATA%\Programs\Raft`: silent
  updates need no UAC prompt and no administrator.
- Fixed `AppId`, so each installer upgrades the previous install in place.
- WinSparkle starts it silently; `CloseApplications=yes` plus WinSparkle's own
  shutdown callback (the plugin posts `WM_CLOSE` to the main window) let it replace
  files; the `[Run]` entry (no `skipifsilent`) relaunches Raft afterwards.
- Unsigned (no Authenticode certificate). Files WinSparkle downloads carry no
  Mark-of-the-Web, but a *manual* download of the setup exe can trigger
  SmartScreen. Authenticode is future work, as for the ZIP.
- Notifications use Windows' system Toast API; neither the installer nor the
  ZIP needs Windows App Runtime. Both register the same current-user identity.

Portable vs installed. In-app update requires the installed copy: Dart treats a
Windows build as installed when `unins000.exe` (Inno's uninstaller) sits next to
the exe. A ZIP-extracted copy reports `available == false` and opens the release
page, so it never silently installs a second copy elsewhere.

Native details (`packages/raft_updater/windows`). `configure` calls
`win_sparkle_set_eddsa_public_key` (rejects invalid keys -> unavailable),
`set_appcast_url`, an explicit registry path, `set_app_details`,
`set_app_build_version(<build number>)` (so `sparkle:version` compares with the CI
run number), disables scheduled checks (no first-run prompt), installs the
shutdown callbacks and calls `win_sparkle_init`. `checkForUpdates` is
`win_sparkle_check_update_with_ui`. WinSparkle.dll is bundled through the plugin's
`_bundled_libraries`.

### What CodexWin must verify on Windows

Nothing in `packages/raft_updater/windows`, the CMake fetch, Inno Setup, or the
installer flow has been compiled or run (this host is Linux).

1. `tool/flutter build windows --release` compiles; `WinSparkle.dll` sits beside
   `raft_flutter.exe` in the bundle and the ZIP; CMake fetched WinSparkle with the
   pinned hash (a zip with a stray `__MACOSX` folder: the `WinSparkle-*` glob in
   the plugin CMake handles it, confirm).
2. `python tool/windows_installer.py` through `tool/release.py build windows`: ISCC
   is found (`choco install innosetup --version=6.4.3` is untested; pin may need
   changing), the setup exe is produced and listed in the receipt.
3. Install the setup exe as a normal user (no UAC); `unins000.exe` is next to the
   exe; Start menu entry exists; uninstall works.
4. Build with `SPARKLE_ED_PUBLIC_KEY=<throwaway public key>`; installed copy:
   `AppUpdater.instance.available == true`; ZIP copy: false -> release page.
5. Rehearsal: install N, build N+1 with the same key and a higher build number,
   create `appcast.xml` with `python tool/appcast.py sign --platform windows --url ...`
   (HTTPS or `http://127.0.0.1`), point N at it with `RAFT_UPDATE_FEED_URL`, press
   the button: WinSparkle UI -> download -> signature check -> app closes ->
   installer runs silently -> N+1 relaunches; version in About is N+1 and user
   data/session survived.
6. Negative: tampered installer or wrong key -> WinSparkle refuses; lower
   `sparkle:version` -> "up to date"; an appcast `sparkle:installerArguments`
   change should not trigger a visible installer UI loop.
7. The shutdown path works with the app minimised / with an open dialog; the app
   exits (no orphaned `raft_flutter.exe`) and the installer can overwrite files.
8. Windows Defender/SmartScreen behaviour for the unsigned installer.
9. Confirm `HKCU\Software\app.raft\Raft\WinSparkle` is written and nothing needs
   elevation.

## Linux AppImage (zsync delta update)

Kevin chose AppImageUpdate-style zsync delta updates. The AppImage carries its
update information, every release publishes a `.zsync` control file next to the
AppImage, and the app downloads only the blocks that changed. The client is
`packages/raft_updater/lib/src/appimage/` (pure Dart); nothing is added to the
AppImage and nothing is compiled.

### Research (2026-10-13)

- **AppImageUpdate** ([repo](https://github.com/AppImage/AppImageUpdate), MIT).
  Newest release `2.0.0-alpha-1-20251018` (alpha, 2025-10-18; last commit the same
  day, "latest-[pre|all]" support added 2025-09). Ships `appimageupdatetool`,
  a GUI and the C++ `libappimageupdate` (no C ABI). The x86_64
  `appimageupdatetool` is a 36.5 MB AppImage whose payload (133 MB unpacked) is
  built on Debian 11: OpenSSL 1.1.1, ICU 67, GPGME, libarchive, GLib, librsvg.
  `appimageupdatetool -j` checks, `-O` overwrites in place, `-r` removes the old
  file, `-u` overrides the update string.
- **zsync2** ([repo](https://github.com/AppImage/zsync2), the engine behind it).
  README: "Artistic License v2", "as of now not functional" (a decade-old
  working-title note); last push 2025-09. The original **zsync 0.6.2** by Colin
  Phipps (Artistic 2.0) is what `zsyncmake` in Debian/Ubuntu is; its `.zsync`
  format is the contract both clients read.
- **Update information** ([AppImageSpec draft](https://github.com/AppImage/AppImageSpec/blob/master/draft.md)):
  `zsync|<url of .zsync>` or `gh-releases-zsync|<owner>|<repo>|<latest|latest-pre|latest-all>|<glob of the .zsync asset>`,
  stored in the ELF section `.upd_info` (1024 bytes) of the type-2 runtime; an
  optional signature lives in `.sha256_sig` with the key in `.sig_key`.
- **appimagetool** ([repo](https://github.com/AppImage/appimagetool); the pinned
  continuous build 854e19e): `-u/--updateinformation STRING` embeds it ("if
  zsyncmake is installed, generate zsync file"; it only warns otherwise, so
  `tool/appimage.py` calls `zsyncmake` itself and verifies the result), `-s/--sign`
  signs with GPG.
- **GitHub behaviour** (checked against this repository's v0.1.0+6 assets):
  `releases/download/<tag>/<asset>` answers 302 to
  `release-assets.githubusercontent.com/...?se=<expiry>` (a signed Azure Blob link
  valid for about an hour). A single `Range: bytes=a-b` gets `206`; a
  multi-range request (what the classic `zsync` client sends) gets
  `501 Not Implemented` from the edge cache. The `gh-releases-zsync` transport
  would also call the rate-limited REST API (`api.github.com/.../releases/latest`).

### Decision: a zsync client in Dart (option c)

| | (a) bundle `appimageupdatetool` | (b) libappimageupdate via FFI/C helper | (c) Dart client (chosen) |
| --- | --- | --- | --- |
| Size | +36 MB compressed (+29 % of the 125 MB AppImage) | native libs + deps | 0 |
| Dependencies | a nested AppImage (FUSE or 133 MB extraction per run), Debian 11 OpenSSL 1.1 (end of life), GPGME, GLib duplicates of ours | C++ library without a C ABI, cpr/curl/gpgme/libarchive built in the Ubuntu 24.04 CI, git submodules | none (`crypto` is already used) |
| Proxy / progress / cancel | environment variables; progress by parsing text | callbacks through a hand-written shim | the app's own proxy-aware client (Settings > Network); typed progress |
| Multi-range | zsync2 sends multi-range requests, which GitHub's CDN rejects with 501 | same | single ranges, merged and parallel |
| Failure reasons | exit codes | exit codes | typed, mapped to specific sentences |
| Upstream | alpha, one maintainer | alpha | the format is fixed since 2005; we own both ends |
| Licence | MIT + Artistic + the bundle's LGPL/GPL set (notices needed) | same | none added |

Option (a) was the closest second; its size, the end-of-life crypto library and
the unusable multi-range behaviour against GitHub decided against it. Option (c)
costs about 600 lines of Dart that are checked against `zsyncmake` itself: the
unit tests parse a control file written by zsync 0.6.2 and reproduce its block
table byte for byte, and the block matcher is compared with the reference `zsync`
client on real releases. Because the embedded
string and the `.zsync` are standard, third-party tools (`appimageupdatetool`,
AppImageLauncher, appimaged) can also update our AppImages.

### Release side

- `tool/appimage.py` embeds `gh-releases-zsync|kevinzhow|raft-flutter|latest|raft-flutter-*-appimage-x64.AppImage.zsync`
  with `appimagetool --updateinformation` (`OFFICIAL_UPDATE_INFORMATION`; a test
  keeps `AppImageUpdateInformation.official` in Dart equal). `latest` follows the
  stable release only, like the red dot.
- `tool/release.py build appimage` then runs `zsyncmake -u <asset name>` (package
  `zsync`, installed by the workflow) and checks that the control file's URL,
  length and SHA-1 describe the artifact. The `.zsync` is an `extraArtifacts`
  entry: checksummed, listed in the receipt and `build-manifest-appimage-x64.json`
  and uploaded by the same publisher; it may only be `<AppImage name>.zsync`.
- The manifest already carries the AppImage's `sha256` and `bytes`; the app
  verifies the result against them. The publisher adds `edSignature` (below).
- **Isolated builds** (`RAFT_APPLICATION_ID_SUFFIX`) embed nothing, so they are
  `available == false` and can never update into the official build. Only the test
  harness may set `RAFT_APPIMAGE_UPDATE_INFO` (rejected unless the suffix is set).

### App side

`AppUpdater.available` on Linux is true only when `$APPIMAGE` names a file, that
file carries parsable update information (`.upd_info`), the app gave the updater
its proxy-aware HTTP client (`configureAppImage`, called from `main`) and the
file's folder accepts a new file (a probe file is created and removed). The path
is resolved through symlinks. `unavailableReason` says which condition failed.

"Update now" (`AppImageUpdater.install`) runs in the Updates card:

1. Fetch `releases/download/<tag>/<asset>.zsync` (tag, asset name, `sha256` and
   `bytes` from the manifest the red dot already uses; no REST API). The control
   file must describe exactly `bytes` and name the same asset on the same origin.
2. Scan the running AppImage for the blocks of the new file at any offset (zsync's
   rolling checksum plus MD4, in an isolate).
3. Download the remaining ranges with single `Range` requests: neighbouring gaps
   under 64 KiB are merged, large ranges are split into 2 MiB pieces and fetched on
   4 connections, redirects are followed by hand so `Range` survives, an expired
   CDN link is resolved again and a cut connection resumes from the first missing
   byte. Output goes to `.<name>.part` beside the AppImage.
4. Verify size, SHA-1 (control file), SHA-256 (manifest) and the Ed25519
   signature (`edSignature` in the manifest, against the public key compiled into
   the app), all in one pass over the file. Any mismatch deletes the partial file
   and leaves the installed one untouched; nothing is replaced before this passes.
5. Copy the old file's permissions, rename the old file to `.<name>.old`, rename
   the new file into place, delete the backup (restored if the second rename
   fails). The running process keeps using the old inode.
6. The card shows "Restart to finish". `restart()` starts a detached shell that
   waits for this process to exit (the new instance must not meet the old one's
   single-instance name), restores the host environment that `AppRun` replaced
   (`RAFT_APPIMAGE_HOST_*`, as `raft-gio-launch-desktop` does), and `exec`s the
   new AppImage; the app then quits.

Failures keep the old version and name their cause (`AppImageUpdateFailureKind`):
network (names the host), unexpected HTTP status, release without `.zsync`,
control file not matching the release, server without Range support, disk full,
folder not writable, missing checksum in the manifest, failed verification, file
could not be moved, cancelled, unexpected. The card shows the sentence, "View
release" (the release page) and "Check for updates"; nothing opens a browser by
itself. The sentences have zh in `zh_native_only.dart`.

Trust: the SHA-1/SHA-256 values come from the same GitHub release as the bytes,
so on their own they protect against corruption and partial releases, not against
someone who can replace release assets. The signature below is what makes the
update trustworthy: only the holder of the private key can produce a file the
app accepts.

### Test override and smoke test

`RAFT_UPDATE_ORIGIN=http://127.0.0.1:PORT` replaces `https://github.com` for the
manifest and the `.zsync`/AppImage URLs. It is honoured only by isolated builds
and non-release builds (`updateOriginOverride`); an official release build ignores
it. `RAFT_UPDATE_SMOKE=1` (additionally requires that override) makes the app run
the update by itself at start, `RAFT_UPDATE_SMOKE_RESTART=1` restart into it, and
`RAFT_UPDATE_SMOKE_LOG` receives the `RAFT_UPDATE_SMOKE ...` lines.

```sh
# two isolated AppImages with a test feed, build numbers 71 and 72
RAFT_APPLICATION_ID_SUFFIX=.isolated GITHUB_RUN_NUMBER=71 \
  RAFT_APPIMAGE_UPDATE_INFO='gh-releases-zsync|kevinzhow|raft-flutter|latest|raft-flutter-*-isolated-appimage-x64.AppImage.zsync' \
  python3 tool/release.py build appimage        # keep build/release/*, repeat with 72
python3 tool/appimage-update-smoke.py --old a/raft-...AppImage --new b/raft-...AppImage --output /tmp/out
```

The harness serves a GitHub-shaped release (302 to a Range-capable object URL),
runs the old AppImage under Xvfb with a throwaway HOME, session bus and keyring,
and reports the bytes served, the replaced file's SHA-256, the leftovers and the
build the restarted app reports. `tool/tests/test_appimage_update_smoke.py` checks
the server itself.

### Signature (Ed25519, the Sparkle key)

Kevin approved signing AppImage updates with the **same Ed25519 key
pair as macOS and Windows**; GPG (`appimagetool --sign`, `.sha256_sig`) is not
used. One key, one rotation story (see "Rotation is not seamless" above).

- **Scheme.** The same as Sparkle's `sign_update`: Ed25519 (RFC 8032, pure) over
  the *whole AppImage file*, the signature (64 bytes) base64 encoded; the public
  key is the base64 of the 32 raw bytes. `tool/appcast.py` (`sign_file`) is the
  signer; it streams the file and takes the key from `SPARKLE_ED_PRIVATE_KEY` in
  the environment, never argv, never logged.
- **Release side** (`tool/release.py`). The build job (no secret) records
  `autoUpdate: {enabled, publicKey, archive}` in the receipt and compiles the
  public key in. The tag-only publisher (`appimage_signature`) checks that the
  secret's public key equals the one built into the app, signs the AppImage,
  verifies its own signature, and writes it as `edSignature` in the entry of
  `build-manifest-appimage-x64.json` (the name matches the appcast attribute
  `sparkle:edSignature`; the manifest is where the app already reads `sha256` and
  `bytes`, so no extra asset or request). Ed25519 is deterministic: a retried
  publisher writes identical bytes. A build without `SPARKLE_ED_PUBLIC_KEY`
  publishes no signature, and a build that embeds a key but finds no secret
  fails to publish, as for the appcasts.
- **App side** (`packages/raft_updater/lib/src/appimage/ed25519.dart`).
  `RAFT_SPARKLE_ED_PUBLIC_KEY` is passed to AppImage release builds like to
  Windows. A build without it reports `available == false` ("This build has no
  update signing key.") and the card says "View release". The updater hashes the
  reconstructed `.part` file once for SHA-1, SHA-256 and the signature, so the
  signature is checked before the file replaces `$APPIMAGE`.
- **Failures.** A manifest without `edSignature`, or a build without a key:
  `missingSignature`, refused before anything is downloaded. A malformed
  signature, a signature of another key or of other bytes (one changed byte is
  enough): `badSignature`, the download is discarded. Both keep the old version,
  show a specific sentence (English and Chinese) and the "View release"
  fallback. The checksum failure (`verification`) is reported first when both
  fail.
- **Why our own verifier.** The dependency tree has no Ed25519 implementation
  (`crypto` only), and the Dart packages that offer one (`cryptography`,
  `pinenacl`, `ed25519_edwards`) take the whole message as one `Uint8List`, while
  the message here is a 120+ MB file that is already streamed through SHA-1 and
  SHA-256. Verification handles only public data, so the short RFC 8032 reference
  arithmetic on `BigInt` (about 100 lines) plus `crypto`'s streaming SHA-512 avoids
  a new dependency, its licence entry and a whole-file buffer. It is pinned by the
  RFC 8032 vectors and by a test that verifies signatures made by
  `tool/appcast.py`. (Swapping in a package later only touches `ed25519.dart`.)
- **Rehearsal.** `python3 tool/appcast.py keygen --out DIR` makes a throwaway key
  pair; build the old and new isolated AppImages with
  `SPARKLE_ED_PUBLIC_KEY=<its public key>` in the environment, and give
  `tool/appimage-update-smoke.py` the private key file
  (`--ed-private-key-file`). `--signature wrong-key` and `--signature missing`
  are the negative cases (the app must refuse and leave the file untouched).

### Not verified / left

- A real tagged release has not been built: CI must install `zsync`, build the
  `.zsync`, publish it and a published `v0.1.x` must be updated from the previous
  one (the local rehearsal used a fake GitHub with the same redirect and Range
  behaviour). The first release with update information has no older release that
  can use it.
- Real-GitHub transport was exercised for the redirect, a 4 MiB range and the
  manifest only.
- Keyring, FUSE-less (`--appimage-extract-and-run`) and Wayland starts of the
  restarted app, AppImages in root-owned folders (`/opt`; the card reports "not
  writable") and desktop-integration copies (AppImageLauncher) are not covered.
- Update information and `.zsync` only exist for x86_64.

## Verified here (Linux) vs not

Verified: Ed25519 signer against RFC 8032 and the `cryptography` library, and the
Dart verifier against the RFC 8032 vectors and the signer's output; the AppImage
signature in the publish flow (valid, wrong key, missing secret, no key) and in
the updater (valid, one changed byte, wrong key, missing and malformed signature); `tool/appimage-update-smoke.py` with a throwaway key pair on two isolated Ubuntu 24.04 builds (71 to 72: 0.7% of the 116 MiB file downloaded, signature verified in the same pass as the checksums, about 4 s verification; a signature by another key, no signature and a wrong SHA-256 are all refused with the installed file untouched); appcast
XML shape, signature, URLs, determinism; publish flow with extra artifacts, missing
or mismatched secret, no-key builds and idempotent retries; macOS inventory,
signing order and plist checks against a mocked `codesign`; Inno script settings;
Dart `AppUpdater` behaviour and fallbacks (`flutter test`, `flutter analyze`); the
Linux AppImage delta update end to end (see above).
Not verified: any native compile (Swift, C++), Sparkle/WinSparkle behaviour, Inno
Setup output, SwiftPM embedding of Sparkle, real GitHub secrets/variables, the
Keychain re-prompt. Those are the checklists above.

## Other platforms

Android (red dot opens the APK link) and iOS have no in-app update;
`AppUpdater.available` is false and `checkAndInstall()` opens the release page. On
Linux outside an AppImage (a distribution package updates through its package
manager) and for an AppImage that cannot update in place, the card also reads
"View release". Intel Macs have no build.
