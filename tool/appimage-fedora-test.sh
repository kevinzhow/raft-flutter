#!/bin/bash
# Disposable Fedora container only; no FUSE device, host data, or graphics drivers are mounted.
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true ]] || [[ -e /dev/fuse ]]; then
  echo 'Expected a disposable CI container without /dev/fuse' >&2
  exit 1
fi
# Select one coherent official release-repository dependency transaction.
# This KDE compatibility floor does not freeze the container's core packages.
mkdir -p /evidence/fedora
dnf --repo=fedora --setopt=allow_downgrade=False install -y python3 dbus-daemon dbus-tools gnome-keyring xorg-x11-server-Xvfb xwininfo ImageMagick \
  kwin-wayland libkscreen mesa-dri-drivers mesa-libEGL mesa-libGL libglvnd-egl libglvnd-glx \
  fontconfig freetype harfbuzz libwayland-client alsa-lib pipewire-libs libstdc++
rpm -q --qf '%{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' \
  kwin kwin-common kwin-libs libkscreen qt6-qtbase xorg-x11-server-Xvfb \
  | tee /evidence/fedora/kde-package-versions.txt
kwin_version=$(rpm -q --qf '%{VERSION}' kwin)
qtbase_version=$(rpm -q --qf '%{VERSION}' qt6-qtbase)
if [[ "$kwin_version" != 6.6.4 || "$qtbase_version" != 6.10.2 ]]; then
  echo "Expected Fedora 44 release-repository KWin 6.6.4 / Qt 6.10.2; got $kwin_version / $qtbase_version" >&2
  exit 1
fi
artifact=$(find /artifacts -maxdepth 1 -name '*.AppImage' -print -quit)
if [[ -z "$artifact" ]]; then exit 1; fi
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
