import json

from builders import manifest_path


PREFIX = 'components.managed-mcp.editor.'


def click(test_id):
    return {'type': 'click', 'target': f'[data-testid="{test_id}"]'}


def tap_text(text):
    return {'type': 'tapText', 'text': text, 'scroll': 'if-needed'}


register = [click('register-app-menu-trigger'), click('register-app-mcp-server')]
register_flutter = [tap_text('Add app'), tap_text('Add a custom MCP app')]
edit = [{'type': 'click', 'target': '[data-testid="connected-app-item-wiki"] button:has-text("Edit")'}]
edit_flutter = [{'type': 'tap', 'key': 'connected-app-action-mcp-wiki', 'scroll': 'if-needed'}]
states = {
    'new': (register, register_flutter),
    'probe-headers': (
        [*register,
         {'type': 'fill', 'target': '[data-testid="mcp-server-url-input"]',
          'value': 'https://mcp.example.invalid/mcp'},
         click('mcp-server-validate')],
        [*register_flutter, {'type': 'enterText', 'key': 'mcp-app-endpoint',
                            'text': 'https://mcp.example.invalid/mcp', 'scroll': 'if-needed'},
         tap_text('Validate')],
    ),
    'edit': (edit, edit_flutter),
    'connection-add': (
        [*edit, click('mcp-connection-add')],
        [*edit_flutter, tap_text('Add connection')],
    ),
    'editor-loading': (edit, edit_flutter),
    'editor-error': (edit, edit_flutter),
}

path = manifest_path()
manifest = json.loads(path.read_text())
cases = [case for case in manifest['cases'] if not case['id'].startswith(PREFIX)]
for state, (web, flutter) in states.items():
    for platform, width, height in [('desktop', 1280, 900), ('phone', 390, 844)]:
        for theme in ['raft-light', 'raft-dark']:
            case_id = f'{PREFIX}{state}.{platform}.{theme}'
            cases.append({
                'id': case_id,
                'title': f'Managed MCP app {state}, {platform} ({theme})',
                'captureType': 'component-fixture',
                'surface': 'mcp-app-editor',
                'category': 'extension/managed-mcp',
                'suite': 'raft-flutter-extension',
                'viewport': {'width': width, 'height': height, 'density': 1},
                'theme': theme,
                'locale': 'en',
                'variants': [{'id': 'default', 'name': 'Default', 'props': {
                    'extFixture': 'managed-mcp', 'routeSet': state, 'state': state,
                    'platform': platform, 'parityTheme': theme,
                }}],
                'capture': {
                    'selector': '[data-testid="mcp-app-editor"]',
                    'crop': 'element',
                    'androidKey': 'connected-app-editor',
                    'interactions': web,
                    'androidInteractions': flutter,
                },
                'reactPathHint': 'packages/web/src/components/settings/mcpApps/McpAppEditor.tsx',
                'androidCaseHint': 'apps/raft_flutter/test/parity/cases/ext_managed_mcp.dart',
                'tolerance': {'pixelRatio': 0.04, 'layoutDp': 1, 'ignoreAntialiasing': True},
            })
manifest['cases'] = cases
path.write_text(json.dumps(manifest, indent=1) + '\n')
