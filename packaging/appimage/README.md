# Thin AppImage runtime policy

The AppImage ships only Raft, the pinned Flutter engine, app plugins and the
Dart SQLite native asset. GTK3, WebKitGTK API 4.1, GLib/GIO, Pango, GdkPixbuf,
libsoup3, GStreamer, TLS modules, libmpv and Poppler come from the distribution.
There is no WPE source builder, private browser SDK, bundled GTK/media closure,
private module cache or older WebKit API fallback.

`tool/linux_system_runtime.py` defines the closed library inventory and runtime
receipt. The Dart SQLite asset `libsqlite3.so` has no SONAME; a system
`libsqlite3.so.0` is forbidden. Every packaged ELF receives only an app-local
`DT_RUNPATH`, then resolves against the bundle or distribution directories.
`DT_RPATH`, `LD_LIBRARY_PATH`, `LD_PRELOAD` and private GIO/GStreamer/GdkPixbuf
module paths are not used to mix a second system ABI into WebKit.

Ubuntu 24.04 x86-64 and Fedora 44 are the declared runtime targets. Install the
explicit runtime packages in `docs/release-ci.md`; the AppImage is not a
self-contained substitute for those packages. Startup, SVG decoding, GIO child
launch, PDF rendering and X11/Wayland gates must run against those system
libraries. Packaging and static receipts alone do not establish native success.

AppRun keeps host environment values unchanged. It exports read-only
`RAFT_APPIMAGE_HOST_*` snapshots for the existing Dart host-child sanitizer,
including unset/empty markers, without selecting another launcher or cache.

The tools lock retains the reviewed official appimagetool/type2-runtime snapshots,
source metadata and SHA-256 checks. The runtime license is shipped. Normal FUSE3,
no-FUSE extract-and-run, Ed25519 update signatures, zsync source binding and
release no-clobber gates remain required. An old private-engine tag is rejected
before AppImage backfill setup; changing the runtime requires a new source/tag.
