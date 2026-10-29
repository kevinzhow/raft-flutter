#!/usr/bin/env python3
"""Raft perf lab: run the fixed profile-mode scenario suite, summarise every
frame against the 8.33 ms (120 Hz) target and the 16.7 ms (60 Hz) gate, and
compare two runs.

  python3 tool/performance/lab.py run --out .local/performance/lab/<name>
  python3 tool/performance/lab.py summarize <run-dir>
  python3 tool/performance/lab.py compare <base-dir> <candidate-dir>
  python3 tool/performance/lab.py detect --out .local/performance/<new-name> --scenarios all

See docs/performance-lab.md.
"""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import random
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / 'apps/raft_flutter'
TARGET = 'integration_test/perf_lab_test.dart'
DRIVER = 'test_driver/perf_lab_driver.dart'
sys.path.insert(0, str(ROOT / 'tool'))
from android_app import SafetyError, flutter_guard, protected_state
BUDGET_120 = 1e6 / 120  # 8333 us
BUDGET_60 = 1e6 / 60    # 16667 us
SCENARIO_ORDER = ['steady-scroll', 'fling', 'image-scroll', 'older-drag', 'scrollbar-drag', 'scrollbar-sweep', 'arrival-scrolled-up', 'resize', 'keyboard', 'idle-final',
                  'open-cold', 'open-warm', 'channel-switch', 'thread-open', 'section-drag', 'section-back-drag', 'section-cycle']
ROW_KINDS = ['plain', 'markdown', 'code', 'image', 'attachments', 'reactions', 'thread-summary', 'task']
DETECTION_SCENARIOS = ['open-cold', 'open-warm', 'steady-scroll', 'image-scroll', 'older-drag',
                       'channel-switch', 'thread-open', 'section-cycle', 'nav-activity-item',
                       'keyboard', 'idle-final']
DETECTION_CONTROLS = ['control-idle', 'control-ticker', 'control-animation']
DETECTION_GAPS = {
    'server-switch': 'Server switching has no arrival-verified lab scene yet.',
    'send-recovery': 'Use the functional send acceptance entry; profile send/recovery is not implemented.',
    'image-preview': 'Image scrolling is measured; preview open/return is not implemented.',
    'video-play-pause': 'No arrival-verified playback/pause scene in this slice.',
    'resource-release': 'Repeated release, post-GC object differences and retaining paths are not collected.',
}
PAGINATION_NOTE = ('Fixture pagination honors the requested limit (normally 50 rows). '
                   'Before PR #117, mix, img and mount-* preloaded the full batch. '
                   'Those older baselines have a different workload; do not attribute the difference to a product change.')


def detect_record(record, *, evidence=None):
    """Inspect one launch's raw observations. Never compare revisions or use uit.

    A slow frame is a review item until there is causal evidence. Missing
    instance/paint geometry/GC evidence is explicit, rather than a zero count.
    """
    evidence = evidence or []
    scene = record.get('scenario', 'unknown')
    diagnostic = record.get('detection') or {}
    findings, checks = [], {}

    def check(name, status, reason, **observed):
        checks[name] = {'status': status, 'reason': reason, **observed}

    def finding(signal, status, observed, *, frame=None, component=None, cause=None, occurrences=1):
        findings.append({'scene': scene, 'theme': record.get('theme'), 'action': observed.get('action', scene),
                         'status': status, 'signal': signal, 'frameId': frame, 'observed': observed,
                         'component': component, 'cause': cause, 'occurrences': occurrences, 'evidence': evidence})

    arrival = diagnostic.get('arrival') or {}
    operation_failure = record.get('failure') or diagnostic.get('operationFailures')
    if operation_failure:
        check('arrival', 'ISSUE', 'The recorded operation failed; its timings cannot establish a functional pass.')
        finding('operation-failure', 'ISSUE', {'failure': operation_failure})
    elif arrival.get('arrived') is not True:
        check('arrival', 'NOT_RUN', 'No positive target/operation arrival proof.', proof=arrival)
    else:
        check('arrival', 'PASS', 'The scene recorded its visible target and required operation.', proof=arrival)

    hz = record.get('displayRefreshRate')
    valid_hz = isinstance(hz, (int, float)) and not isinstance(hz, bool) and math.isfinite(hz) and 1 <= hz <= 1000
    raw = record.get('frames')
    valid_frames = isinstance(raw, list) and all(
        isinstance(f, dict) and all(isinstance(f.get(k), (int, float)) and not isinstance(f[k], bool)
                                   and math.isfinite(f[k]) and f[k] >= 0 for k in ('b', 'ui', 'r')) for f in raw)
    idle_scene = record.get('kind') == 'idle'
    surface = {key: diagnostic.get(key) for key in (
        'renderSurfaceWidth', 'renderSurfaceHeight', 'nativeWindowWidth', 'nativeWindowHeight')}
    surface_known = all(isinstance(v, (int, float)) and not isinstance(v, bool)
                        and math.isfinite(v) and v > 0 for v in surface.values())
    surface_matches = surface_known and all(
        abs(surface[f'renderSurface{axis}'] - surface[f'nativeWindow{axis}']) <= 1
        for axis in ('Width', 'Height'))
    check('render-surface', 'PASS' if surface_matches else 'REVIEW',
          'Native window and render surface match within one physical pixel.' if surface_matches else
          'Native/render surface sizes are missing or differ; frame durations are diagnostic only.', **surface)
    timing_allowed = (record.get('profile') is True and record.get('phasesCollected') is False
                      and diagnostic.get('cpuSamplingEnabled') is False
                      and diagnostic.get('phaseProfilingEnabled') is False and surface_matches)
    budget = 1e6 / hz if valid_hz else None
    actions = diagnostic.get('actions') or []

    def action_for(frame):
        at = frame.get('b', -1)
        for item in actions:
            if item.get('startUs', math.inf) <= at <= item.get('endUs', -1):
                return item.get('name', scene)
        return scene

    if not valid_hz or not valid_frames or not raw and not idle_scene:
        check('frame-budget', 'NOT_RUN', 'Actual refresh rate and complete raw UI/raster frame samples are required.')
    elif not timing_allowed:
        check('frame-budget', 'REVIEW', 'Requires matching native/render surfaces and profile mode with CPU sampling and phase tracing verified off; other durations are diagnostic only.',
              budgetUs=budget, frames=len(raw))
    else:
        over = [f for f in raw if f['ui'] > budget or f['r'] > budget]
        check('frame-budget', 'REVIEW' if over else 'PASS',
              'Raw UI and raster durations checked separately against the actual refresh rate.',
              budgetUs=budget, frames=len(raw), overBudget=len(over))
    if valid_hz and valid_frames:
        streak, run_frames = 0, []
        for f in raw:
            over = f['ui'] > budget or f['r'] > budget
            streak = streak + 1 if over else 0
            if over:
                run_frames.append((f, streak))
        # Keep every over-budget frame, including the first cold frame.
        for f, consecutive in run_frames:
            observed = {'uiMs': ms(f['ui']), 'rasterMs': ms(f['r']), 'budgetMs': ms(budget),
                        'startUs': f['b'], 'action': action_for(f),
                        'priority': 'high' if max(f['ui'], f['r']) > 2 * budget or consecutive >= 3 else 'normal',
                        'timingVerdictAllowed': timing_allowed}
            finding('slow-frame' if timing_allowed else 'instrumented-frame', 'REVIEW', observed, frame=f.get('n'))

    counters = diagnostic.get('rebuilds') or {}
    if counters.get('instancesCollected') is True:
        unexpected = [c for c in counters.get('instances', []) if c.get('unexpected') and c.get('rebuilds', 0) > 0]
        check('unrelated-rebuild', 'ISSUE' if unexpected else 'PASS', 'Existing debug rebuild callback, separate from profile timing.',
              instances=counters.get('instances', []))
        for item in unexpected:
            finding('unrelated-rebuild', 'ISSUE', item, component=item.get('component'),
                    cause='The same instance rebuilt during an operation that declared it unchanged.', occurrences=item['rebuilds'])
    else:
        check('unrelated-rebuild', 'NOT_RUN', counters.get('reason', 'No per-instance rebuild evidence.'),
              timelineRowBuilds=counters.get('timelineRowBuilds'))
        if idle_scene and (counters.get('timelineRowBuilds') or 0) > 0:
            finding('idle-row-builds', 'REVIEW', {'count': counters['timelineRowBuilds']},
                    cause='Existing aggregate row-build counter changed; instance and trigger are unconfirmed.')

    natural_idle = (idle_scene and diagnostic.get('framePolicy') == 'benchmarkLive'
                    and diagnostic.get('bindingAutoFramesSuppressed') is True
                    and diagnostic.get('testerPumpsDuringAction') == 0
                    and record.get('idleSeconds', 0) >= 10)
    if not idle_scene:
        check('idle-work', 'NOT_RUN', 'This scene includes active input or transitions.')
    elif not natural_idle or not valid_frames:
        check('idle-work', 'NOT_RUN', 'Requires a natural 10-second window without tester requests or live-binding automatic frames.')
    else:
        allowed = diagnostic.get('allowedActivity') or []
        span = (raw[-1]['b'] - raw[0]['b']) if len(raw) > 1 else 0
        repeated = len(raw) >= 3 and span >= 1e6
        if repeated and not allowed:
            control = diagnostic.get('control') == 'unexpected-ticker'
            status = 'ISSUE' if control else 'REVIEW'
            check('idle-work', status, 'Application-requested frames continued for at least one second.', frames=len(raw), spanUs=span)
            finding('idle-frames', status, {'frames': len(raw), 'spanUs': span},
                    component='_DetectionTicker' if control else None,
                    cause='Deliberate ticker control fixture.' if control else 'Paint objects and frame requester need a detail replay.',
                    occurrences=len(raw))
        else:
            check('idle-work', 'PASS', 'Observed natural idle window; any declared animation is excluded.',
                  frames=len(raw), allowedActivity=allowed)

    check('paint-area', 'NOT_RUN', 'No per-object paint bounds; frame presence alone does not prove a large repaint.')
    check('layout-jitter', 'NOT_RUN', 'No stable-target per-frame rectangle series in this slice.')
    check('shader-decode-cause', 'NOT_RUN', 'A cold/warm difference cannot identify shader or decode work; inspect a detail trace.')
    check('memory-release', 'NOT_RUN', 'No three comparable post-GC checkpoints and retaining paths; RSS is recorded only.')
    if any(c['status'] == 'ISSUE' for c in checks.values()):
        status = 'ISSUE'
    elif checks['arrival']['status'] == 'NOT_RUN' or checks['frame-budget']['status'] == 'NOT_RUN':
        status = 'NOT_RUN'
    elif any(c['status'] == 'REVIEW' for c in checks.values()) or any(f['status'] == 'REVIEW' for f in findings):
        status = 'REVIEW'
    else:
        status = 'PASS'
    statuses = [status]
    for severity in ('ISSUE', 'REVIEW'):
        if severity != status and any(f['status'] == severity for f in findings):
            statuses.append(severity)
    return {'scene': scene, 'theme': record.get('theme'), 'status': status, 'statuses': statuses,
            'statusLabel': ' + '.join(statuses), 'control': diagnostic.get('control'),
            'refreshRate': hz, 'profile': record.get('profile'), 'checks': checks, 'findings': findings,
            'actions': actions, 'evidence': evidence}


