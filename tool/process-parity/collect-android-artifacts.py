#!/usr/bin/env python3
"""Read only this freshly registered, already persisted host artifact receipt."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.request

base, run, host_output = sys.argv[1:]
out = Path(host_output)
inputs = json.loads((out/'inputs.json').read_text())
if inputs['cacheName'] != run:
    raise SystemExit('Current run differs from declared output')
with urllib.request.urlopen(base+'/__process/artifacts/'+run, timeout=15) as response:
    payload = json.load(response)
receipt, files = payload['receipt'], payload['files']
for key in ('fixtureSha', 'productSha', 'testSha', 'device'):
    if receipt[key] != inputs[key]:
        raise SystemExit('Persisted receipt differs from declared input: '+key)
if receipt['run'] != run or receipt['platform'] != 'android' or receipt['fileCount'] != len(files):
    raise SystemExit('Persisted run/platform/inventory mismatch')
if receipt['files'] != {name: item['sha256'] for name,item in files.items()}:
    raise SystemExit('Persisted receipt file map mismatch')
# Validate every file before creating a complete output directory.
buffers = {}
for name,item in files.items():
    if not re.fullmatch(r'(?:renderer-frames/)?[A-Za-z0-9][A-Za-z0-9._-]*\.(?:json|jsonl|png)', name) or '..' in name:
        raise SystemExit('Unsafe artifact path')
    data = base64.b64decode(item['base64'], validate=True)
    if hashlib.sha256(data).hexdigest() != item['sha256']:
        raise SystemExit('Persisted artifact bytes mismatch: '+name)
    buffers[name] = data
result = json.loads(buffers['result.json'])
for key in ('fixtureSha', 'productSha', 'testSha', 'device', 'platform', 'sourceInputSha', 'runtimeSha', 'result', 'rendererFrameCount'):
    if receipt[key] != result[key]:
        raise SystemExit('Result differs from persisted receipt: '+key)
renderer = json.loads(buffers['renderer-frames.json'])
expected = {'renderer-frames/'+row['file'] for row in renderer}
actual = {name for name in buffers if name.startswith('renderer-frames/') and name.endswith('.png')}
if expected != actual or len(renderer) != receipt['rendererFrameCount']:
    raise SystemExit('Persisted renderer inventory mismatch')
output = out/run
output.mkdir(exist_ok=False)
for name,data in buffers.items():
    path = output/name
    path.parent.mkdir(exist_ok=True)
    with path.open('xb') as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
(out/'handoff.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'run':run,'result':receipt['result'],'files':len(files),'rendererFrames':len(renderer)}))
