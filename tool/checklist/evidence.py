"""Derive checklist progress from unchanged-source test receipts."""
import hashlib
import importlib.util
import json
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

LAYERS = {'model': 0, 'controller': 1, 'mounted': 2, 'native': 3}
LABEL = re.compile(r'\[([NLKP]\d{2}[a-z]?)\]')


def actual_layer(test, declared):
    if LAYERS.get(declared, 0) < LAYERS['mounted']:
        return declared
    # Flutter's machine record points to the actual registration call, so a
    # mixed suite cannot turn a plain test into page proof by changing its flag.
    origin = urlsplit(test.get('root_url') or test.get('url') or '')
    line = test.get('root_line') or test.get('line')
    if origin.scheme != 'file' or not isinstance(line, int) or line < 1:
        return 'model'
    path = Path(unquote(origin.path))
    if not path.is_file():
        return 'model'
    code = path.read_text().splitlines()
    column = test.get('root_column') or test.get('column') or 1
    registration = code[line - 1][column - 1:] if line <= len(code) else ''
    if not re.match(r'^\s*testWidgets\s*\(', registration):
        return 'model'
    return declared


def machine_events(raw):
    """Preserve failed/skipped tests; Flutter may print non-JSON preambles."""
    tests, suites, done, errors = {}, {}, None, []
    for line in raw.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if not isinstance(event, dict):
            continue
        kind = event.get('type')
        if kind == 'suite':
            suites[event['suite']['id']] = event['suite']
        elif kind == 'testStart':
            tests[event['test']['id']] = {**event['test'], 'result': 'incomplete'}
        elif kind == 'testDone':
            record = tests.get(event['testID'])
            if record is not None:
                record.update(result=event.get('result', 'incomplete'),
                              skipped=event.get('skipped', False),
                              hidden=event.get('hidden', False))
        elif kind == 'error':
            errors.append({'testID': event.get('testID'), 'error': event.get('error')})
        elif kind == 'done':
            done = event
    rows = []
    for record in tests.values():
        if record.get('hidden'):
            continue
        labels = LABEL.findall(record.get('name', ''))
        if labels:
            rows.append({**record, 'labels': labels,
                         'suite': suites.get(record.get('suiteID'), {}).get('path')})
    return {'tests': rows, 'completed': bool(done and done.get('success')), 'errors': errors}


def read_runs(paths, source_hash):
    runs = []
    for path in paths:
        path = Path(path)
        run = json.loads(path.read_text())
        if run.get('sourceHash') != source_hash:
            continue
        if run.get('format') == 'raft-native-performance-v1':
            runs.append(read_performance_run(path, run))
            continue
        log = path.parent / run['machineLog']
        if hashlib.sha256(log.read_bytes()).hexdigest() != run['machineLogSha']:
            raise ValueError(f'Changed test log: {log}')
        parsed = machine_events(log.read_text())
        run['tests'] = parsed['tests']
        for test in run['tests']:
            test['layer'] = actual_layer(test, run['suiteLayers'].get(test['suite'], 'model'))
        run['valid'] = (run.get('sourceUnchanged') is True
                        and run.get('exitCode') == 0 and parsed['completed'])
        run['path'] = str(path)
        runs.append(run)
    return runs


