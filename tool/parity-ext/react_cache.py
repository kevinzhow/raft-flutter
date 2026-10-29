"""Content-addressed cache of the Web (React) parity captures, shared by every
raft-flutter worktree: <cache>/react/<key>.png (+ .metadata.json, .key.json).

The key hashes everything that can change what the React side renders; the
Flutter side is not an input, so Flutter-only edits (and Flutter-only manifest
fields) never invalidate a capture:

  * raft-source commit + a digest of its uncommitted changes;
  * the case JSON minus its Flutter-only fields (id, fixture/props, viewport,
    theme, locale, capture selector + interactions, ...);
  * the fixture files the case's host reads (full bytes) and, for the other
    fixtures, their route/list structure (the generated spec registers every
    fixture's routes for every case);
  * the host .tsx file(s) that render the case (plus any other host file whose
    top-level declarations they use);
  * the capture machinery: tool/parity-ext-web.mjs, the spec/config patches
    (repr'd with this worktree's path normalised), tool/parity and the helper
    modules that patch the official spec, reference patches, cached fonts;
  * render flags (text rendering mode, Chromium args, deviceScaleFactor).

Entries are written temp + rename (png first, metadata last; an entry exists
once its metadata does), so concurrent worktrees can share the directory.
"""
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess

# Fields only the Flutter provider (or humans) read; never part of the key.
FLUTTER_ONLY_TOP = ('androidCaseHint', 'notes', 'tolerance', 'reactPathHint')
FLUTTER_ONLY_CAPTURE = ('androidKey', 'androidInteractions')
VERSION = 2


def default_cache_dir(root):
    """<main checkout>/../raft-flutter-wt/.parity-cache, the same for every worktree."""
    override = os.environ.get('PARITY_EXT_CACHE')
    if override:
        return pathlib.Path(override)
    r = subprocess.run(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'], cwd=root,
                       capture_output=True, text=True)
    main = pathlib.Path(r.stdout.strip()).parent if r.returncode == 0 and r.stdout.strip() else pathlib.Path(root)
    return main.parent / 'raft-flutter-wt' / '.parity-cache'


def sha(data):
    if isinstance(data, str):
        data = data.encode()
    return hashlib.sha256(data).hexdigest()


def tree_digest(paths):
    """Digest of file names + bytes under the given files/directories."""
    h = hashlib.sha256()
    for p in paths:
        p = pathlib.Path(p)
        files = sorted(f for f in p.rglob('*') if f.is_file()) if p.is_dir() else [p]
        for f in files:
            if f.is_file():
                h.update(f.relative_to(p.parent).as_posix().encode() + b'\0' + f.read_bytes() + b'\0')
    return h.hexdigest()


def flutter_free_case(case):
    c = {k: v for k, v in case.items() if k not in FLUTTER_ONLY_TOP}
    if isinstance(c.get('capture'), dict):
        c['capture'] = {k: v for k, v in c['capture'].items() if k not in FLUTTER_ONLY_CAPTURE}
    return c


def _canon(obj):
    return json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(',', ':'))


# ---------------------------------------------------------------- host / fixtures
_DECL = re.compile(r'^(?:export\s+)?(?:async\s+)?(?:function|const|let|var|class|type|interface)\s+([A-Za-z_$][\w$]*)', re.M)
_FIXTURE_IMPORT = re.compile(r'virtual:parity-ext/([\w.-]+)')


class Hosts:
    """tool/parity-ext/host/*.tsx: which file(s) render which case."""

    def __init__(self, host_dir):
        self.files = {p.name: p.read_text() for p in sorted(pathlib.Path(host_dir).glob('*.tsx'))}
        self.decls = {n: set(_DECL.findall(t)) for n, t in self.files.items()}

    def claiming(self, case):
        """Host files that mention the case's area (`components.<area>.` or the quoted
        area/extKind). No claimant -> every host file (safe)."""
        parts = case['id'].split('.')
        area = parts[1] if len(parts) > 1 else ''
        props = ((case.get('variants') or [{}])[0].get('props')) or {}
        tokens = [f'components.{area}.', f'"{area}"', f"'{area}'"]
        if props.get('extKind'):
            tokens.append(f'"{props["extKind"]}"')
        hit = [n for n, t in self.files.items() if any(tok in t for tok in tokens)]
        return hit or sorted(self.files)

    def closure(self, names):
        """Add host files whose top-level declarations the chosen files use."""
        chosen = set(names)
        grew = True
        while grew:
            grew = False
            words, own = set(), set()
            for n in chosen:
                words |= set(re.findall(r'[A-Za-z_$][\w$]*', self.files[n]))
                own |= self.decls[n]
            for n, decls in self.decls.items():
                if n not in chosen and (decls - own) & words:
                    chosen.add(n)
                    grew = True
        return sorted(chosen)

    def fixtures_used(self, names):
        return sorted({m for n in names for m in _FIXTURE_IMPORT.findall(self.files[n])})


