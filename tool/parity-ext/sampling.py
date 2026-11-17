"""Theme sampling for the parity extension suite (owner decision 2026-10-11).

The DEFAULT theme name (brutal-light) runs every case. The names elegant-light and
elegant-dark carry only the brightness (every name renders the Raft look), so each of them keeps 1-2 representative cases
per surface (surface = first three id segments, `components.<area>.<surface>`):

  1. the FIRST case of the surface in builder order (the default variant);
  2. one DENSE case: the first case whose name (id without the surface prefix
     and the theme suffix) contains a density keyword (DENSE_WORDS), else the
     LAST case of the surface; skipped when it is the same case as (1).

The choice is deterministic: it depends only on the builder order and ids, and
both non-default themes pick the same variants. Switches:

  PARITY_EXT_ALL_THEMES=1  every case of every theme (no sampling)
  PARITY_EXT_ALL_DARK=1    every elegant-dark case (elegant-light stays sampled)
"""
import os

DEFAULT_THEME = 'brutal-light'
SAMPLED_THEMES = ('elegant-light', 'elegant-dark')
DENSE_WORDS = ('long', 'many', 'dense', 'mixed', 'gallery', 'filled', 'full', 'rich', 'multi', 'batch')


def surface_of(case_id):
    return '.'.join(case_id.split('.')[:3])


def case_name(case):
    """Case id without the `components.<area>.<surface>.` prefix and the theme suffix."""
    parts = case['id'].split('.')
    suffix = {'brutal-light': 'brutal', 'elegant-light': 'elegant', 'elegant-dark': 'elegant-dark'}.get(case.get('theme'))
    if suffix and parts[-1] == suffix:
        parts = parts[:-1]
    return '.'.join(parts[3:])


def _is_dense(name):
    words = set(name.replace('.', '-').split('-'))
    return any(w in words for w in DENSE_WORDS)


def representative_names(cases):
    """-> ordered [name, ...] (1-2) kept per surface, from one theme's cases of that surface."""
    names = [case_name(c) for c in cases]
    keep = [names[0]]
    dense = next((n for n in names[1:] if _is_dense(n)), None) or names[-1]
    if dense not in keep:
        keep.append(dense)
    return keep


def sample_themes(manifest, env=None):
    env = os.environ if env is None else env
    if env.get('PARITY_EXT_ALL_THEMES') == '1':
        return manifest
    keep_all = {'elegant-dark'} if env.get('PARITY_EXT_ALL_DARK') == '1' else set()
    surfaces = {}  # (theme, surface) -> [cases in manifest order]
    for c in manifest['cases']:
        if c.get('theme') in SAMPLED_THEMES:
            surfaces.setdefault((c['theme'], surface_of(c['id'])), []).append(c)
    keep = set()
    for (theme, _), cases in surfaces.items():
        if theme in keep_all:
            keep.update(c['id'] for c in cases)
        else:
            wanted = set(representative_names(cases))
            keep.update(c['id'] for c in cases if case_name(c) in wanted)
    return {**manifest, 'cases': [c for c in manifest['cases']
                                  if c.get('theme') not in SAMPLED_THEMES or c['id'] in keep]}


def sampled_themes_note(env=None):
    env = os.environ if env is None else env
    if env.get('PARITY_EXT_ALL_THEMES') == '1':
        return 'all themes, every case (PARITY_EXT_ALL_THEMES=1)'
    note = 'brutal-light complete; elegant-light and elegant-dark sampled to 1-2 cases per surface'
    if env.get('PARITY_EXT_ALL_DARK') == '1':
        note += ' (elegant-dark complete: PARITY_EXT_ALL_DARK=1)'
    return note + ' (PARITY_EXT_ALL_THEMES=1 for all)'
