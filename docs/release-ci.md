# GitHub build and release

`.github/workflows/release.yml` builds on GitHub-hosted runners using the exact
Flutter version in `.fvmrc` and the checked-in pub lockfile. Windows x64, signed Android ARM64, Linux x64 AppImage and macOS ARM64 are enabled
by default. Builds use `lib/main.dart` and produce no private test fixtures or
test feature defines. This pipeline is separate from the local native-acceptance
packager `tool/build-deliverables`; compilation does not imply full-app acceptance.

## Hosted release runners

Active macOS builds use the standard `macos-15` ARM64 runner; AppImage builds
use `ubuntu-24.04` x64. The jobs install Python 3.12, the exact `.fvmrc` Flutter
SDK and, on macOS, Ruby 3.3 with CocoaPods 1.16.2 and JSON 2.18.0. Native host
architecture and the Ubuntu 24.04 ABI baseline are checked before packaging.
The disabled `linux` tarball entry keeps its Ubuntu 26.04 media contract; this
routing change does not enable it or migrate its package dependencies.

The manual **Backfill an existing platform release** workflow uses these hosted
runners too. It installs tooling from the original tag checkout's `.fvmrc`,
then verifies the original tag, full source SHA and stored build number before
building. The default remains build-only. Explicit publication rechecks that
same provenance, keeps the existing update signatures and no-overwrite checks,
and still requires Ubuntu startup and Fedora compatibility success for
AppImage. The retired runners' storage variables and cleanup hooks are no
longer prerequisites; their historical provisioning notes remain preserved.

## App version follows the Raft server version

Owner decision (Kevin, 2026-10-23): the app version is the Raft server version the client is aligned to, which is the
pinned Web release in `docs/upstream-sync.json` (`v1.21.23-source.1` gives `1.21.23`). Client-only changes add a tag
build: `v1.21.23+1`, `v1.21.23+2`, and so on. `tool/release.py plan` stops a tag whose version is not the pinned
server version, and `apps/raft_flutter/pubspec.yaml` carries the same version for branch builds
(`tool/tests/test_release_version_policy.py`). Moving the pin (`tool/upstream_sync.py record-decision`) therefore also
moves the pubspec version. The installed build number still comes from the workflow run counter, so updates keep
increasing across the switch from `0.1.0` to `1.21.x`.

## Release notes (before tagging)

The app's Settings > Release Notes page shows the client's own notes, not the
Raft server's. Every release must have a notes file before its tag is pushed:

