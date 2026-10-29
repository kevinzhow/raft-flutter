"""Fold the `dart test` / `flutter test` JSON-reporter stream into per-test results and per-file counts.

Shared by tool/check-project (the full check) and tool/preflight (its test-budget step), so both count
the cases a file declares in the same way; tool/test_budget.py judges the counts.
"""
import json


def parse_test_events(lines, to_repo_path=lambda p: p):
    """Fold `dart test` JSON-reporter lines into per-test results.

    Tolerates a truncated stream (killed shard): tests that started and never
    finished are reported as `incomplete`.
    """
    suites, tests, errors = {}, {}, {}
    for line in lines:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get('type')
        if kind == 'suite':
            suites[event['suite']['id']] = to_repo_path(event['suite'].get('path', ''))
        elif kind == 'testStart':
            test = event['test']
            tests[test['id']] = {'name': test['name'], 'suite': test.get('suiteID'), 'start': event['time'], 'done': None, 'result': None, 'skipped': False, 'hidden': False}
        elif kind == 'testDone' and event['testID'] in tests:
            record = tests[event['testID']]
            record.update(done=event['time'], result=event.get('result'), skipped=bool(event.get('skipped')), hidden=bool(event.get('hidden')))
        elif kind == 'error' and event['testID'] in tests:
            errors.setdefault(event['testID'], []).append(str(event.get('error', '')).strip())
    results = []
    for test_id, record in tests.items():
        file = suites.get(record['suite'], '')
        loading = record['name'].startswith('loading ')
        if record['done'] is None:
            status = 'incomplete'
        elif record['skipped']:
            status = 'skipped'
        else:
            status = 'passed' if record['result'] == 'success' else 'failed'
        message = (errors.get(test_id) or [''])[0].splitlines()
        results.append({'name': record['name'], 'file': file, 'loading': loading, 'hidden': record['hidden'], 'status': status,
                        'seconds': round(((record['done'] or record['start']) - record['start']) / 1000, 3),
                        'error': message[0] if message else ''})
    return results


def file_durations(results, shard=None):
    """Per-file seconds: suite load/compile plus the tests inside it."""
    files = {}
    for r in results:
        if not r['file']:
            continue
        entry = files.setdefault(r['file'], {'seconds': 0.0, 'loadSeconds': 0.0, 'tests': 0})
        entry['seconds'] = round(entry['seconds'] + r['seconds'], 3)
        if r['loading']:
            entry['loadSeconds'] = round(entry['loadSeconds'] + r['seconds'], 3)
        elif not r.get('hidden'):
            entry['tests'] += 1
        if shard is not None:
            entry['shard'] = shard
    return files
