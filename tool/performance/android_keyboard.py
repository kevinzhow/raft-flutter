#!/usr/bin/env python3
"""Soft-keyboard frame times on an Android device or emulator, with real taps.

Drives the `.linkperf` build of integration_test/keyboard_jank_main.dart (the
production app on a long CJK / markdown / image channel): opens the channel,
taps the composer (the IME slides up), presses Back (it slides down), repeats,
and reads the per-frame FrameTiming and metrics lines the build prints to
logcat. Reports build (UI thread) and raster times of the frames of every
keyboard animation.

  tool/flutter build apk --profile --target-platform android-x64 \
    --android-project-arg=raftApplicationIdSuffix=.linkperf \
    -t integration_test/keyboard_jank_main.dart
  python3 tool/performance/android_keyboard.py run --device emulator-5554 \
    --apk apps/raft_flutter/build/app/outputs/flutter-apk/app-profile.apk --out .local/performance/keyboard/<name>
  python3 tool/performance/android_keyboard.py compare <base-dir> <candidate-dir>

Only the isolated `app.raft.raft_flutter.linkperf` package is installed (replace
in place, never uninstall); the official app's install state must be unchanged.
A budget on an emulator host is diagnostic: compare two builds on the same host.
"""
import argparse
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tool'))
from android_app import LAB_PACKAGE, SafetyError, apk_metadata, call, protected_state, sdk_tools  # noqa: E402

BUDGET_MS = 1000 / 120
# Taps as fractions of the screen (fixture layout: sidebar row of lab-kb, composer).
CHANNEL_TAP = (0.15, 0.5075)
COMPOSER_TAP = (0.444, 0.895)
GAP_US = 500_000


def pct(values, q):
    s = sorted(values)
    return s[max(0, min(len(s) - 1, math.ceil(q * len(s)) - 1))] if s else 0


def parse(text):
    metrics, frames = [], {}
    for line in text.splitlines():
        found = re.search(r'KBJ (m|f) (.*)$', line)
        if not found:
            continue
        parts = found[2].split()
        if found[1] == 'm':
            metrics.append((int(parts[0]), int(parts[1])))
        else:
            frames[int(parts[0])] = (int(parts[1]), int(parts[2]), int(parts[3]))
    return sorted(metrics), sorted((t, *v) for t, v in frames.items())


def episodes(metrics):
    out, cur = [], []
    for t, inset in metrics:
        if cur and t - cur[-1][0] > GAP_US:
            out.append(cur)
            cur = []
        cur.append((t, inset))
    return out + ([cur] if cur else [])


def summarize(text):
    metrics, frames = parse(text)
    build, raster, animations = [], [], []
    for episode in episodes(metrics):
        if max(inset for _, inset in episode) == 0:
            continue
        window = [f for f in frames if episode[0][0] - 20_000 <= f[0] <= episode[-1][0] + 60_000]
        if not window:
            continue
        build += [f[1] / 1000 for f in window]
        raster += [f[2] / 1000 for f in window]
        animations.append({'direction': 'open' if episode[-1][1] > episode[0][1] else 'close',
                           'metricsEvents': len(episode), 'frames': len(window)})
    dist = lambda v: {'p50': pct(v, .5), 'p90': pct(v, .9), 'p99': pct(v, .99), 'max': max(v, default=0)}
    return {'frames': len(build), 'animations': animations, 'buildMs': dist(build), 'rasterMs': dist(raster),
            'overBudget': sum(1 for b, r in zip(build, raster) if max(b, r) > BUDGET_MS)}


def run(args):
    adb, aapt, _ = sdk_tools()
    meta = apk_metadata(args.apk, aapt)
    if meta['package'] != LAB_PACKAGE:
        raise SafetyError(f'Only {LAB_PACKAGE} may be installed by this probe, got {meta["package"]}.')
    out = Path(args.out)
    if out.exists():
        raise SafetyError('Use a new output directory; earlier runs stay unchanged.')
    out.mkdir(parents=True)
    protected = protected_state(args.device)
    shell = lambda *a: call([adb, '-s', args.device, 'shell', *a])
    call([adb, '-s', args.device, 'install', '-r', args.apk])
    width, height = map(int, re.search(r'(\d+)x(\d+)', shell('wm', 'size'))[0].split('x'))
    tap = lambda point: shell('input', 'tap', str(int(point[0] * width)), str(int(point[1] * height)))
    shell('am', 'force-stop', LAB_PACKAGE)
    call([adb, '-s', args.device, 'logcat', '-c'])
    shell('monkey', '-p', LAB_PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1')
    time.sleep(10)
    tap(CHANNEL_TAP)
    time.sleep(4)
    for _ in range(args.cycles):
        tap(COMPOSER_TAP)
        time.sleep(3)
        shell('input', 'keyevent', '4')
        time.sleep(2.5)
    log = call([adb, '-s', args.device, 'logcat', '-d', '-s', 'flutter:I'])
    (out / 'logcat.txt').write_text(log)
    result = summarize(log)
    result.update(device=args.device, apk=meta, cycles=args.cycles, protectedStateUnchanged=protected_state(args.device) == protected)
    (out / 'result.json').write_text(json.dumps(result, indent=1) + '\n')
    print(json.dumps({k: result[k] for k in ('frames', 'buildMs', 'rasterMs', 'overBudget')}, indent=1))
    if not result['protectedStateUnchanged']:
        raise SafetyError('The official app install state changed.')
    expected = args.cycles * 2
    if len(result['animations']) < expected * 0.75:
        print(f'FAIL: only {len(result["animations"])} of {expected} keyboard animations were observed (taps missed?)')
        return 1
    if result['buildMs']['p99'] > args.budget_p99_ms:
        print(f'FAIL: build p99 {result["buildMs"]["p99"]:.2f} ms exceeds {args.budget_p99_ms} ms')
        return 1
    return 0


def compare(args):
    base, cand = (json.loads((Path(d) / 'result.json').read_text()) for d in (args.base, args.candidate))
    failed = False
    for key in ('p50', 'p90', 'p99'):
        a, b = base['buildMs'][key], cand['buildMs'][key]
        regressed = b > a * (1 + args.threshold) + args.floor_ms
        failed |= regressed
        print(f'build {key}: {a:.2f} -> {b:.2f} ms {"REGRESSION" if regressed else "ok"}')
    return 1 if failed else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    r = sub.add_parser('run')
    r.add_argument('--device', required=True)
    r.add_argument('--apk', required=True)
    r.add_argument('--out', required=True)
    r.add_argument('--cycles', type=int, default=8)
    r.add_argument('--budget-p99-ms', type=float, default=BUDGET_MS)
    c = sub.add_parser('compare')
    c.add_argument('base')
    c.add_argument('candidate')
    c.add_argument('--threshold', type=float, default=0.10)
    c.add_argument('--floor-ms', type=float, default=0.5)
    args = parser.parse_args(argv)
    try:
        return run(args) if args.command == 'run' else compare(args)
    except SafetyError as error:
        sys.exit(f'STOP: {error}')


if __name__ == '__main__':
    raise SystemExit(main())