def detection_report(run_dir, expected, themes):
    """Write a coverage report even when launch/collection failed."""
    run_dir = Path(run_dir)
    results = []
    for theme in themes:
        for scene in expected:
            path = run_dir / f'{theme}-{scene}.json'
            if not path.is_file():
                results.append({'theme': theme, 'scene': scene, 'status': 'NOT_RUN', 'findings': [],
                                'reason': DETECTION_GAPS.get(scene, 'No completed scene record; check runner.log and lab-done.json.')})
                continue
            try:
                record = json.loads(path.read_text())
                if not isinstance(record, dict) or not isinstance(record.get('detection', {}), dict):
                    raise ValueError('Expected a scene record object with detection observations.')
            except (ValueError, OSError) as error:
                results.append({'theme': theme, 'scene': scene, 'status': 'NOT_RUN', 'findings': [],
                                'reason': f'Raw record could not be read: {error}'})
                continue
            links = [path.name]
            links += [p.name for p in sorted(run_dir.glob(f'{theme}-{scene}.*.json'))]
            results.append(detect_record(record, evidence=links))
    covered = {row['scene'] for row in results}
    for scene, reason in DETECTION_GAPS.items():
        if scene not in covered:
            results.append({'scene': scene, 'status': 'NOT_RUN', 'reason': reason, 'findings': []})
    metadata = {}
    for name in ('env.json', 'lab-hello.json', 'lab-done.json', 'driver-result.json', 'run-manifest.json'):
        path = run_dir / name
        if path.is_file():
            try:
                value = json.loads(path.read_text())
                if not isinstance(value, dict):
                    raise ValueError('Metadata must be an object.')
                metadata[name.removesuffix('.json')] = value
            except (ValueError, OSError) as error:
                results.append({'scene': 'collection', 'status': 'NOT_RUN', 'findings': [],
                                'reason': f'{name} could not be read: {error}'})
    failures = list(metadata.get('lab-done', {}).get('failures', []))
    driver = metadata.get('driver-result', {})
    if driver and driver.get('result') != 'true':
        failures.append('Flutter driver reported a failed test; inspect driver-result.json.')
    if metadata.get('env', {}).get('privateRuntimeRemoved') is False:
        failures.append('Private display runtime cleanup failed; inspect env.json.')
    sampler_errors = run_dir / 'lab-sampler-errors.txt'
    if sampler_errors.is_file() and sampler_errors.read_text().strip():
        failures.append('Sampler failed; inspect lab-sampler-errors.txt.')
    if failures:
        results.append({'scene': 'collection', 'status': 'ISSUE', 'findings': [],
                        'reason': '; '.join(str(f) for f in failures)})
    runner = run_dir / 'runner.log'
    renderer_errors = re.findall(r'^\[ERROR:[^\n]+', runner.read_text(errors='replace'), re.MULTILINE) if runner.is_file() else []
    if renderer_errors:
        results.append({'scene': 'collection-renderer', 'status': 'ISSUE',
            'reason': 'Engine error log; the affected frame and visible impact require replay.', 'findings': [{
                'scene': 'collection-renderer', 'theme': None, 'action': 'whole launch',
                'status': 'ISSUE', 'signal': 'engine-error', 'frameId': None,
                'observed': {'examples': list(dict.fromkeys(renderer_errors))[:5]},
                'component': 'Flutter engine', 'cause': None, 'occurrences': len(renderer_errors), 'evidence': ['runner.log'],
            }], 'evidence': ['runner.log']})
    summary = {'schema': 1, 'mode': 'problem-detection', 'comparison': False, 'scenarios': results,
               'counts': {s: sum(row['status'] == s for row in results) for s in ('PASS', 'ISSUE', 'REVIEW', 'NOT_RUN')}, **metadata}
    (run_dir / 'detection.json').write_text(json.dumps(summary, indent=2) + '\n')
    lines = ['# Profile problem detection', '', 'Statuses cover the recorded checks only. Missing signals remain NOT_RUN.', '',
             '| Scene | Theme | Status | Findings | Uncollected signals |', '| --- | --- | --- | --- | --- |']
    if metadata.get('lab-hello', {}).get('fixturePagination') == 'requested-limit-v1':
        lines[4:4] = [PAGINATION_NOTE, '']
    for row in results:
        missing = ', '.join(k for k, v in row.get('checks', {}).items() if v['status'] == 'NOT_RUN') or row.get('reason', '')
        missing = missing.replace('\n', ' ').replace('|', '\\|')
        lines.append(f"| {row['scene']} | {row.get('theme', '-')} | {row.get('statusLabel', row['status'])} | {len(row['findings'])} | {missing} |")
    for row in results:
        if not row['findings']:
            continue
        lines += ['', f"## {row.get('theme', '')} / {row['scene']} — {row.get('statusLabel', row['status'])}", '']
        for item in row['findings'][:12]:
            lines.append(f"- {item['status']} {item['signal']}, frame {item['frameId']}: {json.dumps(item['observed'], ensure_ascii=False)}; component={item['component']}; cause={item['cause']}.")
        if len(row['findings']) > 12:
            lines.append(f"- All {len(row['findings'])} findings are retained in detection.json.")
        lines += ['', 'Evidence: ' + ', '.join(f'[{p}]({p})' for p in row.get('evidence', []))]
    (run_dir / 'detection.md').write_text('\n'.join(lines) + '\n')
    return summary


# ---------------------------------------------------------------- statistics

def pct(values, q):
    """Nearest-rank percentile; 0 for an empty list."""
    if not values:
        return 0
    s = sorted(values)
    return s[max(0, min(len(s) - 1, math.ceil(q * len(s)) - 1))]


def dist(values):
    return {'p50': pct(values, .5), 'p90': pct(values, .9), 'p99': pct(values, .99), 'max': max(values) if values else 0,
            'mean': sum(values) / len(values) if values else 0}


def ms(us):
    return round(us / 1000, 2)


def frames_in(record, t0, t1):
    return [f for f in record.get('frames', []) if t0 <= f['b'] < t1]


def _work(frames, key):
    """Per-frame count summary. None when any frame omitted it.

    `mean` is the reference figure. The sum and max move when the frame
    count moves, so compare does not treat them as a gate.
    """
    if not frames or any(key not in frame for frame in frames):
        return None
    values = [frame[key] for frame in frames]
    return {'sum': int(sum(values)), 'max': int(max(values)), 'mean': sum(values) / len(values)}


def _attach_thread_time(frames, attribution):
    """Copy per-frame timeline tdur onto frame rows. Returns the presence note."""
    if not attribution:
        return None
    by_b = {item['b']: item for item in attribution.get('frameThreadTime') or [] if 'b' in item}
    for frame in frames:
        item = by_b.get(frame.get('b'))
        if not item:
            continue
        for key in ('uiCpuUs', 'rasterCpuUs', 'uiEvent', 'rasterEvent'):
            if item.get(key) is not None:
                frame[key] = item[key]
    return attribution.get('threadTime')


def _present_dist(frames, key):
    values = [frame[key] for frame in frames if key in frame]
    if not values:
        return None
    return {'p50': pct(values, .5), 'p90': pct(values, .9), 'max': max(values), 'frames': len(values)}


def _thread_time_line(keyboard, thread_time):
    """One line: per-frame timeline CPU next to the wall-clock median."""
    def side(cpu_key, wall_key, label):
        cpu = keyboard.get(cpu_key)
        wall = keyboard.get(wall_key)
        cpu_s = '-' if not cpu else f"{ms(cpu['p50'])} ms"
        wall_s = '-' if wall is None else f'{ms(wall)} ms'
        return f'{label} median {cpu_s} CPU, {wall_s} wall'

    def coverage(prefix):
        events = thread_time.get(f'{prefix}Events')
        if events is None:
            return f'{prefix} tdur was not collected'
        with_tdur = thread_time.get(f'{prefix}EventsWithTdur', 0)
        names = thread_time.get(f'{prefix}Threads') or []
        if not names and events == 0:
            return f'no {prefix} thread in the timeline'
        if events and with_tdur == 0:
            tts = thread_time.get(f'{prefix}EventsWithTts', 0)
            if tts:
                return f'{prefix} thread has {events} events, no tdur, {tts} with tts'
            return f'{prefix} thread has {events} events and no tdur'
        return f'{prefix} events {with_tdur}/{events} with tdur'

    if thread_time.get('collected') is False:
        return 'timeline was not collected, so tdur is absent.'
    return f"{side('uiCpuUs', 'uiWallP50Us', 'UI')}; {side('rasterCpuUs', 'rasterWallP50Us', 'raster')}. {coverage('ui')}. {coverage('raster')}."


def _proc_cpu_line(proc):
    """Whole-scene kernel CPU. Names the source so it is not read as timeline tts."""
    if not proc or proc.get('collected') is False:
        if proc and proc.get('error'):
            return f"scene CPU from /proc schedstat was not collected ({proc['error']})."
        return None

    def side(key, label):
        item = proc.get(key) or {}
        if item.get('missing') or 'ms' not in item:
            return f'{label} missing'
        comm = item.get('comm') or '?'
        ms = item['ms']
        text = f'{ms:.1f}' if isinstance(ms, float) else str(ms)
        if item.get('matchedBy') == 'main-thread':
            return f'{label} {text} ms (main thread `{comm}`; UI runs on the platform thread, kernel name is not 1.ui)'
        return f'{label} {text} ms (`{comm}`)'

    window = proc.get('windowMs')
    span = '' if window is None else f' Window {window / 1000:.1f} s.'
    return f"scene CPU from /proc schedstat, not timeline tts: {side('ui', 'UI')}; {side('raster', 'raster')}.{span}"


def paired_ratio_ci(pairs, samples=4000, seed=1):
    """95% interval of the median new/old ratio, resampling rounds.

    `pairs` is a sequence of (old, new), one entry per alternating round.
    A round with a non-positive old value is dropped. Rounds that shared a
    process are not independent samples. Use `cluster_ratio_ci` for that
    count. `compare` does not call this.
    """
    ratios = [new / old for old, new in pairs if old > 0 and new >= 0]
    if not ratios:
        return {'rounds': 0, 'low': None, 'high': None, 'median': None}

    def median(xs):
        ordered = sorted(xs)
        n = len(ordered)
        mid = n // 2
        if n % 2:
            return ordered[mid]
        return (ordered[mid - 1] + ordered[mid]) / 2

    rng = random.Random(seed)
    n = len(ratios)
    boots = sorted(median([ratios[rng.randrange(n)] for _ in range(n)]) for _ in range(samples))
    return {
        'rounds': n,
        'low': boots[int(0.025 * (samples - 1))],
        'high': boots[int(0.975 * (samples - 1))],
        'median': median(ratios),
    }


def cluster_ratio_ci(batch_pairs, samples=4000, seed=1):
    """95% interval of the median launch-batch ratio.

    Each item is `(old_batch, new_batch)`: the scene-CPU values from one old
    launch and one new launch. The pair ratio is mean(new) / mean(old).
    Bootstrap draws those launches whole, so rounds that shared a process
    stay together. The independent sample count is the number of launch
    pairs. `compare` does not call this.
    """
    ratios = []
    for old, new in batch_pairs:
        old_values = [value for value in old if value > 0]
        new_values = [value for value in new if value >= 0]
        if not old_values or not new_values:
            continue
        old_mean = sum(old_values) / len(old_values)
        new_mean = sum(new_values) / len(new_values)
        ratios.append(new_mean / old_mean)
    if not ratios:
        return {'pairs': 0, 'low': None, 'high': None, 'median': None}

    def median(xs):
        ordered = sorted(xs)
        n = len(ordered)
        mid = n // 2
        if n % 2:
            return ordered[mid]
        return (ordered[mid - 1] + ordered[mid]) / 2

    rng = random.Random(seed)
    n = len(ratios)
    boots = sorted(median([ratios[rng.randrange(n)] for _ in range(n)]) for _ in range(samples))
    return {
        'pairs': n,
        'low': boots[int(0.025 * (samples - 1))],
        'high': boots[int(0.975 * (samples - 1))],
        'median': median(ratios),
    }


def ratio_verdict(ci, *, high_limit=1.05, low_limit=None):
    """Whole interval within the limit passes. Entirely past it is a regression."""
    low, high = ci.get('low'), ci.get('high')
    if low is None or high is None:
        return 'no-data'
    if low_limit is not None:
        return 'same' if low >= low_limit and high <= high_limit else 'not-same'
    if high <= high_limit:
        return 'pass'
    if low > high_limit:
        return 'regression'
    return 'uncertain'


