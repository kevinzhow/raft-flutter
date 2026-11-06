# Linux browser and attachment runtime

Windows and Linux use media_kit/libmpv for attachment media; Android, iOS and
macOS use their system player (see [media playback](media-playback.md)). On
Linux, libmpv and its codec/driver dependencies now come from the distribution.
The app no longer downloads a private media closure before a build or installs
that closure into its bundle. Build with the distribution's `libmpv-dev` and
`libwebkit2gtk-4.1-dev` development packages on Ubuntu, or the corresponding
Fedora `mpv-devel` and `webkit2gtk4.1-devel` packages.

The Linux HTML viewer uses system WebKitGTK API 4.1: GTK3 and libsoup3. GTK, GLib,
GIO, Pango, GdkPixbuf, GStreamer, TLS modules, WebKit child processes and libmpv
must belong to the same installed distribution stack. There is no WPE source
builder, restored browser SDK, older WebKit fallback or private GTK/media stack.
The AppImage remains available as a thin app package; it is not self-contained.
GTK and the core desktop libraries are needed to start Flutter. WebKitGTK,
libmpv and Poppler are optional attachment features: their absence must not
prevent signing in, reading or sending messages, or opening ordinary settings.
The runner loads the real WebKit and media plugins only when a feature is used.
Both plugins still ship in the app package; their system runtime libraries do not.

### Installing optional features

Settings → Desktop → System dependencies shows known feature status. Opening
an affected attachment checks that feature and offers the appropriate install
command when its runtime is missing. Raft copies commands for the user to run;
it does not obtain administrator access or install system packages itself.

| Feature | Ubuntu 24.04 | Fedora 44 |
|---|---|---|
| Interactive HTML | `sudo apt-get install libwebkit2gtk-4.1-0` | `sudo dnf install webkit2gtk4.1` |
| Audio/video | `sudo apt-get install libmpv2` | `sudo dnf install mpv-libs` |
| PDF | `sudo apt-get install poppler-utils` | `sudo dnf install poppler-utils` |

Install through the distribution's trusted package manager, then choose Check
again. Failed checks are retried; an earlier missing-library result does not
require restarting Raft. Installing an ABI-incompatible library, a broken driver
or unsupported codec can still fail an actual preview or playback operation.
No installation popup blocks application startup. Other distributions receive
generic package-manager guidance rather than an unverified command.

Without WebKit, the HTML attachment keeps its bounded static text preview and
browser/download actions. Interactive scripts and HTML region selection need
WebKitGTK API4.1; GTK alone, API4.0, or GTK4's API6.0 does not provide it. Missing
mpv affects playback and frame extraction; missing Poppler affects PDF previews.

Ubuntu 24.04 x86-64 and Fedora 44 are the declared runtime targets. Install the
runtime prerequisites listed in [release CI](release-ci.md#linux-appimage),
including WebKitGTK4.1, libmpv, Secret Service client libraries, GStreamer plugins,
GLib networking and the SVG loader. Media formats depend on the installed
codecs. The display, audio, notification, Secret Service and graphics drivers
remain host services. Packaging does not install packages or alter a user profile.

PDF previews use Android's `PdfRenderer` and the distribution's Poppler
`pdfinfo`/`pdftoppm` on Linux (`poppler-utils`); no helper is downloaded silently
when a preview opens. The CI extract gate still converts a real colored PDF page,
and decodes a known SVG through system GdkPixbuf with a pixel oracle. System GIO
must spawn a harmless child with the original host environment.

Video is streamed: the decoder receives the attachment's signed `http(s)` URL through `loadfile` and reads it itself (bounded in-memory read-ahead, `cache-on-disk=no`; nothing is saved except by the Download action), through the app's proxy decision (`http-proxy`, set at run time). The protocol whitelist is the fixed `file, http, https, tcp, tls, crypto` (`proxy_hook_guard_test`); network references, automatic extra audio/subtitle files, scripts and yt-dlp stay disabled, and the player does not autoplay. A 401/403/410 from the host triggers one fresh signature (`AttachmentSource.refresh`). Closing, logout, authority loss and backgrounding stop playback; the player is disposed with its last holder ([streaming and sessions](media-playback.md#streaming-and-sessions)). No signed URL enters the persistent application cache. A local file (the audio viewer's cached copy) is still opened with the `file` protocol.

## Packaging and evidence

`tool/release.py` stages the normal production entry. Its thin inventory allows
only the app, pinned Flutter engine, app plugins, Dart SQLite native asset and
the exact `lib/raft-webview/libraft_system_webview_extension.so` app adapter.
That small module observes native WebKit events through system APIs; it is not
a browser engine and does not carry a private WebKit/GTK library. A package with
the native WebView plugin but without this matching module is rejected. The video
plugin must link the system `libmpv.so.2`; a stub build is rejected, and the HTML
plugin must link `libwebkit2gtk-4.1.so.0`.
That private `libsqlite3.so` has no SONAME; system `libsqlite3.so.0`, GTK, GLib,
WebKit, libmpv, private loaders and obsolete browser plugins are rejected.

Each application ELF gets a relative `DT_RUNPATH` (`$ORIGIN/lib` for the app,
`$ORIGIN` for plugins, `$ORIGIN/..` for the WebExtension). No transitive `DT_RPATH` or process-wide library override
selects a second system ABI. Dependencies must resolve in the app or distribution
library directories; missing libraries and an AppImage GLIBC requirement newer
than 2.39 stop packaging. The launcher keeps host module paths unchanged and
preserves unset/empty host values for the Dart child-process sanitizer. Before
starting the app it checks the runner and core app-owned shared modules for
missing distribution dependencies. The exact optional WebKit/media backend
modules and WebExtension are excluded from this startup rejection; their full
ELF dependencies are still checked when building the package. The launcher must
continue to reject a missing core library or an unexpected plugin dependency.

The staging directory includes `linux-dependency-checks.json` and
`linux-system-runtime.json`, with the app-private inventory, required external
SONAMEs, distribution prerequisites and explicit native-acceptance scope. These
receipts describe build-host lookup; they do not establish login, HTML, playback,
PDF or another distribution's runtime success. The four published AppImage gates
remain Ubuntu direct/extract and Fedora X11/native Wayland at 2× display scale.
Signatures, update metadata, no-clobber publication and source/build identity
checks remain independent release requirements.

The optional-runtime acceptance tools distinguish environment/startup results
from user-flow results. A container with all features installed cannot prove
missing-dependency behavior. The matching absence must be established through
both package-manager state and dynamic loading, followed by actual application
input and data readback. Recovery must retain the original application process;
a fresh launch with newly installed packages does not prove in-process retry.

Run an extracted Linux package through `./run-raft`. An AppImage uses its normal
AppRun entry, directly or with `--appimage-extract-and-run` when FUSE is unavailable.
Keep the full directory together. An old private-engine release tag cannot be
rebuilt as the new runtime under the old source identity; its assets remain
untouched, and the new system runtime needs its own source/tag.
