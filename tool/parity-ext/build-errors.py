#!/usr/bin/env python3
"""Append the error-presentation cases to the run-time manifest ($PARITY_EXT_MANIFEST).

Idempotent: every `components.errors.*` case is replaced, all others are kept.

Derivation (raft-source packages/web/src):
  components/LocalizedToastProvider.tsx  toast rows (ToastRoot layout=inline + icon + title + close)
  components/ui/Banner.tsx               <Banner intent="warning" className="font-bold">
  components/ui/FormField.tsx            FormField error= / hint=
  components/task/CreateTaskDialog.tsx   dialog error row (DialogCard + Banner)
  components/agent/AgentSkills.tsx       page-level load failure + Retry
Auth page error banners are covered by components.auth.* (login.error, forgot.error, ...).
Ids: components.errors.<surface>.<variant>.<theme>; the first variant of a surface is its default.
"""
import json
import pathlib
import sys

here = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(here))
from builders import manifest_path  # noqa: E402  (tool/parity-ext/builders.py)
THEMES = {'brutal': 'brutal-light', 'elegant': 'elegant-light', 'elegant-dark': 'elegant-dark'}
DART = 'ext_errors.dart'
HINTS = {
    'toast': 'packages/web/src/components/LocalizedToastProvider.tsx',
    'banner': 'packages/web/src/components/ui/Banner.tsx',
    'field': 'packages/web/src/components/ui/FormField.tsx',
    'dialog': 'packages/web/src/components/task/CreateTaskDialog.tsx (+ ui/DialogCard.tsx)',
    'loaderror': 'packages/web/src/components/agent/AgentSkills.tsx (error block)',
}
LONG = ('The server could not complete this request because your session expired. '
        'Sign in again and retry.')


def case(surface, variant, message, *, viewport, selector, android_key=None, title, width=480,
         interactions=(), android=()):
    out = []
    for suffix, theme in THEMES.items():
        cid = f'components.errors.{surface}.{variant}.{suffix}'
        props = {'extCase': f'{surface}.{variant}', 'extKind': 'errors', 'parityTheme': theme,
                 'surface': surface, 'variant': variant, 'message': message, 'width': str(width)}
        capture = {'selector': selector.replace('{cid}', cid), 'crop': 'element', 'contract': 'component-bounds',
                   'interactions': list(interactions), 'androidInteractions': list(android)}
        if android_key:
            capture['androidKey'] = android_key
        out.append({
            'id': cid,
            'title': f'Error presentation: {title} ({theme})',
            'captureType': 'component-fixture',
            'surface': 'errors',
            'category': 'extension/errors',
            'suite': 'raft-flutter-extension',
            'viewport': viewport,
            'theme': theme,
            'locale': 'en',
            'variants': [{'id': 'default', 'name': 'Default', 'props': props}],
            'capture': capture,
            'reactPathHint': HINTS[surface],
            'androidCaseHint': f"apps/raft_flutter/test/parity/cases/{DART} '{surface}.{variant}'",
            'tolerance': {'pixelRatio': 0.02, 'layoutDp': 1, 'ignoreAntialiasing': True},
        })
    return out


FRAME = "[data-visual-case='{cid}']"
cases = []
TOAST_VP = {'width': 480, 'height': 240, 'density': 1}
for variant, message, label in [
    ('error', 'Failed to update profile', 'error, title only'),
    ('error-long', LONG, 'error, wrapping title'),
    ('success', 'Channel converted successfully to a Joint Channel.', 'success'),
    ('info', '2 selected messages are no longer available.', 'info'),
]:
    cases += case('toast', variant, message, viewport=TOAST_VP, selector='[data-testid="localized-toast-row"]',
                  android_key='errors-toast', title=f'toast {label}',
                  interactions=[{'type': 'wait', 'ms': 800}])

BANNER_VP = {'width': 480, 'height': 160, 'density': 1}
for variant, message, label in [
    ('line', 'Failed to create task', 'one line'),
    ('long', LONG, 'wrapping message'),
    ('sm', 'Failed to load skills', 'density sm'),
    ('action', 'Failed to load skills', 'with Try again action'),
]:
    cases += case('banner', variant, message, viewport=BANNER_VP, selector=FRAME, android_key=None,
                  title=f'banner {label}')

FIELD_VP = {'width': 480, 'height': 140, 'density': 1}
cases += case('field', 'error', 'Invalid email format', viewport=FIELD_VP, selector=FRAME, title='field with error')
cases += case('field', 'hint', 'Shown in the sidebar, invites, and setup prompts.', viewport=FIELD_VP,
              selector=FRAME, title='field with hint')

DIALOG_VP = {'width': 640, 'height': 480, 'density': 1}
TITLE = 'Wire the Tasks board to the new status lanes'
steps = [{'type': 'fill', 'target': 'input[placeholder="Task 1"]', 'value': TITLE},
         {'type': 'click', 'target': 'role=button[name="Create Task"s]'}, {'type': 'wait', 'ms': 300}]
a_steps = [{'type': 'tap', 'key': 'create-task-submit'}]
for variant, message, label in [('error', 'Failed to create task', 'server error'),
                                ('error-long', LONG, 'wrapping server error')]:
    cases += case('dialog', variant, message, viewport=DIALOG_VP,
                  selector='.fixed.inset-0 [data-slot="dialog-card"]', android_key='create-task-dialog',
                  title=f'create task dialog, {label}', interactions=steps, android=a_steps)

LOAD_VP = {'width': 480, 'height': 200, 'density': 1}
cases += case('loaderror', 'page', 'Failed to load skills', viewport=LOAD_VP, selector=FRAME,
              title='page load failure with Retry')
cases += case('loaderror', 'embedded', 'Failed to load skills', viewport=LOAD_VP, selector=FRAME,
              title='embedded load failure with Retry')

path = manifest_path()
manifest = json.loads(path.read_text())
manifest['cases'] = [c for c in manifest['cases'] if not c['id'].startswith('components.errors.')] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
print(f'{len(cases)} error presentation cases appended ({len(manifest["cases"])} total)')
