#!/usr/bin/env bash
# Idle CPU / frames-per-second lab on the Linux desktop (Xvfb when no DISPLAY).
#   tool/idle-cpu/run.sh <label> [seconds] [only,scenarios]
# Writes $RAFT_IDLE_OUT/<label>.json (default /tmp/idle-cpu). See
# apps/raft_flutter/tool/idle_cpu_lab.dart.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
label="${1:-run}"; secs="${2:-30}"; only="${3:-}"
out="${RAFT_IDLE_OUT:-/tmp/idle-cpu}"
mkdir -p "$out"
cd "$root/apps/raft_flutter"
runner=(xvfb-run -a -s "-screen 0 1920x1200x24")
[ -n "${DISPLAY:-}" ] && runner=()
export RAFT_IDLE_FIXTURE="$root/tool/desktop-parity/desktop-fixture.json"
export RAFT_IDLE_OUT="$out/$label.json" RAFT_IDLE_LABEL="$label" RAFT_IDLE_SECONDS="$secs" RAFT_IDLE_ONLY="$only"
# A plain profile app: flutter_test bindings re-schedule a frame after every
# frame and would hide the bug class being measured.
"$root/tool/flutter" build linux --profile --no-pub -t tool/idle_cpu_lab.dart
bundle=build/linux/x64/profile/bundle
"${runner[@]}" "$bundle/raft_flutter" 2>&1 | tee "$out/$label.log" | grep --line-buffered IDLELAB