def fixture_structure(data):
    """What other fixtures contribute to a case: their route keys / route sets / list names
    (the spec registers every fixture's routes for every case)."""
    if not isinstance(data, dict):
        return None
    return {
        'keys': sorted(data),
        'routes': sorted((data.get('routes') or {}).keys()),
        'routeSets': {k: sorted(v) if isinstance(v, dict) else None for k, v in (data.get('routeSets') or {}).items()},
        'lists': sorted((data.get('lists') or {}).keys()),
        'search': bool(data.get('search')),
    }


class KeyContext:
    """Everything that is the same for all cases of a run, computed once."""

    def __init__(self, root, ext, source, machinery):
        self.root, self.ext, self.source = pathlib.Path(root), pathlib.Path(ext), pathlib.Path(source)
        self.hosts = Hosts(self.ext / 'host')
        self.fixture_bytes = {p.stem: p.read_bytes() for p in sorted((self.ext / 'fixtures').glob('*.json'))}
        self.fixture_struct = {}
        for n, b in self.fixture_bytes.items():
            try:
                self.fixture_struct[n] = fixture_structure(json.loads(b))
            except ValueError:
                self.fixture_struct[n] = sha(b)
        tool = self.root / 'tool'
        norm = str(self.root)
        self.executor_inputs = {
            name: sha(path.read_bytes()) if path.is_file() else None
            for name, path in {
                'driver': self.ext / 'run',
                'upstreamSpec': self.source / 'packages/visual-testing/tests/react-provider.spec.ts',
                'upstreamConfig': self.source / 'packages/web/playwright.visual-testing.config.ts',
                'baseProvider': tool / 'parity',
            }.items()
        }
        self.executor_inputs['machinery'] = sha(machinery.replace(norm, '<root>'))
        self.source_bindings = {
            'v': VERSION,
            'raftCommit': self._git('rev-parse', 'HEAD'),
            'raftDirty': sha(self._git('status', '--short') + self._git('diff', 'HEAD')),
            'machinery': machinery.replace(norm, '<root>'),
            'executorInputs': self.executor_inputs,
            'files': [sha((tool / f).read_bytes()) if (tool / f).is_file() else None for f in (
                'parity-ext-web.mjs', 'parity', 'parity-baseline-web.mjs',
                'parity_baseline_repairs.py', 'parity_reference_defects.py')],
            'trees': tree_digest([tool / 'parity-fonts', tool / 'reference-patches']),
        }
        self.common = sha(_canon(self.source_bindings))

    def _git(self, *args):
        r = subprocess.run(['git', *args], cwd=self.source, capture_output=True, text=True)
        return r.stdout.strip() if r.returncode == 0 else ''

    def inputs(self, case):
        hosts = self.hosts.closure(self.hosts.claiming(case))
        used = self.hosts.fixtures_used(hosts)
        return {
            'cacheVersion': VERSION,
            'common': self.common,
            'executorInputs': self.executor_inputs,
            'sourceBindings': self.source_bindings,
            'case': flutter_free_case(case),
            'hosts': {n: sha(self.hosts.files[n]) for n in hosts},
            'fixtures': {n: sha(self.fixture_bytes[n]) for n in used if n in self.fixture_bytes},
            'otherFixtures': {n: self.fixture_struct[n] for n in self.fixture_struct if n not in used},
        }

    def key(self, case):
        return sha(_canon(self.inputs(case)))[:40]


# ---------------------------------------------------------------- storage
def artifact_identity(png, metadata):
    """Identity of an existing pair, without changing its original metadata."""
    return {'pngSha256': sha(pathlib.Path(png).read_bytes()),
            'metadataSha256': sha(pathlib.Path(metadata).read_bytes())}


def _hash(value):
    return isinstance(value, str) and re.fullmatch(r'[0-9a-f]{64}', value) is not None


