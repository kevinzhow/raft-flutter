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
  python3 /source/tool/appimage-wayland-smoke.py --artifact "$RAFT_APPIMAGE" --output /evidence/fedora
'
