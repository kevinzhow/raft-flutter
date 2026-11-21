import json
from pathlib import Path

from builders import manifest_path


PREFIX = 'components.dialogs.desktop.migration-cancel.'
fixture = {
    'notice': {
        'migrationRef': 'fixture-ref',
        'revision': 2,
        'state': 'in_transit',
        'sourceMachineId': 'c1',
        'targetMachineId': 'c2',
    },
    'machines': [
        {'id': 'c1', 'name': 'Source', 'status': 'online', 'isComputer': True},
        {'id': 'c2', 'name': 'Target', 'status': 'online', 'isComputer': True},
    ],
}
Path(__file__).with_name('fixtures').joinpath('migration-cancel.json').write_text(json.dumps(fixture))

manifest = manifest_path()
data = json.loads(manifest.read_text())
cases = [case for case in data['cases'] if not case['id'].startswith(PREFIX)]
for platform, width, height, dpr in [('desktop', 1280, 900, 1), ('mobile', 390, 844, 3)]:
    for hosted in ('hosted', 'computers'):
        for theme in ('elegant', 'elegant-dark'):
            case_id = f'{PREFIX}{platform}.{hosted}.{theme}'
            cases.append({
                'id': case_id,
                'title': f'Migration cancel confirmation ({platform}, {hosted}, {theme})',
                'captureType': 'component-fixture',
                'surface': 'migration-cancel-dialog',
                'category': 'extension/dialogs',
                'suite': 'raft-flutter-extension',
                'viewport': {'width': width, 'height': height, 'density': dpr},
                'theme': 'elegant-light' if theme == 'elegant' else theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'extFixture': 'migration-cancel', 'targetKind': hosted,
                    'platform': platform,
                    'parityTheme': 'elegant-light' if theme == 'elegant' else theme,
                }}],
                'capture': {
                    'selector': '[role="dialog"]:has([data-slot="confirm-dialog-content"])',
                    'crop': 'element',
                    'contract': 'component-bounds',
                    'androidKey': 'migration-cancel-parity-surface',
                },
                'reactPathHint': 'packages/web/src/components/agentMigration/AgentMigrationCancelDialog.tsx',
                'androidCaseHint': f"apps/raft_flutter/test/parity/cases/ext_migration_cancel.dart '{case_id}'",
                'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
data['cases'] = cases
manifest.write_text(json.dumps(data, indent=1))
