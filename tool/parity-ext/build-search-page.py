#!/usr/bin/env python3
"""Add mounted Search page states to the extension manifest."""
import json

from builders import manifest_path, raft_source

PREFIX = 'components.search-ext.'
INPUT = '[data-testid="message-search-input"]'
CHANNEL = 'button[aria-label="Open channel filter"]'
WAIT = {'type': 'wait', 'ms': 850}


def build_cases(official):
    for platform, states in (
        ('phone', ('results', 'channel-dropdown', 'scoped')),
        ('desktop', ('results', 'filters', 'channel-dropdown', 'artifacts')),
    ):
        phone = platform == 'phone'
        viewport = (
            {'width': 390, 'height': 844, 'density': 3, 'touch': True}
            if phone else {'width': 1280, 'height': 900, 'density': 1}
        )
        for state in states:
            themes = ('raft-dark',) if phone and state != 'scoped' else ('raft-light', 'raft-dark')
            for theme in themes:
                case_id = f'{PREFIX}{platform}.{state}.{theme}'
                actions = [
                    {'type': 'fill', 'target': INPUT, 'value': 'android'},
                    WAIT,
                ]
                if state == 'channel-dropdown':
                    if phone:
                        actions.extend([
                            {'type': 'reveal', 'target': CHANNEL},
                            {'type': 'wait', 'ms': 1050},
                        ])
                    actions.extend([{'type': 'click', 'target': CHANNEL}, {'type': 'wait', 'ms': 250}])
                if state == 'filters':
                    actions.extend([
                        {'type': 'click', 'target': 'button[aria-label="Time"]'},
                        {'type': 'click', 'target': '[role="option"]:has-text("Last 7 days")'},
                        {'type': 'click', 'target': '[data-testid="search-sort-chip"]'},
                        {'type': 'click', 'target': '[role="option"]:has-text("Recent")'},
                        WAIT,
                        {'type': 'tab', 'count': 1},
                        {'type': 'focus', 'target': CHANNEL},
                    ])
                selector = f'[data-visual-case="{case_id}"]'
                yield {
                    'id': case_id,
                    'title': f'Search page ({platform}): {state} ({theme})',
                    'captureType': 'component-fixture',
                    'surface': 'search-ext',
                    'category': 'extension/search-page',
                    'suite': 'raft-flutter-extension',
                    'viewport': viewport,
                    'theme': theme,
                    'locale': 'en',
                    'variants': [{'id': 'default', 'name': 'Default', 'props': {
                        'extCase': state,
                        'extKind': 'search-page',
                        'extFixture': 'search-page',
                        'routeSet': state,
                        'platform': 'mobile' if phone else 'desktop',
                        'parityTheme': theme,
                        'lang': 'en',
                    }}],
                    'capture': {
                        'selector': selector,
                        'crop': 'element',
                        'contract': 'component-bounds',
                        'interactions': actions,
                    },
                    'reactPathHint': 'packages/web/src/features/search/MessageSearchPage.tsx',
                    'androidCaseHint': 'apps/raft_flutter/test/parity/cases/ext_search_page.dart',
                    'tolerance': official['tolerance'],
                }


def main():
    shared = raft_source() / 'packages/visual-testing/shared/sharedCases.json'
    official = next(case for case in json.loads(shared.read_text())['cases']
                    if case['id'] == 'components.home.search.results')
    path = manifest_path()
    manifest = json.loads(path.read_text())
    manifest['cases'] = [case for case in manifest['cases'] if not case['id'].startswith(PREFIX)]
    manifest['cases'].extend(build_cases(official))
    path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    main()
