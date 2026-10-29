import importlib.machinery
import importlib.util
import hashlib
import inspect
import io
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import ExitStack, redirect_stderr
from types import SimpleNamespace
from unittest import mock

import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[2]
EXT = ROOT / 'tool/parity-ext'
sys.path.insert(0, str(EXT))
import builders  # noqa: E402
import react_cache  # noqa: E402
import sampling  # noqa: E402
_inv_loader = importlib.machinery.SourceFileLoader('parity_ext_inventory_test', str(EXT / 'inventory.py'))
inventory = importlib.util.module_from_spec(importlib.util.spec_from_loader(_inv_loader.name, _inv_loader))
_inv_loader.exec_module(inventory)

_loader = importlib.machinery.SourceFileLoader('parity_ext_analyze_diffs_test', str(EXT / 'analyze-diffs.py'))
analyze = importlib.util.module_from_spec(importlib.util.spec_from_loader(_loader.name, _loader))
sys.modules[_loader.name] = analyze
_loader.exec_module(analyze)


def write(path, text):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


class BuilderOrderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ext = pathlib.Path(self.tmp.name) / 'tool/parity-ext'
        self.ext.mkdir(parents=True)
        for name in ('build-b.py', 'build-a.py', 'build-z.py', 'build-new.py'):
            write(self.ext / name, 'print(1)\n')

    def tearDown(self):
        self.tmp.cleanup()

    def test_discovered_alphabetically_with_build_cases_first(self):
        write(self.ext / 'build-cases.py', 'print(1)\n')
        names = builders.ordered_builders(self.ext)
        self.assertEqual(names, ['build-cases.py', 'build-a.py', 'build-b.py', 'build-new.py', 'build-z.py'])

    def test_order_constant_sorts_before_filename(self):
        write(self.ext / 'build-z.py', '"""doc"""\nORDER = 10\nprint(1)\n')
        write(self.ext / 'build-b.py', 'ORDER = 20  # after z\n')
        write(self.ext / 'build-new.py', 'x = 1\n    ORDER = 5\n')  # indented: not a top-level constant
        self.assertEqual(builders.ordered_builders(self.ext), ['build-z.py', 'build-b.py', 'build-a.py', 'build-new.py'])

    def test_build_manifest_runs_in_order_and_writes_the_output_dir(self):
        write(self.ext / 'build-z.py', 'ORDER = 10\n')
        for name in ('build-a.py', 'build-b.py', 'build-z.py', 'build-new.py'):
            tag = name[6:-3]
            path = self.ext / name
            body = path.read_text() if name == 'build-z.py' else ''
            write(path, body + 'import json, os, pathlib\n'
                  "p = pathlib.Path(os.environ['PARITY_EXT_MANIFEST'])\n"
                  "m = json.loads(p.read_text()) if p.exists() else {'cases': []}\n"
                  f"m['cases'].append({{'id': 'components.{tag}.x'}})\n"
                  'p.write_text(json.dumps(m))\n')
        out = pathlib.Path(self.tmp.name) / 'out'
        target = builders.build_manifest(out, ext=self.ext)
        self.assertEqual(target, out / 'cases.json')
        self.assertEqual([c['id'].split('.')[1] for c in json.loads(target.read_text())['cases']],
                         ['z', 'a', 'b', 'new'])

    def test_failing_builder_stops_the_run(self):
        write(self.ext / 'build-a.py', 'raise SystemExit(3)\n')
        with self.assertRaises(SystemExit):
            builders.build_manifest(pathlib.Path(self.tmp.name) / 'out', ext=self.ext)

    def test_builders_need_the_manifest_env(self):
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop('PARITY_EXT_MANIFEST', None)
            with self.assertRaises(SystemExit):
                builders.manifest_path()

    def test_repo_builders_are_discovered_with_build_cases_first(self):
        names = builders.ordered_builders(EXT)
        self.assertEqual(names[0], 'build-cases.py')  # creates the manifest the others amend
        self.assertEqual(sorted(names), sorted(p.name for p in EXT.glob('build-*.py')))
        self.assertFalse((EXT / 'builders.txt').exists(), 'builders are discovered; there is no registry to edit')


CASE = {
    'id': 'components.demo.card.brutal', 'theme': 'brutal-light', 'viewport': {'width': 640, 'height': 600, 'density': 1},
    'variants': [{'id': 'default', 'props': {'extKind': 'demo', 'state': 'a'}}],
    'capture': {'selector': '#x', 'interactions': [{'type': 'hover', 'target': '#x'}],
                'androidKey': 'demo-card', 'androidInteractions': []},
    'androidCaseHint': 'hint', 'notes': 'n', 'tolerance': {'pixelRatio': 0.02}, 'reactPathHint': 'x.tsx',
}


class ReactCacheKeyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name) / 'wt'
        self.source = pathlib.Path(self.tmp.name) / 'raft-source'
        self.source.mkdir()
        self.reset()

    def tearDown(self):
        self.tmp.cleanup()

    def reset(self):
        ext = self.root / 'tool/parity-ext'
        write(ext / 'host/DemoCases.tsx', 'import f from "virtual:parity-ext/demo";\n'
              'function parityExtDemoElement() { return params.get("extKind") === "demo" ? helper() : null; }\n'
              'function demoOwn() {}\n')
        write(ext / 'host/OtherCases.tsx', 'import g from "virtual:parity-ext/other";\n'
              'function parityExtOtherElement() { return null; }\n')
        write(ext / 'fixtures/demo.json', json.dumps({'routes': {'GET /a': {'x': 1}}}))
        write(ext / 'fixtures/other.json', json.dumps({'routes': {'GET /b': {'y': 1}}}))
        write(self.root / 'tool/parity-ext-web.mjs', 'web v1')
        write(self.root / 'tool/parity', 'parity v1')
        write(self.root / 'tool/parity-fonts/manifest.json', '{}')

    def key(self, case=CASE, machinery='m1', root_name=None):
        ctx = react_cache.KeyContext(self.root, self.root / 'tool/parity-ext', self.source, machinery)
        return ctx.key(case)

    def variant(self, **changes):
        case = json.loads(json.dumps(CASE))
        for path, value in changes.items():
            node = case
            *head, last = path.split('/')
            for part in head:
                node = node[int(part)] if part.isdigit() else node[part]
            node[int(last) if last.isdigit() else last] = value
        return case

    def test_stable_and_sensitive_to_case_content(self):
        base = self.key()
        self.assertEqual(base, self.key())
        for change in ({'variants/0/props/state': 'b'}, {'viewport/width': 641}, {'theme': 'elegant-light'},
                       {'capture/interactions/0/type': 'press'}, {'capture/selector': '#y'}, {'id': 'components.demo.card.elegant'}):
            self.assertNotEqual(base, self.key(self.variant(**change)), change)

    def test_ignores_flutter_only_fields(self):
        base = self.key()
        for change in ({'capture/androidKey': 'other'}, {'capture/androidInteractions': [{'type': 'tap'}]},
                       {'androidCaseHint': 'z'}, {'notes': 'z'}, {'tolerance': {'pixelRatio': 0.5}}, {'reactPathHint': 'z'}):
            self.assertEqual(base, self.key(self.variant(**change)), change)

    def test_own_host_and_fixture_invalidate_others_do_not(self):
        base = self.key()
        ext = self.root / 'tool/parity-ext'
        write(ext / 'host/OtherCases.tsx', 'import g from "virtual:parity-ext/other";\nfunction parityExtOtherElement() { return 1; }\n')
        write(ext / 'fixtures/other.json', json.dumps({'routes': {'GET /b': {'y': 2}}}))  # same route keys, other body
        self.assertEqual(base, self.key())
        write(ext / 'fixtures/other.json', json.dumps({'routes': {'GET /b': {}, 'GET /new': {}}}))  # new route: may shadow
        self.assertNotEqual(base, self.key())
        self.reset()
        write(ext / 'fixtures/demo.json', json.dumps({'routes': {'GET /a': {'x': 2}}}))
        self.assertNotEqual(base, self.key())
        self.reset()
        write(ext / 'host/DemoCases.tsx', (ext / 'host/DemoCases.tsx').read_text() + '// edit\n')
        self.assertNotEqual(base, self.key())

    def test_host_using_another_hosts_declarations_depends_on_it(self):
        ext = self.root / 'tool/parity-ext'
        write(ext / 'host/OtherCases.tsx', 'function helper() {}\nfunction parityExtOtherElement() { return null; }\n')
        before = self.key()
        write(ext / 'host/OtherCases.tsx', 'function helper() { return 1; }\nfunction parityExtOtherElement() { return null; }\n')
        self.assertNotEqual(before, self.key())

    def test_machinery_and_tool_files_invalidate(self):
        base = self.key()
        self.assertNotEqual(base, self.key(machinery='m2'))
        write(self.root / 'tool/parity-ext-web.mjs', 'web v2')
        self.assertNotEqual(base, self.key())
        self.reset()
        write(self.root / 'tool/parity', 'parity v2')
        self.assertNotEqual(base, self.key())

    def test_key_is_independent_of_the_worktree_path(self):
        a = self.key(machinery=f'cmd node {self.root}/tool/parity-ext-web.mjs')
        moved = pathlib.Path(self.tmp.name) / 'wt2'
        self.root.rename(moved)
        self.root = moved
        self.assertEqual(a, self.key(machinery=f'cmd node {self.root}/tool/parity-ext-web.mjs'))


