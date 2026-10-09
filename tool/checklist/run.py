#!/usr/bin/env python3
"""Run identified Flutter suites once and write immutable machine proof."""
import argparse
import datetime as dt
import hashlib
import json
import subprocess
from pathlib import Path
from evidence import LAYERS


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--suite', action='append', required=True, help='layer:path relative to app')
    args = parser.parse_args()
    root, out = args.root.resolve(), args.out.resolve()
    if out.exists():
        parser.error('Use a new output path; prior attempts are retained')
    app = root / 'apps/raft_flutter'
    layers = {}
    for value in args.suite:
        layer, path = value.split(':', 1)
        if layer not in LAYERS or not (app / path).is_file():
            parser.error(f'Unknown layer or missing suite: {value}')
        layers[str((app / path).resolve())] = layer
    stamp = lambda: subprocess.check_output([str(root / 'tool/source-hash')], text=True).strip()
    source_hash = stamp()
    out.mkdir(parents=True)
    command = [str(root / 'tool/flutter'), 'test', *layers, '--no-pub', '--machine']
    receipt = {'sourceHash': source_hash, 'flutterCommit': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'startedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
        'suiteLayers': layers, 'machineLog': 'tests.jsonl', 'command': command}
    (out / 'inputs.json').write_text(json.dumps(receipt, indent=2) + '\n')
    with (out / 'tests.jsonl').open('w') as log:
        completed = subprocess.run(command, cwd=app, stdout=log, stderr=subprocess.STDOUT)
    receipt.update(exitCode=completed.returncode, sourceUnchanged=stamp() == source_hash,
                   endedAt=dt.datetime.now(dt.timezone.utc).isoformat(),
                   machineLogSha=hashlib.sha256((out / 'tests.jsonl').read_bytes()).hexdigest())
    (out / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps({'exit': completed.returncode, 'sourceUnchanged': receipt['sourceUnchanged'],
                      'receipt': str(out / 'receipt.json')}))
    return completed.returncode if receipt['sourceUnchanged'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
