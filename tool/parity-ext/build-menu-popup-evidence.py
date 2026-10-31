#!/usr/bin/env python3
"""Add current-Raft real popup/Dialog evidence; preserve existing cases."""
import copy
import json
import os
import pathlib
import sys

ORDER = 2000  # after build-list-pages.py; no change to historical builders
here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402

path = manifest_path()
manifest = json.loads(path.read_text())
source = pathlib.Path(os.environ.get(
    'PARITY_RAFT_SOURCE', '/home/kevinzhow/.slock/agents/9a92b742-8942-488c-8635-67d224ec54ab/work/raft-source'))
shared = json.loads((source / 'packages/visual-testing/shared/sharedCases.json').read_text())
files_base = next(c for c in shared['cases'] if c['id'] == 'components.thread.files.list')
tasks_base = next(c for c in manifest['cases']
                  if c['id'] == 'components.list-pages.tasks.desktop-filter-assignee.brutal')
prefixes = ('components.files-popup.', 'components.list-pages.tasks.desktop-filter-assignee-popup.')
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith(prefixes)]

for suffix, theme in {'raft': 'raft-light', 'raft-dark': 'raft-dark'}.items():
    for state in ('default', 'hover', 'focus'):
        for family in ('files', 'tasks'):
            c = copy.deepcopy(files_base if family == 'files' else tasks_base)
            props = dict(c['variants'][0].get('props') or {})
            props.update(parityTheme=theme, menuPopupState=state, lang='en')
            if family == 'files':
                cid = f'components.files-popup.{state}.{suffix}'
                props.update(extKind='files-popup', platform='mobile')
                selector = '[data-testid="channel-file-overflow-menu"]'
                popup_key = 'channel-file-overflow-menu-visual-file-image'
                target = '[data-testid="channel-file-overflow-jump"]'
                flutter_target = {'text': 'Jump to original message', 'in': popup_key}
                interactions = [
                    {'type': 'wait', 'ms': 600},
                    {'type': 'click', 'target': '[data-testid="channel-file-overflow-trigger"][data-file-id="visual-file-image"]'},
                ]
                android = [
                    {'type': 'wait', 'ms': 600},
                    {'type': 'tap', 'key': 'channel-file-overflow-visual-file-image', 'mouse': True},
                ]
                hint = 'packages/web/src/components/message/ChannelFileOverflowMenu.tsx'
                dart = 'thread_composer.dart'
            else:
                cid = f'components.list-pages.tasks.desktop-filter-assignee-popup.{state}.{suffix}'
                # Preserve the real page and existing host dispatch props.
                selector = '[data-slot="popover-content"]'
                popup_key = 'task-selection-assignee-popover'
                target = selector + ' button:has-text("Cindy")'
                flutter_target = {'key': 'task-filter-Assignee-agent:agent-cindy'}
                interactions = copy.deepcopy(tasks_base['capture']['interactions'])
                android = [
                    {'type': 'wait', 'ms': 850},
                    {'type': 'tap', 'finder': {'text': 'Assignee'}, 'mouse': True},
                ]
                hint = 'packages/web/src/components/task/TasksPanel.tsx (IdentityFilterChip -> SelectionPopover)'
                dart = 'ext_list_pages.dart'
            interactions.append({'type': 'wait', 'ms': 300})
            android.append({'type': 'wait', 'ms': 300})
            if state == 'hover':
                interactions.append({'type': 'hover', 'target': target})
                android.append({'type': 'hover', 'finder': flutter_target})
            elif state == 'focus':
                interactions.extend([
                    {'type': 'press', 'target': selector, 'key': 'ArrowDown'}
                    if family == 'files' else {'type': 'tab', 'count': 1},
                    {'type': 'focus', 'target': target},
                ])
                android.append(
                    {'type': 'key', 'key': 'arrowDown'}
                    if family == 'files'
                    else {'type': 'focus', 'finder': flutter_target}
                )
            c.update(id=cid, title=f'Actual {family} popup bounds, {state} ({theme})',
                     captureType='component-fixture', suite='raft-flutter-extension',
                     category='extension/menu-popup', theme=theme, locale='en',
                     variants=[{'id': 'default', 'name': 'Default', 'props': props}],
                     capture={'selector': selector, 'metadataSelector': selector,
                              'crop': 'element', 'contract': 'component-bounds',
                              'androidKey': popup_key,
                              'interactions': interactions, 'androidInteractions': android},
                     reactPathHint=hint,
                     androidCaseHint=f'apps/raft_flutter/test/parity/cases/{dart}',
                     notes='Real product entry and full popup; no native platform or overall-shell pass claim.')
            manifest['cases'].append(c)

# Reuse the real directory -> agent profile -> reset dialog journey. The old
# members builder's nine legacy cases and their objects remain untouched.
reset_modes = ('restart', 'session', 'full')
reset_themes = {'raft': 'raft-light', 'raft-dark': 'raft-dark'}
reset_ids = {
    f'components.members-ext.agent.reset-{mode}.{suffix}'
    for mode in reset_modes for suffix in reset_themes
}
manifest['cases'] = [c for c in manifest['cases'] if c['id'] not in reset_ids]
for mode in reset_modes:
    base_id = f'components.members-ext.agent.reset-{mode}.elegant'
    base = next(c for c in manifest['cases'] if c['id'] == base_id)
    for suffix, theme in reset_themes.items():
        c = copy.deepcopy(base)
        props = c['variants'][0]['props']
        props.update(parityTheme=theme, lang='en')
        c.update(id=f'components.members-ext.agent.reset-{mode}.{suffix}',
                 title=f'Actual Reset agent dialog, {mode} ({theme})',
                 theme=theme, locale='en',
                 notes='Real directory/profile entry and full Dialog bounds; '
                       'original legacy cases are preserved.')
        manifest['cases'].append(c)

path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n')
print('12 current-Raft real Files/Tasks popups and 6 real Reset dialogs appended; historical cases untouched')