def qualify_pair(old, new, *, seen_launches=frozenset(), measured_rounds=3):
    """Qualify one same-source calibration pair, never individual rounds.

    CPU counters check concurrent fairness. Product conclusions use Flutter
    frame time, visible latency and over-budget frames, not these counters.
    This function does not change the legacy comparison or infer equivalence.
    """
    result = {'qualified': False, 'independentPairs': 0, 'reasons': [], 'rounds': [], 'launchKeys': [],
              'primaryMetrics': 'Flutter UI/raster p90/p99, visible latency and over-budget frames'}

    def require(value, reason):
        if not value:
            raise ValueError(reason)

    def integer(value, label, minimum=0):
        require(type(value) is int and value >= minimum, f'{label}: missing or invalid integer')
        return value

    def cpu_set(value):
        require(isinstance(value, list) and value, 'role affinity missing')
        require(all(type(v) is int and v >= 0 for v in value), 'invalid role affinity')
        require(len(set(value)) == len(value), 'duplicate CPU in affinity')
        return set(value)

    try:
        runs = {'old': old, 'new': new}
        manifests = {side: run['manifest'] for side, run in runs.items()}
        a, b = manifests.values()
        require(a['source']['digest'] == b['source']['digest'], 'calibration product sources differ')
        require(a['driverSha256'] == b['driverSha256'] and a['fixtureSha256'] == b['fixtureSha256'], 'observer or fixture sources differ')
        require(a['config'] == b['config'], 'workload configurations differ')
        require(a['toolchain'] == b['toolchain'], 'calibration toolchains differ')
        require(a['artifact']['files']['lib/libflutter_linux_gtk.so'] == b['artifact']['files']['lib/libflutter_linux_gtk.so'], 'calibration Flutter engines differ')
        require(old['hello']['fixtureVersion'] == new['hello']['fixtureVersion'] and old['hello']['fixtureVersion'], 'loaded fixture versions differ or are missing')
        config = a['config']
        require(config['rounds'] == measured_rounds, 'measured round count differs from protocol')
        require(',' not in config['themes'] and ',' not in config['scenarios'], 'calibration requires one theme and one scenario')
        require(a['pair'] == b['pair'] and a['pair'], 'pair identities differ')
        require(a.get('bootId') == b.get('bootId') and a.get('bootId'), 'host monotonic clock identity missing or different')
        require(a['buildReceipt']['identitySuffix'] != b['buildReceipt']['identitySuffix'], 'test application identities are not isolated')
        groups, batches, identities = {}, {}, {}
        expected_rounds = list(range(measured_rounds + 1))
        for side, run in runs.items():
            m = manifests[side]
            require(m['schema'] == 1 and m['order'] == side and m['invocation'], f'{side}: invocation identity missing')
            require(all(re.fullmatch(r'[0-9a-f]{64}', str(value)) for value in
                        (m['source']['digest'], m['artifact']['digest'], m['driverSha256'], m['fixtureSha256'])), f'{side}: source/artifact hash missing')
            receipt = m['buildReceipt']
            require(receipt['exitCode'] == 0 and receipt['identitySuffix'], f'{side}: isolated build receipt missing')
            require(receipt['sourceAfter'] == receipt['source'], f'{side}: source changed during build')
            for field in ('source', 'artifact', 'config', 'toolchain'):
                require(receipt[field] == m[field], f'{side}: {field} differs from build receipt')
            require(all(isinstance(m['toolchain'][key], str) and m['toolchain'][key] for key in
                        ('frameworkRevision', 'engineRevision', 'dartSdkVersion')), f'{side}: toolchain identity missing')
            require(run['env']['exitCode'] == 0, f'{side}: run failed')
            activity = run['env']['hostActivity']
            require(activity['intervalSeconds'] > 0 and isinstance(activity['processes'], list), f'{side}: host load observation missing')
            require(not run['samplerErrors'], f'{side}: sampler errors')
            require(run['driverResult']['result'] in ('true', True) and not run['driverResult']['failureDetails'], f'{side}: driver failed')
            require(not run['done']['failures'], f'{side}: scenario failed')
            hello = run['hello']
            require(hello['linuxApplicationIdSuffix'] == receipt['identitySuffix'], f'{side}: loaded fixture identity differs')
            require(hello['themes'] == [config['themes']] and hello['scenarios'] == [config['scenarios']]
                    and hello['seconds'] == config['seconds'] and hello['semantics'] == config['semantics']
                    and hello['phases'] == config['phases'], f'{side}: loaded fixture configuration differs')
            cpus = cpu_set(m['cpus'])
            topology = {entry['cpu']: entry for entry in m['topology']}
            require(cpus <= topology.keys(), f'{side}: CPU topology missing')
            groups[side] = {(topology[cpu]['socket'], topology[cpu]['core']) for cpu in cpus}
            require(all(set(topology[cpu]['siblings']) <= cpus for cpu in cpus), f'{side}: SMT sibling escaped the core group')
            for field in ('procRounds', 'frameRounds', 'barrierRounds'):
                require([row['round'] for row in run[field]] == expected_rounds, f'{side}: incomplete or duplicated {field}')
            rows = run['procRounds']
            batches[side] = rows[0]['batch']
            identities[side] = (rows[0]['pid'], rows[0]['processStartTicks'])
            result['launchKeys'] += [f"batch:{batches[side]}", f"process:{m['bootId']}:{identities[side][0]}:{identities[side][1]}"]
            roles = {}
            for row, frames, barrier in zip(rows, run['frameRounds'], run['barrierRounds']):
                n = row['round']
                require(row['batch'] == batches[side] and frames['batch'] == batches[side] and barrier['batch'] == batches[side], f'{side}/{n}: launch changed')
                require((row['pid'], row['processStartTicks']) == identities[side], f'{side}/{n}: process changed')
                integer(row['pid'], 'pid', 1)
                integer(row['processStartTicks'], 'process start', 1)
                require(row['executable'] == str(Path(m['artifact']['path']) / 'raft_flutter'), f'{side}/{n}: loaded executable differs')
                require(row['mappedAot'] == [str(Path(m['artifact']['path']) / 'lib/libapp.so')], f'{side}/{n}: loaded AOT artifact differs')
                require(row['pair'] == m['pair'] and row['order'] == side, f'{side}/{n}: pair side differs')
                require(row['collected'] is True and row['source'] == 'proc-schedstat', f'{side}/{n}: counters missing')
                require(row['warmup'] is (n == 0) and frames['warmup'] is (n == 0), f'{side}/{n}: warmup missing or duplicated')
                require(row['theme'] == config['themes'] and row['scenario'] == config['scenarios'], f'{side}/{n}: workload changed')
                for key in ('load', 'loadEnd'):
                    load = [float(v) for v in row[key].split()]
                    require(len(load) == 3 and all(math.isfinite(v) and v >= 0 for v in load), f'{side}/{n}: load observation missing')
                for role in ('ui', 'raster'):
                    counter = row[role]
                    integer(counter['ns'], f'{side}/{n}/{role} CPU', 1)
                    ms = counter['ms']
                    require(type(ms) in (int, float) and math.isfinite(ms) and math.isclose(ms, counter['ns'] / 1e6, rel_tol=1e-12), f'{side}/{n}/{role}: CPU units differ')
                    tid = integer(counter['tid'], f'{side}/{n}/{role} TID', 1)
                    start, end = counter['start'], counter['end']
                    require(start['startTicks'] == end['startTicks'], f'{side}/{n}/{role}: thread changed')
                    integer(start['startTicks'], 'thread start', 1)
                    identity = (tid, start['startTicks'])
                    require(roles.setdefault(role, identity) == identity, f'{side}/{n}/{role}: role TID changed')
                    require(cpu_set(start['cpus']) == cpus and cpu_set(end['cpus']) == cpus, f'{side}/{n}/{role}: actual thread affinity differs')
                    times = [integer(point[key], f'{side}/{n}/{role} counter time') for point in (start, end) for key in ('beforeNs', 'afterNs')]
                    require(times == sorted(times) and times[1] < times[2], f'{side}/{n}/{role}: invalid counter read bounds')
                require(row['ui']['tid'] != row['raster']['tid'], f'{side}/{n}: UI and raster role alias')
                record = frames['record']
                require(record['theme'] == config['themes'] and record['scenario'] == config['scenarios'], f'{side}/{n}: Flutter workload differs')
                require(record['frames'], f'{side}/{n}: Flutter frames missing')
                for frame in record['frames']:
                    require(all(type(frame[key]) in (int, float) and math.isfinite(frame[key]) and frame[key] >= 0 for key in ('ui', 'uit', 'r')), f'{side}/{n}: invalid Flutter frame data')
        require(batches['old'] != batches['new'] and identities['old'] != identities['new'], 'launches are not independent')
        require(not (set(result['launchKeys']) & seen_launches), 'launch already used')
        require(not (groups['old'] & groups['new']) and len(groups['old']) == len(groups['new']), 'physical core groups overlap or differ in size')
        for n in expected_rounds:
            shares = {}
            for side, peer in (('old', 'new'), ('new', 'old')):
                require(runs[side]['barrierRounds'][n]['peerBatch'] == batches[peer], f'{side}/{n}: peer ready record differs')
            for role in ('ui', 'raster'):
                left, right = old['procRounds'][n][role], new['procRounds'][n][role]
                # Use the guaranteed intersection and the maximum possible
                # duration. Slow counter reads cannot manufacture overlap.
                intersection = min(left['end']['beforeNs'], right['end']['beforeNs']) - max(left['start']['afterNs'], right['start']['afterNs'])
                shares[role] = {side: max(0, intersection) / (row['end']['afterNs'] - row['start']['beforeNs']) for side, row in (('old', left), ('new', right))}
                require(min(shares[role].values()) >= .95, f'round {n}/{role}: counter overlap below 95%')
            result['rounds'].append({'round': n, 'warmup': n == 0, 'overlap': shares})
        result.update(qualified=True, independentPairs=1)
    except (KeyError, TypeError, ValueError, IndexError, ZeroDivisionError) as error:
        result['reasons'].append(str(error))
    return result


def window_overlap(old_start, old_end, new_start, new_end, *, minimum=.95):
    """Descriptive overlap; qualification also accounts for read uncertainty."""
    values = (old_start, old_end, new_start, new_end)
    if not all(type(v) in (int, float) and math.isfinite(v) for v in values) or old_end <= old_start or new_end <= new_start:
        return {'ok': False, 'old': 0., 'new': 0., 'overlap': 0}
    overlap = max(0, min(old_end, new_end) - max(old_start, new_start))
    left, right = overlap / (old_end - old_start), overlap / (new_end - new_start)
    return {'ok': min(left, right) >= minimum, 'old': left, 'new': right, 'overlap': overlap}


def stutters(record):
    """Frames that arrived more than 1.5 vsync periods after the previous one
    during a continuously animated scenario (dropped / doubled frame)."""
    if record.get('kind') not in ('continuous',):
        return 0
    rate = record.get('displayRefreshRate') or 60
    period = 1e6 / rate
    v = [f['v'] for f in record.get('frames', [])]
    return sum(1 for a, b in zip(v, v[1:]) if b - a > 1.5 * period)


