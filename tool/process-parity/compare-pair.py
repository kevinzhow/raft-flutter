#!/usr/bin/env python3
"""Compare raw paired process receipts; do not score pixels or hide transitions."""
import argparse
import json
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


def url(value):
    part = urlsplit(value)
    return part.path, parse_qs(part.query, keep_blank_values=True)


def summary(path):
    complete = (path / 'result.json').exists()
    result = json.loads((path / ('result.json' if complete else 'progress.json')).read_text())
    if not complete:
        result = {**result, 'result': 'FAIL', 'runnerLimit': 'Native/framework abort before final receipt; inspect CLI failure log.'}
    frames = [json.loads(row) for row in (path / 'frames.jsonl').read_text().splitlines() if row]
    renderer = json.loads((path / 'renderer-frames.json').read_text())
    target = next((frame for frame in frames if (frame.get('target') or {}).get('inView')), None)
    thread_target = next((frame for frame in frames if (frame.get('threadTarget') or {}).get('inView')), None)
    pending = [frame for frame in frames if 'msg=' in frame['url'] and (target is None or frame['frame'] < target['frame'])]
    def center(frame, key='target'):
        message = frame[key]; box = message['focusRect']; view = message['view']
        return abs(box['y'] + box['height']/2 - view['y'] - view['height']/2)
    timestamps = [row['metadata']['timestamp'] * 1000 for row in renderer] if result['provider'].startswith('Source') else [row['frame']['wallTime'] for row in renderer]
    return {
        'completedReceipt': complete, 'receipt': result, 'domOrLayoutFrames': len(frames), 'rendererFrames': len(renderer),
        'rendererManifestMatchesCount': len(renderer) == result['rendererFrameCount'],
        'rendererPngCount': len(list((path/'renderer-frames').glob('*.png'))),
        'maxRendererTimestampGapMs': max((b-a for a,b in zip(timestamps, timestamps[1:])), default=None),
        'firstObservedTarget': None if target is None else {'frame': target['frame'], 'stage': target['stage'], 'centerError': center(target), 'highlighted': target['target']['highlighted'], 'wallTime': target.get('wallTime')},
        'firstObservedThreadTarget': None if thread_target is None else {'frame': thread_target['frame'], 'stage': thread_target['stage'], 'centerError': center(thread_target, 'threadTarget'), 'highlighted': thread_target['threadTarget']['highlighted'], 'wallTime': thread_target.get('wallTime')},
        'pendingUriObservations': len(pending),
        'missingPendingHeaders': [r['frame'] for r in pending if not r['headers']],
        'missingPendingTabs': [r['frame'] for r in pending if not r['tabs']],
        'missingPendingComposer': [r['frame'] for r in pending if not r['composer']],
        'missingPendingAcceptedList': [r['frame'] for r in pending if not (r.get('accepted') or {}).get('inView')],
        'stages': {s['name']: s['frame'] for s in result['stages']},
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument('source', type=Path)
    p.add_argument('flutter', type=Path)
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    if args.out.exists():
        raise SystemExit('Refusing to overwrite paired evidence')
    source, flutter = summary(args.source), summary(args.flutter)
    failures = []
    a,b = source['receipt'], flutter['receipt']
    for key in ('fixtureSha', 'sourceHead', 'sourceInputSha', 'runtimeSha', 'theme', 'form', 'viewport'):
        if a[key] != b[key]: failures.append(f'Input mismatch: {key}')
    for name, summary_ in [('Source',source), ('Flutter',flutter)]:
        if summary_['receipt']['result'] != 'PASS': failures.append(f'{name} flow receipt failed')
        if not summary_['rendererManifestMatchesCount'] or summary_['rendererPngCount'] != summary_['rendererFrames']:
            failures.append(f'{name} renderer manifest/count mismatch')
    flow = a.get('flow', 'activity-uncached-channel-target')
    requirement = a.get('requirement', 'N24/channel-single')
    if flow != b.get('flow', 'activity-uncached-channel-target') or requirement != b.get('requirement', 'N24/channel-single'):
        failures.append('Input mismatch: process flow or N24 gesture')
    checkpoints = ['accepted-tail', 'activity']
    if flow != 'activity-uncached-channel-target':
        checkpoints += ['thread-pending-parent-and-replies', 'thread-replies-before-parent', 'thread-parent-accepted', 'thread-highlight-expired']
    if flow in ('activity-uncached-channel-target', 'activity-channel-after-thread'):
        checkpoints += ['pending-context', 'accepted-context', 'highlight-expired']
    for name in checkpoints:
        if name not in source['stages'] or name not in flutter['stages']:
            failures.append(f'Missing paired checkpoint {name}'); continue
        if url(source['stages'][name]['url']) != url(flutter['stages'][name]['url']):
            failures.append(f'Location mismatch at {name}')
    evidence = {
        'flow': flow, 'requirement': requirement, 'result': 'FAIL' if failures else 'BEHAVIOR_PASS_WITH_LIMITS',
        'failures': failures, 'source': source, 'flutter': flutter,
        'limits': [
            'DOM rAF rectangles and Flutter post-frame layout observations are not compositor pixel assertions.',
            'Chromium CDP PNGs sample emitted renderer frames; timestamp gaps are retained and can conceal intermediate paints.',
            f"Flutter PNGs rasterize changed display-list layers on {b.get('platform', 'linux')} ({b.get('device', 'linux-xvfb')}); they do not observe physical screen scanout.",
            'Stage receipt PASS does not remove earlier transient missing controls, offsets, errors or runner failures.',
            'No pixel similarity acceptance, read-back backend, real auth/socket, all N24 gestures or complete process matrix claim.',
        ],
    }
    args.out.write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps({'result': evidence['result'], 'failures': failures}))
    return 1 if failures else 0

if __name__ == '__main__':
    raise SystemExit(main())
