#!/bin/bash
# Real GTK/X11 drag-and-drop E2E for the patched desktop_drop Linux plugin.
# Needs Xvfb, dbus-run-session, python3-gi and libXtst. The probe app is a
# stock `flutter create --platforms=linux` project whose lib/main.dart is
# probe_main.dart and that depends on this package by path.
# It owns its Xvfb (:97) and a private session bus (no portal activation).
HERE=$(cd "$(dirname "$0")" && pwd); export HERE
# usage: run.sh <probe-bundle> <OFFER> <KEY>   (own Xvfb + private session bus; kills only its own PIDs)
BUNDLE=$1; export OFFER=$2 KEY=$3
export NO_AT_BRIDGE=1 GTK_USE_PORTAL=0 GDK_BACKEND=x11 DISPLAY=:97 PROBE_OUT=/tmp/out.$$.jsonl
Xvfb :97 -screen 0 1920x1080x24 >/dev/null 2>&1 & XPID=$!
sleep 1.5
exec_inner() {
  "$BUNDLE/dropprobe" >/tmp/app.$$.log 2>&1 & APID=$!
  for i in $(seq 40); do grep -q ready $PROBE_OUT 2>/dev/null && break; sleep 0.5; done
  sleep 1.5
  python3 $HERE/source.py 2>/dev/null
  sleep 1.5
  kill $APID 2>/dev/null
}
export -f exec_inner
RES=$(env HERE="$HERE" BUNDLE="$BUNDLE" PROBE_OUT=$PROBE_OUT dbus-run-session --config-file=$HERE/bus.conf -- bash -c exec_inner)
kill $XPID 2>/dev/null
echo "OFFER=$OFFER KEY=$KEY portal:$RES"
grep -v ready $PROBE_OUT
grep -h "desktop_drop" /tmp/app.$$.log | head -3