def summarize_record(record, attribution=None):
    frames = record.get('frames', [])
    thread_time = _attach_thread_time(frames, attribution)
    for f in frames:
        # UI thread time per frame: engine build span plus the semantics,
        # finalize-tree and post-frame work that runs after scene submission.
        f.setdefault('uit', f['ui'])
    ui = [f['uit'] for f in frames]
    raster = [f['r'] for f in frames]
    n = len(frames)
    over = lambda xs, b: sum(1 for x in xs if x > b)
    either8 = sum(1 for f in frames if f['uit'] > BUDGET_120 or f['r'] > BUDGET_120)
    phases = {}
    for f in frames:
        for k, v in (f.get('ph') or {}).items():
            phases[k] = phases.get(k, 0) + v
    ui_total = sum(ui) or 1
    row = {
        'theme': record['theme'], 'scenario': record['scenario'], 'kind': record.get('kind'),
        'frames': n, 'elapsedSeconds': record.get('elapsedSeconds'),
        'displayRefreshRate': record.get('displayRefreshRate'),
        'view': f"{record.get('viewWidth', 0):.0f}x{record.get('viewHeight', 0):.0f}",
        'uiUs': dist(ui), 'uiBuildUs': dist([f['ui'] for f in frames]), 'rasterUs': dist(raster),
        'over8Ui': over(ui, BUDGET_120), 'over8Raster': over(raster, BUDGET_120), 'over8Either': either8,
        'over8EitherPct': round(100 * either8 / n, 1) if n else 0,
        'over16Ui': over(ui, BUDGET_60), 'over16Raster': over(raster, BUDGET_60),
        'stutters': stutters(record),
        'phaseShare': {k: round(100 * v / ui_total, 1) for k, v in sorted(phases.items(), key=lambda kv: -kv[1])},
        'semanticsShare': round(100 * phases.get('semantics', 0) / ui_total, 1),
        'semanticsEnabled': record.get('semanticsEnabled'),
        'cpuSeconds': record.get('cpuSeconds'),
        'uiThreadCpuSeconds': record.get('uiThreadCpuSeconds'),
        'rssDeltaMb': round(((record.get('rssAfter') or 0) - (record.get('rssBefore') or 0)) / 2**20, 1),
        'clockMatched': record.get('clockMatched'),
        'failure': record.get('failure'),
    }
    row['gate60'] = n > 0 and row['over16Ui'] == 0 and row['over16Raster'] == 0 and row['stutters'] == 0 and not row['failure']
    worst = sorted(frames, key=lambda f: -f['uit'])[:3]
    row['worstUiFrames'] = [{'uiMs': ms(f['uit']), 'buildMs': ms(f['ui']), 'rasterMs': ms(f['r']), 'phasesMs': {k: ms(v) for k, v in sorted((f.get('ph') or {}).items(), key=lambda kv: -kv[1])[:4]}} for f in worst]
    blocks = record.get('blockTotalsUs') or {}
    row['topBlocksMs'] = {k: ms(v) for k, v in sorted(blocks.items(), key=lambda kv: -kv[1])[:10]}
    for key in ('idleSeconds', 'movedPx', 'anchorDriftPx', 'anchorLostFrames', 'olderPagesServed', 'rowsBefore', 'rowsAfter', 'imageReads', 'arrivals', 'resizeSteps',
                'touchMoves', 'acceptedSection', 'taskRows', 'visibleChatTags', 'fileRows', 'decodedFileThumbnails', 'retainedTaskCards', 'chatRows', 'taggedChatRows', 'sectionVisits'):
        if key in record:
            row[key] = record[key]
    if 'opens' in record:
        opens = []
        for o in record['opens']:
            fs = frames_in(record, o['t0'], o['t1'])
            opens.append({'channel': o['channel'], 'visibleMs': round(o['visibleMs'], 1),
                          'worstUiMs': ms(max((f['uit'] for f in fs), default=0)),
                          'worstRasterMs': ms(max((f['r'] for f in fs), default=0)),
                          'uiSumMs': ms(sum(f['uit'] for f in fs)), 'frames': len(fs)})
        row['opens'] = opens
        vis = [o['visibleMs'] for o in opens if o['visibleMs'] >= 0]
        row['visibleMs'] = {'p50': pct(vis, .5), 'max': max(vis) if vis else -1}
        live = [o for o in record['opens'] if 'liveActivity' in o]
        if live:
            accepted, requests, responses = {}, {}, {}
            for o in live:
                for target, source in ((accepted, o['liveActivity'].get('accepted', {})),
                                       (requests, o.get('requests', {})),
                                       (responses, o.get('responses', {}))):
                    for key, count in source.items():
                        target[key] = target.get(key, 0) + count
            row['navigationActivity'] = {
                'transitions': len(live),
                'events': sum(len(o['liveActivity'].get('events', [])) for o in live),
                'accepted': accepted,
                'workspaceNotifications': sum(o['liveActivity'].get('workspaceNotifications', 0) for o in live),
                'predictiveBackGestures': sum(o.get('predictiveBackGestures', 0) for o in live),
                'imageResponsesStarted': sum(o.get('imageResponsesStarted', 0) for o in live),
                'cacheReads': sum(o.get('cacheReads', 0) for o in live),
                'cacheWritesCompleted': sum(o.get('cacheWritesCompleted', 0) for o in live),
                'requests': requests,
                'responses': responses,
            }
    if 'steps' in record:
        per_row, per_row_cpu, mount_ui, follow, rows = [], [], [], [], []
        for s in record['steps']:
            fs = frames_in(record, s['t0'], s['t1'])
            if not fs:
                continue
            mount_ui.append(fs[0]['uit'])
            follow.append(sum(f['uit'] for f in fs[1:]))
            rows.append(s['newRows'])
            if s['newRows'] > 0:
                per_row.append(fs[0]['uit'] / s['newRows'])
                if 'cpuUs' in s:
                    per_row_cpu.append(s['cpuUs'] / s['newRows'])
        row['mount'] = {'rowKind': record.get('rowKind'), 'steps': len(mount_ui), 'rowsMounted': sum(rows),
                        'perRowUs': dist(per_row), 'perRowCpuUs': dist(per_row_cpu), 'mountFrameUs': dist(mount_ui), 'followUpUs': dist(follow),
                        'coldFirstStepUs': mount_ui[0] if mount_ui else 0}
    if 'keyboard' in record:
        anim, episodes, cpu, cpu_known = [], [], 0, bool(record['keyboard'])
        for episode in record['keyboard']:
            fs = frames_in(record, episode['t0'], episode['t1'])
            anim.extend(fs)
            if 'cpuUs' not in episode:
                cpu_known = False
            else:
                cpu += episode['cpuUs']
            item = {'direction': episode.get('direction'), 'frames': len(fs),
                    'worstUiMs': ms(max((f['uit'] for f in fs), default=0)),
                    'worstRasterMs': ms(max((f['r'] for f in fs), default=0))}
            if 'cpuUs' in episode:
                item['cpuUs'] = episode['cpuUs']
            episodes.append(item)
        ui_anim = [f['uit'] for f in anim]
        raster_anim = [f['r'] for f in anim]
        keyboard = {
            'cycles': record.get('keyboardCycles'), 'episodes': episodes, 'frames': len(anim),
            'worstUiMs': ms(max(ui_anim, default=0)), 'worstRasterMs': ms(max(raster_anim, default=0)),
            'over8Ui': over(ui_anim, BUDGET_120), 'over8Raster': over(raster_anim, BUDGET_120),
            'over16Ui': over(ui_anim, BUDGET_60), 'over16Raster': over(raster_anim, BUDGET_60),
        }
        for key in ('builds', 'layouts', 'paints'):
            counted = _work(anim, key)
            if counted is not None:
                keyboard[key] = counted
        if cpu_known:
            keyboard['uiThreadCpuUs'] = cpu
        for key in ('uiCpuUs', 'rasterCpuUs'):
            counted = _present_dist(anim, key)
            if counted is not None:
                keyboard[key] = counted
        if ui_anim:
            keyboard['uiWallP50Us'] = pct(ui_anim, .5)
        if raster_anim:
            keyboard['rasterWallP50Us'] = pct(raster_anim, .5)
        row['keyboard'] = keyboard
    if thread_time:
        row['threadTime'] = thread_time
    if attribution and attribution.get('procThreadCpu'):
        row['procThreadCpu'] = attribution['procThreadCpu']
    if attribution:
        worst_cpu = attribution.get('cpuWorstUiFrames') or {}
        total = worst_cpu.get('samples') or 0
        row['gcCount'] = attribution.get('gcCount')
        gc = attribution.get('gcEvents') or {}
        row['gcTimeMs'] = ms(sum(v.get('totalUs', 0) for v in gc.values()))
        row['gcInWorstUiFrames'] = len(attribution.get('gcInWorstUiFrames') or [])
        row['worstUiAttribution'] = {
            'samples': total,
            'categories': {k: round(100 * v / total, 1) for k, v in sorted((worst_cpu.get('categories') or {}).items(), key=lambda kv: -kv[1])} if total else {},
            'app': [{'name': e['name'], 'pct': round(100 * e['value'] / total, 1)} for e in (worst_cpu.get('appInclusive') or [])[:8]] if total else [],
            'all': [{'name': e['name'], 'pct': round(100 * e['value'] / total, 1)} for e in (worst_cpu.get('inclusive') or [])[:25]] if total else [],
            'self': [{'name': e['name'], 'pct': round(100 * e['value'] / total, 1)} for e in (worst_cpu.get('self') or [])[:8]] if total else [],
        }
        raster = (attribution.get('rasterWorstFrames') or {}).get('inclusiveUs') or []
        row['worstRasterAttribution'] = [{'name': e['name'], 'ms': ms(e['value'])} for e in raster[:8]]
    return row


def load_run(run):
    run = Path(run)
    records = []
    for path in sorted(run.glob('*.json')):
        if path.name.endswith('.attribution.json') or path.name.startswith(('lab-', 'env', 'summary', 'compare', 'driver-')):
            continue
        data = json.loads(path.read_text())
        if isinstance(data, dict) and 'scenario' in data and 'frames' in data:
            att = run / f"{data['theme']}-{data['scenario']}.attribution.json"
            records.append((data, json.loads(att.read_text()) if att.is_file() else None))
    return records


def order_key(row):
    s = row['scenario']
    if s.startswith('mount-'):
        k = s[6:]
        return (1, ROW_KINDS.index(k) if k in ROW_KINDS else 99, row['theme'])
    return (0, SCENARIO_ORDER.index(s) if s in SCENARIO_ORDER else 99, row['theme'])


def summarize(run):
    run = Path(run)
    rows = sorted((summarize_record(r, a) for r, a in load_run(run)), key=order_key)
    env = json.loads((run / 'env.json').read_text()) if (run / 'env.json').is_file() else {}
    names = ' '.join(e['name'] for _, a in load_run(run) if a for e in (a.get('rasterWorstFrames') or {}).get('inclusiveUs', []))
    backend = next((label for key, label in (('GLES', 'Impeller (OpenGLES)'), ('Vulkan', 'Impeller (Vulkan)'), ('VK', 'Impeller (Vulkan)'), ('Metal', 'Impeller (Metal)'), ('MTL', 'Impeller (Metal)')) if key in names), None)
    if backend or names:
        env['renderer'] = backend or 'Skia (no Impeller raster events)'
    hello = json.loads((run / 'lab-hello.json').read_text()) if (run / 'lab-hello.json').is_file() else {}
    notes = [json.loads(l) for l in (run / 'lab-notes.jsonl').read_text().splitlines()] if (run / 'lab-notes.jsonl').is_file() else []
    summary = {'format': 'raft-perf-lab-v1', 'run': run.name, 'env': env, 'hello': hello, 'notes': notes, 'scenarios': rows,
               'gate60Passed': bool(rows) and all(r['gate60'] for r in rows)}
    (run / 'summary.json').write_text(json.dumps(summary, indent=1, ensure_ascii=False) + '\n')
    (run / 'summary.md').write_text(markdown(summary))
    return summary


def fmt_dist(d):
    return f"{ms(d['p50'])} / {ms(d['p90'])} / {ms(d['p99'])} / {ms(d['max'])}"


def fmt_cpu(r):
    """Process CPU of the scenario: seconds, share of one core, and per frame
    (the lab process: UI, raster, GC helpers and the VM-service sampler)."""
    cpu, elapsed = r.get('cpuSeconds'), r.get('elapsedSeconds')
    if cpu is None:
        return '-'
    share = f'{100 * cpu / elapsed:.0f}%' if elapsed else '-'
    per = f"{1000 * cpu / r['frames']:.1f}" if r.get('frames') else '-'
    ui = r.get('uiThreadCpuSeconds')
    ui_per = f", UI thread {1000 * ui / r['frames']:.2f} ms/frame" if ui is not None and r.get('frames') else ''
    return f'{cpu:.2f} / {share} / {per}{ui_per}'


