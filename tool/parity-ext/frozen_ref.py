"""Frozen reference images for the Elegant and Brutal looks (owner scope 2026-10-24).

The Raft look is compared against the pinned Web render. Elegant and Brutal have no Web counterpart any more, so
each is compared against its own frozen original: the Flutter render of commit a57b9dab captured once
(tool/theme-baseline for the official cases and the extension desktop cases, tool/parity-ext/frozen-capture for the
rest). `install` copies those images into <results>/react/ under the case ids, which is where the official diff
looks for its reference, so every later step (diff, site, summary) is the unmodified pipeline.
"""
import json
import os
import pathlib
import shutil

HERE = pathlib.Path(__file__).resolve().parent
REGISTRY = json.loads((HERE / 'frozen-baselines.json').read_text())


def root():
    return pathlib.Path(os.environ.get('PARITY_FROZEN_ROOT', '/mnt/data/theme-baseline'))


def search_dirs(kind, theme=None):
    """Directories to search, in priority order. kind: 'ext' or 'official' (+ theme-name for official)."""
    rels = REGISTRY['ext'] if kind == 'ext' else REGISTRY['official'][theme]
    return [root() / r for r in rels]


def find(case_id, dirs):
    for d in dirs:
        png = d / f'{case_id}.png'
        if png.is_file():
            return png
    return None


def install(results_dir, case_ids, dirs):
    """Copy the frozen image (+ metadata when present) of every case id to <results>/react/. -> (found, missing)."""
    react = pathlib.Path(results_dir) / 'react'
    react.mkdir(parents=True, exist_ok=True)
    found, missing = [], []
    for case_id in case_ids:
        dest_png = react / f'{case_id}.png'
        dest_meta = react / f'{case_id}.metadata.json'
        dest_png.unlink(missing_ok=True)
        dest_meta.unlink(missing_ok=True)
        png = find(case_id, dirs)
        if png is None:
            missing.append(case_id)
            continue
        shutil.copyfile(png, dest_png)
        meta = png.with_name(f'{case_id}.metadata.json')
        if meta.is_file():
            data = json.loads(meta.read_text())
            data['source'] = 'frozen-a57b9dab'
            dest_meta.write_text(json.dumps(data))
        found.append(case_id)
    return found, missing
