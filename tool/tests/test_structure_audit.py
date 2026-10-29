"""Hotspot ratchet policy and real AST anti-bypass fixtures."""
import contextlib
import copy
import datetime
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
LOADER = importlib.machinery.SourceFileLoader('structure_audit', str(ROOT / 'tool/structure-audit'))
SPEC = importlib.util.spec_from_loader('structure_audit', LOADER)
audit = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(audit)
TODAY = datetime.date(2026, 10, 14)


def baseline(metrics=None):
    return {'version': 1, 'modules': {'workspace_controller': {
        'root': 'apps/raft_flutter/lib/root.dart',
        'metrics': metrics or {'lines': 10, 'tokens': 50, 'field.Root.old': 1}}}, 'exceptions': []}


def report(metrics):
    return {'modules': {'workspace_controller': {'metrics': metrics, 'files': ['root.dart']}}}


def exception(**overrides):
    return dict(module='workspace_controller', metric='tokens', limit=55,
                reason='necessary bug repair', reviewer='Cindy', expires='2026-10-15', **overrides)


class PolicyTest(unittest.TestCase):
    def test_compacting_cannot_hide_token_growth_or_new_field(self):
        growth, lower, _ = audit.compare(baseline(), report({
            'lines': 1, 'tokens': 51, 'field.Root.new': 1}), {})
        self.assertIn(('workspace_controller', 'tokens', 50, 51), growth)
        self.assertIn(('workspace_controller', 'field.Root.new', 0, 1), growth)
        self.assertIn(('workspace_controller', 'field.Root.old', 1, 0), lower)

    def test_exception_is_exact_bounded_and_needs_approved_reviewer(self):
        document = baseline()
        document['exceptions'] = [exception()]
        limits = audit.validate(document, TODAY)
        growth, _, allowed = audit.compare(document, report({'lines': 10, 'tokens': 55}), limits)
        self.assertEqual(growth, [])
        self.assertEqual(allowed, [('workspace_controller', 'tokens', 50, 55)])
        self.assertTrue(audit.compare(document, report({'lines': 11, 'tokens': 56}), limits)[0])
        for field, value in [('reviewer', 'anyone'), ('reason', ''), ('limit', True),
                             ('module', 'other'), ('expires', 'later')]:
            invalid = copy.deepcopy(document)
            invalid['exceptions'][0][field] = value
            with self.subTest(field=field), self.assertRaises(audit.AuditError):
                audit.validate(invalid, TODAY)

    def test_expiry_uses_injected_date_and_rejects_duplicate_or_stale_exception(self):
        document = baseline()
        document['exceptions'] = [exception()]
        audit.validate(document, TODAY)
        for day in [datetime.date(2026, 10, 15), datetime.date(2026, 10, 16)]:
            with self.assertRaisesRegex(audit.AuditError, 'expired'):
                audit.validate(document, day)
        document['exceptions'] *= 2
        with self.assertRaisesRegex(audit.AuditError, 'duplicate'):
            audit.validate(document, TODAY)

    def test_update_lowers_only_and_never_bakes_in_an_exception(self):
        document = baseline()
        document['exceptions'] = [exception()]
        lower = audit.lower_baseline(copy.deepcopy(document), report({'lines': 9, 'tokens': 49}))
        self.assertEqual(lower['modules']['workspace_controller']['metrics'],
                         {'lines': 9, 'tokens': 49, 'field.Root.old': 0})
        with self.assertRaisesRegex(audit.AuditError, 'cannot raise'):
            audit.lower_baseline(document, report({'lines': 9, 'tokens': 51}))

    def test_module_update_preserves_unrelated_approved_growth(self):
        document = baseline()
        document['modules']['main'] = {
            'root': 'apps/raft_flutter/lib/main.dart',
            'metrics': {'lines': 10, 'tokens': 50},
        }
        approved = exception()
        approved['module'] = 'main'
        document['exceptions'] = [approved]
        measured = report({'lines': 9, 'tokens': 49})
        measured['modules']['main'] = {'metrics': {'lines': 10, 'tokens': 51}}
        original = copy.deepcopy(document)
        with self.assertRaisesRegex(audit.AuditError, 'cannot raise'):
            audit.lower_baseline(copy.deepcopy(document), measured)
        lowered = audit.lower_baseline(document, measured, ['workspace_controller'])
        self.assertEqual(lowered['modules']['workspace_controller']['metrics'],
                         {'lines': 9, 'tokens': 49, 'field.Root.old': 0})
        self.assertEqual(lowered['modules']['main'], original['modules']['main'])
        self.assertEqual(lowered['exceptions'], original['exceptions'])
        with self.assertRaisesRegex(audit.AuditError, 'cannot raise'):
            audit.lower_baseline(copy.deepcopy(original), measured, ['main'])

    def test_module_update_rejects_unknown_scope_without_mutation(self):
        document = baseline()
        before = copy.deepcopy(document)
        with self.assertRaisesRegex(audit.AuditError, 'existing baseline module'):
            audit.lower_baseline(document, report({'lines': 9, 'tokens': 49}), ['typo'])
        self.assertEqual(document, before)

    def test_module_flag_only_updates_explicit_scope(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'baseline.json'
            path.write_text(json.dumps(baseline()))
            with mock.patch.object(audit, 'BASELINE', path), mock.patch.object(
                    audit, 'run_scanner', return_value=report({'lines': 9, 'tokens': 49})), \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(audit.main(['--update', '--module', 'workspace_controller'], today=TODAY), 0)
            self.assertEqual(json.loads(path.read_text())['modules']['workspace_controller']['metrics']['lines'], 9)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            audit.main(['--check', '--module', 'workspace_controller'], today=TODAY)
        self.assertEqual(error.exception.code, 2)

    def test_check_exit_message_and_no_implicit_baseline_write(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'baseline.json'
            path.write_text(json.dumps(baseline()))
            before = path.read_bytes()
            output = io.StringIO()
            with mock.patch.object(audit, 'BASELINE', path), mock.patch.object(
                    audit, 'run_scanner', return_value=report({'lines': 10, 'tokens': 51})), \
                    contextlib.redirect_stdout(output):
                self.assertEqual(audit.main(['--check'], today=TODAY), 1)
            self.assertIn('GROW workspace_controller/tokens: 50 -> 51', output.getvalue())
            self.assertIn('existing domain owner', output.getvalue())
            self.assertIn('reviewer', output.getvalue())
            self.assertEqual(path.read_bytes(), before)


class SyntaxTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        config = ROOT / '.dart_tool/package_config.json'
        names = ({p['name'] for p in json.loads(config.read_text())['packages']}
                 if config.is_file() else set())
        if not {'analyzer', 'ds_audit'} <= names:
            message = (
                'AST fixtures need resolved workspace dependencies; run '
                '`TMPDIR=$HOME/.cache/tmp-cindy tool/flutter pub get --enforce-lockfile` '
                'at the repository root. The project gate requires these fixtures.')
            if os.environ.get('RAFT_PROJECT_GATE') == '1':
                raise AssertionError(message)
            raise unittest.SkipTest(message)

    def test_parts_extensions_aliases_and_transitive_facades_stay_in_scope(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            lib = root / 'apps/raft_flutter/lib'
            lib.mkdir(parents=True)
            config = root / 'baseline.json'
            config.write_text(json.dumps(baseline()))
            (lib / 'root.dart').write_text("part 'part.dart'; class Root { int a = 1; }")
            (lib / 'part.dart').write_text("part of 'root.dart'; class Page { final values = <int>[]; } class Primary(final int owned);")
            initial = audit.run_scanner(config, root)['modules']['workspace_controller']
            self.assertEqual(set(initial['files']), {
                'apps/raft_flutter/lib/root.dart', 'apps/raft_flutter/lib/part.dart'})
            self.assertEqual(initial['metrics']['field.Root.a'], 1)
            self.assertEqual(initial['metrics']['field.Page.values'], 1)
            self.assertEqual(initial['metrics']['field.Primary.owned'], 1)
            # A comment/line-format change cannot erase non-comment tokens.
            (lib / 'root.dart').write_text("// comments do not count as tokens\npart 'part.dart';\nclass Root { int a = 1; }\n")
            same = audit.run_scanner(config, root)['modules']['workspace_controller']
            self.assertEqual(initial['metrics']['tokens'], same['metrics']['tokens'])
            (lib / 'extension.dart').write_text('extension Actions on Root { int extra() => 2; }')
            (lib / 'child.dart').write_text('class Child extends Root { int newState = 0; }')
            (lib / 'grandchild.dart').write_text('class Leaf implements Child {}')
            (lib / 'alias.dart').write_text('class Alias = Root with Extra;')
            (lib / 'typedef.dart').write_text('typedef Renamed = Root;')
            (lib / 'alias_extension.dart').write_text('extension More on Renamed { int more() => 3; }')
            (lib / 'unrelated.dart').write_text('class Unrelated { int ignored = 0; }')
            current = audit.run_scanner(config, root)['modules']['workspace_controller']
            self.assertEqual(len(current['files']), 8)
            self.assertNotIn('apps/raft_flutter/lib/unrelated.dart', current['files'])
            self.assertIn('Leaf', current['types'])
            self.assertIn('Alias', current['types'])
            document = baseline(initial['metrics'])
            growth = audit.compare(document, {'modules': {'workspace_controller': current}}, {})[0]
            self.assertIn(('workspace_controller', 'field.Child.newState', 0, 1), growth)
            self.assertTrue(any(metric == 'tokens' for _, metric, _, _ in growth))

    def test_invalid_source_and_missing_part_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            lib = root / 'apps/raft_flutter/lib'
            lib.mkdir(parents=True)
            config = root / 'baseline.json'
            config.write_text(json.dumps(baseline()))
            for source in ['class Broken {', "part 'missing.dart'; class Root {}"]:
                (lib / 'root.dart').write_text(source)
                with self.subTest(source=source), self.assertRaises(audit.AuditError):
                    audit.run_scanner(config, root)


class DependencyPreflightTest(unittest.TestCase):
    def test_manual_run_without_dependencies_explains_skip(self):
        with tempfile.TemporaryDirectory() as temp, \
                mock.patch.dict(os.environ, {'RAFT_PROJECT_GATE': '0'}), \
                mock.patch(__name__ + '.ROOT', Path(temp)):
            with self.assertRaisesRegex(unittest.SkipTest, 'pub get --enforce-lockfile'):
                SyntaxTest.setUpClass()

    def test_project_gate_without_dependencies_fails_instead_of_skipping(self):
        with tempfile.TemporaryDirectory() as temp, \
                mock.patch.dict(os.environ, {'RAFT_PROJECT_GATE': '1'}), \
                mock.patch(__name__ + '.ROOT', Path(temp)):
            with self.assertRaisesRegex(AssertionError, 'pub get --enforce-lockfile'):
                SyntaxTest.setUpClass()


if __name__ == '__main__':
    unittest.main()
