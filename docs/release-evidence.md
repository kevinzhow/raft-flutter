# Released artifact evidence

Current product and verification source hash: `b98e0a301b74980654be7a5268f2ada2202541b2c2ba026b9a8b3f575a7fc079`.
Product commit: `032f9f0442cf972c3e566c57ee9a19e8f361e2f3`. The build manifest binds both actual archives to that commit and source. Engineering passed 709 Dart tests, 33 host tests and whole-project analysis. The matching full native suites passed: Android run `2026-10-08T13:04:28.088026Z`, 66 checkpoints; Linux run `2026-10-08T13:10:10.004525Z`, 56 checkpoints, including real sign-out and secure-store clearing.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `raft-flutter-android.apk` | 137440047 | `7729c4bfe315e7b7facf8b87005c3913503d879d8f6677ac2a138d62df632648` |
| `raft-flutter-linux-x64.tar.gz` | 117119938 | `e5988ce3c0dff7fec60dec50fe9a0d7946f809b6912c2a3cd51496a223980b72` |

Build-manifest SHA-256: `61795cac1b94413923549efa04412a2b183fc0648b2c5f38c741f7b8d198c979`. The strict builder checked unchanged source and package locks after compilation. Android uses the local debug acceptance signing key; these files are not store-signed production releases.

## Actual released APK verification

The exact delivered APK was installed and cold-launched on the owned API37 Android emulator with 16KiB pages. All 21 packaged ELF files were inspected; 64-bit load alignment is at least 16KiB. APK signature and 16KiB ZIP alignment checks passed. Compiled manifest/resources confirm non-debuggable application, disabled backup, cloud/device-transfer exclusions and exactly three development-only cleartext domains with subdomain inclusion disabled. No cloud restore or OEM migration was executed.

Real pointer input entered an example.invalid email on the native login form without submitting it. The real system keyboard content rectangle was `[0,1517,1080,2400]`; the focused email field `[110,803,970,918]` remained above it. A real edge swipe dismissed the keyboard. The app window covered all 1080×2400 pixels; sampled status-bar, navigation-bar and app canvas pixels all matched white. The prior keyboard setting was restored. Screenshots and the source/artifact-bound receipt are published as supplemental release evidence.

This unauthenticated released APK smoke does not repeat the authenticated development-build suite, establish a physical device, system CJK IME input, store signing or cloud restore.

## Relocated Linux archive verification

The exact archive was extracted outside the checkout. ELF dependency resolution and RPATH checks passed for 218 ELF files without checkout library mappings. The isolated GTK/X11 release GUI passed on `2026-10-08T13:36:03Z`: actual native login controls, measured painted-frame pointer target, XTest click and clipboard paste, exact native AT-SPI CJK text readback, visible CJK screenshot, no login submission and no developer-checkout library mappings. The owned display, bus and application were stopped. A fresh empty SecretService/keyring was initialized only in the isolated session; no user collection was touched.

The separately exercised `Component.GetExtents` method remains an unresolved timeout, even though live text and state calls respond. Its failed attempts are retained. The successful pointer target was measured from the fresh painted login screenshot and verified editable Email/Password order; no source coordinates were used. This passing basic GUI interaction does not establish AT-SPI component-coordinate correctness.

The separately relocated bundled libmpv decoded a generated three-second WAV into 48,000 mono 16-bit PCM frames at 16,000Hz: 96,000 bytes, zero mean absolute sample error. This verifies actual bundled-library decoding; it does not prove physical audio, GPU video rendering, Wayland or another Linux distribution.

## Preserved failures and acceptance boundaries

Two earlier 14fd Android native attempts remain failures: 53 checkpoints before an uncorrelated unsolicited HTTP-response parser exception, and 42 before an attachment-title pointer miss. The first cause remains unknown; the current pass does not erase or explain it. The verified helper change centrally reveals the real filename target and waits for bounded hit-test readiness before the same fatal tap and decoder assertions.

Release-probe plumbing failures are also preserved: apkanalyzer omitted compiled XML text, the obsolete accessibility object path did not exist, an overlong isolated runtime path exceeded the Unix socket limit, and a keyboard-window frame was initially mistaken for its visible content rectangle. Corrections affect only independent verification scripts, not the delivered product bytes.

A decompressed artifact privacy scan found no fixture passwords, tokens or test markers. Its origin-only matches were independently traced to three existing public production defaults; the raw failed scan is preserved alongside a narrowly reviewed exception. This is not a blanket private-origin allowlist.

Functional verification is complete for these main suites. Pixel-level parity remains unaccepted: 523 inventory cases plus three diagnostics are pending, historical reviewed failures are retained, native touch-layout adaptations and dataset/safe-area differences are explicit. Historical 75 SDK browser-theme receipts do not certify the current source. Independent native workspace windows, full Mermaid grammar/layout, broad accessibility and iOS native/background execution remain limited or unproved. Configured OAuth/mail, Slack, Stripe and the default-OFF conversion worker retain their documented external boundaries.

All three source/artifact-bound supplemental release probes passed: Android installation/IME/back/paint, relocated Linux GUI/CJK, and bundled libmpv PCM decoding. The public report was opened in a real browser. Both rendered artifact links downloaded successfully and matched the trusted local manifest in byte count and SHA-256; all 221 report images decoded. Published-file privacy review passed with the same narrowly documented production-origin collision. Historical SDK labels and the explicit incomplete visual status were verified. The final remote push remains pending.