1. Add `docs/release-notes/<tag>.md`, e.g. `docs/release-notes/v0.1.1+1.md`
   (the file name is the tag; keep the older files, they are the history):

   ```
   ---
   date: 2026-10-20
   ---
   - feature: A user-facing sentence in English.
   - improvement!: A trailing `!` after the type emphasises the entry.
   - fix: Types are feature, improvement, fix, breaking and deprecated.
   ```

   `version:` is optional (it must equal the tag's version); `state: retracted`
   marks a withdrawn release. Check it locally with
   `python3 tool/release_notes.py <tag> --out /tmp/release-notes.json`.
2. Merge it, then push the tag. `prepare-release` runs `tool/release_notes.py`
   and attaches `release-notes.json` to the draft release before any platform
   build starts; a missing or malformed file stops the release there. The asset
   has the shape of one Web `GET /release-notes` page and holds the full
   history, so the latest release always carries every earlier entry.
3. The app downloads `releases/latest/download/release-notes.json` (through the
   Settings > Network proxy) and keeps the last copy for offline use. Opening
   Settings > Release Notes shows that copy at once and refreshes it in the
   background (also on returning to the app and on pull-to-refresh); a copy
   written by another app build is never reused as current, so the first look
   after an update downloads again. The update prompt in Settings > About reads
   the notes of the offered release from the same asset and lists every release
   between the installed one and the offered one; release builds pass the tag
   as `RAFT_RELEASE_TAG` so the installed release is known. English entries are
   shown as written; there is no translation of the notes themselves.

## Trigger a release

1. Review and merge the source through the normal integration batch and
   `tool/check-project` gate.
2. Push a version tag such as `v0.1.1`. For another build of the same app version,
   push a new tag such as `v0.1.1+1`, then `v0.1.1+2`. Prerelease tags such as
   `v0.1.1-rc.1+2` are also accepted.
3. The tag selects the compiled app version (`0.1.1` above), overriding the
   pubspec version via Flutter build flags without modifying tracked files.
   CI uses `GITHUB_RUN_NUMBER` as the build number, as in the local Miraa Google
   Play workflow. New workflow runs increase it automatically; rerunning the
   same run keeps it. There is no need to edit the pubspec for each tagged build.

For example, `v0.1.1+2` on workflow run 47 builds app version `0.1.1` with build
number `47` (ARM64 split APK version code `2047`). The `+2` distinguishes the
release and is kept in the asset name, e.g.
`raft-flutter-0.1.1+2-android-arm64.apk`, and the Release tag/title. Each tag creates
its own Release, so earlier builds remain available; a stable release is marked
as Latest, while prereleases are not. Keep the same release key
for Android updates. Branch PR/manual runs use the pubspec app version and the
workflow counter; local runs without GitHub context fall back to the pubspec.

Malformed tags or invalid/missing tag-run counters stop before building. A shared
plan validates the release protocol, then `prepare-release` creates one draft
with the tag, source commit, build number and expected platform inventory. Each
matrix entry calls `.github/workflows/release-platform.yml`, which owns its build,
platform checks and publisher. The first successful platform uploads its assets
and makes the release public; other successful platforms append their assets as
they finish. A failed Windows, Android, macOS or AppImage job does not block the
other platforms. The workflow still reports failures, and a missing asset may
mean that its platform is still running or failed.

AppImage packaging tests, Ubuntu startup checks and Fedora compatibility checks
must pass before **AppImage** publishes. macOS packaging tests run in the macOS
job. Neither platform's checks gate Windows or Android. All publishers verify
their own artifact's SHA-256, architecture, version, build number, full release
tag and source commit before uploading. Each platform owns a separate
`CHECKSUMS-PLATFORM-ARCH.txt` and `build-manifest-PLATFORM-ARCH.json`; there is no
shared checksum or manifest file for concurrent publishers to overwrite. For
example, Android publishes `CHECKSUMS-android-arm64.txt` alongside its APK and
`build-manifest-android-arm64.json`.

Pull requests touching release tooling, the lockfile or desktop hosts run the
unsigned desktop platforms and retain artifacts for 14 days. Tag builds keep their
release artifacts for 2 days only, because the same run copies them into the GitHub
Release; this keeps the account's Actions storage from filling up. **PR and manual
runs never publish.** From Actions → Build and release → Run workflow, leave
`platforms` blank for the enabled set, or select e.g. `windows,macos` to test
builders before enabling them. Pull request plans exclude Android and pass no
persistent signing secrets. Android changes are tested by a manual Android build
on a reviewed branch; tags build all enabled platforms. Builds use read-only
repository permission; only tag preparation and platform publishers use
`contents: write` with the built-in `GITHUB_TOKEN`.

Concurrency is serialized per event/ref. Published assets are never overwritten.
On a retry of the same run, preparation verifies the existing release's source,
build number and platform inventory. Publishers compare already uploaded files
by SHA-256 and upload only missing files. An interrupted first upload leaves a
draft until a platform finishes; an interrupted later upload leaves the already
published platforms available. Do not delete successful assets to recover a
failed platform. Rerun the failed publication with the original artifact; if a
rebuild produces different bytes, the publisher refuses to replace existing
files. Use a new tag (`+N` is sufficient) for changed artifacts, source or build
number, or to replace a release created by the previous publication pipeline.

Independent append operations require **mutable GitHub Releases**. Enabling
immutable releases would lock the assets after the first platform publishes and
prevent later platforms from appending. This pipeline does not change repository
settings. The current repository has immutable releases disabled. Prerelease
tags remain prereleases and are not marked Latest. Stable `+N` tags retain the
whole tag and are marked Latest when the first platform succeeds.

This follows the local SwiftWire release workflow's independent platform
publication and checksum-verified, non-overwriting retries. GitHub's
[`needs` failure propagation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs)
means `fail-fast: false` alone cannot make an aggregate publisher independent;
the publication dependencies must also stay within each platform instance.

## Enable other platforms

Change `enabled` in `tool/release-platforms.json` after a manual build and platform
acceptance. The same matrix and reusable platform workflow handle every enabled platform. Runner
labels and architecture metadata are in that file; changing architecture also
requires adjusting the corresponding native build and packaging implementation.

| Platform | Runner | Asset | Requirements / current limits |
| --- | --- | --- | --- |
| Windows x64 | `windows-2022` | Complete portable ZIP plus a per-user Inno Setup installer (`-setup.exe`, the WinSparkle update vehicle) | No Authenticode signature. MSVC runtime included; system Toast needs no Windows App Runtime. Keep all DLLs and `data/`; first launch registers the current-user notification identity and protocol. Device acceptance is separate from hosted CI. |
| Android ARM64 | `ubuntu-24.04` | Signed split APK | SDK 37 / build tools 37.0.0, Java 17. Requires all signing secrets below; missing secrets fail instead of producing a debug-signed release. No Play Store/AAB upload. |
| Linux x64 | `ubuntu-26.04` | Relocatable `.tar.gz` | Uses existing pinned Ubuntu Resolute media preparation; package/hash drift fails. Bundles library notices/provenance and verifies ELF lookup. Ubuntu 26.04 glibc/GTK/drivers required; other distributions are unverified. Review media GPL terms and supply matching source before enabling distribution. |
| Linux x64 AppImage | `ubuntu-24.04` | `.AppImage` | Bundled GTK/media/PDF tools; latest reviewed static AppImage runtime, glibc ≤ 2.39, direct and no-FUSE startup checks, plus Fedora KDE Wayland compatibility checks. |
| macOS ARM64 | `macos-15` | `.app` ZIP via `ditto` | Existing ad-hoc signing; embeds Sparkle 2. No Developer ID/notarization; Gatekeeper distribution acceptance is pending. No Intel build. |

## In-app update feeds

macOS and Windows also publish `appcast-macos.xml` / `appcast-windows.xml` (Sparkle /
WinSparkle feeds, EdDSA-signed in the tag-only publish job). Actions **variable**
`SPARKLE_ED_PUBLIC_KEY` is embedded into the builds (empty disables auto-update for
that build) and Actions **secret** `SPARKLE_ED_PRIVATE_KEY` signs the enclosure.
The Linux AppImage uses the same key pair: the publisher signs the AppImage bytes
and writes the base64 Ed25519 signature as `edSignature` into
`build-manifest-appimage-x64.json` (no appcast, no extra asset); the app verifies it
against the embedded public key before replacing the AppImage.
A build that embeds a key but finds no secret fails to publish. Receipts may list
`extraArtifacts` (the Windows setup exe, the AppImage's `.zsync`), which are
checksummed and uploaded with the platform. Details, key rotation and verification checklists:
[auto-update.md](auto-update.md).

Android repository **Actions secrets**:

- `RAFT_ANDROID_KEYSTORE_BASE64`: base64 bytes of the persistent release JKS/keystore.
- `RAFT_ANDROID_STORE_PASSWORD`: keystore password.
- `RAFT_ANDROID_KEY_ALIAS`: signing key alias.
- `RAFT_ANDROID_KEY_PASSWORD`: key password.

### Prepare the Android release key locally

Run `python3 tool/android-release-signing.py init` once. This creates an RSA-4096
JKS key with 10,000-day validity at `.local/android-release-signing/release.jks`
and random store/key passwords in `.local/android-release-signing/credentials.json`.
The directory is ignored by Git, accessible only to its owner, and cannot be
replaced by running `init` again. Back up both files securely together and retain
the same key for every released Android update.

`python3 tool/android-release-signing.py export` prints a JSON object containing
the four secret names above and their values, including the base64-encoded key.
For a private file instead, run:

```sh
python3 tool/android-release-signing.py export --output .local/android-release-secrets.json
```

Create each entry under repository **Settings → Secrets and variables → Actions
→ Secrets → New repository secret**. These are Secrets, not Variables; copy each
JSON string's value without quotes. To copy one value on macOS, for example:

```sh
python3 tool/android-release-signing.py export --secret RAFT_ANDROID_KEYSTORE_BASE64 | pbcopy
```

The helper refuses to generate/export secrets in CI, overwrite existing exports,
or save an export outside `.local/`. Keep its output out of logs and commits.
Android is enabled in `tool/release-platforms.json` for version-tag releases.
Use a manual run with `platforms: android` to test signing without publishing.
The build verifies the compiled package, version name, ARM64-only libraries,
non-debuggable manifest and APK signature against the configured JKS certificate.
The manifest records the certificate SHA-256 and actual APK version code (the
pinned Flutter split-APK builder adds 2000 to the pubspec build number for ARM64).

The keystore is decoded into a temporary directory and removed after the build.
Passwords stay in environment variables and are never written to source or
artifacts. Gradle uses this keystore when supplied; local acceptance builds retain
their existing debug signing. Do not upload keys or secrets as build artifacts.
Device installation continues to use `tool/android-install` and its signature,
version and data-preservation checks; CI does not install on any device.

Developer ID/notarization, Windows certificate signing, installers, app stores and
iOS remain future extensions; this pipeline currently publishes GitHub assets.

Sources: [GitHub runner labels](https://docs.github.com/en/actions/reference/runners/github-hosted-runners),
[Flutter SDK action / FVM pinning](https://github.com/subosito/flutter-action),
[GitHub CLI release creation](https://cli.github.com/manual/gh_release_create),
[release asset upload](https://cli.github.com/manual/gh_release_upload).

## Android CI verification (2026-10-12)

The [manual Android run](https://github.com/kevinzhow/raft-flutter/actions/runs/38229094176)
passed on source `95d161f7d122167b58e223bd9c6b6091ddd7a5f5`. The downloaded
`raft-flutter-0.1.0-android-arm64.apk` was independently checked with Build Tools 37:
package `app.raft.raft_flutter`, version `0.1.0`, version code `2001`, only
`arm64-v8a`, and certificate SHA-256
`565c29877e7edc82ff449b8f4406e7b98ef2fce11e67a2555d142be1306ccd33`.
Its 54,590,020 bytes matched SHA-256
`675241868000a8b4fbb4f15c126c36320e4803e9706a8765e63dfc668e827a9f`.
This source also passed the integration gate: 5,320 Dart tests, 261 host tests,
analysis and the design-system ratchet (36 Dart tests skipped; sampled themes).

Earlier failed runs remain available: missing SDK command-line PATH
[38226748717](https://github.com/kevinzhow/raft-flutter/actions/runs/38226748717),
removed `tools` package
[38227008234](https://github.com/kevinzhow/raft-flutter/actions/runs/38227008234),
wrong platform package name
[38227279262](https://github.com/kevinzhow/raft-flutter/actions/runs/38227279262),
and old certificate-output parsing
[38227596272](https://github.com/kevinzhow/raft-flutter/actions/runs/38227596272).
The workflow now initializes SDK command-line tools explicitly and installs
`platforms;android-37.0` / `build-tools;37.0.0`; both CI and installation preflight
recognize versioned signer labels such as `V3.0 Signer`.

SDK setup: [setup-android](https://github.com/android-actions/setup-android).
Signature verification: [Android apksigner](https://developer.android.com/tools/apksigner).
Compilation, signatures and asset publication do not establish device functional acceptance.

## Linux AppImage

`python tool/release.py build appimage` builds the production Linux entry on
Ubuntu 24.04. `tool/prepare-media-appimage` prepares that distribution's media
libraries separately from the Ubuntu 26.04 development pins. GTK, Secret Service
client libraries, media codecs and PDF helpers are included with SHA-256/source
package provenance and copyright notices. The host provides glibc, desktop
services and graphics drivers; the vendored official AppImage exclusion list
prevents bundling incompatible device libraries. Every ELF is checked for missing
libraries and a maximum glibc requirement of 2.39 before packaging.

The latest reviewed official appimagetool and type2-runtime snapshots are recorded
in `packaging/appimage/tools.json` with source commits and verified SHA-256. CI
downloads them from this repository's `appimage-tools-<date>` pre-release, not from
upstream's `continuous` releases, whose files are replaced on every rebuild; the
`upstream` field records where each copy came from. To adopt a newer snapshot,
review the upstream change, upload the files as a new `appimage-tools-<date>`
pre-release (never marked latest, so in-app updates are unaffected) and update the
lock.
The runtime statically includes FUSE 3, so users do not need `libfuse2`. The normal
launch uses the kernel FUSE device when available; extract-and-run uses no FUSE
at all. Changed upstream downloads fail the hash check instead of silently
changing the executable.

A version-tag release includes `raft-flutter-VERSION-appimage-x64.AppImage` and its
`raft-flutter-VERSION-appimage-x64.AppImage.zsync` in the independently verified
AppImage release inventory. The AppImage embeds `gh-releases-zsync|...` update
information (`appimagetool --updateinformation`) and the `.zsync` (zsync 0.6.2
`zsyncmake`, installed by the workflow with `apt install zsync`) lets the app
update with a delta download; `release.py` fails the build when `zsyncmake` is
missing or its output does not describe the artifact. The AppImage's
Ed25519 signature (same `SPARKLE_ED_PRIVATE_KEY`) is added to its manifest by the
publisher; an app without the matching public key, or a release without the
signature, falls back to the release page. See
[auto-update.md](auto-update.md#linux-appimage-zsync-delta-update). Flatpak is no longer a supported
release target, including manual platform selections. PR/manual builds retain
artifacts without publishing.

```sh
chmod +x raft-flutter-VERSION-appimage-x64.AppImage
./raft-flutter-VERSION-appimage-x64.AppImage
# Optional when FUSE is disabled, unavailable, or forbidden in a container:
./raft-flutter-VERSION-appimage-x64.AppImage --appimage-extract-and-run
```

Verify the release SHA-256 before execution. AppImage is unsigned and has no
Flatpak sandbox; it uses the native application's normal data locations and
host Secret Service, notification and display services. Packaging does not
import, migrate or delete an existing profile. Ubuntu 24.04's ABI baseline permits
many newer desktop distributions, but does not establish compatibility with older
systems, every GPU, or all desktop configurations.

### Isolated test AppImage

For a test on a machine that already runs the real app, build with
`RAFT_APPLICATION_ID_SUFFIX=.isolated python tool/release.py build appimage`
(with `GITHUB_RUN_NUMBER` set to the latest release's build number so the update
check stays quiet). The suffix reaches CMake (`APPLICATION_ID`) and Dart
(`RAFT_LINUX_APPLICATION_ID_SUFFIX`), so the GApplication/D-Bus name, the XDG
data and cache directories `app.raft.raft_flutter.isolated`, the libsecret
`account` attribute `app.raft.raft_flutter.isolated.secureStorage`, the desktop
file and icon all differ from the real app, the desktop file carries no `MimeType`, no update information is embedded (an isolated build never
self-updates into the official one; `RAFT_APPIMAGE_UPDATE_INFO` is the test-only exception),
and the build never registers `raft://` or edits mime defaults (OAuth uses the
loopback). The binary is renamed `raft_isolated` because the notification plugin
keeps `$XDG_RUNTIME_DIR/<executable>/notification_plugin_cache.json` and
path_provider_linux has a legacy data directory of that name; AppRun also creates
the id's data and cache directories first. The shown
version is `X.Y.Z-isolated`. Release CI never sets the variable.

CI runs the actual release file directly and in extract-and-run mode at 2× scale.
A Fedora 44 container without `/dev/fuse` additionally runs the downloaded artifact
in X11 and under KDE's KWin native Wayland compositor. Source/OS/mode, startup logs,
original PNGs and Wayland buffer-commit evidence are retained. KWin is nested on
Xvfb to make its CPU-rendered output capturable on a GPU-less runner; the app
itself is forced to use Wayland, and the monitor and client scale are checked at 2×. These are production
startup checks, not login or full feature acceptance. The disposable tests use a
fresh Secret Service keyring; the Fedora headless Wayland check uses software
rendering and does not establish compatibility with the user's physical GPU.

References: [AppImage concepts](https://docs.appimage.org/introduction/concepts.html),
[compatibility requirements](https://docs.appimage.org/reference/best-practices.html),
[current static runtime](https://github.com/AppImage/type2-runtime),
[official FUSE guidance](https://github.com/AppImage/AppImageKit/wiki/FUSE).
Build counter semantics: [GitHub default variables](https://docs.github.com/en/actions/reference/workflows-and-actions/variables).

## Independent platform verification (2026-10-13)

The [four-platform manual run](https://github.com/kevinzhow/raft-flutter/actions/runs/38278726932)
on `256d477a384229d10576bf27666a5c9c266ba541` passed Windows, Android ARM64,
macOS ARM64, AppImage startup and Fedora compatibility checks. All four downloaded
artifacts independently matched their receipt's platform, source commit, version,
workflow build number and SHA-256.

The [merged-source run](https://github.com/kevinzhow/raft-flutter/actions/runs/38280123560)
on `97a7ce97e26d68228eabcad775931ac0978e055f` also passed all platforms. Its first
attempt failed to download Android SDK command-line tools because Google returned
HTTP 502; Windows, macOS and AppImage/Fedora completed successfully while Android
failed. Rerunning only the Android build succeeded without rebuilding the other
platforms. The original failed attempt is retained.

Local publication tests cover first-platform publication, partial-upload recovery,
failed later platforms, idempotent retries, per-platform manifests, mismatched
assets and provenance, legacy asset digest fallback, and full `+N` tag semantics.
Workflow lint and 72 publication-condition combinations confirm platform-local
dependencies and tag-only publishing. These manual runs did not create or modify
a GitHub Release; remote publication is triggered by the next version-tag push.
