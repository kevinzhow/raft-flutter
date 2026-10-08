#!/usr/bin/env bash
# Flutter Linux desktop captures for docs/desktop-cases.json (provider android,
# source flutter-linux). Usage: tool/desktop-parity/capture-flutter.sh [only-substr,...]
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
out="${RAFT_DESKTOP_RESULTS:-$root/.local/desktop-parity/visual-testing-results}"
mkdir -p "$out"
cd "$root/apps/raft_flutter"
runner=(xvfb-run -a -s "-screen 0 1920x1200x24")
[ -n "${DISPLAY:-}" ] && runner=()
"${runner[@]}" "$root/tool/flutter" test integration_test/desktop_screens_test.dart -d linux --no-pub \
  --dart-define=RAFT_DESKTOP_FIXTURE="$root/tool/desktop-parity/desktop-fixture.json" \
  --dart-define=RAFT_DESKTOP_CASES="$root/docs/desktop-cases.json" \
  --dart-define=RAFT_DESKTOP_OUT="$out" \
  --dart-define=RAFT_DESKTOP_ONLY="${1:-}"
