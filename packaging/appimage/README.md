# AppImage tooling and host library policy

The tools lock records the latest official release assets reviewed on 2026-10-12.
Downloads must match the recorded SHA-256. AppImageKit's obsolete appimagetool is
not used. The current type2-runtime has static FUSE 3 and extract-and-run support.

`excludelist` is vendored unchanged from
https://github.com/AppImage/pkg2appimage/blob/19e30b276ffedf4d3b4b56bc6320f463625a74f8/excludelist.
Its rationale comments are retained. The optional JACK client is an explicit
exception: Ubuntu libmpv/libavdevice link it, while a KDE desktop may not have it.
GLES and Vulkan device loaders are additionally kept on the host. This keeps libc/device/display/font libraries
on the host and bundles the remaining GTK and media dependencies together.

The shipped runtime's MIT license and source snapshot metadata accompany the
payload. All copied distribution libraries and PDF commands carry their own
copyright notices, source package versions and digests in data/notices/raft-media.

The matching Ubuntu GLib desktop launcher is included under raft/bin and
AppRun selects a small wrapper through GIO_LAUNCH_DESKTOP using the current
AppImage mount path. Before launching external applications, the wrapper restores
the original PATH, LD_LIBRARY_PATH, GIO_MODULE_DIR and GSETTINGS_SCHEMA_DIR, including
whether each variable was unset or explicitly empty. An explicitly supplied desktop
helper override remains supported through that wrapper. This removes the
Ubuntu-only build-time helper path that failed on Fedora KDE. The helper has
its own package source, copyright and digest receipt like the PDF commands.

If GTK_IM_MODULE_FILE was not supplied, AppRun selects a readable host GTK3
input-method cache from Fedora, Debian/Ubuntu or Arch-style library directories.
The installed IBus/Fcitx bridge and its desktop daemon remain host services. An
explicit cache selection is preserved. This fixes the Ubuntu cache prefix failing
to discover the installed IBus module on Fedora; actual language composition still
needs platform acceptance. Desktop children recover the original cache variable too.
