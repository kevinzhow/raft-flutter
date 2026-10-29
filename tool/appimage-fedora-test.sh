#!/bin/bash
# Disposable Fedora container only; no FUSE device, host data, or graphics drivers are mounted.
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true ]] || [[ -e /dev/fuse ]]; then
  echo 'Expected a disposable CI container without /dev/fuse' >&2
  exit 1
fi
dnf install -y python3 dbus-daemon dbus-tools gnome-keyring xorg-x11-server-Xvfb xwininfo ImageMagick \
  kwin-wayland libkscreen mesa-dri-drivers mesa-libEGL mesa-libGL libglvnd-egl libglvnd-glx \
  fontconfig freetype harfbuzz libwayland-client alsa-lib pipewire-libs libstdc++
artifact=$(find /artifacts -maxdepth 1 -name '*.AppImage' -print -quit)
if [[ -z "$artifact" ]]; then exit 1; fi
mkdir -p /evidence/fedora
# Execute the released file via its no-FUSE runtime path on a different distribution.
xvfb-run -a -s '-screen 0 2880x1800x24' dbus-run-session -- \
  python3 /source/tool/appimage-smoke.py --artifact "$artifact" --output /evidence/fedora --mode extract
# Run the same production binary under KDE's native Wayland compositor.
export XDG_RUNTIME_DIR
XDG_RUNTIME_DIR=$(mktemp -d)
chmod 700 "$XDG_RUNTIME_DIR"
export RAFT_APPIMAGE="$artifact"
xvfb-run -a -s '-screen 0 3200x2000x24' dbus-run-session -- bash -euo pipefail -c '
  export QT_QPA_PLATFORM=offscreen LIBGL_ALWAYS_SOFTWARE=1 KWIN_COMPOSE=O2 XDG_CURRENT_DESKTOP=KDE KDE_SESSION_VERSION=6
  kwin_wayland --x11-display "$DISPLAY" --no-lockscreen --no-global-shortcuts --width 2880 --height 1800 --socket wayland-raft > /evidence/fedora/kwin.log 2>&1 &
  compositor=$!
  trap "kill $compositor 2>/dev/null || true" EXIT
  for i in $(seq 1 120); do
    if [[ -S "$XDG_RUNTIME_DIR/wayland-raft" ]]; then break; fi
    kill -0 "$compositor"
    sleep 0.25
  done
  test -S "$XDG_RUNTIME_DIR/wayland-raft"
  export WAYLAND_DISPLAY=wayland-raft XDG_SESSION_TYPE=wayland
  unset QT_QPA_PLATFORM
  dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP KDE_SESSION_VERSION XDG_SESSION_TYPE
  gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.supportInformation > /evidence/fedora/kwin-support.txt
  QT_QPA_PLATFORM=wayland kscreen-doctor output.1.scale.2 > /evidence/fedora/output-scale.log 2>&1
  QT_QPA_PLATFORM=wayland kscreen-doctor -o >> /evidence/fedora/output-scale.log 2>&1
  xwininfo -root -tree > /evidence/fedora/nested-compositor-windows.txt
  python3 /source/tool/appimage-smoke.py --artifact "$RAFT_APPIMAGE" --output /evidence/fedora --mode wayland
'
