# Linux desktop integration

Two Linux-only behaviours. Neither touches other platforms.

## Message notifications

Linux follows the macOS desktop rules (`DesktopInboxNotifications`): DMs,
mentions and followed-thread replies from the same accepted Activity inbox,
filtered by the member's server notification mode (`all` / `mentions` /
muted). Nothing is shown while the window is focused (`AppLifecycleState.resumed`);
an unfocused window gets the alert. The notification daemon owns Do Not Disturb
and per-app settings (the Settings card says "Managed by the system"; there is
no app-owned switch).

Delivery is `org.freedesktop.Notifications` through
`flutter_local_notifications_linux`; it works on KDE and GNOME, inside an
AppImage, and needs no portal.

- One notification per conversation (channel, DM or thread): a newer message
  replaces the previous banner (`replaces_id`), so a busy channel never stacks.
- Icon: `data/icons/hicolor/256x256/apps/app.raft.raft_flutter.png` in the
  bundle (or the copy an AppImage installs); hints `category=im.received`,
  `desktop-entry=<launcher id>`.
- Body text is XML-escaped when the daemon advertises `body-markup`.
- Click: the default action opens the conversation through the navigation
  registry and raises the window. When the daemon sends the spec 1.3
  `ActivationToken` signal, the token is passed to the runner, which hands it to
  GTK (xdg-activation on Wayland, startup id on X11) so KWin and Wayland
  compositors allow the focus change.

Manual check on a private bus, never the member's own:

    tool/linux-notify-daemon.py --log notify.jsonl &      # fake daemon
    raft_flutter --linux-notification-test                # posts a test alert and, on every focus change, sample message alerts
    gdbus call --session --dest org.raft.FakeNotifyd --object-path /control \
        --method org.raft.FakeNotifyd.Click <id>          # or ClickWithToken <id> <token>

The app prints `raft-probe ...` lines (lifecycle, tap payload, activation token)
to stderr in this mode.

## `raft://` links from an AppImage

An AppImage installs nothing, so `xdg-open raft://v1/join/...` has no handler.
When `APPIMAGE` is set the app (after the first frame) maintains
`$XDG_DATA_HOME/applications/app.raft.raft_flutter-appimage.desktop`
(`Exec="<APPIMAGE>" %u`, `MimeType=x-scheme-handler/raft;`) and the icon under
`$XDG_DATA_HOME/icons/hicolor/256x256/apps/`, then runs
`xdg-mime default ...` and `update-desktop-database`.

- It takes the scheme only if no handler is set or the handler is this launcher
  (any image path; a moved AppImage rewrites the file). Another handler, a
  packaged `app.raft.raft_flutter.desktop` included, is left alone; Settings >
  Desktop shows a one-time "Use Raft / Keep it" prompt.
- Settings > Desktop (AppImage only) has the "Open raft:// links with this app"
  switch. Off removes the launcher and our entries in `mimeapps.list` and is
  remembered; a native install is never touched.
- Host programs run with a cleaned environment (`linux_host_env.dart`): values
  AppRun saved as `RAFT_APPIMAGE_HOST_<NAME>` / `_SET` are restored, then
  `RAFT_APPIMAGE_HOST_*`, `APPDIR`, `APPIMAGE`, `ARGV0` and `OWD` are removed.
  Older AppRuns without the exports lose the image variables and `$APPDIR`
  path entries instead.
- A second launch with a `raft://` argument is forwarded by GApplication to the
  running instance.

Generic `xdg-open` (no desktop environment) cannot start a launcher whose
`Exec` path contains spaces; KDE and GNOME openers can.