class ReactCacheStorageTest(unittest.TestCase):
    def test_unproved_stores_and_legacy_entries_miss(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            results = tmp / 'results/react'
            write(results / 'c.metadata.json', '{"caseId":"c"}')
            (results / 'c.png').write_bytes(b'png-bytes')
            cache = react_cache.Cache(tmp / 'cache')
            self.assertFalse(cache.has('k'))
            self.assertFalse(cache.store('k', 'c', results, {'a': 1}), 'unproved metadata cannot create a new hit')
            cache.dir.mkdir(parents=True, exist_ok=True)
            png, meta, info = cache.paths('legacy')
            png.write_bytes(b'old-png')
            meta.write_text('{"caseId":"c"}')
            info.write_text('{"caseId":"c","inputs":{"a":1}}')
            self.assertFalse(cache.has('legacy'), 'old material stays on disk but is not accepted as v2')
            self.assertEqual(png.read_bytes(), b'old-png')
            self.assertFalse(cache.has('k'))

    def test_failed_capture_is_not_stored(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = react_cache.Cache(pathlib.Path(tmp) / 'cache')
            self.assertFalse(cache.store('k', 'missing', pathlib.Path(tmp) / 'empty', {}))
            self.assertFalse(cache.has('k'))


class ReactCaptureProvenanceTest(unittest.TestCase):
    """The real extension driver/cache; only the browser boundary is simulated.

    The legacy-call adapters make the old tree fail on its unsafe behavior,
    rather than merely fail because the new optional arguments do not exist.
    Every generated artifact is a small owned file under TemporaryDirectory.
    """

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='react-proof-')
        self.addCleanup(self.tmp.cleanup)
        self.base = pathlib.Path(self.tmp.name)
        self.root, self.source = self.base / 'wt', self.base / 'source'
        self.ext, self.out = self.root / 'tool/parity-ext', self.base / 'out'
        self.react_dir = self.out / 'visual-testing-results/react'
        self.gen = self.out / 'react-provider'
        self.out.mkdir(parents=True)
        self.gen.mkdir()
        self.react_dir.mkdir(parents=True)
        self.cache = react_cache.Cache(self.base / 'cache')
        for path in ('tool/parity-ext/run', 'tool/parity', 'tool/parity-ext-web.mjs'):
            dest = self.root / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, dest)
        write(self.ext / 'host/DemoCases.tsx', 'function parityExtDemoElement() { return "demo"; }\n')
        write(self.ext / 'fixtures/demo.json', '{"routes":{}}')
        write(self.root / 'tool/parity-fonts/manifest.json', '{}')
        write(self.source / 'packages/visual-testing/tests/react-provider.spec.ts', '// upstream spec v1\n')
        write(self.source / 'packages/web/playwright.visual-testing.config.ts', '// upstream config v1\n')
        loader = importlib.machinery.SourceFileLoader('parity_ext_proof_driver_test', str(EXT / 'run'))
        self.driver = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
        loader.exec_module(self.driver)
        # These new provenance/CLI-policy tests simulate render outputs. Root's
        # real reference/look contract is covered separately; do not read a live
        # upstream checkout or infer a valid real frame from these unit fixtures.
        for name, value in {
                'configure_theme': 'raft',
                'validate_reference': {'status': 'unit-fixture-only'},
                'validate_flutter_metadata': {'errors': [], 'status': 'unit-fixture-only'},
        }.items():
            patcher = mock.patch.object(self.driver.reference_contract, name, return_value=value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.cases = []
        for number in range(3):
            case = json.loads(json.dumps(CASE))
            case['id'] = f'components.demo.proof{number}.raft'
            case['viewport']['density'] = 1 if number < 2 else 3
            case['capture']['interactions'] = [{'type': 'focus', 'target': '#requested-only'}]
            self.cases.append(case)
        write(self.out / 'cases.json', json.dumps({'cases': self.cases}))
        self.invocations, self.produced, self.returncodes = [], set(), {}
        self.raise_runner = False

    def context(self):
        return react_cache.KeyContext(self.root, self.ext, self.source, self.driver.capture_machinery())

    @staticmethod
    def digest(data):
        return hashlib.sha256(data).hexdigest()

    @staticmethod
    def canon(data):
        return json.dumps(data, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()

    def artifact(self, case, captured_at='2025-01-02T03:04:05Z'):
        cid = case['id']
        png = self.react_dir / f'{cid}.png'
        Image.new('RGB', (2, 2), (12, 34, 56)).save(png)
        write(self.react_dir / f'{cid}.metadata.json', json.dumps({
            'caseId': cid, 'capturedAt': captured_at,
            # An echoed request is deliberately NOT observed actual focus.
            'fixtureState': {'requestedFocus': '#requested-only', 'avatarState': 'requested-loaded'},
        }))

    def proof(self, case, key, inputs):
        cid = case['id']
        meta = self.react_dir / f'{cid}.metadata.json'
        applied = {'baseProviderSha256': self.digest((self.root / 'tool/parity').read_bytes()),
                   'spec': [{'anchorSha256': self.digest(b'anchor'), 'replacementSha256': self.digest(b'replacement')}],
                   'config': [{'anchorSha256': self.digest(b'config-anchor'),
                               'replacementSha256': self.digest(b'config-replacement')}],
                   'appendixSha256': self.digest(b'appendix')}
        original_spec = write(self.base / 'origin-executors/spec.ts', 'original-executed-spec')
        original_config = write(self.base / 'origin-executors/config.ts', 'original-executed-config')
        return {'version': 2, 'caseId': cid, 'cacheKey': key,
                'capturedAt': json.loads(meta.read_text())['capturedAt'],
                'sourceBindings': inputs.get('sourceBindings', {'oldTree': inputs.get('common')}),
                'executorInputs': inputs.get('executorInputs', {'oldTree': self.digest(b'old-executor')}),
                'generated': {'specSha256': self.digest(b'original-executed-spec'),
                              'configSha256': self.digest(b'original-executed-config'),
                              'specSnapshot': str(original_spec), 'configSnapshot': str(original_config),
                              'specExecutedPath': str(original_spec), 'configExecutedPath': str(original_config)},
                'appliedPatches': applied, 'appliedPatchIdentity': self.digest(self.canon(applied)),
                'execution': {'startedAt': '2025-01-02T03:04:04Z', 'completedAt': '2025-01-02T03:04:06Z',
                              'returncode': 0, 'temporaryBytesStable': True},
                'artifacts': {'pngSha256': self.digest((self.react_dir / f'{cid}.png').read_bytes()),
                              'metadataSha256': self.digest(meta.read_bytes())},
                'observedState': {'status': 'not-recorded'}}

    def store(self, case, key, inputs, proof):
        method = self.cache.store
        kwargs = {'execution_proof': proof} if 'execution_proof' in inspect.signature(method).parameters else {}
        return method(key, case['id'], self.react_dir, inputs, **kwargs)

    def has(self, key, inputs):
        method = self.cache.has
        return method(key, inputs=inputs) if 'inputs' in inspect.signature(method).parameters else method(key)

    def seed(self, case):
        context = self.context()
        key, inputs = context.key(case), context.inputs(case)
        self.artifact(case)
        proof = self.proof(case, key, inputs)
        self.assertTrue(self.store(case, key, inputs, proof), 'the fixture publishes one valid original capture')
        self.assertTrue(self.has(key, inputs))
        return key, inputs, proof

    def prepare(self):
        # Preserve the REAL patch loop in react_capture: these are its input
        # anchors, not a reimplementation of its generated output.
        anchors = list(dict.fromkeys(old for old, _ in self.driver.SPEC_EXT_PATCHES + self.driver.SPEC_STATES_PATCHES))
        write(self.gen / 'react-provider.spec.ts', '\n'.join(anchors) + '\n')
        if getattr(self, 'prepare_produces_stale', False):
            for case in self.cases:
                self.artifact(case, '2000-01-01T00:00:00Z')
        return write(self.gen / 'playwright.visual-testing.config.ts',
                     '\n'.join(old for old, _ in self.driver.CONFIG_EXT_PATCHES) + '\n')

    def runner(self, command, **kwargs):
        if command[0] == 'git':
            return self.real_run(command, **kwargs)
        self.assertEqual(command[:4], ['pnpm', 'exec', 'playwright', 'test'])
        env = kwargs['env']
        config = pathlib.Path(command[command.index('--config') + 1])
        spec = self.gen / 'react-provider.spec.ts'
        self.invocations.append({'ids': env['SLOCK_VISUAL_CASE_IDS'].split(','),
                                 'spec': spec.read_bytes(), 'config': config.read_bytes(),
                                 'specPath': str(spec), 'configPath': str(config)})
        if self.raise_runner:
            raise OSError('simulated runner could not launch')
        for case in self.cases:
            if case['id'] in self.invocations[-1]['ids'] and case['id'] in self.produced:
                self.artifact(case, '2026-10-29T08:20:00Z')
        if getattr(self, 'mutate_executor', False):
            config.write_bytes(config.read_bytes() + b'\n// changed during execution\n')
        if getattr(self, 'browser_marker', False):
            kwargs['stdout'].write('browserType.launch: simulated browser missing\n')
        return SimpleNamespace(returncode=self.returncodes.get(env['PARITY_EXT_DSF'], 0))

    def capture(self, cases, *, preparation_error=False, context_error=False, copy_error=None):
        self.real_run = subprocess.run
        (self.out / 'react-source.json').unlink(missing_ok=True)
        with ExitStack() as stack:
            for name, value in {'ROOT': self.root, 'EXT': self.ext, 'OUT': self.out,
                                'FIXTURES': self.ext / 'fixtures', 'MANIFEST': self.out / 'cases.json'}.items():
                stack.enter_context(mock.patch.object(self.driver, name, value))
            for name, value in {'RAFT_SOURCE': self.source, 'VT': self.source / 'packages/visual-testing',
                                'RESULTS': self.out / 'visual-testing-results', 'REACT_GEN': self.gen}.items():
                stack.enter_context(mock.patch.object(self.driver.parity, name, value))
            stack.enter_context(mock.patch.dict(os.environ, {'PARITY_EXT_CACHE': str(self.base / 'cache')}))
            fonts = stack.enter_context(mock.patch.object(self.driver.parity, 'cmd_fonts'))
            stack.enter_context(mock.patch.object(self.driver.parity, 'node_env', return_value={}))
            preparation = stack.enter_context(mock.patch.object(
                self.driver.parity, 'prepare_react_provider',
                side_effect=RuntimeError('simulated preparation failure') if preparation_error else self.prepare))
            stack.enter_context(mock.patch.object(self.driver.subprocess, 'run', side_effect=self.runner))
            if context_error:
                stack.enter_context(mock.patch.object(self.driver.react_cache, 'KeyContext',
                                                     side_effect=RuntimeError('simulated context preparation failure')))
            if copy_error:
                original_copy = shutil.copyfile

                def failing_copy(src, dst, *args, **kwargs):
                    if str(src).endswith('.metadata.json') and copy_error in str(dst):
                        raise OSError('simulated partial metadata copy failure')
                    return original_copy(src, dst, *args, **kwargs)

                stack.enter_context(mock.patch.object(react_cache.shutil, 'copyfile', side_effect=failing_copy))
            try:
                result = self.driver.react_capture(cases, refresh=False)
            except (OSError, RuntimeError, SystemExit) as exc:
                result = exc  # The receipt contract must still hold on these paths.
        self.font_preparations = fonts.call_count
        return result, preparation.call_count

    def receipt(self):
        path = self.out / 'react-source.json'
        self.assertTrue(path.is_file(), 'every exit, including preparation/copy failure, persists a receipt')
        receipt = json.loads(path.read_text())
        self.assertEqual(receipt.get('receiptVersion'), 2, 'counts alone do not prove which case was executed')
        return {case['caseId']: case for case in receipt['cases']}

    def test_real_machinery_driver_and_upstream_bytes_invalidate_but_flutter_and_path_moves_do_not(self):
        baseline = self.context().key(CASE)
        with self.subTest(input='actual-states-patch-composition'):
            with mock.patch.object(self.driver, 'SPEC_STATES_PATCHES',
                                   self.driver.SPEC_STATES_PATCHES + [('new-state-anchor', 'new-state-replacement')]):
                self.assertNotEqual(baseline, self.context().key(CASE), 'actual state patch composition belongs in the key')
        for path in (self.root / 'tool/parity-ext/run',
                     self.source / 'packages/visual-testing/tests/react-provider.spec.ts',
                     self.source / 'packages/web/playwright.visual-testing.config.ts'):
            with self.subTest(input=path.relative_to(self.base)):
                old = path.read_bytes()
                path.write_bytes(old + b'\n// actual byte mutation\n')
                self.assertNotEqual(baseline, self.context().key(CASE))
                path.write_bytes(old)
        write(self.root / 'apps/raft_flutter/lib/flutter_only.dart', 'unrelated Flutter change')
        self.assertEqual(baseline, self.context().key(CASE))
        moved = self.base / 'moved-wt'
        self.root.rename(moved)
        self.root, self.ext = moved, moved / 'tool/parity-ext'
        self.assertEqual(baseline, self.context().key(CASE))

    def test_storage_requires_complete_v2_info_and_rejects_tampered_pair_or_origin_proof(self):
        case = self.cases[0]
        key, inputs, proof = self.seed(case)
        png, meta, info = self.cache.paths(key)
        original = {p: p.read_bytes() for p in (png, meta, info)}
        for corruption in ('missing-info', 'v1', 'png', 'metadata', 'proof'):
            with self.subTest(corruption=corruption):
                for p, content in original.items():
                    p.write_bytes(content)
                if corruption == 'missing-info':
                    info.unlink()
                elif corruption == 'v1':
                    info.write_text(json.dumps({'caseId': case['id'], 'inputs': inputs}))
                elif corruption in ('png', 'metadata'):
                    (png if corruption == 'png' else meta).write_bytes(b'tampered bytes')
                else:
                    data = json.loads(info.read_text())
                    data['executionProof'] = {**proof, 'capturedAt': '2030-01-01T00:00:00Z'}
                    info.write_text(json.dumps(data))
                self.assertFalse(self.has(key, inputs), 'png+metadata presence is not a verified cache hit')
        self.artifact(case)
        with self.subTest(corruption='unproved-store'):
            self.assertFalse(self.store(case, 'unproved', inputs, None), 'metadata echo alone cannot seed v2')
        for path, content in original.items():
            path.write_bytes(content)
        self.artifact(case, '2026-10-29T08:20:00Z')
        replacement = self.proof(case, key, inputs)
        with self.subTest(corruption='existing-origin-overwrite'):
            self.assertTrue(self.store(case, key, inputs, replacement))
            self.assertEqual({p: p.read_bytes() for p in original}, original,
                             'the same key cannot silently replace the original pair/proof')

    def test_all_hits_skip_preparation_and_playwright_and_preserve_original_capture_proof(self):
        case = self.cases[0]
        _, _, proof = self.seed(case)
        (self.react_dir / f"{case['id']}.png").unlink()
        _, preparations = self.capture([case])
        self.assertEqual((preparations, self.invocations), (0, []))
        self.assertEqual(self.font_preparations, 0)
        row = self.receipt()[case['id']]
        self.assertEqual((row['mode'], row['outcome']), ('cache-hit', 'restored'))
        self.assertFalse(row['attemptedThisRun'])
        self.assertFalse(row['playwrightAttempted'])
        self.assertIs(row['actionsExecutedThisRun'], False)
        self.assertEqual(row['executionProof'], proof)
        self.assertEqual(json.loads((self.react_dir / f"{case['id']}.metadata.json").read_text())['capturedAt'], proof['capturedAt'])

    def test_mixed_hits_fresh_and_nonzero_group_bind_actual_executors_without_claiming_actions(self):
        hit, fresh, failed = self.cases
        fresh['viewport']['density'] = 3  # The same nonzero group produces one pair and misses one.
        _, _, origin = self.seed(hit)
        self.artifact(failed, '2000-01-01T00:00:00Z')  # stale output must be removed, not counted as produced.
        self.produced = {fresh['id']}
        self.returncodes = {'3': 2}
        self.capture(self.cases)
        rows = self.receipt()
        self.assertEqual(rows[hit['id']]['executionProof'], origin)
        self.assertEqual(rows[fresh['id']]['outcome'], 'runner-failed')
        self.assertEqual(rows[failed['id']]['outcome'], 'runner-failed')
        totals = json.loads((self.out / 'react-source.json').read_text())['cache']
        self.assertEqual({name: totals[name] for name in ('hits', 'attempted', 'captured')},
                         {'hits': 1, 'attempted': 2, 'captured': 1})
        self.assertEqual({cid for call in self.invocations for cid in call['ids']}, {fresh['id'], failed['id']})
        for case in (fresh, failed):
            row = rows[case['id']]
            self.assertTrue(row['attemptedThisRun'])
            self.assertTrue(row['playwrightAttempted'])
            self.assertIsNone(row['actionsExecutedThisRun'], 'process/artifact production does not observe semantic actions')
        proof = rows[fresh['id']]['executionProof']
        execution = next(call for call in self.invocations if fresh['id'] in call['ids'])
        generated = proof['generated']
        self.assertEqual({name: generated[name] for name in ('specSha256', 'configSha256')},
                         {'specSha256': self.digest(execution['spec']),
                          'configSha256': self.digest(execution['config'])})
        for name in ('spec', 'config'):
            self.assertEqual(generated[f'{name}ExecutedPath'], execution[f'{name}Path'])
            snapshot = pathlib.Path(generated[f'{name}Snapshot'])
            self.assertEqual(snapshot.read_bytes(), execution[name])
            self.assertEqual(self.digest(snapshot.read_bytes()), generated[f'{name}Sha256'])
        self.assertEqual(proof['appliedPatchIdentity'], self.digest(self.canon(proof['appliedPatches'])))
        self.assertTrue(proof['execution']['temporaryBytesStable'])
        self.assertEqual(proof['execution']['returncode'], 2)
        self.assertEqual(rows[fresh['id']]['cacheStore'], 'not-stored-group-failure')
        self.assertFalse(self.has(self.context().key(fresh), self.context().inputs(fresh)))
        self.assertFalse((self.react_dir / f"{failed['id']}.png").exists())
        self.assertFalse(self.has(self.context().key(failed), self.context().inputs(failed)))
        # A real driver success, rather than hand-seeded proof, must publish a
        # cache entry that the next real driver call can reuse without work.
        self.returncodes.clear()
        self.produced = {fresh['id']}
        self.capture([fresh])
        fresh_row = self.receipt()[fresh['id']]
        self.assertEqual(fresh_row['outcome'], 'captured')
        original_fresh = fresh_row['executionProof']
        self.assertEqual(original_fresh['execution']['returncode'], 0)
        self.assertTrue(self.has(self.context().key(fresh), self.context().inputs(fresh)))
        previous_calls = len(self.invocations)
        self.produced.clear()
        _, preparations = self.capture([fresh])
        cached_row = self.receipt()[fresh['id']]
        self.assertEqual((preparations, len(self.invocations)), (0, previous_calls))
        self.assertEqual(cached_row['mode'], 'cache-hit')
        self.assertEqual(cached_row['executionProof'], original_fresh)
        self.assertIs(cached_row['actionsExecutedThisRun'], False)
        with self.subTest(failure='executor-bytes-changed-during-run'):
            self.produced = {failed['id']}
            self.mutate_executor = True
            result, _ = self.capture([failed])
            row = self.receipt()[failed['id']]
            self.assertIs(result, True)
            self.assertEqual(row['outcome'], 'executor-drift')
            self.assertIsNone(row['executionProof'])
            self.assertFalse(self.has(self.context().key(failed), self.context().inputs(failed)))

    def test_prepare_runner_store_and_partial_restore_failures_have_honest_persistent_receipts(self):
        case = self.cases[0]
        for failure in ('context', 'prepare', 'runner', 'store', 'restore'):
            with self.subTest(failure=failure):
                shutil.rmtree(self.base / 'cache', ignore_errors=True)
                self.invocations.clear()
                self.raise_runner = failure == 'runner'
                self.produced = {case['id']}
                self.artifact(case, '2000-01-01T00:00:00Z')
                if failure == 'restore':
                    self.seed(case)
                    self.produced.clear()
                self.capture([case], preparation_error=failure == 'prepare', context_error=failure == 'context',
                             copy_error={'restore': 'visual-testing-results/react',
                                         'store': 'cache/react'}.get(failure))
                row = self.receipt()[case['id']]
                self.assertIsNot(row['actionsExecutedThisRun'], True)
                events = [row] + row.get('events', [])
                expected = {'context': 'prepare-failed', 'prepare': 'prepare-failed', 'runner': 'runner-failed',
                            'store': 'store-failed', 'restore': 'restore-failed'}[failure]
                # A failed restore may be followed by a fresh attempt. Its
                # original error must survive even when the final outcome moves on.
                if failure == 'restore':
                    self.assertIn('restore', [event.get('stage') for event in row.get('events', [])])
                    event = next(event for event in row['events'] if event.get('stage') == 'restore')
                    self.assertEqual(event['copySteps'], {'png': 'copied', 'metadata': 'failed',
                                                          'cleanup': {'png': True, 'metadata': True}})
                else:
                    self.assertIn(expected, [event.get('outcome') for event in events])
                if failure == 'store':
                    self.assertIsNotNone(row['executionProof'], 'storage failure must retain the independently produced pair proof')
                    event = next(event for event in row['events'] if event.get('stage') == 'store')
                    self.assertEqual(event['copySteps'], {'png': 'copied', 'sidecar': 'copied', 'metadata': 'failed',
                                                          'cleanup': {'png': True, 'sidecar': True, 'metadata': True}})
                if failure in ('context', 'prepare', 'runner'):
                    self.assertNotEqual(row['outcome'], 'captured')
                    self.assertFalse((self.react_dir / f"{case['id']}.png").exists())
                    self.assertFalse((self.react_dir / f"{case['id']}.metadata.json").exists())
                if failure in ('context', 'prepare'):
                    self.assertFalse(row['playwrightAttempted'])
                if failure == 'restore':
                    self.assertFalse((self.react_dir / f"{case['id']}.png").exists(), 'partial restored png must be cleaned')
                    self.assertFalse((self.react_dir / f"{case['id']}.metadata.json").exists())
        self.raise_runner = False
        shutil.rmtree(self.base / 'cache', ignore_errors=True)
        key, inputs, _ = self.seed(case)
        restore_dir = self.base / 'partial-restore'
        original_copy = shutil.copyfile

        def fail_restore_metadata(src, dst, *args, **kwargs):
            if str(src).endswith('.metadata.json'):
                raise OSError('restore failed after copying PNG')
            return original_copy(src, dst, *args, **kwargs)

        with mock.patch.object(react_cache.shutil, 'copyfile', side_effect=fail_restore_metadata):
            with self.assertRaises(OSError) as failed_restore:
                method = self.cache.restore
                kwargs = {'inputs': inputs} if 'inputs' in inspect.signature(method).parameters else {}
                method(key, case['id'], restore_dir, **kwargs)
        with self.subTest(failure='direct-partial-restore-cleanup'):
            self.assertEqual(getattr(failed_restore.exception, 'copySteps', None),
                             {'png': 'copied', 'metadata': 'failed', 'cleanup': {'png': True, 'metadata': True}})
            self.assertFalse((restore_dir / f"{case['id']}.png").exists())
            self.assertFalse((restore_dir / f"{case['id']}.metadata.json").exists())
        shutil.rmtree(self.base / 'cache', ignore_errors=True)
        self.artifact(case)
        context = self.context()
        key, inputs = context.key(case), context.inputs(case)
        proof = self.proof(case, key, inputs)
        original_copy = shutil.copyfile

        def fail_store_metadata(src, dst, *args, **kwargs):
            if str(src).endswith('.metadata.json'):
                raise OSError('metadata publication failed after png copy')
            return original_copy(src, dst, *args, **kwargs)

        with mock.patch.object(react_cache.shutil, 'copyfile', side_effect=fail_store_metadata):
            with self.assertRaises(OSError) as failed_store:
                self.store(case, key, inputs, proof)
        with self.subTest(failure='direct-partial-store-steps'):
            self.assertEqual(getattr(failed_store.exception, 'copySteps', None),
                             {'png': 'copied', 'sidecar': 'copied', 'metadata': 'failed',
                              'cleanup': {'png': True, 'sidecar': True, 'metadata': True}})
        self.assertFalse(self.has(key, inputs), 'a partial store cannot become a hit')
        with self.subTest(failure='preparation-artifact-is-not-execution'):
            self.produced.clear()
            self.returncodes.clear()
            self.prepare_produces_stale = True
            result, _ = self.capture([case])
            row = self.receipt()[case['id']]
            self.assertEqual(row['outcome'], 'missing-artifacts')
            self.assertIsNone(row['executionProof'])
            self.assertFalse((self.react_dir / f"{case['id']}.png").exists())
            self.assertIs(result, False, 'a zero-exit ordinary missing surface still uses CLI coverage policy')
        with self.subTest(failure='ordinary-missing-is-not-fatal-before-cli-policy'):
            self.prepare_produces_stale = False
            self.produced.clear()
            self.returncodes = {'1': 2}
            result, _ = self.capture([case])
            self.assertIs(result, False, 'ordinary absent surfaces belong to cmd_run coverage policy')
            self.assertEqual(self.receipt()[case['id']]['outcome'], 'runner-failed')
        with self.subTest(failure='browser-marker-remains-fatal'):
            self.browser_marker = True
            result, _ = self.capture([case])
            self.assertIs(result, True)
            self.browser_marker = False
        with self.subTest(failure='dom-dump-propagates-capture-failure'):
            with mock.patch.object(self.driver, 'OUT', self.out), \
                    mock.patch.object(self.driver, 'ext_cases', return_value=[case]), \
                    mock.patch.object(self.driver, 'react_capture', return_value=True):
                with self.assertRaises(SystemExit) as stopped:
                    self.driver.cmd_dom_dump(SimpleNamespace(cases=case['id'], out=str(self.base / 'dom')))
                self.assertNotEqual(stopped.exception.code, 0)
        with self.subTest(failure='ordinary-capture-error-is-not-labelled-browser-failure'):
            site = self.out / 'site'
            summary = {'totals': {'total': 1, 'passing': 0, 'percentage': 0, 'geometryPass': 0,
                                  'geometryPercentage': 0, 'reactCaptured': 1}, 'cases': []}

            def summarize(*args):
                write(self.out / 'summary.json', json.dumps(summary))
                write(self.out / 'summary.md', 'mock summary for CLI error propagation only')
                return summary

            def cli(*args, **kwargs):
                if args[0] == 'site':
                    site.mkdir(parents=True, exist_ok=True)

            (self.out / 'summary.json').unlink(missing_ok=True)
            error_output = io.StringIO()
            with mock.patch.object(self.driver, 'OUT', self.out), \
                    mock.patch.object(self.driver.parity, 'SITE', site), \
                    mock.patch.object(self.driver, 'ext_cases', return_value=[case]), \
                    mock.patch.object(self.driver, 'react_capture', return_value=True), \
                    mock.patch.object(self.driver, 'cli', side_effect=cli), \
                    mock.patch.object(self.driver, 'summarize', side_effect=summarize), \
                    redirect_stderr(error_output):
                with self.assertRaises(SystemExit):
                    self.driver.cmd_run(SimpleNamespace(cases=case['id'], skip_flutter=True,
                                                        frozen=False, refresh_react=False))
            self.assertNotIn('browser failure=', error_output.getvalue())
        for scenario, allow, lost, captured, fatal in [
            ('allow-known-gap', True, False, 1, False),
            ('explicit-gap', False, False, 1, False),
            ('lost-reference', True, True, 1, False),
            ('no-references', True, False, 0, False),
            ('infrastructure-failure', True, False, 2, True),
        ]:
            with self.subTest(failure=scenario):
                other = self.cases[1]
                site = self.out / 'site'
                summary = {'totals': {'total': 2, 'passing': captured, 'percentage': 50 * captured,
                                      'geometryPass': 0, 'geometryPercentage': 0,
                                      'reactCaptured': captured, 'reactMissing': 2 - captured},
                           'cases': [{'id': case['id'], 'react': captured == 2},
                                     {'id': other['id'], 'react': captured > 0}]}
                if lost:
                    write(self.out / 'summary.json', json.dumps({'cases': [{'id': case['id'], 'react': True}]}))
                else:
                    (self.out / 'summary.json').unlink(missing_ok=True)
                with mock.patch.object(self.driver, 'OUT', self.out), \
                        mock.patch.object(self.driver.parity, 'SITE', site), \
                        mock.patch.object(self.driver, 'ext_cases', return_value=[case, other]), \
                        mock.patch.object(self.driver, 'react_capture', return_value=fatal), \
                        mock.patch.object(self.driver, 'cli', side_effect=cli), \
                        mock.patch.object(self.driver, 'summarize', side_effect=summarize):
                    args = SimpleNamespace(cases='components.demo.*', skip_flutter=True,
                                           frozen=False, refresh_react=False, allow_structural_gaps=allow)
                    if scenario == 'allow-known-gap':
                        self.driver.cmd_run(args)
                    else:
                        with self.assertRaises(SystemExit):
                            self.driver.cmd_run(args)

    def test_cache_hit_cannot_upgrade_old_fixture_echo_to_current_observed_focus_or_avatar_state(self):
        case = self.cases[0]
        _, _, original = self.seed(case)
        self.capture([case])
        row = self.receipt()[case['id']]
        self.assertEqual(row['executionProof'], original)
        self.assertEqual(row['executionProof']['observedState'], {'status': 'not-recorded'})
        self.assertNotIn('observedFocus', row['executionProof'])
        self.assertNotIn('observedAvatarState', row['executionProof'])
        self.assertFalse(row['attemptedThisRun'])
        self.assertIs(row['actionsExecutedThisRun'], False)


def save(path, array):
    Image.fromarray(array.astype(np.uint8)).save(path)


class NonTextScoreTest(unittest.TestCase):
    def scores(self, react, flutter):
        with tempfile.TemporaryDirectory() as tmp:
            rp, fp = pathlib.Path(tmp) / 'r.png', pathlib.Path(tmp) / 'f.png'
            save(rp, react)
            save(fp, flutter)
            return analyze.non_text_scores({'c': (rp, fp, 1)}, jobs=1)['c']

    def test_identical_images(self):
        img = np.full((40, 60, 3), 255)
        s = self.scores(img, img)
        self.assertEqual((s['similarity'], s['nonTextSimilarity'], s['textShare']), (100.0, 100.0, 0.0))

    def test_glyph_noise_is_excluded_but_a_wrong_fill_is_not(self):
        rng = np.random.default_rng(1)
        react = np.full((60, 80, 3), 255)
        react[10:30, 10:50] = rng.integers(0, 256, (20, 40, 1)).repeat(3, 2)  # dense "ink"
        flutter = react.copy()
        flutter[10:30, 10:50] = rng.integers(0, 256, (20, 40, 1)).repeat(3, 2)  # different AA, no shift explains it
        s = self.scores(react, flutter)
        self.assertLess(s['similarity'], 99)
        self.assertGreater(s['textShare'], 0.5)
        self.assertGreater(s['nonTextSimilarity'], s['similarity'] + 10)  # block rim stays in other buckets
        wrong = np.full((60, 80, 3), 255)
        wrong[10:40, 10:70] = (0, 0, 0)
        other = wrong.copy()
        other[10:40, 10:70] = (200, 30, 30)  # a flat region of the wrong colour: not text
        s = self.scores(wrong, other)
        self.assertEqual(s['textShare'], 0.0)
        self.assertLess(s['nonTextSimilarity'], 99.5)

    def test_memo_reuses_results(self):
        with tempfile.TemporaryDirectory() as tmp:
            rp = pathlib.Path(tmp) / 'r.png'
            save(rp, np.full((10, 10, 3), 255))
            memo = {}
            analyze.non_text_scores({'c': (rp, rp, 1)}, jobs=1, memo=memo)
            self.assertEqual(len(memo), 1)
            with mock.patch.object(analyze, 'classify', side_effect=AssertionError('classified again')):
                analyze.non_text_scores({'c': (rp, rp, 1)}, jobs=1, memo=memo)


if __name__ == '__main__':
    unittest.main()


class ThemeSamplingTest(unittest.TestCase):
    THEMES = (('brutal-light', 'brutal'), ('elegant-light', 'elegant'), ('elegant-dark', 'elegant-dark'))

    def manifest(self, surfaces):
        cases = []
        for surface, names in surfaces.items():
            for name in names:
                for theme, suffix in self.THEMES:
                    cases.append({'id': '.'.join(filter(None, [surface, name, suffix])), 'theme': theme})
        return {'cases': cases}

    def names(self, manifest, theme, surface):
        return [sampling.case_name(c) for c in manifest['cases']
                if c['theme'] == theme and sampling.surface_of(c['id']) == surface]

    SURFACES = {
        'components.a.list': ['default', 'empty', 'loading', 'many-rows', 'error'],
        'components.a.dialog': ['one', 'two', 'three'],
        'components.a.single': ['only'],
        'components.a.bare': [''],
    }

    def test_default_theme_is_complete_and_others_keep_first_plus_dense(self):
        full = self.manifest(self.SURFACES)
        out = sampling.sample_themes(full, {})
        for theme in ('elegant-light', 'elegant-dark'):
            self.assertEqual(self.names(out, theme, 'components.a.list'), ['default', 'many-rows'])
            self.assertEqual(self.names(out, theme, 'components.a.dialog'), ['one', 'three'])  # no keyword: last
            self.assertEqual(self.names(out, theme, 'components.a.single'), ['only'])
            self.assertEqual(self.names(out, theme, 'components.a.bare'), [''])
        self.assertEqual(self.names(out, 'brutal-light', 'components.a.list'), self.SURFACES['components.a.list'])
        self.assertEqual(sum(c['theme'] == 'brutal-light' for c in out['cases']), 10)
        self.assertEqual(len(out['cases']), 10 + 2 * 6)

    def test_deterministic_and_same_variants_in_both_themes(self):
        full = self.manifest(self.SURFACES)
        first = sampling.sample_themes(full, {})
        self.assertEqual(first, sampling.sample_themes(full, {}))
        for surface in self.SURFACES:
            self.assertEqual(self.names(first, 'elegant-light', surface), self.names(first, 'elegant-dark', surface))

    def test_all_themes_switch_keeps_everything(self):
        full = self.manifest(self.SURFACES)
        self.assertEqual(sampling.sample_themes(full, {'PARITY_EXT_ALL_THEMES': '1'}), full)

    def test_all_dark_switch_keeps_dark_complete_but_light_sampled(self):
        full = self.manifest(self.SURFACES)
        out = sampling.sample_themes(full, {'PARITY_EXT_ALL_DARK': '1'})
        self.assertEqual(self.names(out, 'elegant-dark', 'components.a.list'), self.SURFACES['components.a.list'])
        self.assertEqual(self.names(out, 'elegant-light', 'components.a.list'), ['default', 'many-rows'])

    def test_every_repo_surface_keeps_one_or_two_cases_per_sampled_theme(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            target = builders.build_manifest(pathlib.Path(tmp))
            full = json.loads(target.read_text())
        out = sampling.sample_themes(full, {})
        for theme in sampling.SAMPLED_THEMES:
            per = {}
            for c in out['cases']:
                if c['theme'] == theme:
                    per.setdefault(sampling.surface_of(c['id']), []).append(c['id'])
            wanted = {sampling.surface_of(c['id']) for c in full['cases'] if c['theme'] == theme}
            self.assertEqual(set(per), wanted)
            self.assertTrue(all(1 <= len(v) <= 2 for v in per.values()))
        self.assertEqual(sum(c['theme'] == 'brutal-light' for c in out['cases']),
                         sum(c['theme'] == 'brutal-light' for c in full['cases']))


class FrameFixtureContractTest(unittest.TestCase):
    def test_channel_tasks_use_the_canonical_empty_projection(self):
        with tempfile.TemporaryDirectory() as tmp:
            builders.build_manifest(pathlib.Path(tmp))
        frame = json.loads((EXT / 'fixtures/frame.json').read_text())
        screens = json.loads((EXT / 'fixtures/screens.json').read_text())
        channel = screens['scenes']['channel']['selected']
        self.assertEqual(frame['routeSets']['fr-channel'].get(f'GET /tasks/channel/{channel}'), {'tasks': []})


class ChannelSettingsFixtureContractTest(unittest.TestCase):
    def test_channel_task_responses_match_both_clients(self):
        with tempfile.TemporaryDirectory() as tmp:
            ext = pathlib.Path(tmp)
            (ext / 'fixtures').mkdir()
            for name in ('builders.py', 'build-channel-settings.py'):
                shutil.copyfile(EXT / name, ext / name)
            manifest = ext / 'manifest.json'
            manifest.write_text('{"cases": []}')
            subprocess.run(
                [sys.executable, str(ext / 'build-channel-settings.py')],
                env={**os.environ, 'PARITY_EXT_MANIFEST': str(manifest)},
                check=True, capture_output=True, text=True,
            )
            generated = json.loads((ext / 'fixtures/channelsettings.json').read_text())
        checked = json.loads((EXT / 'fixtures/channelsettings.json').read_text())
        derived = json.loads((EXT / 'fixtures/members-pages-channel.json').read_text())
        task_routes = []
        for fixture in (generated, checked, derived):
            routes = {key: value for key, value in fixture['routes'].items()
                      if key.startswith('GET /tasks/channel/')}
            self.assertTrue(routes)
            for key, value in routes.items():
                self.assertEqual(value, {'tasks': []}, key)
            task_routes.append(routes)
        self.assertEqual(task_routes[0], task_routes[1])
        self.assertEqual(task_routes[1], task_routes[2])


class FeedbackFixtureScopeTest(unittest.TestCase):
    def test_feedback_cases_bind_their_own_route_family(self):
        with tempfile.TemporaryDirectory() as tmp:
            manifest = json.loads(builders.build_manifest(pathlib.Path(tmp)).read_text())
        feedback = [case for case in manifest['cases']
                    if case['id'].startswith('components.ext-settings.feedback.')]
        self.assertTrue(feedback)
        for case in feedback:
            props = case['variants'][0]['props']
            self.assertEqual(props.get('extFixture'), 'settings', case['id'])


class DesktopDownloadFixtureContractTest(unittest.TestCase):
    def test_about_families_supply_a_platform_status_for_every_os(self):
        with tempfile.TemporaryDirectory() as tmp:
            builders.build_manifest(pathlib.Path(tmp))
        for family in ('settings', 'public-server'):
            with self.subTest(family=family):
                fixture = json.loads((EXT / f'fixtures/{family}.json').read_text())
                response = fixture['routes'].get('GET /desktop-download/platforms')
                self.assertIsInstance(response, dict)
                self.assertEqual(set(response), {'mac', 'linux', 'windows'})
                for platform in response.values():
                    self.assertIn(platform['status'], {'available', 'none', 'unknown'})
                    if platform['status'] == 'available':
                        self.assertIsInstance(platform['version'], str)


class PageInventoryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ctx = inventory.default_context()  # manifest from the builders, official ids when the checkout exists

    def test_rows_and_id_globs_are_consistent(self):
        self.assertEqual(inventory.problems(self.ctx), [])

    def test_document_renders_without_a_committed_copy(self):
        self.assertFalse((ROOT / 'docs/parity-page-inventory.md').exists(),
                         'the inventory is generated on demand: python3 tool/parity-ext/inventory.py --write <path>')
        text = inventory.render(self.ctx)
        self.assertIn('## Prioritized missing pages', text)
        self.assertIn('## Cases no row claims', text)
        self.assertNotIn('wip', text.split('## Summary')[1].split('## Prioritized')[0])

    def test_status_is_computed_from_existing_case_ids(self):
        row = inventory.Row('9.99', 'demo', 'x.tsx', 'DP', off=['components.demo.official'],
                            d=['components.demo.desktop.*', '!*.skip'], p=['components.demo.mobile.a'])
        cases = [('components.demo.desktop.a', 1280), ('components.demo.desktop.skip', 1280), ('components.demo.mobile.a', 390)]
        st = lambda ctx, plat: row.state(plat, ctx)
        # official ids unknown (no checkout) count as existing
        self.assertEqual((st(inventory.Context(cases), 'D'), st(inventory.Context(cases), 'P')), ('ok', 'ok'))
        # nothing built yet: expected ids, no cases
        none = inventory.Context([], official=[])
        self.assertEqual((st(none, 'D'), st(none, 'P')), ('MISSING', 'MISSING'))
        # only part of the expected phone ids exist
        part = inventory.Context([('components.demo.mobile.a', 390)], official=[])
        self.assertEqual(st(part, 'P'), 'partial')
        # negations only remove matches
        only_skip = inventory.Context([('components.demo.desktop.skip', 1280)], official=[])
        self.assertEqual(st(only_skip, 'D'), 'MISSING')
        # noFlutterSurface-only coverage
        web = inventory.Context(cases, official=['components.demo.official'], web_only={'components.demo.desktop.a'})
        self.assertEqual(st(web, 'D'), 'web-only')
        self.assertEqual(st(web, 'P'), 'ok')
        # a case appearing flips the status without touching the row
        later = inventory.Context(cases + [('components.demo.mobile.b', 390)], official=['components.demo.official'])
        self.assertEqual(st(later, 'P'), 'ok')
        # mark: known fewer states than the page has
        marked = inventory.Row('9.98', 'demo', 'x.tsx', 'D', d=['components.demo.desktop.*'], d_state='partial')
        self.assertEqual(marked.state('D', inventory.Context(cases)), 'partial')
        self.assertEqual(marked.state('P', inventory.Context(cases)), 'n/a')
        self.assertEqual(inventory.Row('9.97', 'demo', 'x', 'D', d=['components.demo.*'],
                                       excl=('obsolete', 'reason')).state('D', inventory.Context(cases)), 'excluded')

    def test_problems_report_malformed_globs_and_wrong_platform_matches(self):
        bad = inventory.Row('9.96', 'demo', 'x', 'D', d=['nothing.demo', 'components.demo.*'], p=['components.demo.*'])
        ctx = inventory.Context([('components.demo.a', 390)])
        with mock.patch.object(inventory, 'all_rows', return_value=[bad]):
            out = inventory.problems(ctx)
        self.assertTrue(any('malformed or unknown extension id prefix: nothing.demo' in o for o in out), out)
        self.assertTrue(any('desktop glob components.demo.* matches a 390 wide' in o for o in out), out)
        self.assertTrue(any('extension ids given for P' in o for o in out), out)
        # an expected id with no case yet is fine
        ok = inventory.Row('9.95', 'demo', 'x', 'D', d=['components.not-built-yet.*'])
        with mock.patch.object(inventory, 'all_rows', return_value=[ok]):
            self.assertEqual(inventory.problems(inventory.Context([])), [])

    def test_row_numbers_are_unique_and_states_are_known(self):
        rows = inventory.all_rows()
        self.assertEqual(len({r.num for r in rows}), len(rows))
        for r in rows:
            self.assertIn(r.prio, (1, 2, 3))
            self.assertTrue(set(r.ap) <= set('DP') and r.ap, r.num)
            self.assertTrue({r.state('D'), r.state('P')} <= {'ok', 'partial', 'web-only', 'MISSING', 'n/a', 'excluded'})

    def test_missing_list_is_ordered_by_priority(self):
        prios = [r.prio for r in inventory.missing_rows()]
        self.assertEqual(prios, sorted(prios))
        self.assertTrue(all('MISSING' in (r.state('D'), r.state('P')) for r in inventory.missing_rows()))

    def test_excluded_rows_have_a_known_reason_and_stay_out_of_the_ranking(self):
        excluded = inventory.excluded_rows()
        self.assertTrue(excluded)
        for r in excluded:
            reason, evidence = r.excl
            self.assertIn(reason, inventory.REASONS, r.num)
            self.assertGreater(len(evidence), 20, f'{r.num}: cite evidence')
            self.assertEqual({r.state(p) for p in r.ap}, {'excluded'})
        ranked = {r.num for r in inventory.missing_rows()}
        self.assertFalse(ranked & {r.num for r in excluded})
        self.assertTrue(all(reason in inventory.REASONS for _, reason, _ in inventory.EXCLUDED))
        counts = inventory.counts()
        self.assertEqual(counts['rows'] + sum(counts['excluded'].values()), counts['all_rows'])
