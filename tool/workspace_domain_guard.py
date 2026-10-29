#!/usr/bin/env python3
"""Keep migrated workspace domains independent of the controller facade.

Legacy edges are an explicit, non-growing migration inventory. A clean or new
file receives no allowance. This checks import/export edges, root type mentions,
and common dynamic/opaque-identity escapes; normal JSON dynamic remains valid.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys

spec = importlib.util.spec_from_file_location('domain_guard_lexer', Path(__file__).with_name('controller_clusters.py'))
lexer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lexer)
ROOT_FILE = 'workspace_controller.dart'
MANIFEST = 'tool/workspace-domain-boundaries.json'
ROOT_PROPERTIES = {'client', 'server', 'channel', 'composer', 'messageWindows', 'ledger', 'services', 'notifyListeners', 'presentationSource', 'sessionScope', 'readState', 'navigation'}
ROOT_NAMES = {'context', 'workspace', 'controller', 'root', 'receiver', 'authority'}


def directives(text):
    code, strings = lexer.blank(text)
    result = []
    for match in re.finditer(r'\b(import|export|part)\b', code):
        prefix = code[:match.start()].rstrip()
        if prefix and prefix[-1] not in ';}':
            continue
        end = code.find(';', match.end())
        if end < 0:
            continue
        for offset, value in strings.items():
            if match.end() <= offset < end:
                result.append((match.group(1), value))
    return code, result


def resolve_uri(root, source, uri):
    if uri.startswith('package:raft_flutter/'):
        return root / 'apps/raft_flutter/lib' / uri.split('/', 1)[1]
    if ':' in uri:
        return None
    return (source.parent / uri).resolve()


def exports_root(root, source, seen=None):
    if source.name == ROOT_FILE:
        return True
    seen = set() if seen is None else seen
    if source in seen or not source.is_file():
        return False
    seen.add(source)
    _, imports = directives(source.read_text(encoding='utf-8'))
    for kind, uri in imports:
        target = resolve_uri(root, source, uri)
        if kind == 'export' and target is not None and exports_root(root, target, seen):
            return True
    return False


def inspect(root, source, text):
    code, imports = directives(text)
    root_edges = sum(1 for _, uri in imports if (target := resolve_uri(root, source, uri)) is not None and exports_root(root, target))
    identifiers = len(re.findall(r'\bWorkspaceController\b', code))
    violations = []
    if re.search(r'\bas\s+dynamic\b', code):
        violations.append('dynamic-cast: do not erase a domain/context type')
    dynamic_vars = set(re.findall(r'\bdynamic\s+([A-Za-z_]\w*)', code))
    for name in sorted(dynamic_vars):
        if name.lstrip('_') in ROOT_NAMES or re.search(r'\b' + re.escape(name) + r'\s*\.\s*(?:' + '|'.join(ROOT_PROPERTIES) + r')\b', code):
            violations.append(f'dynamic-root: {name} must use a typed domain port')
    opaque = set(re.findall(r'\b(?:final|var|Object\??|dynamic)\s+([A-Za-z_]\w*)\s*=\s*[^;]*?\breceiverKey\b', code))
    # Track direct aliases of an opaque receiver, across simple assignments.
    changed = True
    while changed:
        changed = False
        for name, value in re.findall(r'\b(?:final|var|Object\??|dynamic)\s+([A-Za-z_]\w*)\s*=\s*([A-Za-z_]\w*)\s*;', code):
            if value in opaque and name not in opaque:
                opaque.add(name)
                changed = True
    for name in sorted(opaque):
        if re.search(r'\b' + re.escape(name) + r'\s*\.', code):
            violations.append(f'opaque-receiver: {name} is an identity key, not a root-object port')
    for name in ROOT_NAMES:
        if re.search(r'\bfinal\s+_*' + name + r'\s*;', code):
            violations.append(f'untyped-root: declare a typed port for {name}')
    return {'rootEdges': root_edges, 'rootIdentifiers': identifiers}, violations


def check(root):
    manifest = json.loads((root / MANIFEST).read_text(encoding='utf-8'))
    legacy = manifest['legacyDomains']
    hosts = manifest['compositionHosts']
    allowances = legacy | hosts
    findings = []
    counts = {}
    lib = root / 'apps/raft_flutter/lib'
    files = sorted(p for p in lib.rglob('*.dart') if p.is_relative_to(lib / 'data') or 'domain' in p.relative_to(lib).parts or 'view_models' in p.relative_to(lib).parts or p.name.endswith(('_view_model.dart', '_viewmodel.dart')))
    for source in files:
        relative = source.relative_to(root).as_posix()
        if source.name == ROOT_FILE:
            continue
        stats, local = inspect(root, source, source.read_text(encoding='utf-8'))
        counts[relative] = stats
        allowance = allowances.get(relative, {'rootEdges': 0, 'rootIdentifiers': 0})
        for key in ('rootEdges', 'rootIdentifiers'):
            if stats[key] > allowance[key]:
                findings.append(f'{relative}: {key} {stats[key]} > {allowance[key]}')
            elif relative in allowances and stats[key] < allowance[key]:
                findings.append(f'{relative}: lower the {key} allowance to {stats[key]}')
        if relative in allowances and not any(stats.values()):
            findings.append(f'{relative}: remove the stale legacy allowance after migration')
        findings.extend(f'{relative}: {entry}' for entry in local)
    for name in allowances:
        if name not in counts:
            findings.append(f'{name}: allowance does not resolve to a domain/host file')
    return {'passed': not findings, 'scanned': len(counts), 'legacyDomains': len(legacy), 'compositionHosts': len(hosts), 'findings': findings}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    result = check(args.root.resolve())
    print(json.dumps(result, indent=2))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