def markdown(summary):
    env, hello = summary.get('env', {}), summary.get('hello', {})
    out = [f"# Perf lab run `{summary['run']}`", '']
    out.append(f"- Commit: `{env.get('commit', '?')}`{' (dirty)' if env.get('dirty') else ''}; fixture `{hello.get('fixtureVersion', '?')}`")
    if hello.get('fixturePagination') == 'requested-limit-v1':
        out.append(f'- Pagination: {PAGINATION_NOTE}')
    out.append(f"- Engine: Flutter {env.get('flutter', {}).get('frameworkVersion', '?')} (engine `{str(env.get('flutter', {}).get('engineRevision', '?'))[:10]}`), renderer: {env.get('renderer', '?')}")
    out.append(f"- Host: {env.get('os', '?')}; CPU: {env.get('cpu', '?')}; GPU: {env.get('gpu', '?')}")
    load = lambda key: ', '.join(f'{v:.1f}' for v in env.get(key) or []) or '?'
    out.append(f"- Host load (1/5/15 min) at start: {load('loadavg')}; at end: {load('loadavgEnd')}" + (' — **NOISY HOST: other work was running; do not use these numbers as a baseline**' if env.get('noisyHost') else ''))
    first = summary['scenarios'][0] if summary['scenarios'] else {}
    out.append(f"- Display: {hello.get('displayRefreshRate', '?')} Hz, DPR {hello.get('devicePixelRatio', '?')}, view {first.get('view', '?')} physical px; semantics mode `{hello.get('semantics', '?')}` (embedder requested: {hello.get('platformSemanticsEnabled', '?')}); phase collection {'on' if hello.get('phases') else 'off'}")
    out.append(f"- Gate (60 Hz: no UI or raster frame over 16.7 ms, no stutter): **{'PASS' if summary['gate60Passed'] else 'FAIL'}**. Target: every frame within 8.33 ms (120 Hz).")
    out += ['', '## Frames (ms: p50 / p90 / p99 / max)', '',
            '| Scenario | Theme | Frames | UI thread (build+layout+paint+semantics) | Raster | >8.33 ms (UI/R, either %) | >16.7 ms (UI/R) | Stutter | GC | Semantics % | Process CPU (s, % of a core, ms/frame) | Gate 60 |',
            '|---|---|---|---|---|---|---|---|---|---|---|---|']
    for r in summary['scenarios']:
        out.append(f"| {r['scenario']} | {r['theme']} | {r['frames']} | {fmt_dist(r['uiUs'])} | {fmt_dist(r['rasterUs'])} | {r['over8Ui']}/{r['over8Raster']} ({r['over8EitherPct']}%) | {r['over16Ui']}/{r['over16Raster']} | {r['stutters']} | {r.get('gcCount', '-')} | {r['semanticsShare']} | {fmt_cpu(r)} | {'pass' if r['gate60'] else 'FAIL'} |")
    sections = [r for r in summary['scenarios'] if r['scenario'].startswith('section-')]
    if sections:
        out += ['', '## Populated mobile sections', '',
                '| Scenario | Theme | Chat rows | Visible task tags | Tasks / mounted cards | Files / decoded thumbnails | Accepted sections |',
                '|---|---|---|---|---|---|---|']
        for r in sections:
            visits = ' → '.join(r.get('sectionVisits', [])) or r.get('acceptedSection', '?')
            out.append(f"| {r['scenario']} | {r['theme']} | {r.get('chatRows', r.get('taggedChatRows', '?'))} | {r.get('visibleChatTags', '?')} | {r.get('taskRows', '?')} / {r.get('retainedTaskCards', '?')} | {r.get('fileRows', '?')} / {r.get('decodedFileThumbnails', '?')} | {visits} |")
    mounts = [r for r in summary['scenarios'] if 'mount' in r]
    if mounts:
        out += ['', '## New-row mount cost (UI µs of the frame that mounts rows, divided by rows mounted)', '',
                '| Row kind | Theme | Rows | Per row p50 / p90 / max | Per row UI-thread CPU p50 / p90 (us) | Mount frame p50 / max (ms) | Follow-up frames p50 (ms) | First (cold) step (ms) |', '|---|---|---|---|---|---|---|---|']
        for r in mounts:
            m = r['mount']
            out.append(f"| {m['rowKind']} | {r['theme']} | {m['rowsMounted']} | {round(m['perRowUs']['p50'])} / {round(m['perRowUs']['p90'])} / {round(m['perRowUs']['max'])} | {round(m['perRowCpuUs']['p50'])} / {round(m['perRowCpuUs']['p90'])} | {ms(m['mountFrameUs']['p50'])} / {ms(m['mountFrameUs']['max'])} | {ms(m['followUpUs']['p50'])} | {ms(m['coldFirstStepUs'])} |")
    trans = [r for r in summary['scenarios'] if 'opens' in r]
    if trans:
        out += ['', '## Transitions', '', '| Scenario | Theme | Opens | Visible ms (p50 / max) | Worst UI frame per open (ms) |', '|---|---|---|---|---|']
        for r in trans:
            out.append(f"| {r['scenario']} | {r['theme']} | {len(r['opens'])} | {r['visibleMs']['p50']} / {r['visibleMs']['max']} | {', '.join(str(o['worstUiMs']) for o in r['opens'])} |")
    keys = [r for r in summary['scenarios'] if 'keyboard' in r]
    if keys:
        out += ['', '## Soft keyboard', '',
                'The rows below count only the inset slides. The hold between an open and a close is not included. 8.33 ms and 16.7 ms are this lab\'s frame budgets. Build, layout and paint figures are the average count per frame, a reference, not a gate. Slide UI CPU is the UI thread\'s schedstat time over the slides. The lines under the table are per-frame timeline thread CPU (`tdur`) next to the wall-clock median. Scene CPU, when the next line is present, is `/proc` schedstat nanoseconds for the whole scenario, not `tts`.',
                '',
                '| Theme | Frames | Worst UI ms | Worst raster ms | >8.33 ms (UI/R) | >16.7 ms (UI/R) | Builds per frame | Layouts per frame | Paints per frame | Slide UI CPU ms |',
                '|---|---|---|---|---|---|---|---|---|---|']
        def work_pair(k, name):
            counted = k.get(name)
            if not counted:
                return '-'
            return f"{counted['mean']:.1f}"
        for r in keys:
            k = r['keyboard']
            cpu = k.get('uiThreadCpuUs')
            cpu_cell = '-' if cpu is None else f'{cpu / 1000:.1f}'
            out.append(f"| {r['theme']} | {k['frames']} | {k['worstUiMs']} | {k['worstRasterMs']} | {k['over8Ui']}/{k['over8Raster']} | {k['over16Ui']}/{k['over16Raster']} | {work_pair(k, 'builds')} | {work_pair(k, 'layouts')} | {work_pair(k, 'paints')} | {cpu_cell} |")
            out.append(f"- {r['theme']}: {_thread_time_line(k, r.get('threadTime') or {})}")
            proc_line = _proc_cpu_line(r.get('procThreadCpu'))
            if proc_line:
                out.append(f"- {r['theme']}: {proc_line}")
    out += ['', '## Worst-frame attribution', '']
    for r in summary['scenarios']:
        att = r.get('worstUiAttribution') or {}
        phases = ', '.join(f"{k} {v}%" for k, v in list(r['phaseShare'].items())[:5])
        out.append(f"- **{r['scenario']} / {r['theme']}**: worst UI {', '.join(str(f['uiMs']) for f in r['worstUiFrames'])} ms; phase share {phases or 'n/a'}")
        if att.get('categories'):
            out.append('  - worst-frame CPU by category (inclusive %): ' + ', '.join(f"{k} {v}%" for k, v in att['categories'].items()))
        if att.get('app'):
            out.append('  - app code (inclusive % of worst-frame samples): ' + '; '.join(f"{e['name']} {e['pct']}%" for e in att['app'][:5]))
        if att.get('self'):
            out.append('  - hottest leaf functions: ' + '; '.join(f"{e['name']} {e['pct']}%" for e in att['self'][:4]))
        if r.get('worstRasterAttribution'):
            out.append('  - raster: ' + '; '.join(f"{e['name']} {e['ms']}ms" for e in r['worstRasterAttribution'][:4]))
        extra = {k: r[k] for k in ('movedPx', 'anchorDriftPx', 'olderPagesServed', 'imageReads', 'gcTimeMs', 'gcInWorstUiFrames') if k in r}
        if extra:
            out.append('  - ' + ', '.join(f"{k} {v}" for k, v in extra.items()))
    if summary.get('notes'):
        out += ['', '## Notes', ''] + [f"- {json.dumps(n, ensure_ascii=False)}" for n in summary['notes']]
    return '\n'.join(out) + '\n'


# ---------------------------------------------------------------- compare

COMPARED = [('uiUs', 'p90'), ('uiUs', 'p99'), ('uiUs', 'max'), ('rasterUs', 'p90'), ('rasterUs', 'p99'), ('rasterUs', 'max')]


def compare(base, cand, threshold=0.10, floor_us=500):
    b = {(r['theme'], r['scenario']): r for r in base['scenarios']}
    c = {(r['theme'], r['scenario']): r for r in cand['scenarios']}
    problems, rows = [], []
    if base.get('hello', {}).get('fixtureVersion') != cand.get('hello', {}).get('fixtureVersion'):
        problems.append('fixture versions differ; numbers are not comparable')
    views = lambda s: sorted({r.get('view') for r in s['scenarios']})
    if views(base) != views(cand):
        problems.append(f'view sizes differ: {views(base)} vs {views(cand)} (layout cost scales with width)')
    for name, run in (('base', base), ('candidate', cand)):
        if run.get('env', {}).get('noisyHost'):
            problems.append(f'{name} run was taken on a noisy host (load above limit)')
    for key in ('cpu', 'gpu', 'renderer', 'os'):
        if base.get('env', {}).get(key) != cand.get('env', {}).get(key):
            problems.append(f'environment differs: {key}')
    if base.get('env', {}).get('flutter', {}).get('engineRevision') != cand.get('env', {}).get('flutter', {}).get('engineRevision'):
        problems.append('environment differs: Flutter engine')
    for key in sorted(set(b) & set(c), key=lambda k: order_key({'theme': k[0], 'scenario': k[1]})):
        x, y = b[key], c[key]
        row = {'theme': key[0], 'scenario': key[1], 'regressions': [], 'improvements': [], 'metrics': {}}
        for group, q in COMPARED:
            old, new = x[group][q], y[group][q]
            row['metrics'][f'{group}.{q}'] = (old, new)
            # Single-frame maxima are reported but too noisy to flag; frames
            # beyond the 60 Hz budget are flagged through over16 counts.
            if q == 'max':
                continue
            if new > old * (1 + threshold) and new - old > floor_us:
                row['regressions'].append(f'{group[:-2]} {q} {ms(old)}→{ms(new)} ms')
            elif new < old * (1 - threshold) and old - new > floor_us:
                row['improvements'].append(f'{group[:-2]} {q} {ms(old)}→{ms(new)} ms')
        for metric in ('over16Ui', 'over16Raster', 'stutters'):
            row['metrics'][metric] = (x[metric], y[metric])
            if y[metric] > x[metric]:
                row['regressions'].append(f'{metric} {x[metric]}→{y[metric]}')
            elif y[metric] < x[metric]:
                row['improvements'].append(f'{metric} {x[metric]}→{y[metric]}')
        row['metrics']['over8EitherPct'] = (x['over8EitherPct'], y['over8EitherPct'])
        if y['over8EitherPct'] > x['over8EitherPct'] + 2:
            row['regressions'].append(f"frames over 8.33 ms {x['over8EitherPct']}%→{y['over8EitherPct']}%")
        elif y['over8EitherPct'] < x['over8EitherPct'] - 2:
            row['improvements'].append(f"frames over 8.33 ms {x['over8EitherPct']}%→{y['over8EitherPct']}%")
        if x['gate60'] and not y['gate60']:
            row['regressions'].append('60 Hz gate pass→FAIL')
        if 'mount' in x and 'mount' in y:
            old, new = x['mount']['perRowUs']['p50'], y['mount']['perRowUs']['p50']
            row['metrics']['mount.perRow.p50'] = (old, new)
            if new > old * (1 + threshold) and new - old > 100:
                row['regressions'].append(f'per-row mount p50 {round(old)}→{round(new)} µs')
            elif new < old * (1 - threshold) and old - new > 100:
                row['improvements'].append(f'per-row mount p50 {round(old)}→{round(new)} µs')
        if 'visibleMs' in x and 'visibleMs' in y:
            row['metrics']['visibleMs.p50'] = (x['visibleMs']['p50'], y['visibleMs']['p50'])
        if 'keyboard' in x and 'keyboard' in y:
            kx, ky = x['keyboard'], y['keyboard']
            for field in ('frames', 'worstUiMs', 'worstRasterMs', 'over8Ui', 'over8Raster', 'over16Ui', 'over16Raster', 'uiThreadCpuUs'):
                row['metrics'][f'keyboard.{field}'] = (kx.get(field), ky.get(field))
            for count in ('builds', 'layouts', 'paints'):
                old, new = kx.get(count) or {}, ky.get(count) or {}
                # Native counts move with the frame count. The per-frame mean
                # stays in the report as a reference and does not change the
                # comparison.
                row['metrics'][f'keyboard.{count}'] = ({'mean': old.get('mean')}, {'mean': new.get('mean')})
        rows.append(row)
    missing = sorted(set(b) ^ set(c))
    return {'problems': problems, 'missing': [list(k) for k in missing], 'rows': rows,
            'regressions': sum(len(r['regressions']) for r in rows)}


def compare_markdown(result, base_name, cand_name):
    out = [f'# Perf lab compare: `{base_name}` → `{cand_name}`', '']
    for p in result['problems']:
        out.append(f'- WARNING: {p}')
    if result['missing']:
        out.append(f"- Scenarios present in only one run: {', '.join('/'.join(k) for k in result['missing'])}")
    out += ['', '| Scenario | Theme | UI p99 (ms) | Raster p99 (ms) | >8.33 % | >16.7 UI/R | Regressions | Improvements |', '|---|---|---|---|---|---|---|---|']
    for r in result['rows']:
        m = r['metrics']
        out.append(f"| {r['scenario']} | {r['theme']} | {ms(m['uiUs.p99'][0])}→{ms(m['uiUs.p99'][1])} | {ms(m['rasterUs.p99'][0])}→{ms(m['rasterUs.p99'][1])} | {m['over8EitherPct'][0]}→{m['over8EitherPct'][1]} | {m['over16Ui'][0]}/{m['over16Raster'][0]}→{m['over16Ui'][1]}/{m['over16Raster'][1]} | {'**' + '; '.join(r['regressions']) + '**' if r['regressions'] else ''} | {'; '.join(r['improvements'])} |")
    keyboard_rows = [r for r in result['rows'] if 'keyboard.worstUiMs' in r['metrics']]
    if keyboard_rows:
        out += ['', '## Soft keyboard (animation frames only)', '',
                'Worst milliseconds and the 8.33 / 16.7 ms counts are the slide frames. UI-thread CPU is on-CPU time during those slides. Build, layout and paint figures are the average count per frame, a reference, not a gate.',
                '',
                '| Scenario | Theme | Worst UI ms | Worst raster ms | >8.33 UI/R | >16.7 UI/R | Builds per frame | Layouts per frame | Paints per frame | UI-thread CPU ms |',
                '|---|---|---|---|---|---|---|---|---|---|']
        for r in keyboard_rows:
            m = r['metrics']
            def side(field, index, scale=1):
                value = m.get(f'keyboard.{field}', (None, None))[index]
                if value is None:
                    return '-'
                return f'{value / scale:.1f}' if scale != 1 else str(value)
            def duo(ui_field, raster_field):
                def one(index):
                    ui = m.get(f'keyboard.{ui_field}', (None, None))[index]
                    raster = m.get(f'keyboard.{raster_field}', (None, None))[index]
                    if ui is None or raster is None:
                        return '-'
                    return f'{ui}/{raster}'
                return f'{one(0)}→{one(1)}'
            def means(name):
                def one(index):
                    counted = m.get(f'keyboard.{name}', ({}, {}))[index] or {}
                    value = counted.get('mean')
                    return '-' if value is None else f'{value:.1f}'
                return f'{one(0)}→{one(1)}'
            out.append(
                f"| {r['scenario']} | {r['theme']} | {side('worstUiMs', 0)}→{side('worstUiMs', 1)} | {side('worstRasterMs', 0)}→{side('worstRasterMs', 1)} | {duo('over8Ui', 'over8Raster')} | {duo('over16Ui', 'over16Raster')} | {means('builds')} | {means('layouts')} | {means('paints')} | {side('uiThreadCpuUs', 0, 1000)}→{side('uiThreadCpuUs', 1, 1000)} |")
    out += ['', f"Total regressions: {result['regressions']}"]
    return '\n'.join(out) + '\n'


