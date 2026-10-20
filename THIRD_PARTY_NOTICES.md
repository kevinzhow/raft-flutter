# Third-party notices

Raft protocol behavior, theme mapping and SyncCore compatibility ports reference `botiverse/raft-source` commit `26f77ef97c40d3d91aa2c5e42b0fd66b8bf39fe6`, copyright 2026 Botiverse, Inc. The source license is preserved in [docs/licenses/raft-source-FSL-1.1-ALv2.txt](docs/licenses/raft-source-FSL-1.1-ALv2.txt). Source provenance and local test-fixture patches are recorded in [docs/source-reference.json](docs/source-reference.json).

Bundled Geist, Geist Mono, Hanken Grotesk and Inter fonts carry their respective SIL Open Font License notices beside the font assets in `packages/raft_ui/assets/fonts/` and in `docs/licenses/` for packaged distribution.

The dependency versions are fixed in `pubspec.lock`. Flutter includes package license notices in its generated native assets; dependency source and licenses remain in the package cache. Native Mermaid rendering uses `mermaid_flutter` and its Dart dependencies; it does not bundle the Web Mermaid JavaScript runtime.

The Windows host uses Microsoft.WindowsAppSDK 1.7.250310001 from official NuGet, pinned by SHA-256 in `windows/runner/windows_app_sdk.cmake`. Its bootstrap DLL is bundled; the full Windows App Runtime remains an external prerequisite. The package's unmodified [Microsoft license terms](docs/licenses/Microsoft-Windows-App-SDK-1.7-license.txt) and [third-party notices](docs/licenses/Microsoft-Windows-App-SDK-1.7-NOTICE.txt) are preserved here and copied to `data/licenses/windows-app-sdk/` in the Windows bundle.

Exact icon geometry from the pinned Web dependency lucide-react 1.55.0 (also imported by raft-ui 0.5.52) carries its ISC and Feather MIT notices in `docs/licenses/lucide-1.55.0-ISC.txt` and `packages/raft_ui/LICENSE-LUCIDE`.

Liberation Sans (diagram-only): unchanged fonts from fonts-liberation 1:2.1.5-3build1, copyright Google Corporation and Red Hat, Inc.; SIL OFL 1.1. See docs/licenses/LiberationSans-OFL.txt and docs/diagram-font-provenance.json.

Design-token sources vendored for `tool/gen-tokens` live in `tool/design-source/` (hashes in `manifest.json`): raft-ui 0.5.52 `dist/foundation.css`, `dist/styles.css`, `dist/fonts.css` (MIT, per the npm package metadata), tailwindcss 4.3.3 `theme.css` (MIT, license copied beside it), and raft-source a98ae00 `packages/web/src/index.css` (covered by the raft-source license above). See docs/design-tokens.md.

Runtime alternate icons use a locally modified flutter_dynamic_icon_plus 1.4.1 (MIT), copyright 2024 chandrabezzo. The original [license](packages/flutter_dynamic_icon_plus/LICENSE), [upstream provenance](packages/flutter_dynamic_icon_plus/UPSTREAM.json) and [local changes](packages/flutter_dynamic_icon_plus/RAFT_PATCHES.md) are preserved with the vendored source.

Linux file drops use a locally modified desktop_drop 0.8.4 (Apache-2.0), copyright 2021 Mixin. The original [license](packages/desktop_drop/LICENSE), [upstream provenance](packages/desktop_drop/UPSTREAM.json) and [local changes](packages/desktop_drop/RAFT_PATCHES.md) are preserved with the vendored source.

macOS Dock unread badges use app_badge_plus 1.3.5 (MIT), copyright 2024 LioLin. The unmodified [license](docs/licenses/app_badge_plus-1.3.5-MIT.txt) is preserved for distribution.

The Linux runner vendors `apps/raft_flutter/linux/runner/flutter_embedder.h` unchanged from Flutter 3.47.6 (BSD-3-Clause, copyright The Flutter Authors) to add the vsync callback the GTK embedder omits (`vsync_driver.cc`).

In-app updates use Sparkle 2.10.0 on macOS (MIT with bundled third-party notices; fetched as a Swift package, embedded in `Raft.app/Contents/Frameworks/Sparkle.framework`) and WinSparkle 0.9.4 on Windows (MIT, includes Expat; downloaded and pinned by SHA-256 in `packages/raft_updater/windows/CMakeLists.txt`, `WinSparkle.dll` bundled). Their unmodified licenses are preserved in [docs/licenses/Sparkle-2.10.0-LICENSE.txt](docs/licenses/Sparkle-2.10.0-LICENSE.txt) and [docs/licenses/WinSparkle-0.9.4-COPYING.txt](docs/licenses/WinSparkle-0.9.4-COPYING.txt) and copied into the distributed archives. See [docs/auto-update.md](docs/auto-update.md).