def read_performance_run(path, run):
    """Read actual Flutter Driver results and recompute the native frame gate."""
    artifacts = []

    def read_artifact(base, entry):
        if entry is None:
            return {}
        if not isinstance(entry, dict):
            raise ValueError('Invalid native performance artifact')
        source = base / entry['path']
        if hashlib.sha256(source.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError(f'Changed native performance artifact: {source}')
        artifacts.append(source)
        return json.loads(source.read_text())

    base = path.parent
    samples = [read_artifact(base, entry) for entry in run.get('samples', [])]
    driver = read_artifact(base, run.get('driverResult'))
    gate = read_artifact(base, run.get('gateResult'))
    reference = None
    reference_valid = False
    if run.get('referenceReceipt'):
        reference_entry = run['referenceReceipt']
        receipt = read_artifact(base, reference_entry)
        reference_base = (base / reference_entry['path']).parent
        reference = [read_artifact(reference_base, entry)
                     for entry in receipt.get('samples', [])]
        reference_driver = read_artifact(reference_base, receipt.get('driverResult'))
        reference_valid = (
            receipt.get('completed') is True and receipt.get('sourceUnchanged') is True
            and receipt.get('nativeExitCode') == 0
            and reference_driver.get('result') == 'true'
            and receipt.get('commit') == 'e210562a80e403986d0fc44090245657906277a0'
            and receipt.get('harnessSha256') == run.get('harnessSha256')
            and receipt.get('semanticsEnabled') == run.get('semanticsEnabled')
            and not receipt.get('diagnosticOnly') and len(reference) == 9
        )
    comparator = Path(__file__).resolve().parents[1] / 'performance' / 'compare.py'
    spec = importlib.util.spec_from_file_location('native_performance_gate', comparator)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    recomputed = module.assess(samples, reference)
    recorded_mode = run.get('semanticsEnabled')
    modes_match = isinstance(recorded_mode, bool) and all(
        sample.get('semanticsEnabled') is recorded_mode for sample in samples)
    valid = (run.get('sourceUnchanged') is True and run.get('completed') is True
             and run.get('nativeExitCode') == 0 and run.get('exitCode') == 0
             and not run.get('diagnosticOnly') and driver.get('result') == 'true'
             and gate.get('passed') is True and recomputed['passed']
             and reference_valid and modes_match)
    name = f"{run['name']} · semantics={str(recorded_mode).lower()}"
    suite = run['suite']
    return {**run, 'path': str(path), 'valid': valid,
            'artifactPaths': [str(source) for source in artifacts],
            'suiteLayers': {suite: 'native'},
            'tests': [{'labels': LABEL.findall(name), 'name': name,
                       'suite': suite, 'layer': 'native', 'skipped': False,
                       'result': 'success' if valid else 'failure'}]}


def evaluate_check(check, runs):
    rows = []
    for run in runs:
        for test in run['tests']:
            if check['id'] not in test['labels']:
                continue
            layer = test.get('layer', run['suiteLayers'].get(test['suite'], 'model'))
            rows.append({'name': test['name'], 'result': test['result'],
                         'skipped': test.get('skipped', False), 'layer': layer,
                         'suite': test['suite'],
                         'validRun': run['valid'], 'receipt': run['path']})
    strong = [row for row in rows if LAYERS.get(row['layer'], 0)
              >= LAYERS[check.get('minimum_layer', 'mounted')]
              and (not check.get('proof_file')
                   or str(row.get('suite', '')).endswith(check['proof_file']))]
    unique_passes = {(row['name'], row['layer']) for row in strong
                     if row['validRun'] and row['result'] == 'success' and not row['skipped']}
    failures = [row for row in rows if not row['validRun']
                or row['result'] != 'success' or row['skipped']]
    passed_names = [name for name, _ in unique_passes]
    coverage = all(any(fragment in name for name in passed_names)
                   for fragment in check.get('required_name_fragments', []))
    verified = len(unique_passes) >= check.get('minimum_passes', 1) and coverage and not failures
    return {**check, 'status': 'verified' if verified else ('partial' if rows else 'not_started'),
            'passed': len(unique_passes), 'failures': len(failures), 'proofs': rows}


def evaluate_item(item, runs, audit=None):
    if 'status' in item:
        raise ValueError('Canonical item data must not contain a completion status')
    checks = [evaluate_check(check, runs) for check in item['checks']]
    if all(check['status'] == 'verified' for check in checks):
        status = 'verified'
    elif any(check['proofs'] for check in checks):
        status = 'partial'
    elif audit and audit.get('status') == 'not_started':
        status = 'not_started'
    elif audit and audit.get('status') == 'partial':
        status = 'partial'
    else:
        status = 'missing_evidence'
    # Historical review describes implementation progress, never current proof.
    return {**item, 'status': status, 'checks': checks,
            'implementationAuditStatus': audit.get('status') if audit else None}
