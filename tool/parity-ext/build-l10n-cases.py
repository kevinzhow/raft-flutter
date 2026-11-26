from copy import deepcopy
import json

from builders import manifest_path

ORDER = 2000

path = manifest_path()
manifest = json.loads(path.read_text())
source = {case['id']: case for case in manifest['cases']}
cases = []
for platform in ('desktop', 'mobile'):
    for theme in ('brutal', 'elegant-dark'):
        settings = 'settings.language' + ('-mobile' if platform == 'mobile' else '')
        home = f'components.shell.{platform}.home.index'
        for locale in ('en', 'es', 'pt-br', 'ru', 'ko', 'ja', 'zh-tw'):
            for surface, base in (
                ('settings', f'components.wp6.{settings}'),
                ('picker', f'components.wp6.{settings}'),
                ('home', home),
                ('channel', home),
            ):
                if surface in ('home', 'channel') and locale not in ('ru', 'ja'):
                    continue
                case = deepcopy(source[f'{base}.{theme}'])
                case['id'] = f'{base}.l10n-{surface}-{locale}.{theme}'
                case['title'] = f'{locale} {surface} ({platform}, {theme})'
                case['locale'] = locale
                case['viewport']['height'] = 900 if platform == 'desktop' else 844
                case['androidCaseHint'] = 'apps/raft_flutter/test/parity/cases/ext_l10n.dart'
                capture = case['capture']
                capture['selector'] = capture['selector'].replace(f'{base}.{theme}', case['id'])
                props = case['variants'][0]['props']
                props.update(lang=locale, displayLanguage=locale)
                if surface == 'channel':
                    props.update(preset='default', route='channel/shell-design', routeSet='row')
                if surface == 'picker':
                    capture.update(selector='body', crop='viewport')
                    capture.pop('androidKey', None)
                    capture['interactions'].append({
                        'type': 'click', 'target': '[data-testid="display-language-select"]',
                    })
                    capture['androidInteractions'].append({
                        'type': 'tap', 'key': 'display-language-select',
                    })
                cases.append(case)

manifest['cases'] = [case for case in manifest['cases'] if '.l10n-' not in case['id']] + cases
path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n')
