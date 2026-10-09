#!/usr/bin/env python3
"""Compare raw paired process receipts; do not score pixels or hide transitions."""
import argparse
import json
import re
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


def input_failures(source, flutter):
    failures = []
    keys = ('fixtureSha', 'sourceHead', 'sourceInputSha', 'runtimeSha',
            'theme', 'form', 'viewport')
    for key in keys:
        if key not in source or key not in flutter:
            failures.append(f'Missing bound input: {key}')
        elif source[key] != flutter[key]:
            failures.append(f'Input mismatch: {key}')
    for provider, receipt in [('Source', source), ('Flutter', flutter)]:
        for key, length in [('fixtureSha', 64), ('sourceHead', 40),
                            ('sourceInputSha', 64), ('runtimeSha', 64)]:
            value = receipt.get(key)
            if not isinstance(value, str) or not re.fullmatch(f'[0-9a-f]{{{length}}}', value):
                failures.append(f'{provider} missing or malformed input fingerprint: {key}')
    if flutter.get('platform') not in ('linux', 'android'):
        failures.append('Flutter missing or unsupported actual platform')
    if not isinstance(flutter.get('device'), str) or not flutter['device'].strip():
        failures.append('Flutter missing actual device')
    return failures


def loading_failures(flow, source, flutter):
    """Reject a resolved shell before metadata or a canceled-only race receipt."""
    failures = []
    if flow.startswith('cold-'):
        for name, summary_ in [('Source', source), ('Flutter', flutter)]:
            for stage_name in ('pending-tail', 'tail-still-held'):
                frame = summary_['stages'].get(stage_name, {})
                if not all(frame.get(key) for key in ('headers', 'tabs', 'composer')) or frame.get('accepted'):
                    failures.append(f'{name} cold resolved shell/window mismatch at {stage_name}')
            if flow == 'cold-unknown':
                frame = summary_['stages'].get('pending-identity', {})
                if not frame.get('channelPlaceholder') or frame.get('tabs') or frame.get('composer') or frame.get('accepted'):
                    failures.append(f'{name} unresolved identity fabricated conversation state')
    elif flow.startswith('stale-'):
        for name, summary_ in [('Source', source), ('Flutter', flutter)]:
            released = next((s for s in summary_['receipt']['stages'] if s['name'] == 'stale-response-released'), {})
            if not released.get('staleResponseObserved'):
                failures.append(f'{name} late HTTP response was not delivered; cancellation is separate evidence')
    return failures


def replacement_cache_prelude(source_pending, native_pending):
    """Expose observed list visibility; generic loading flags are insufficient."""
    source_list = bool(source_pending.get('channelScroller'))
    native_list = bool(native_pending.get('channelScroller'))
    native_ids = native_pending.get('acceptedIds') or []
    return {
        'sourceMessageLoading': source_pending.get('messageLoading'),
        'sourceSurfaceText': [row.get('text') for row in source_pending.get('surfaces', [])],
        'sourcePendingListVisible': source_list,
        'nativePendingListVisible': native_list,
        'nativeAcceptedDestinationIds': native_ids,
        'differentObservedPrestate': not source_list and native_list and bool(native_ids),
        'pendingWindowEqualityAsserted': False,
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
    a,b = source['receipt'], flutter['receipt']
    failures = input_failures(a, b)
    for name, summary_ in [('Source',source), ('Flutter',flutter)]:
        if summary_['receipt']['result'] != 'PASS': failures.append(f'{name} flow receipt failed')
        if not summary_['rendererManifestMatchesCount'] or summary_['rendererPngCount'] != summary_['rendererFrames']:
            failures.append(f'{name} renderer manifest/count mismatch')
    flow = a.get('flow', 'activity-uncached-channel-target')
    requirement = a.get('requirement', 'N24/channel-single')
    if flow != b.get('flow', 'activity-uncached-channel-target') or requirement != b.get('requirement', 'N24/channel-single'):
        failures.append('Input mismatch: process flow or N24 gesture')
    checkpoints = ['accepted-tail', 'activity']
    if flow.startswith('cold-'):
        prelude = 'sidebar-ready' if 'sidebar-ready' in source['stages'] else 'activity-ready'
        checkpoints = [prelude, 'pending-tail', 'tail-still-held', 'tail-accepted']
        if flow == 'cold-unknown':
            checkpoints += ['pending-identity']
    elif flow.startswith('stale-'):
        checkpoints = ['accepted-tail', 'activity-ready', 'superseded-target-pending', 'back-to-activity', 'replacement-pending', 'replacement-accepted', 'stale-response-released']
    elif flow != 'activity-uncached-channel-target':
        checkpoints += ['thread-pending-parent-and-replies', 'thread-replies-before-parent', 'thread-parent-accepted', 'thread-highlight-expired']
    if flow in ('activity-uncached-channel-target', 'activity-channel-after-thread'):
        checkpoints += ['pending-context', 'accepted-context', 'highlight-expired']
    for name in checkpoints:
        if name not in source['stages'] or name not in flutter['stages']:
            failures.append(f'Missing paired checkpoint {name}'); continue
        if url(source['stages'][name]['url']) != url(flutter['stages'][name]['url']):
            failures.append(f'Location mismatch at {name}')
    failures += loading_failures(flow, source, flutter)
    evidence = {
        'flow': flow, 'requirement': requirement, 'result': 'FAIL' if failures else 'BEHAVIOR_PASS_WITH_LIMITS',
        'failures': failures, 'source': source, 'flutter': flutter,
        'limits': [
            'DOM rAF rectangles and Flutter post-frame layout observations are not compositor pixel assertions.',
            'Chromium CDP PNGs sample emitted renderer frames; timestamp gaps are retained and can conceal intermediate paints.',
            f"Flutter PNGs rasterize changed display-list layers on {b.get('platform', 'unreported')} ({b.get('device', 'unreported')}); they do not observe physical screen scanout.",
            'Stage receipt PASS does not remove earlier transient missing controls, offsets, errors or runner failures.',
            'No pixel similarity acceptance, read-back backend, real auth/socket, all N24 gestures or complete process matrix claim.',
        ],
    }
    if flow.startswith('stale-'):
        source_pending = source['stages'].get('replacement-pending', {})
        native_pending = flutter['stages'].get('replacement-pending', {})
        evidence['replacementPendingCachePrelude'] = replacement_cache_prelude(source_pending, native_pending)
        if evidence['replacementPendingCachePrelude']['differentObservedPrestate']:
            evidence['limits'].append('Source entered directly through Android; native bootstrap previously accepted design. Destination B pending windows have different accepted cache preludes. This pair proves stale response ownership after B acceptance, not identical B-pending lists.')
    args.out.write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps({'result': evidence['result'], 'failures': failures}))
    return 1 if failures else 0

if __name__ == '__main__':
    raise SystemExit(main())
