"""Preconditions for a current Web comparison; no image scores or thresholds."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess


class InvalidComparison(ValueError):
    pass


def configure_theme(*, frozen: bool, env: dict) -> str | None:
    override = env.get('PARITY_THEME_OVERRIDE') or None
    modern = {'raft-case', 'raft', 'raft-light', 'raft-dark', 'light'}
    if frozen:
        if override in modern:
            raise InvalidComparison('Frozen references cannot use a Raft theme override.')
        return override
    if override is not None and override not in modern:
        raise InvalidComparison('A current Web comparison requires the Raft look; use --frozen for legacy references.')
    # Historical case names carry brightness, not the current comparison look.
    env['PARITY_THEME_OVERRIDE'] = override or 'raft-case'
    return env['PARITY_THEME_OVERRIDE']


def validate_reference(source: Path, contract: dict) -> dict:
    source = source.resolve(strict=True)
    try:
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
        dirty = subprocess.check_output([
            'git', 'status', '--porcelain', '--untracked-files=no', '--',
            'packages/web/src', 'packages/web/package.json', 'pnpm-lock.yaml',
        ], cwd=source, text=True).strip()
        web = source / 'packages/web'
        web_version = json.loads((web / 'package.json').read_text())['version']
        package = (web / 'node_modules/@botiverse/raft-ui').resolve(strict=True)
        ui_version = json.loads((package / 'package.json').read_text())['version']
        actual_files = {
            str(path.relative_to(package)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted((package / 'dist').rglob('*'))
            if path.is_file() and path.suffix in {'.mjs', '.css'}
        }
    except (OSError, KeyError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        raise InvalidComparison('The pinned Web source and installed UI package must be readable.') from error
    mismatches = [
        name for name, actual, expected in [
            ('Web commit', commit, contract['webCommit']),
            ('Web version', web_version, contract['webVersion']),
            ('UI version', ui_version, contract['raftUIVersion']),
            ('UI published files', actual_files, contract['raftUIFiles']),
        ] if actual != expected
    ]
    if dirty:
        mismatches.append('tracked Web source changes')
    if mismatches:
        raise InvalidComparison('Reference mismatch: ' + ', '.join(mismatches) + '. Update the explicit reference contract when advancing upstream.')
    return {'sourceRoot': str(source), 'webCommit': commit, 'webVersion': web_version,
            'raftUIVersion': ui_version, 'publishedFilesChecked': len(actual_files)}


def expected_theme(case: dict, override: str) -> str:
    if override != 'raft-case':
        return 'raft-dark' if override == 'raft-dark' else 'raft-light'
    props = ((case.get('variants') or [{}])[0].get('props') or {})
    return 'raft-dark' if str(props.get('parityTheme', '')).endswith('dark') else 'raft-light'


def validate_flutter_metadata(cases: list[dict], directory: Path, override: str) -> dict:
    checked = 0
    errors = []
    for case in cases:
        case_id = case['id']
        if not (directory / f'{case_id}.png').is_file():
            continue  # Capture failures are handled by the existing required-image checks.
        try:
            data = json.loads((directory / f'{case_id}.metadata.json').read_text())
            if (data.get('source'), data.get('caseId'), data.get('theme')) != (
                'flutter', case_id, expected_theme(case, override)
            ):
                errors.append(case_id + ': Flutter look or case provenance does not match the Web comparison')
            checked += 1
        except (OSError, json.JSONDecodeError):
            errors.append(case_id + ': captured image lacks readable provenance metadata')
    result = {'phase': 'flutter-metadata', 'checkedImages': checked,
              'status': 'INADMISSIBLE' if errors else 'VALIDATED' if checked else 'NOT_RUN',
              'errors': errors}
    return result
