#!/usr/bin/env bash
# Isolated native renderer/test. The caller owns the fixture runtime and output.
set -euo pipefail
if [ "$#" -ne 4 ]; then
  echo 'capture-flutter.sh FIXTURE OUTPUT THEME desktop|mobile' >&2
  exit 2
fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(realpath "$1")"
out="$(realpath -m "$2")"
if [ -e "$out" ]; then
  echo "Refusing to overwrite process evidence: $out" >&2
  exit 2
fi
if [ ! -f "$root/.local/media-linux/bundle/libs/libmpv.so.2" ]; then
  echo 'Prepare this checkout media runtime with ./tool/prepare-media-linux first.' >&2
  exit 2
fi
requirement="$(python3 - "$fixture" <<'PYREQ'
import json,sys
print(json.load(open(sys.argv[1]))['process'].get('requirement','N24/channel-single'))
PYREQ
)"
cd "$root/apps/raft_flutter"
xvfb-run -a -s '-screen 0 1920x1200x24' "$root/tool/flutter" test integration_test/process_activity_target_test.dart -d linux --no-pub \
  --dart-define=RAFT_PROCESS_FIXTURE="$fixture" \
  --dart-define=RAFT_PROCESS_OUT="$out" \
  --dart-define=RAFT_PROCESS_BASE="${RAFT_PROCESS_BASE:-http://127.0.0.1:15413}" \
  --dart-define=RAFT_PROCESS_REQUIREMENT="$requirement" \
  --dart-define=RAFT_PROCESS_THEME="$3" \
  --dart-define=RAFT_PROCESS_FORM="$4"