def _valid_proof(proof, key, case_id, inputs, png, meta):
    """Execution identity is evidence of bytes run, never of rendered UI state."""
    if not isinstance(proof, dict) or not isinstance(inputs, dict):
        return False
    executor = inputs.get('executorInputs', {})
    bindings = inputs.get('sourceBindings', {})
    if not isinstance(executor, dict) or not isinstance(bindings, dict):
        return False
    if (inputs.get('cacheVersion') != VERSION or bindings.get('v') != VERSION
            or not all(_hash(executor.get(name)) for name in
                       ('driver', 'upstreamSpec', 'upstreamConfig', 'baseProvider', 'machinery'))
            or bindings.get('executorInputs') != executor
            or inputs.get('common') != sha(_canon(bindings))
            or key != sha(_canon(inputs))[:40]):
        return False
    generated, applied = proof.get('generated', {}), proof.get('appliedPatches', {})
    execution = proof.get('execution', {})
    if not all(isinstance(value, dict) for value in (generated, applied, execution)):
        return False
    if (proof.get('version') != VERSION or proof.get('caseId') != case_id
            or proof.get('cacheKey') != key
            or proof.get('sourceBindings') != bindings
            or proof.get('executorInputs') != executor
            or not all(_hash(generated.get(name)) for name in ('specSha256', 'configSha256'))
            or applied.get('baseProviderSha256') != executor.get('baseProvider')
            or not _hash(applied.get('appendixSha256'))
            or proof.get('appliedPatchIdentity') != sha(_canon(applied))
            or execution.get('temporaryBytesStable') is not True
            or not isinstance(execution.get('returncode'), int)
            or not all(isinstance(execution.get(name), str) and execution[name]
                       for name in ('startedAt', 'completedAt'))
            or proof.get('observedState') != {'status': 'not-recorded'}):
        return False
    for name in ('spec', 'config'):
        snapshot, executed = generated.get(f'{name}Snapshot'), generated.get(f'{name}ExecutedPath')
        if (not isinstance(snapshot, str) or not snapshot
                or not isinstance(executed, str) or not executed
                or sha(pathlib.Path(snapshot).read_bytes()) != generated[f'{name}Sha256']):
            return False
    for name in ('spec', 'config'):
        if not isinstance(applied.get(name), list):
            return False
        if not all(isinstance(patch, dict) and _hash(patch.get('anchorSha256'))
                   and _hash(patch.get('replacementSha256')) for patch in applied[name]):
            return False
    metadata = json.loads(pathlib.Path(meta).read_text())
    return (metadata.get('caseId') == case_id
            and isinstance(proof.get('capturedAt'), str) and bool(proof['capturedAt'])
            and metadata.get('capturedAt') == proof['capturedAt']
            and proof.get('artifacts') == artifact_identity(png, meta))


