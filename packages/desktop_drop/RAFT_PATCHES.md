# Raft local changes

This is the published `desktop_drop` 0.8.4 source (Apache-2.0, see `LICENSE`), vendored so Linux drops survive a dead file-portal key. `UPSTREAM.json` preserves the archive SHA-256 and the original file hashes; the `example/` directory is omitted. The Dart API and MethodChannel (`desktop_drop`) stay compatible; a Raft change is marked `RAFT PATCH` in the source. macOS, Windows, Android and Web code is unchanged.

## Why

On Linux (KDE Plasma Wayland with Dolphin, seen in the AppImage) a drop failed with `desktop_drop: failed to resolve portal transfer: org.freedesktop.DBus.Error.AccessDenied: Invalid transfer` and attached nothing. Upstream 0.8.1+ registers `application/vnd.portal.filetransfer` and GTK, with `GTK_DEST_DEFAULT_DROP`, asks the source for exactly one target. When the source offers the portal key, that target wins even if `text/uri-list` is also offered (the real-GTK run in `e2e/` reproduces this for both offer orders). Dart then calls `org.freedesktop.portal.FileTransfer.RetrieveFiles`. xdg-desktop-portal answers AccessDenied "Invalid transfer" for any key it does not hold: a key that was already retrieved (transfers autostop after the first `RetrieveFiles`), stopped by the source, or dropped when the source disconnected. The plugin swallowed the error and returned no files; it never fell back to the URI list.

## Changes

- `linux/desktop_drop_plugin.cc`: drop the `GTK_DEST_DEFAULT_DROP` flag and handle `drag-drop` ourselves. All offered targets of the same drag are read in turn (`text/uri-list`, the portal key, then `STRING` only when neither gave data) before `gtk_drag_finish`. When a file target was read the plugin sends the new `performOperation_linux_sources` message `[uriText, portalKey, point]`; a text-only drag keeps `performOperation_linux`. `on_drag_motion` now returns `FALSE` explicitly (it was declared `void` for a `gboolean` signal, so GTK read an undefined value).
- `lib/src/channel.dart`: `resolveLinuxDrop` decides which source to use. Outside a Flatpak it takes the `file://` paths of the URI list when they exist and asks the portal only when none is readable. Inside a Flatpak (`FLATPAK_ID` or `/.flatpak-info`) it asks the portal first. The other source is the fallback in both cases. Portal failures are no longer swallowed silently inside the resolver; they fall back and are logged with `debugPrint`. `DropDoneEvent.error` (and `DropDoneDetails.error`) is set only when the drag offered files and nothing could be read, so the app can show a message. `performOperation_portal` (old native builds) goes through the same logic.
- `lib/src/events.dart`, `lib/src/drop_target.dart`: carry `error`.
- `test/channel_linux_test.dart`: resolution cases with a fake resolver, plus a fake `org.freedesktop.portal.Documents` on a private session bus (one-shot keys, real AccessDenied). The bus tests run only with `DESKTOP_DROP_PRIVATE_BUS=1 dbus-run-session -- flutter test test/channel_linux_test.dart`; they claim a well-known name and must never run on a real session bus.
- `pubspec.yaml`: `publish_to: none`, workspace SDK constraint. `analysis_options.yaml` is rewritten by the Flutter tool to exclude platform directories.
- `e2e/`: real GTK/X11 drag-and-drop harness (Xvfb, XTest pointer, a GTK drag source with configurable targets, a fake portal on a private bus). See `e2e/run.sh`.

Raft's composer (`apps/raft_flutter/lib/features/composer_attachment_input.dart`) shows "Couldn't read dropped files" when `error` is set.

Moving back to the hosted package needs an upstream release with the same behavior; 0.8.4 is the latest as of 2026-10-12.
