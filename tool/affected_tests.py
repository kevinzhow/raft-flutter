#!/usr/bin/env python3
"""Which test files can execute a changed Dart file? (static import closure)

A test can only run code in files it reaches through `import` / `export` /
`part`, so the tests worth running for a change are exactly the test files from
which a changed file is reachable. The nightly per-PR coverage run uses this to
run a few dozen test files instead of the whole suite: the coverage of the
changed lines is then complete (no other test can hit them), not an estimate.

    tool/affected_tests.py --root DIR file1.dart file2.dart     # prints test files

Limits, all conservative toward running MORE tests: conditional imports follow
every branch; `part` files are tied to their library both ways; dynamic loading
(`Isolate.spawn(uri)`, `rootBundle`) is invisible, and so are non-Dart inputs
(assets, fixtures) -- a change to those is reported by the caller, not mapped.
"""
import argparse
import collections
import posixpath
import re
import subprocess
import sys

DIRECTIVE = re.compile(r'^\s*(import|export|part)\s+([^;]*);', re.M)
QUOTED = re.compile(r'''['"]([^'"]+)['"]''')
TEST_DIR = re.compile(r'(^|/)test/')


def directive_targets(source):
    """URIs named by import/export/part directives (every branch of a conditional import)."""
    targets = []
    for match in DIRECTIVE.finditer(source):
        kind, rest = match.group(1), match.group(2)
        if kind == 'part' and rest.strip().startswith('of'):
            continue  # `part of 'lib.dart'` is the child side; the library's `part` covers it
        targets.extend(QUOTED.findall(rest))
    return targets


def resolve(uri, source_file, package_roots):
    """Repo-relative path of a directive URI, or None for dart:/external packages."""
    if uri.startswith('dart:'):
        return None
    if uri.startswith('package:'):
        name, _, rest = uri[len('package:'):].partition('/')
        root = package_roots.get(name)
        return None if root is None else posixpath.join(root, 'lib', rest)
    if '://' in uri:
        return None
    return posixpath.normpath(posixpath.join(posixpath.dirname(source_file), uri))


def build_graph(sources, package_roots):
    """`{file: set(files it reaches directly)}` plus part<->library edges.

    `sources` maps repo-relative path -> Dart source text; `package_roots` maps
    package name -> repo-relative package directory (`raft_ui` -> `packages/raft_ui`).
    """
    graph = collections.defaultdict(set)
    known = set(sources)
    for file, text in sources.items():
        for uri in directive_targets(text):
            target = resolve(uri, file, package_roots)
            if target and target in known:
                graph[file].add(target)
        for match in DIRECTIVE.finditer(text):
            if match.group(1) == 'part':
                for uri in QUOTED.findall(match.group(2)):
                    target = resolve(uri, file, package_roots)
                    if target and target in known:
                        graph[target].add(file)  # editing a part changes its library
    return graph


def reverse_graph(graph):
    reverse = collections.defaultdict(set)
    for file, targets in graph.items():
        for target in targets:
            reverse[target].add(file)
    return reverse


def affected(changed, graph):
    """Every file from which a changed file is reachable (the changed files included)."""
    reverse = reverse_graph(graph)
    seen, stack = set(changed), list(changed)
    while stack:
        for parent in reverse.get(stack.pop(), ()):
            if parent not in seen:
                seen.add(parent)
                stack.append(parent)
    return seen


def distances(changed, graph):
    """`{file: import steps from a changed file}` for every file that reaches a changed file (changed files are 0)."""
    reverse = reverse_graph(graph)
    found = {name: 0 for name in changed}
    queue = collections.deque(sorted(changed))
    while queue:
        current = queue.popleft()
        for parent in sorted(reverse.get(current, ())):
            if parent not in found:
                found[parent] = found[current] + 1
                queue.append(parent)
    return found


def is_test_file(path):
    return path.endswith('_test.dart') and bool(TEST_DIR.search(path))


def affected_tests(changed, sources, package_roots):
    """Sorted test files (`*_test.dart` under a `test/` directory) that reach a changed file."""
    graph = build_graph(sources, package_roots)
    return sorted(f for f in affected(changed, graph) if is_test_file(f))


def ranked_affected_tests(changed, sources, package_roots):
    """`[(distance, test file)]`, closest first: a changed test is 0, a test importing the changed file is 1, and so on."""
    found = distances(changed, build_graph(sources, package_roots))
    return sorted((distance, name) for name, distance in found.items() if is_test_file(name))


def tracked_dart_sources(root):
    """`{path: text}` of every git-tracked .dart file under `root` (generated files are ignored by git and skipped)."""
    names = subprocess.run(['git', 'ls-files', '-z', '--', '*.dart'], cwd=root, capture_output=True, check=True).stdout
    sources = {}
    for raw in names.split(b'\0'):
        if not raw:
            continue
        name = raw.decode('utf-8')
        try:
            with open(posixpath.join(str(root).replace('\\', '/'), name), encoding='utf-8', errors='replace') as handle:
                sources[name] = handle.read()
        except OSError:
            pass
    return sources


def workspace_packages(root):
    """`{package name: repo-relative dir}` for apps/ and packages/ (the name from each pubspec.yaml)."""
    import pathlib
    found = {}
    for pubspec in sorted(pathlib.Path(root).glob('apps/*/pubspec.yaml')) + sorted(pathlib.Path(root).glob('packages/*/pubspec.yaml')):
        match = re.search(r'^name:\s*([A-Za-z0-9_]+)', pubspec.read_text(encoding='utf-8'), re.M)
        if match:
            found[match.group(1)] = pubspec.parent.relative_to(root).as_posix()
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', default='.')
    parser.add_argument('files', nargs='+')
    args = parser.parse_args(argv)
    for path in affected_tests(set(args.files), tracked_dart_sources(args.root), workspace_packages(args.root)):
        print(path)


if __name__ == '__main__':
    sys.exit(main())