class Cache:
    def __init__(self, directory):
        self.dir = pathlib.Path(directory) / 'react'
        self.last_store_status = None

    def paths(self, key):
        return (self.dir / f'{key}.png', self.dir / f'{key}.metadata.json', self.dir / f'{key}.key.json')

    def _entry(self, key, inputs=None):
        png, meta, info = self.paths(key)
        try:
            entry = json.loads(info.read_text())
            own_inputs, proof = entry['inputs'], entry['executionProof']
            if (entry.get('version') != VERSION or (inputs is not None and own_inputs != inputs)
                    or entry.get('proofSha256') != sha(_canon(proof))
                    or proof.get('execution', {}).get('returncode') != 0
                    or not _valid_proof(proof, key, entry['caseId'], own_inputs, png, meta)):
                return None
            return entry
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            return None

    def has(self, key, inputs=None):
        return self._entry(key, inputs) is not None

    def restore(self, key, case_id, react_dir, inputs=None):
        """Restore the SAME verified origin pair/proof, never a current attempt."""
        entry = self._entry(key, inputs)
        if entry is None or entry['caseId'] != case_id:
            raise ValueError('cache entry has no valid v2 execution proof')
        png, meta, _ = self.paths(key)
        react_dir = pathlib.Path(react_dir)
        react_dir.mkdir(parents=True, exist_ok=True)
        targets = (react_dir / f'{case_id}.png', react_dir / f'{case_id}.metadata.json')
        steps = {'png': 'not-attempted', 'metadata': 'not-attempted', 'cleanup': {}}
        try:
            for name, source, target in zip(('png', 'metadata'), (png, meta), targets):
                try:
                    _atomic_copy(source, target)
                    steps[name] = 'copied'
                except BaseException:
                    steps[name] = 'failed'
                    raise
            if not _valid_proof(entry['executionProof'], key, case_id, entry['inputs'], *targets):
                raise ValueError('restored pair differs from original execution proof')
        except BaseException as error:
            for name, path in zip(('png', 'metadata'), targets):
                try:
                    path.unlink(missing_ok=True)
                    steps['cleanup'][name] = not path.exists()
                except OSError as cleanup_error:
                    steps['cleanup'][name] = {'removed': False, 'error': str(cleanup_error)}
            error.copySteps = steps
            raise
        return entry['executionProof']

    def store(self, key, case_id, react_dir, inputs, execution_proof=None):
        """Publish only a proven fresh pair; an existing origin is immutable."""
        self.last_store_status = None
        react_dir = pathlib.Path(react_dir)
        src_png, src_meta = react_dir / f'{case_id}.png', react_dir / f'{case_id}.metadata.json'
        try:
            valid = _valid_proof(execution_proof, key, case_id, inputs, src_png, src_meta)
        except (OSError, ValueError, TypeError, AttributeError):
            valid = False
        if not valid or execution_proof['execution']['returncode'] != 0:
            return False
        self.dir.mkdir(parents=True, exist_ok=True)
        png, meta, info = self.paths(key)
        # The cache is shared across worktrees. A failing writer may only
        # retire its own generation, never another writer's committed origin.
        lock = self.dir / f'.{key}.publish-lock'
        try:
            descriptor = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError as error:
            raise FileExistsError('cache publish lock retained; wait for its owner or use a new owned '
                                  'PARITY_EXT_CACHE directory; do not delete an unknown lock') from error
        publication_error = None
        try:
            if self.has(key, inputs):
                self.last_store_status = 'existing-preserved'
                return True
            if any(path.exists() for path in (png, meta, info)):
                raise FileExistsError('unverified cache files retained; use a new owned PARITY_EXT_CACHE '
                                      'directory and rerun; the original entry was not overwritten')
            entry = {'version': VERSION, 'caseId': case_id, 'inputs': inputs,
                     'executionProof': execution_proof, 'proofSha256': sha(_canon(execution_proof))}
            steps = {'png': 'not-attempted', 'sidecar': 'not-attempted',
                     'metadata': 'not-attempted', 'cleanup': {}}
            copying = 'png'
            try:
                _atomic_copy(src_png, png)
                steps['png'] = 'copied'
                copying = 'sidecar'
                _atomic_write(info, json.dumps(entry, indent=1, sort_keys=True))
                steps['sidecar'] = 'copied'
                copying = 'metadata'
                _atomic_copy(src_meta, meta)
                steps['metadata'] = 'copied'
                if self._entry(key, inputs) != entry:
                    raise ValueError('stored pair differs from execution proof')
            except BaseException as error:
                if steps[copying] == 'not-attempted':
                    steps[copying] = 'failed'
                for name, path in (('png', png), ('metadata', meta), ('sidecar', info)):
                    try:
                        path.unlink(missing_ok=True)
                        steps['cleanup'][name] = not path.exists()
                    except OSError as cleanup_error:
                        steps['cleanup'][name] = {'removed': False, 'error': str(cleanup_error)}
                error.copySteps = steps
                raise
            self.last_store_status = 'stored'
            return True
        except BaseException as error:
            publication_error = error
            raise
        finally:
            cleanup = {}
            try:
                os.close(descriptor)
            except OSError as error:
                cleanup['lockClose'] = str(error)
            try:
                lock.unlink(missing_ok=True)
            except OSError as error:
                cleanup['lockUnlink'] = str(error)
            if cleanup:
                if publication_error is not None:
                    publication_error.cleanupSteps = {**getattr(publication_error, 'cleanupSteps', {}), **cleanup}
                else:
                    error = OSError('cache origin retained but publish lock cleanup failed; '
                                    'use a new owned PARITY_EXT_CACHE directory if the lock remains')
                    error.cleanupSteps = cleanup
                    raise error


def _tmp(path):
    return path.with_name(f'.{path.name}.{os.getpid()}.tmp')


def _discard_tmp(tmp, original_error):
    try:
        tmp.unlink(missing_ok=True)
    except OSError as cleanup_error:
        if original_error is None:
            raise
        original_error.cleanupSteps = {**getattr(original_error, 'cleanupSteps', {}),
                                       'temporaryFile': str(cleanup_error)}


def _atomic_copy(src, dst):
    tmp = _tmp(pathlib.Path(dst))
    original_error = None
    try:
        shutil.copyfile(src, tmp)
        os.replace(tmp, dst)
    except BaseException as error:
        original_error = error
        raise
    finally:
        _discard_tmp(tmp, original_error)


def _atomic_write(dst, text):
    dst = pathlib.Path(dst)
    tmp = _tmp(dst)
    original_error = None
    try:
        tmp.write_text(text)
        os.replace(tmp, dst)
    except BaseException as error:
        original_error = error
        raise
    finally:
        _discard_tmp(tmp, original_error)
