#!/usr/bin/env python3
"""Run Source App and native WorkspaceView with one immutable, gated fixture.

Every attempt receives a new directory. Local Linux integration uses an isolated
Xvfb display; callers must coordinate exclusive native integration ownership.
This runner proves only Activity -> uncached channel target, not all six flows.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / 'tool/process-parity'
THEMES = ('brutal', 'elegant-light', 'elegant-dark')
FORMS = ('desktop', 'mobile')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', required=True)
    p.add_argument('--only', default='brutal-desktop', help='comma separated theme-form, or all')
    p.add_argument('--source-only', action='store_true')
    p.add_argument('--port', type=int, default=15413)
    args = p.parse_args()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=False)
    cases = [(theme, form) for theme in THEMES for form in FORMS
             if args.only == 'all' or f'{theme}-{form}' in args.only.split(',')]
    if not cases:
        raise SystemExit('Selection matches no declared process cases')
    fixture = out / 'fixture.json'
    subprocess.run(['python3', str(TOOLS / 'build-fixture.py'), '--out', str(fixture)], check=True, cwd=ROOT)
    manifest = {'flow': 'activity-uncached-channel-target', 'fixtureSha': sha(fixture),
                'started': time.time(), 'sourceOnly': args.source_only,
                'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                'toolInputs': {str(path.relative_to(ROOT)): sha(path) for path in sorted(TOOLS.glob('*')) if path.is_file()},
                'cases': [], 'result': 'STARTED'}
    log = (out / 'runtime.log').open('w')
    runtime = subprocess.Popen(['node', str(TOOLS / 'fixture-runtime.mjs'), str(fixture), str(out / 'runtime'), str(args.port)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    base = f'http://127.0.0.1:{args.port}'
    def persist():
        (out / 'run.json').write_text(json.dumps(manifest, indent=2) + '\n')
    persist()
    try:
        for _ in range(200):
            if runtime.poll() is not None:
                raise RuntimeError('Owned fixture runtime exited before readiness')
            try:
                with urllib.request.urlopen(base + '/__process/state', timeout=.2) as response:
                    state = json.load(response)
                if state['fixtureSha'] != manifest['fixtureSha']:
                    raise RuntimeError('Port belongs to different fixture runtime')
                break
            except (OSError, TimeoutError):
                time.sleep(.05)
        else:
            raise RuntimeError('Owned fixture runtime not ready')
        manifest['runtimeInputs'] = json.loads((out / 'runtime/runtime.json').read_text())
        for theme, form in cases:
            item = {'id': f'{theme}-{form}', 'started': time.time(), 'providers': []}
            manifest['cases'].append(item)
            commands = [('Source', ['node', str(TOOLS / 'capture-source.mjs'), str(fixture), str(out / f'source-{theme}-{form}'), base, theme, form])]
            if not args.source_only:
                commands.append(('Flutter Linux', [str(TOOLS / 'capture-flutter.sh'), str(fixture), str(out / f'flutter-{theme}-{form}'), theme, form]))
            for provider, command in commands:
                receipt = {'provider': provider, 'started': time.time(), 'result': 'STARTED'}
                item['providers'].append(receipt)
                persist()
                with (out / f'{provider.split()[0].lower()}-{theme}-{form}.log').open('w') as runlog:
                    env = os.environ.copy()
                    env['RAFT_PROCESS_BASE'] = base
                    result = subprocess.run(command, cwd=ROOT, env=env, stdout=runlog, stderr=subprocess.STDOUT)
                receipt.update(finished=time.time(), exitCode=result.returncode,
                               result='PASS' if result.returncode == 0 else 'FAIL')
                persist()
                print(f'{provider} {theme}/{form}: {receipt["result"]}', flush=True)
        manifest['result'] = ('SOURCE_ONLY' if args.source_only else 'PASS') if all(p['result'] == 'PASS' for c in manifest['cases'] for p in c['providers']) else 'FAIL'
    except Exception as error:
        manifest['result'] = 'FAIL'
        manifest['runnerError'] = str(error)
        raise
    finally:
        manifest['finished'] = time.time()
        persist()
        runtime.terminate()
        try:
            runtime.wait(timeout=10)
        except subprocess.TimeoutExpired:
            runtime.kill(); runtime.wait()
        log.close()
    return 0 if manifest['result'] in ('PASS', 'SOURCE_ONLY') else 1

if __name__ == '__main__':
    raise SystemExit(main())
