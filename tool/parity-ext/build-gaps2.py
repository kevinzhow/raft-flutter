import json
from pathlib import Path

from builders import manifest_path


PREFIX = 'components.gaps2.'
fixture = {
    'migration': {
        'agentId': 'a1',
        'migrationRef': 'MV-123',
        'revision': 2,
        'state': 'failed',
        'sourceMachineId': 'source',
        'targetMachineId': 'target',
        'failureReason': 'MIGRATION_LEASE_EXPIRED',
        'retryOfMigrationId': 'previous',
        'retryComparison': {
            'previousFailure': {'entries': 24},
            'packed': {'files': 12, 'bytes': 2147483648, 'final': False},
        },
    },
    'machines': [{'id': 'source', 'name': 'Source'}, {'id': 'target', 'name': 'Target'}],
    'agents': [
        {'id': 'alpha', 'name': 'Alpha', 'text': 'Editing Flow.tsx · #25'},
        {'id': 'beta', 'name': 'Beta', 'text': 'Drafting release notes · #31'},
    ],
}
Path(__file__).with_name('fixtures').joinpath('gaps2.json').write_text(json.dumps(fixture) + '\n')

manifest = manifest_path()
data = json.loads(manifest.read_text())
cases = [case for case in data['cases'] if not case['id'].startswith(PREFIX)]
for surface, selector, key, path, trigger in [
    ('migration', '[data-testid="agent-last-migration-body"]', 'agent-last-migration-body',
     'agentMigration/LastMigration.tsx', None),
    ('working-now', '[data-testid="working-now-list"]', 'working-now',
     'layout/WorkingNowSummary.tsx', 'working-now-summary'),
    ('forward-toast', '.forward-toast-viewport [data-slot="toast"]', 'raft-toast-top',
     'message/ForwardToastProvider.tsx', 'forward-toast-trigger'),
]:
    for platform, width, height, density in [('desktop', 1280, 900, 1), ('phone', 390, 844, 3)]:
        for suffix, theme in [('brutal', 'brutal-light'), ('elegant-dark', 'elegant-dark')]:
            case_id = f'{PREFIX}{surface}.{platform}.{suffix}'
            cases.append({
                'id': case_id,
                'title': f'{surface} ({platform}, {theme})',
                'captureType': 'component-fixture',
                'surface': surface,
                'category': 'extension/components',
                'suite': 'raft-flutter-extension',
                'viewport': {'width': width, 'height': height, 'density': density},
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'extFixture': 'gaps2', 'surface': surface, 'platform': platform,
                    'parityTheme': theme,
                }}],
                'capture': {
                    'selector': selector,
                    'crop': 'element',
                    'contract': 'component-bounds',
                    'androidKey': key,
                    'interactions': [] if trigger is None else [
                        {'type': 'click', 'target': f'[data-testid="{trigger}"]'},
                        {'type': 'wait', 'ms': 450},
                    ],
                },
                'reactPathHint': f'packages/web/src/components/{path}',
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_gaps2.dart '{case_id}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
data['cases'] = cases
manifest.write_text(json.dumps(data, indent=1))
