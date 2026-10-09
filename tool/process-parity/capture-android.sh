#!/usr/bin/env bash
# The caller owns the Android device and isolated fixture runtime.
set -euo pipefail
if [ "$#" -ne 5 ]; then
  echo 'capture-android.sh FIXTURE NEW_HOST_OUTPUT THEME desktop|mobile DEVICE' >&2
  exit 2
fi
root="$(cd "$(dirname "$0")/../.." && pwd)"
fixture="$(realpath "$1")"
out="$(realpath -m "$2")"
theme="$3"
form="$4"
device="$5"
port="${RAFT_PROCESS_PORT:-15413}"
base="http://127.0.0.1:$port"
if [ -e "$out" ]; then
  echo "Refusing to overwrite Android evidence: $out" >&2
  exit 2
fi
fixture_sha="$(sha256sum "$fixture" | cut -d' ' -f1)"
product_sha="$(python3 "$root/tool/process-parity/product-hash.py")"
test_sha="$(python3 "$root/tool/process-parity/test-hash.py")"
python3 - "$base" "$fixture_sha" <<'PY'
import hashlib,sys,urllib.request
with urllib.request.urlopen(sys.argv[1]+'/__process/fixture') as response:
    data=response.read()
if hashlib.sha256(data).hexdigest()!=sys.argv[2]:
    raise SystemExit('Owned fixture server bytes differ from declared fixture')
PY
mkdir -p "$out"
cache_name="raft-process-$(date -u +%Y%m%dT%H%M%S)-$$"
python3 - "$out" "$cache_name" "$device" "$fixture_sha" "$product_sha" "$test_sha" "$port" <<'PY'
import json,sys,pathlib
pathlib.Path(sys.argv[1],'inputs.json').write_text(json.dumps(dict(zip(
 ['cacheName','device','fixtureSha','productSha','testSha','port'],sys.argv[2:])),indent=2)+'\n')
PY
python3 - "$base" "$cache_name" "$device" "$fixture_sha" "$product_sha" "$test_sha" <<'PYREG'
import json,sys,urllib.request
base,run,device,fixture,product,test=sys.argv[1:]
payload=dict(run=run,device=device,fixtureSha=fixture,productSha=product,testSha=test,platform='android')
request=urllib.request.Request(base+'/__process/artifacts/register',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'},method='POST')
with urllib.request.urlopen(request,timeout=15) as response:
    receipt=json.load(response)
if not receipt.get('registered') or receipt.get('run')!=run:
    raise SystemExit('Current Android run registration failed')
PYREG
adb -s "$device" reverse "tcp:$port" "tcp:$port"
cd "$root/apps/raft_flutter"
set +e
"$root/tool/flutter" test integration_test/process_activity_target_test.dart -d "$device" --no-pub \
  --dart-define=RAFT_PROCESS_OUT="$cache_name" \
  --dart-define=RAFT_PROCESS_BASE="$base" \
  --dart-define=RAFT_PROCESS_THEME="$theme" \
  --dart-define=RAFT_PROCESS_FORM="$form" \
  --dart-define=RAFT_PROCESS_DEVICE="$device" \
  --dart-define=RAFT_PROCESS_FIXTURE_SHA="$fixture_sha" \
  --dart-define=RAFT_PROCESS_PRODUCT_SHA="$product_sha" \
  --dart-define=RAFT_PROCESS_TEST_SHA="$test_sha" > "$out/native.log" 2>&1
native_status=$?
python3 "$root/tool/process-parity/collect-android-artifacts.py" "$base" "$cache_name" "$out" > "$out/readback.log" 2>&1
readback_status=$?
set -e
python3 - "$out" "$native_status" "$readback_status" <<'PY'
import json,sys,pathlib
pathlib.Path(sys.argv[1],'run.json').write_text(json.dumps({
 'provider':'actual Android integration; pre-teardown validated host handoff',
 'nativeExit':int(sys.argv[2]),'readbackExit':int(sys.argv[3]),
 'result':'PASS' if sys.argv[2:]==['0','0'] else 'FAIL'},indent=2)+'\n')
PY
if [ "$native_status" -ne 0 ]; then exit "$native_status"; fi
exit "$readback_status"
