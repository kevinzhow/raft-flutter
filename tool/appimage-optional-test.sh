#!/bin/bash
# Disposable missing-library acceptance only. Never run this on a developer host.
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true || ! -f /.dockerenv || -e /dev/fuse ]]; then
  echo 'Expected a disposable CI Docker container without /dev/fuse' >&2
  exit 1
fi
restore_only=false
provision_only=false
run_only=false
case "${1:-}" in
  --restore-only) restore_only=true; shift;;
  --provision-only) provision_only=true; shift;;
  --run-only) run_only=true; shift;;
esac
distribution=${1:?ubuntu or fedora required}
source /etc/os-release
if [[ "$ID:$VERSION_ID:$distribution" != ubuntu:24.04:ubuntu && "$ID:$VERSION_ID:$distribution" != fedora:44:fedora ]]; then
  echo 'Expected the declared Ubuntu 24.04 or Fedora 44 runtime' >&2
  exit 1
fi
if $restore_only; then
  if [[ "$distribution" == ubuntu ]]; then
    apt-get -o Dir::Cache::archives=/opt/raft-optional-recovery-debs \
      -o Binary::apt-get::APT::Keep-Downloaded-Packages=true --no-download \
      install -y --no-install-recommends libwebkit2gtk-4.1-0 libmpv2 poppler-utils
  else
    shopt -s nullglob
    optional_archives=(/var/cache/raft-optional-rpms/*.x86_64.rpm /var/cache/raft-optional-rpms/*.noarch.rpm)
    if [[ ${#optional_archives[@]} -eq 0 ]]; then
      echo 'No x86_64/noarch offline recovery packages were cached' >&2
      exit 1
    fi
    dnf --disablerepo='*' --setopt=allow_downgrade=True --setopt=localpkg_gpgcheck=True \
      install -y "${optional_archives[@]}"
  fi
  exit
fi
scenario=${2:?scenario required}
case "$scenario" in missing-webkit|missing-mpv|missing-both|restored) ;; *) exit 2;; esac
mkdir -p /evidence
# Keep test tools and the GTK/display/keyring baseline distinct from feature
# runtimes. Nothing below removes/masks files to simulate a missing library.
if ! $run_only; then
if [[ "$distribution" == ubuntu ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends python3 nodejs npm binutils dbus-x11 gnome-keyring \
    xvfb xauth x11-utils xdotool imagemagick tesseract-ocr libgtk-3-0t64 libsecret-1-0 librsvg2-common \
    libgl1-mesa-dri libegl1 libglx-mesa0 sudo passwd util-linux
  # Cache the complete recovery transaction before the driver starts. Restoring
  # after the first failed ensure uses --no-download, never changes host policy.
  mkdir -p /opt/raft-optional-recovery-debs/partial
  apt-get -o Dir::Cache::archives=/opt/raft-optional-recovery-debs \
    -o Binary::apt-get::APT::Keep-Downloaded-Packages=true --download-only \
    install -y --no-install-recommends libwebkit2gtk-4.1-0 libmpv2 poppler-utils
  case "$scenario" in
    missing-webkit) apt-get -o Dir::Cache::archives=/opt/raft-optional-recovery-debs \
      -o Binary::apt-get::APT::Keep-Downloaded-Packages=true --no-download install -y --no-install-recommends libmpv2;;
    missing-mpv) apt-get -o Dir::Cache::archives=/opt/raft-optional-recovery-debs \
      -o Binary::apt-get::APT::Keep-Downloaded-Packages=true --no-download install -y --no-install-recommends libwebkit2gtk-4.1-0;;
    restored) bash "$0" --restore-only "$distribution";;
  esac
  dpkg-query -W -f='${binary:Package} ${Version} ${Status}\n' > "/evidence/$scenario-packages-before.txt"
else
  dnf --repo=fedora --setopt=allow_downgrade=True install -y python3 nodejs npm binutils dbus-daemon dbus-tools \
    gnome-keyring xorg-x11-server-Xvfb xorg-x11-xauth xwininfo xdotool ImageMagick tesseract \
    gtk3 libsecret librsvg2 mesa-dri-drivers mesa-libEGL mesa-libGL sudo shadow-utils util-linux
  mkdir -p /var/cache/raft-optional-rpms
  # `download`, unlike transaction --downloadonly, persists these files across
  # subsequent installs. Installed core dependencies stay frozen in this image.
  dnf --repo=fedora download --resolve --arch=x86_64,noarch --destdir=/var/cache/raft-optional-rpms \
    webkit2gtk4.1 mpv-libs poppler-utils
  case "$scenario" in
    missing-webkit) dnf --repo=fedora --setopt=allow_downgrade=True install -y mpv-libs;;
    missing-mpv) dnf --repo=fedora --setopt=allow_downgrade=True install -y webkit2gtk4.1;;
    restored) bash "$0" --restore-only "$distribution";;
  esac
  rpm -qa --qf '%{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' > "/evidence/$scenario-packages-before.txt"
fi
  # Pre-resolve only the locked, synthetic loopback fixture; no npm operation
  # is needed after the runtime is started with networking disabled.
  mkdir -p /opt/raft-optional-fixture
  cp /source/tool/linux_optional_fixture/package.json /source/tool/linux_optional_fixture/package-lock.json /opt/raft-optional-fixture/
  npm ci --ignore-scripts --prefix /opt/raft-optional-fixture
  useradd --create-home --uid 20001 raft-optional-qa
  printf '%s\n' 'Defaults:raft-optional-qa env_keep += "GITHUB_ACTIONS"' \
    "raft-optional-qa ALL=(root) NOPASSWD: /bin/bash /source/tool/appimage-optional-test.sh --restore-only $distribution" \
    > /etc/sudoers.d/raft-optional-restore
  chmod 440 /etc/sudoers.d/raft-optional-restore
  visudo -cf /etc/sudoers.d/raft-optional-restore
fi
if $provision_only; then exit; fi
artifact=$(find /artifacts -maxdepth 1 -name '*.AppImage' -print -quit)
[[ -n "$artifact" ]] || exit 1
restore_command=$(python3 -c 'import json,sys; print(json.dumps(["sudo","-n","/bin/bash",sys.argv[1],"--restore-only",sys.argv[2]]))' "/source/tool/appimage-optional-test.sh" "$distribution")
driver=()
if [[ -n "${RAFT_OPTIONAL_NATIVE_DRIVER:-}" ]]; then
  driver=(--driver "$RAFT_OPTIONAL_NATIVE_DRIVER")
fi
# The native driver owns its loopback fixture and private XDG configuration.
# This boundary never accesses the developer's account, display or keyring.
[[ ! -e "/evidence/$scenario" ]] || { echo 'Refusing to overwrite a prior runtime case' >&2; exit 1; }
qa_root=$(mktemp -d /tmp/raft-optional-qa.XXXXXX)
chown raft-optional-qa:raft-optional-qa "$qa_root"
# Export only newly created evidence on exit; preserve failures too. Do not
# chown or modify the mounted source/artifact/host evidence directories.
trap 'case_exit=$?; if [[ -d "$qa_root/$scenario" ]]; then cp -R --no-preserve=ownership "$qa_root/$scenario" /evidence/ || case_exit=1; fi; exit "$case_exit"' EXIT
if [[ "$distribution" == ubuntu ]]; then
  dpkg-query -W -f='${binary:Package} ${Version} ${Status}\n' > "/evidence/$scenario-packages-runtime.txt"
else
  rpm -qa --qf '%{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}.%{ARCH}\n' > "/evidence/$scenario-packages-runtime.txt"
fi
install -d -m 700 -o raft-optional-qa -g raft-optional-qa "$qa_root/runtime"
runuser -u raft-optional-qa -- env HOME=/home/raft-optional-qa XDG_RUNTIME_DIR="$qa_root/runtime" \
  RAFT_OPTIONAL_FIXTURE_NODE_PATH=/opt/raft-optional-fixture/node_modules \
  xvfb-run -a -s '-screen 0 2880x1800x24' dbus-run-session -- \
  python3 /source/tool/appimage-optional-runtime.py --artifact "$artifact" \
    --output "$qa_root/$scenario" --scenario "$scenario" \
    --restore-command-json "$restore_command" "${driver[@]}"