# ---------------------------------------------------------------- run

def capture(args, **kw):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=60, **kw).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ''


def environment(device):
    env = {'os': f'{platform.system()} {platform.release()}', 'machine': platform.machine(), 'device': device,
           'commit': capture(['git', 'rev-parse', 'HEAD'], cwd=ROOT),
           'dirty': bool(capture(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT)),
           'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'loadavg': os.getloadavg()}
    try:
        env['flutter'] = json.loads(capture([str(ROOT / 'tool/flutter'), '--version', '--machine']))
    except ValueError:
        env['flutter'] = {}
    if platform.system() == 'Linux':
        model = re.search(r'model name\s*:\s*(.+)', Path('/proc/cpuinfo').read_text())
        env['cpu'] = f"{model.group(1) if model else '?'} x{os.cpu_count()}"
        gov = Path('/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor')
        env['cpuGovernor'] = gov.read_text().strip() if gov.is_file() else None
        glx = capture(['glxinfo', '-B'])
        renderer = re.search(r'OpenGL renderer string:\s*(.+)', glx)
        env['gpu'] = renderer.group(1) if renderer else '?'
        env['session'] = os.environ.get('XDG_SESSION_TYPE')
    elif platform.system() == 'Darwin':
        env['cpu'] = f"{capture(['sysctl', '-n', 'machdep.cpu.brand_string'])} x{os.cpu_count()}"
        displays = capture(['system_profiler', 'SPDisplaysDataType'])
        chip = re.search(r'Chipset Model:\s*(.+)', displays)
        env['gpu'] = chip.group(1) if chip else '?'
        env['displays'] = re.findall(r'Resolution:\s*(.+)|UI Looks like:\s*(.+)', displays)
    return env


def _digest(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def _sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_snapshot():
    names = subprocess.check_output(['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT).decode().split('\0')
    files = {name: _sha(ROOT / name) for name in sorted(set(names)) if name and (ROOT / name).is_file()}
    return {'digest': _digest(files), 'files': files, 'commit': capture(['git', 'rev-parse', 'HEAD'], cwd=ROOT)}


def artifact_snapshot(directory):
    directory = directory.resolve()
    files = {str(path.relative_to(directory)): _sha(path) for path in sorted(directory.rglob('*')) if path.is_file()}
    if not files or 'raft_flutter' not in files:
        raise ValueError('Linux profile bundle has no raft_flutter executable')
    return {'path': str(directory), 'digest': _digest(files), 'files': files}


def same_source(left, right):
    # A later commit with identical source bytes does not invalidate a build.
    # Keep the build's original revision in the receipt instead of rewriting it.
    return left.get('digest') == right.get('digest') and left.get('files') == right.get('files')


def workload_config(args):
    rounds = getattr(args, 'rounds', None)
    config = {'themes': args.themes, 'scenarios': args.scenarios or '', 'seconds': args.seconds,
            'semantics': args.semantics, 'phases': not args.no_trace,
            'rounds': rounds if rounds is not None else int(os.environ.get('RAFT_LAB_ROUNDS', '1'))}
    if config['seconds'] <= 0 or config['rounds'] <= 0:
        sys.exit('Duration and measured round count must be positive.')
    if getattr(args, 'detection', False):
        config.update(problemDetection=True, idleSeconds=10)
    return config


def workload_defines(config):
    defines = {'RAFT_LAB_THEMES': config['themes'], 'RAFT_LAB_SCENARIOS': config['scenarios'],
            'RAFT_LAB_SECONDS': str(config['seconds']), 'RAFT_LAB_SEMANTICS': config['semantics'],
            'RAFT_LAB_PHASES': str(config['phases']).lower(), 'RAFT_LAB_ROUNDS': str(config['rounds'])}
    if config.get('problemDetection'):
        defines.update(RAFT_LAB_DETECT='true', RAFT_LAB_IDLE_SECONDS=str(config['idleSeconds']))
    return defines


def flutter_toolchain():
    version = json.loads(capture([str(ROOT / 'tool/flutter'), '--version', '--machine']))
    result = {key: version.get(key) for key in ('frameworkRevision', 'engineRevision', 'dartSdkVersion')}
    if not all(isinstance(value, str) and value for value in result.values()):
        raise ValueError('Flutter toolchain identity is incomplete.')
    return result


def linux_build_preflight():
    # A failed first configure can leave /usr/local cached as the install
    # prefix. A retry must not install outside this worktree's bundle.
    if not (ROOT / '.local/media-linux/bundle/libs/libmpv.so.2').is_file():
        raise ValueError('Prepared Linux media runtime is missing. Run tool/prepare-media-linux before building.')
    build_root = APP / 'build/linux'
    if not build_root.resolve().is_relative_to(APP.resolve()):
        raise ValueError(f'Linux build directory escapes this app directory: {build_root}')
    for profile in build_root.glob('*/profile'):
        bundle = profile / 'bundle'
        if not bundle.resolve().is_relative_to(APP.resolve()):
            raise ValueError(f'Linux bundle escapes this app directory: {bundle}')
        cache = profile / 'CMakeCache.txt'
        if cache.is_file():
            prefix = re.search(r'^CMAKE_INSTALL_PREFIX:[^=]+=(.*)$', cache.read_text(), re.MULTILINE)
            if not prefix or Path(prefix.group(1)).resolve() != bundle.resolve():
                raise ValueError(f'Unsafe CMake install prefix in {cache}. Preserve this failed cache, then reset this worktree cache before retrying; expected {bundle}.')


def build(args):
    """Build an isolated Linux fixture and bind immutable source to its bundle.

    No app is installed or launched. The copied bundle and receipt are kept
    even on a source-change failure; callers must not relabel that failure.
    """
    if platform.system() != 'Linux':
        sys.exit('This receipt builder supports Linux only; existing platform build paths are unchanged.')
    if args.out.exists():
        sys.exit('Build output already exists; use a new directory.')
    if not re.fullmatch(r'(\.[a-z][a-z0-9_]*)+', args.identity_suffix):
        sys.exit('An isolated identity suffix such as .m7old is required.')
    config = workload_config(args)
    defines = {**workload_defines(config), 'RAFT_LINUX_APPLICATION_ID_SUFFIX': args.identity_suffix}
    argv = [str(ROOT / 'tool/flutter'), 'build', 'linux', '--profile', f'--target={TARGET}', '--no-pub',
            *[f'--dart-define={key}={value}' for key, value in defines.items()]]
    flutter_guard(argv[1:], cwd=APP)
    before = source_snapshot()
    args.out.mkdir(parents=True)
    receipt = {'schema': 1, 'source': before, 'config': config, 'identitySuffix': args.identity_suffix,
               'argv': argv, 'cwd': str(APP), 'startedAt': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    with (args.out / 'build.log').open('w') as log:
        try:
            linux_build_preflight()
            receipt['toolchain'] = flutter_toolchain()
            status = subprocess.run(argv, cwd=APP, env={**os.environ, 'RAFT_APPLICATION_ID_SUFFIX': args.identity_suffix},
                                    stdout=log, stderr=subprocess.STDOUT).returncode
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            status = 1
            receipt['error'] = str(error)
            log.write(str(error) + '\n')
    after = source_snapshot()
    receipt['sourceAfter'] = after
    receipt['exitCode'] = status
    if status == 0:
        bundles = list((APP / 'build/linux').glob('*/profile/bundle'))
        if len(bundles) != 1:
            receipt.update(exitCode=1, error='Expected exactly one Linux profile bundle.')
        else:
            shutil.copytree(bundles[0], args.out / 'bundle', symlinks=True)
            receipt['artifact'] = artifact_snapshot(args.out / 'bundle')
    if before != after:
        receipt.update(exitCode=1, error='Source changed during the build.')
    receipt['endedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    (args.out / 'build-receipt.json').write_text(json.dumps(receipt, indent=1) + '\n')
    print(f"Build receipt: {args.out / 'build-receipt.json'}; exit={receipt['exitCode']}")
    return 0 if receipt['exitCode'] == 0 else 1


def _cpu_list(text):
    result = set()
    for part in text.strip().split(','):
        limits = [int(value) for value in part.split('-')]
        result.update(range(limits[0], limits[-1] + 1))
    return sorted(result)


def cpu_topology():
    result = []
    for cpu in _cpu_list(Path('/sys/devices/system/cpu/online').read_text()):
        root = Path(f'/sys/devices/system/cpu/cpu{cpu}/topology')
        result.append({'cpu': cpu, 'core': int((root / 'core_id').read_text()),
                       'socket': int((root / 'physical_package_id').read_text()),
                       'siblings': _cpu_list((root / 'thread_siblings_list').read_text())})
    return result


def host_cpu_snapshot():
    """CPU occupancy without process arguments, environment or user data."""
    processes = {}
    for path in Path('/proc').glob('[0-9]*/stat'):
        try:
            text = path.read_text()
            fields = text[text.rfind(')') + 2:].split()
            processes[path.parent.name] = {'startTicks': int(fields[19]), 'cpuTicks': int(fields[11]) + int(fields[12]),
                                            'name': text[text.index('(') + 1:text.rfind(')')]}
        except (OSError, ValueError, IndexError):
            continue  # unrelated processes can exit while the snapshot is read
    return {'monotonicNs': time.monotonic_ns(), 'ticksPerSecond': os.sysconf('SC_CLK_TCK'), 'processes': processes}


def host_cpu_delta(before, after):
    seconds = (after['monotonicNs'] - before['monotonicNs']) / 1e9
    rows = []
    for pid, end in after['processes'].items():
        start = before['processes'].get(pid)
        if start and start['startTicks'] == end['startTicks'] and end['cpuTicks'] >= start['cpuTicks'] and seconds > 0:
            rows.append({'pid': int(pid), 'name': end['name'], 'cpuPercent':
                         100 * (end['cpuTicks'] - start['cpuTicks']) / after['ticksPerSecond'] / seconds})
    return {'intervalSeconds': seconds, 'scope': 'entire drive, including startup; not individual frame windows',
            'coverage': 'processes alive at both snapshots; newly started or exited processes are not estimated',
            'startedCount': len(after['processes'].keys() - before['processes'].keys()),
            'exitedCount': len(before['processes'].keys() - after['processes'].keys()),
            'processes': sorted(rows, key=lambda row: -row['cpuPercent'])[:20]}


def run_owned_process(command, *, process_groups=None, **kwargs):
    """Keep detached and sandboxed descendants in one private user scope.

    A process can change its session or hide its environment; neither moves it
    out of the scope's cgroup. Never discover cleanup targets by process name.
    """
    unit = f'raft-detect-{uuid.uuid4().hex}.scope'
    child = dict(kwargs.pop('env', os.environ))
    private_runtime = child.get('XDG_RUNTIME_DIR')
    # systemd-run must contact the real user manager. Only its launched
    # command receives the private compositor runtime directory.
    child['XDG_RUNTIME_DIR'] = os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')
    launch = ['systemd-run', '--user', '--scope', '--quiet', '--collect', '--no-ask-password',
              f'--unit={unit}', '--property=TimeoutStopSec=2s']
    if private_runtime:
        launch.append(f'--setenv=XDG_RUNTIME_DIR={private_runtime}')
    launch += ['--', *command]
    process = subprocess.Popen(launch, start_new_session=True, env=child, **kwargs)
    group = {'leaderPid': process.pid, 'processGroup': process.pid,
             'command': Path(command[0]).name, 'unit': unit, 'stopSignals': []}

    def state():
        result = subprocess.run(['systemctl', '--user', 'show', '--no-pager',
            '--property=LoadState,ActiveState,ControlGroup', unit], capture_output=True, text=True, timeout=5)
        values = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
        if not values or values.get('LoadState') not in ('loaded', 'not-found'):
            raise RuntimeError('Could not verify the private systemd scope state.')
        return values

    try:
        if process_groups is not None:
            process_groups.append(group)
        return process.wait()
    finally:
        # Reap the starter first: it must not create a scope after we stop it.
        for stop_signal in (signal.SIGTERM, signal.SIGKILL):
            if process.poll() is not None:
                break
            try:
                os.killpg(process.pid, stop_signal)
                group['stopSignals'].append(stop_signal.name)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                continue
        process.wait(timeout=2)
        group['leaderExitCode'] = process.returncode
        before = state()
        group['controlGroup'] = before.get('ControlGroup')
        if before['LoadState'] == 'loaded':
            stopped = subprocess.run(['systemctl', '--user', 'stop', unit],
                capture_output=True, text=True, timeout=8)
            group['scopeStopExitCode'] = stopped.returncode
        after = state()
        # --collect can unload the now-empty scope between show and stop.
        # Its fresh state and cgroup emptiness decide cleanup, not that race's
        # "unit not loaded" exit status.
        cgroup = before.get('ControlGroup')
        populated = None
        if cgroup:
            events = Path('/sys/fs/cgroup') / cgroup.lstrip('/') / 'cgroup.events'
            try:
                populated = dict(line.split() for line in events.read_text().splitlines()).get('populated')
            except FileNotFoundError:
                populated = '0'  # An unloaded, removed cgroup has no members.
        group['scopeAfter'] = after
        group['cgroupPopulatedAfter'] = populated
        group['cleanupComplete'] = (after.get('LoadState') == 'not-found' or
            after.get('ActiveState') in ('inactive', 'failed')) and populated in (None, '0')
        if not group['cleanupComplete']:
            raise RuntimeError('The private systemd scope still has active members after cleanup.')


def cleanup_private_runtime(directory):
    """Unmount only this owned session's FUSE helpers before deleting it."""
    root = Path(directory)
    if root.parent != Path('/tmp') or not root.name.startswith('raft-detect-') or root.is_symlink():
        raise ValueError('Refusing cleanup outside the owned private runtime.')
    mounts = [Path(line.split()[4].replace('\\040', ' '))
              for line in Path('/proc/self/mountinfo').read_text().splitlines()]
    actions = []
    for mount in sorted((m for m in mounts if m.is_relative_to(root)), key=lambda p: -len(p.parts)):
        try:
            result = subprocess.run(['fusermount3', '-u', '-z', '--', str(mount)], capture_output=True, text=True)
            actions.append({'mount': str(mount), 'exitCode': result.returncode, 'stderr': result.stderr.strip()})
        except OSError as failure:
            actions.append({'mount': str(mount), 'exitCode': None, 'stderr': str(failure)})
    error = None
    try:
        shutil.rmtree(root)
    except OSError as failure:
        error = str(failure)
    return {'path': str(root), 'unmounts': actions, 'removed': not root.exists(), 'error': error}


def concurrent_run(device):
    requested = os.environ.get('RAFT_LAB_ALLOW_CONCURRENT') == '1' or bool(os.environ.get('RAFT_LAB_SYNC_DIR'))
    if requested and (platform.system() != 'Linux' or device != 'linux' or not os.environ.get('RAFT_LAB_SYNC_DIR')
                      or not re.fullmatch(r'[A-Za-z0-9_-]+', os.environ.get('RAFT_LAB_PAIR', ''))
                      or os.environ.get('RAFT_LAB_ORDER') not in ('old', 'new')):
        sys.exit('Concurrent sampling requires Linux, a fresh sync directory, pair ID and old/new side.')
    return requested


def run_manifest(args, config):
    if not getattr(args, 'build_receipt', None):
        sys.exit('Concurrent runs require --build-receipt from the isolated build command.')
    if len(args.flutter_args) != 1 or not args.flutter_args[0].startswith('--use-application-binary='):
        sys.exit('Concurrent runs accept exactly one --use-application-binary=<verified bundle executable>.')
    binary = Path(args.flutter_args[0].split('=', 1)[1]).resolve()
    receipt = json.loads(args.build_receipt.read_text())
    source, artifact = source_snapshot(), artifact_snapshot(binary.parent)
    toolchain = flutter_toolchain()
    if (binary.name != 'raft_flutter' or receipt.get('exitCode') != 0 or not receipt.get('identitySuffix')
        or receipt.get('sourceAfter') != receipt.get('source') or not same_source(receipt.get('source', {}), source)
        or any(receipt.get(key) != value for key, value in (('artifact', artifact), ('config', config), ('toolchain', toolchain)))):
        sys.exit('Source, configuration, toolchain or artifact differs from the successful isolated build receipt.')
    safe_keys = ('DISPLAY', 'GDK_BACKEND', 'VK_ICD_FILENAMES', '__EGL_VENDOR_LIBRARY_FILENAMES', 'LIBGL_ALWAYS_SOFTWARE',
                 'RAFT_LAB_SYNC_DIR', 'RAFT_LAB_PAIR', 'RAFT_LAB_ORDER', 'RAFT_FLUTTER_BIN',
                 'XDG_RUNTIME_DIR', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME')
    manifest = {'schema': 1, 'source': receipt['source'], 'observedSource': source, 'artifact': artifact, 'buildReceipt': receipt, 'config': config, 'toolchain': toolchain,
            'driverSha256': _sha(APP / DRIVER), 'fixtureSha256': _sha(APP / TARGET),
            'invocation': sys.argv, 'environment': {key: os.environ[key] for key in safe_keys if key in os.environ},
            'bootId': Path('/proc/sys/kernel/random/boot_id').read_text().strip(),
            'cpus': sorted(os.sched_getaffinity(0)), 'topology': cpu_topology()}
    if getattr(args, 'detection', False):
        manifest.update(mode='problem-detection', naturalHostLoad=True)
    else:
        manifest.update(pair=os.environ['RAFT_LAB_PAIR'], order=os.environ['RAFT_LAB_ORDER'])
    return manifest


def other_instance():
    if platform.system() != 'Linux':
        return []
    lines = capture(['ps', '-eo', 'pid,args']).splitlines()
    return [l.strip() for l in lines if 'bundle/raft_flutter' in l]


def wait_for_display(args):
    if getattr(args, 'detection', False):
        # The caller already verified its isolated build receipt and uses a
        # private HOME/DBus session. It never waits for unrelated apps to exit.
        return
    if concurrent_run(args.device or 'linux'):
        return
    waited = 0
    while other_instance():
        if not args.wait:
            sys.exit('Another raft_flutter bundle is running on this display:\n' + '\n'.join(other_instance()) + '\nRe-run with --wait to poll.')
        time.sleep(15)
        waited += 15
        if waited > args.wait:
            sys.exit('Timed out waiting for the other raft_flutter instance to exit')


def max_load(args):
    return args.max_load if args.max_load is not None else (os.cpu_count() or 4) * 0.35


def wait_for_quiet_host(args):
    """Frame times scale with host contention (other builds/test suites on
    the same machine). Wait for the 1-minute load to drop below the limit."""
    waited = 0
    while os.getloadavg()[0] > max_load(args):
        if waited >= args.wait_quiet:
            if args.allow_noisy:
                print(f'WARNING: host load {os.getloadavg()[0]:.1f} exceeds {max_load(args):.1f}; results will be marked noisy', flush=True)
                return
            sys.exit(f'Host load {os.getloadavg()[0]:.1f} exceeds {max_load(args):.1f}; wait (--wait-quiet) or pass --allow-noisy')
        time.sleep(15)
        waited += 15


def run(args):
    out = args.out.resolve()
    if out.exists():
        sys.exit(f'{out} exists; use a new output directory so earlier runs stay unchanged')
    device = args.device or ('macos' if platform.system() == 'Darwin' else 'linux')
    argv = [str(ROOT / 'tool/flutter'), 'drive', '--profile', f'--driver={DRIVER}', f'--target={TARGET}', '-d', device, '--no-pub',
            *args.flutter_args]
    android = device not in ('macos', 'linux', 'windows', 'chrome', 'edge', 'web-server')
    if android:
        argv.append('--keep-app-running')
    try:
        flutter_guard(argv[1:], cwd=APP)
        protected_before = protected_state(device) if android else None
    except SafetyError as error:
        sys.exit(f'STOP: {error}')
    detection = getattr(args, 'detection', False)
    if device == 'linux' and not os.environ.get('DISPLAY') and not getattr(args, 'headless', False):
        sys.exit('DISPLAY must name the real X11 display (see docs/performance-lab.md)')
    concurrent = False if detection else concurrent_run(device)
    config = workload_config(args)
    manifest = run_manifest(args, config) if concurrent or detection else None
    wait_for_display(args)
    if not concurrent and not detection:
        wait_for_quiet_host(args)
    out.mkdir(parents=True)
    if android:
        # Freeze the verified test artifact; a concurrent Gradle build must not
        # replace the path that Flutter will later install.
        for index, argument in enumerate(argv):
            if argument.startswith('--use-application-binary='):
                source = argument.split('=', 1)[1]
                value_index = index
                break
            if argument == '--use-application-binary':
                source = argv[index + 1]
                value_index = index + 1
                break
        binary = out / 'test-profile.apk'
        shutil.copyfile((APP / source).resolve(), binary)
        binary.chmod(0o444)
        argv[value_index] = f'--use-application-binary={binary}' if argv[value_index].startswith('--use-application-binary=') else str(binary)
        try:
            flutter_guard(argv[1:], cwd=APP)
        except SafetyError as error:
            sys.exit(f'STOP: staged test APK verification failed: {error}')
    env = environment(device)
    if android:
        env['protectedAppBefore'] = protected_before
    (out / 'env.json').write_text(json.dumps(env, indent=1) + '\n')
    defines = workload_defines(config)
    child = dict(os.environ, RAFT_PERF_OUT=str(out), RAFT_LAB_ROOT=str(ROOT), RAFT_LAB_DEVICE=device, **defines)
    runtime_directory = None
    status = 1
    try:
        if detection:
            for key in list(child):
                if key.startswith('RAFT_LAB_') and key not in {*defines, 'RAFT_LAB_ROOT', 'RAFT_LAB_DEVICE'}:
                    child.pop(key)
            # Keep toolchain/package locations while giving the app a fresh profile.
            version = json.loads((ROOT / '.fvmrc').read_text())['flutter']
            candidates = [Path(os.environ['RAFT_FLUTTER_BIN'])] if os.environ.get('RAFT_FLUTTER_BIN') else [
                ROOT / '.fvm/flutter_sdk/bin/flutter', Path.home() / 'flutter-sdks/versions' / version / 'bin/flutter',
                Path.home() / 'fvm/versions' / version / 'bin/flutter']
            child['RAFT_FLUTTER_BIN'] = str(next(p for p in candidates if p.is_file()).resolve())
            child['PUB_CACHE'] = os.environ.get('PUB_CACHE', str(Path.home() / '.pub-cache'))
            child['DASH__SUPPRESS_ANALYTICS'] = 'true'
            for key, name in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'),
                              ('XDG_CACHE_HOME', 'cache'), ('XDG_STATE_HOME', 'state'), ('XDG_RUNTIME_DIR', 'runtime')]:
                directory = out / 'profile' / name
                directory.mkdir(parents=True, mode=0o700)
                child[key] = str(directory)
            manifest['isolatedProfile'] = str(out / 'profile')
            manifest['headlessRequested'] = bool(getattr(args, 'headless', False))
            # A private compositor has no window, input device or connection to
            # the user's desktop. A short path is required by AF_UNIX sockets.
            runtime_directory = tempfile.mkdtemp(prefix='raft-detect-', dir='/tmp')
            child.update(XDG_RUNTIME_DIR=runtime_directory, WAYLAND_DISPLAY='raft-detect', GDK_BACKEND='wayland')
            for key in ('DISPLAY', 'XAUTHORITY', 'WAYLAND_SOCKET'):
                child.pop(key, None)
            mesa_vendor = Path('/usr/share/glvnd/egl_vendor.d/50_mesa.json')
            if mesa_vendor.is_file():
                child.setdefault('__EGL_VENDOR_LIBRARY_FILENAMES', str(mesa_vendor))
            manifest['displaySession'] = {'backend': 'Weston headless GL', 'runtimeDirectory': runtime_directory,
                'virtualRefreshRateHz': 60, 'physicalDisplay': False,
                'eglVendorSelection': child.get('__EGL_VENDOR_LIBRARY_FILENAMES', 'system default')}
            suffix = manifest['buildReceipt']['identitySuffix']
            if f'app.raft.raft_flutter{suffix}'.encode() not in Path(manifest['artifact']['path'], 'raft_flutter').read_bytes():
                sys.exit('Isolated native application identity is absent from the verified executable.')
        if device == 'linux' and not detection:
            child['GDK_BACKEND'] = os.environ.get('RAFT_LAB_GDK_BACKEND', 'x11')
        argv += [f'--dart-define={k}={v}' for k, v in defines.items()]
        if manifest:
            manifest['driveArgv'] = argv
            (out / 'run-manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
        if detection:
            # Initialize only this new profile's CLI settings. The first-run
            # analytics notice would otherwise corrupt the pinned-SDK JSON check.
            with (out / 'sdk-init.log').open('w') as log:
                initialized = run_owned_process([child['RAFT_FLUTTER_BIN'], '--disable-analytics'],
                    process_groups=env.setdefault('processGroups', []),
                    cwd=APP, env=child, stdout=log, stderr=subprocess.STDOUT)
            if initialized:
                env.update(exitCode=initialized, preparationError='Isolated Flutter settings initialization failed; see sdk-init.log.')
                (out / 'env.json').write_text(json.dumps(env, indent=1) + '\n')
                return 1
        cpu_before = host_cpu_snapshot() if concurrent or detection else None
        print('Running:', ' '.join(argv), flush=True)
        for attempt in range(1, 2 if detection else 4):
            wait_for_display(args)
            with (out / 'runner.log').open('w') as log:
                launch = ['dbus-run-session', '--', 'weston', '--backend=headless', '--renderer=gl',
                    '--width=1280', '--height=900', '--refresh-rate=60000', '--socket=raft-detect',
                    '--no-config', '--idle-time=0', f'--log={out / "compositor.log"}', '--', *argv] if detection else argv
                if manifest:
                    manifest['launchArgv'] = launch
                    (out / 'run-manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
                status = (run_owned_process(launch, process_groups=env.setdefault('processGroups', []),
                          cwd=APP, env=child, stdout=log, stderr=subprocess.STDOUT) if detection else
                          subprocess.run(launch, cwd=APP, env=child, stdout=log, stderr=subprocess.STDOUT).returncode)
            text = (out / 'runner.log').read_text(errors='replace')
            # The desktop app is single-instance: a launch racing another
            # worktree's run exits at once. Keep the failed log and retry.
            if detection or concurrent or 'Application failed to start' not in text or (out / 'lab-hello.json').exists():
                break
            (out / 'runner.log').rename(out / f'runner-failed-start-{attempt}.log')
            time.sleep(20)
        impeller = re.search(r'Using the Impeller rendering backend \(([^)]+)\)', text)
        if android:
            try:
                env['protectedAppAfter'] = protected_state(device)
                if env['protectedAppAfter'] != protected_before:
                    raise SafetyError('Official App identity changed during the benchmark.')
            except SafetyError as error:
                status = 1
                env['protectedAppError'] = str(error)
                print(f'STOP: {error} No reinstall/restore attempt will be made.', flush=True)
        env['renderer'] = f'Impeller ({impeller.group(1)})' if impeller else 'unknown (derived from raster events in summarize)'
        if detection:
            compositor_log = out / 'compositor.log'
            if compositor_log.exists():
                renderer = re.search(r'GL renderer: (.+)', compositor_log.read_text())
                env['compositorRenderer'] = renderer.group(1) if renderer else 'unknown'
            env['displaySession'] = manifest['displaySession']
            # Weston terminates with its launched program but may not propagate
            # that program's exit status. Require the driver's explicit receipt.
            try:
                driver = json.loads((out / 'driver-result.json').read_text())
                if driver.get('result') != 'true':
                    status = 1
            except (OSError, ValueError, AttributeError):
                status = 1
    except BaseException as failure:
        status = 130 if isinstance(failure, KeyboardInterrupt) else 1
        if detection:
            env['interruptedBy'] = type(failure).__name__
        raise
    finally:
        if runtime_directory is not None:
            env['runtimeCleanup'] = cleanup_private_runtime(runtime_directory)
            env['privateRuntimeRemoved'] = env['runtimeCleanup']['removed']
            if not env['privateRuntimeRemoved']:
                status = 1
            env['exitCode'] = status
            env['endedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
            (out / 'env.json').write_text(json.dumps(env, indent=1) + '\n')
    env['exitCode'] = status
    env['endedAt'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    env['loadavgEnd'] = os.getloadavg()
    env['maxLoad'] = max_load(args)
    env['noisyHost'] = max(env['loadavg'][0], env['loadavgEnd'][0]) > env['maxLoad']
    if concurrent or detection:
        env['hostActivity'] = host_cpu_delta(cpu_before, host_cpu_snapshot())
        if not same_source(manifest['source'], source_snapshot()) or manifest['artifact'] != artifact_snapshot(Path(manifest['artifact']['path'])):
            status = env['exitCode'] = 1
            env['sourceOrArtifactChanged'] = True
    (out / 'env.json').write_text(json.dumps(env, indent=1) + '\n')
    if detection:
        return 0 if status == 0 else 1
    summary = summarize(out)
    print((out / 'summary.md').read_text())
    if args.reference:
        comparison_status = compare_cmd(argparse.Namespace(base=args.reference, candidate=out, out=None, no_fail=False))
        return 1 if status else comparison_status
    return 0 if status == 0 else 1


def detect_cmd(args):
    """One isolated launch under natural load, or inspect existing observations."""
    out = args.out.resolve()
    if out.exists():
        sys.exit('Detection output exists; use a new directory to preserve earlier findings.')
    expected = DETECTION_SCENARIOS if args.scenarios == 'all' else args.scenarios.split(',')
    known = set(DETECTION_SCENARIOS + DETECTION_CONTROLS) | DETECTION_GAPS.keys()
    if not expected or any(s not in known for s in expected):
        sys.exit('Unknown scene. Choose all or: ' + ','.join(sorted(known)))
    themes = args.themes.split(',')
    if any(t not in {'brutal-light', 'elegant-light', 'elegant-dark'} for t in themes):
        sys.exit('Use a supported product theme: brutal-light,elegant-light,elegant-dark.')
    if args.details and len(expected) != 1:
        sys.exit('Detail replay accepts one scene. Its instrumented durations cannot establish a timing verdict.')
    out.mkdir(parents=True)
    if args.records:
        raw = out / 'run'
        raw.mkdir()
        for path in args.records.iterdir():
            if path.is_file() and path.suffix in {'.json', '.jsonl', '.log', '.txt'}:
                shutil.copyfile(path, raw / path.name)
        status = 0
    else:
        if platform.system() != 'Linux':
            sys.exit('This first detection runner supports Linux. Other platforms remain NOT_RUN.')
        runnable = [s for s in expected if s not in DETECTION_GAPS]
        raw = out / 'run'
        if runnable:
            build_args = argparse.Namespace(out=out / 'build', identity_suffix='.profile_detect', themes=args.themes,
                scenarios=','.join(runnable), seconds=args.seconds, rounds=1, semantics=args.semantics,
                no_trace=not args.details, detection=True)
            status = build(build_args)
            if status == 0:
                receipt = build_args.out / 'build-receipt.json'
                run_args = argparse.Namespace(**{**vars(build_args), 'out': raw, 'device': 'linux', 'reference': None,
                    'max_load': None, 'wait_quiet': 0, 'allow_noisy': True, 'wait': 0, 'build_receipt': receipt,
                    'headless': True,
                    'flutter_args': [f'--use-application-binary={build_args.out / "bundle/raft_flutter"}']})
                status = run(run_args)
        else:
            status = 0
        raw.mkdir(exist_ok=True)
    summary = detection_report(raw, expected, themes)
    summary['collectionExitCode'] = status
    (raw / 'detection.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f"Detection: {raw / 'detection.md'}; {summary['counts']}; collection exit={status}")
    print('Exit status describes collection, not a performance pass. Read the scene and signal statuses.')
    return status


def compare_cmd(args):
    base, cand = Path(args.base), Path(args.candidate)
    sb = summarize(base) if not (base / 'summary.json').is_file() else json.loads((base / 'summary.json').read_text())
    sc = summarize(cand) if not (cand / 'summary.json').is_file() else json.loads((cand / 'summary.json').read_text())
    result = compare(sb, sc)
    text = compare_markdown(result, base.name, cand.name)
    target = Path(args.out) if args.out else cand / f'compare-{base.name}.md'
    target.write_text(text)
    target.with_suffix('.json').write_text(json.dumps(result, indent=1, ensure_ascii=False) + '\n')
    print(text)
    return 1 if result['regressions'] and not args.no_fail else 0


def load_pair_run(directory):
    def read(name):
        return json.loads((directory / name).read_text())

    def rows(name):
        return [json.loads(line) for line in (directory / name).read_text().splitlines() if line.strip()]

    errors = directory / 'lab-sampler-errors.txt'
    return {'manifest': read('run-manifest.json'), 'env': read('env.json'),
            'driverResult': read('driver-result.json'), 'done': read('lab-done.json'), 'hello': read('lab-hello.json'),
            'samplerErrors': errors.read_text() if errors.exists() else '',
            'procRounds': rows('proc-rounds.jsonl'), 'frameRounds': rows('frame-rounds.jsonl'),
            'barrierRounds': rows('barrier-rounds.jsonl')}


def qualify_cmd(args):
    if args.out.exists():
        sys.exit('Qualification output exists; keep earlier results unchanged.')
    seen = set()
    try:
        for previous in args.previous:
            seen.update(json.loads(previous.read_text())['launchKeys'])
        result = qualify_pair(load_pair_run(args.old), load_pair_run(args.new), seen_launches=seen)
    except (OSError, ValueError, KeyError) as error:
        result = {'qualified': False, 'independentPairs': 0, 'launchKeys': [], 'reasons': [str(error)]}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=1, allow_nan=False) + '\n')
    print(f"{'QUALIFIED PAIR' if result['qualified'] else 'VOID PAIR'}: " + '; '.join(result['reasons']))
    print('CPU checks fairness only. Flutter frames determine product performance; this is not method acceptance.')
    return 0 if result['qualified'] else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)
    d = sub.add_parser('detect', help='one-command profile problem detection; no calibration, quiet-host wait or revision comparison')
    d.add_argument('--out', type=Path, required=True)
    d.add_argument('--scenarios', default='all', help='all, one scene, or a comma list; gaps remain NOT_RUN')
    d.add_argument('--themes', default='brutal-light')
    d.add_argument('--seconds', type=int, default=8)
    d.add_argument('--semantics', choices=['platform', 'on', 'off'], default='platform')
    d.add_argument('--details', action='store_true', help='diagnostic replay of one scene; timing verdict disabled')
    d.add_argument('--headless', action='store_true', default=True, help=argparse.SUPPRESS)
    d.add_argument('--records', type=Path, help='inspect existing scene JSON files without launching an app')
    r = sub.add_parser('run', help='run the suite in profile mode')
    r.add_argument('--out', type=Path, required=True)
    r.add_argument('--themes', default='brutal-light,elegant-light', help='comma list: brutal-light, brutal-dark, elegant-light, elegant-dark')
    r.add_argument('--scenarios', help='comma list; "mount-*" selects every row kind')
    r.add_argument('--seconds', type=int, default=8, help='duration of continuous scenarios')
    r.add_argument('--semantics', choices=['platform', 'on', 'off'], default='platform',
                   help='platform: as the embedder requests (Linux GTK: always on); on: forced (VoiceOver); off: forced off (usual macOS)')
    r.add_argument('--no-trace', action='store_true', help='disable framework phase collection and engine timeline (cleanest timings, no phase/raster attribution)')
    r.add_argument('--device', help='flutter device id (default: linux or macos)')
    r.add_argument('--reference', type=Path, help='compare against this earlier run directory')
    r.add_argument('--max-load', type=float, help='1-minute load average above which the host counts as noisy (default 0.35 x CPUs)')
    r.add_argument('--wait-quiet', type=int, default=1800, help='seconds to wait for a quiet host before giving up')
    r.add_argument('--allow-noisy', action='store_true', help='run anyway on a loaded host (summary is marked noisy)')
    r.add_argument('--wait', type=int, default=0, help='seconds to wait for another raft_flutter instance to exit (Linux)')
    r.add_argument('--rounds', type=int, help='measured rounds in one launch, in addition to the keyboard warmup')
    r.add_argument('--build-receipt', type=Path, help='required for concurrent Linux runs; source/config/artifact must match')
    r.add_argument('flutter_args', nargs='*', help='extra flutter drive arguments after --, e.g. -- --no-enable-impeller')
    s = sub.add_parser('summarize', help='rebuild summary.json/summary.md for a run')
    s.add_argument('run', type=Path)
    c = sub.add_parser('compare', help='before/after comparison against the budgets')
    c.add_argument('base', type=Path)
    c.add_argument('candidate', type=Path)
    c.add_argument('--out', type=Path)
    c.add_argument('--no-fail', action='store_true')
    b = sub.add_parser('build', help='build and copy an isolated Linux profile fixture with its source/artifact receipt; does not launch')
    b.add_argument('--out', type=Path, required=True, help='new output directory, normally under .local/performance')
    b.add_argument('--identity-suffix', required=True, help='isolated native and Dart suffix, for example .m7old')
    b.add_argument('--themes', default='brutal-light')
    b.add_argument('--scenarios', default='keyboard')
    b.add_argument('--seconds', type=int, default=8)
    b.add_argument('--rounds', type=int, default=3)
    b.add_argument('--semantics', choices=['platform', 'on', 'off'], default='platform')
    b.add_argument('--no-trace', action='store_true')
    q = sub.add_parser('qualify', help='qualify a whole same-source calibration pair, including warmup; no product verdict')
    q.add_argument('--old', type=Path, required=True)
    q.add_argument('--new', type=Path, required=True)
    q.add_argument('--out', type=Path, required=True)
    q.add_argument('--previous', type=Path, action='append', default=[], help='prior pair result; its launches cannot be reused')
    args = parser.parse_args(argv)
    if args.command == 'detect':
        return detect_cmd(args)
    if args.command == 'run':
        return run(args)
    if args.command == 'build':
        return build(args)
    if args.command == 'qualify':
        return qualify_cmd(args)
    if args.command == 'summarize':
        summarize(args.run)
        print((args.run / 'summary.md').read_text())
        return 0
    return compare_cmd(args)


if __name__ == '__main__':
    raise SystemExit(main())
